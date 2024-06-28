use anyhow::{
  Result,
  Context,
};

use clap::{arg, Command};

use hala_pathtracer::config;

use hala_renderer::{
  renderer::HalaRendererTrait,
  rt_renderer::HalaRenderer,
  scene,
};

use hala_imgui::{
  HalaApplication,
  HalaImGui,
};

/// The PathTracer renderer application.
struct PathTracerApplication {
  log_file: String,
  config: config::AppConfig,
  renderer: Option<HalaRenderer>,
  imgui: Option<HalaImGui>,
}

/// The implementation of the PathTracer renderer application.
impl PathTracerApplication {
  pub fn new() -> Result<Self> {
    // Parse the command line arguments.
    let matches = cli().get_matches();
    let log_file = match matches.get_one::<String>("log") {
      Some(log_file) => log_file,
      None => "./logs/pathtracer.log"
    };
    let config_file = matches.get_one::<String>("config").with_context(|| "Failed to get the config file path.")?;

    // Load the configure.
    let config = config::load_app_config(config_file)?;
    log::debug!("Config: {:?}", config);
    config::validate_app_config(&config)?;

    // Create out directory.
    std::fs::create_dir_all("./out")
      .with_context(|| "Failed to create the output directory: ./out")?;

    Ok(Self {
      log_file: log_file.to_string(),
      config,
      renderer: None,
      imgui: None,
    })
  }
}

/// The implementation of the application trait for the PathTracer renderer application.
impl HalaApplication for PathTracerApplication {
  fn get_log_console_fmt(&self) -> &str {
    "{d(%H:%M:%S)} {h({l:<5})} {t:<20.20} - {m}{n}"
  }
  fn get_log_file_fmt(&self) -> &str {
    "{d(%Y-%m-%d %H:%M:%S)} {h({l:<5})} {f}:{L} - {m}{n}"
  }
  fn get_log_file(&self) -> &std::path::Path {
    std::path::Path::new(self.log_file.as_str())
  }
  fn get_log_file_size(&self) -> u64 {
    1024 * 1024 /* 1MB */
  }
  fn get_log_file_roller_count(&self) -> u32 {
    5
  }

  fn get_window_title(&self) -> &str {
    "PathTracer"
  }
  fn get_window_size(&self) -> winit::dpi::PhysicalSize<u32> {
    winit::dpi::PhysicalSize::new(self.config.window.width as u32, self.config.window.height as u32)
  }

  fn get_imgui(&self) -> Option<&HalaImGui> {
    self.imgui.as_ref()
  }
  fn get_imgui_mut(&mut self) -> Option<&mut HalaImGui> {
    self.imgui.as_mut()
  }

  /// The before run function.
  /// param width: The width of the window.
  /// param height: The height of the window.
  /// param window: The window.
  /// return: The result.
  fn before_run(&mut self, _width: u32, _height: u32, window: &winit::window::Window) -> Result<()> {
    let now = std::time::Instant::now();
    let scene = scene::cpu::HalaScene::new(&self.config.scene_file)?;
    log::info!("Load scene used {}ms", now.elapsed().as_millis());

    // Find all required features.
    let use_medium = scene.has_medium();
    let use_vol_mis = use_medium;
    let use_transparent = scene.has_transparent();
    let mut features = vec!["PATH_TRACER"];
    if use_medium {
      features.push("MEDIUM");
    }
    if use_vol_mis {
      features.push("VOL_MIS");
    }
    if use_transparent {
      features.push("TRANSPARENT");
    }

    // Setup the renderer.
    let gpu_req = hala_gfx::HalaGPURequirements {
      width: self.config.window.width as u32,
      height: self.config.window.height as u32,
      version: (1, 3, 0),
      require_ray_tracing: true,
      require_10bits_output: false,
      is_low_latency: true,
      require_depth: true,
      ..Default::default()
    };

    let mut renderer = HalaRenderer::new(
      "PathTracer",
      &gpu_req,
      window,
      self.config.tracer.max_depth as u32,
      self.config.tracer.rr_depth as u32,
      self.config.tracer.tonemap.enable,
      self.config.tracer.tonemap.enable_aces,
      self.config.tracer.tonemap.use_simple_aces,
      self.config.tracer.max_samples as u64,
    )?;

    let shaders_dir = if cfg!(debug_assertions) {
      format!("shaders/output/debug/hala-pathtracer/{}", features.join("#"))
    } else {
      format!("shaders/output/release/hala-pathtracer/{}", features.join("#"))
    };
    renderer.push_general_shader_with_file(
      &format!("{}/pathtracer.rgen.spv", shaders_dir),
      hala_gfx::HalaShaderStageFlags::RAYGEN,
      hala_gfx::HalaRayTracingShaderGroupType::GENERAL,
      "pathtracer.rgen.spv")?;
    renderer.push_general_shader_with_file(
      &format!("{}/pathtracer.rmiss.spv", shaders_dir),
      hala_gfx::HalaShaderStageFlags::MISS,
      hala_gfx::HalaRayTracingShaderGroupType::GENERAL,
      "pathtracer.rmiss.spv")?;
    renderer.push_general_shader_with_file(
      &format!("{}/shadow_ray.rmiss.spv", shaders_dir),
      hala_gfx::HalaShaderStageFlags::MISS,
      hala_gfx::HalaRayTracingShaderGroupType::GENERAL,
      "shadow_ray.rmiss.spv")?;
    renderer.push_hit_shaders_with_file(
      Some(&format!("{}/triangles.rchit.spv", shaders_dir)),
      None,
      None,
      "triangles")?;
    renderer.push_hit_shaders_with_file(
      Some(&format!("{}/lights.rchit.spv", shaders_dir)),
      None,
      Some(&format!("{}/lights.rint.spv", shaders_dir)),
      "lights")?;
    let callables = vec![
      "perspective_ray.rcall.spv",
      "orthographic_ray.rcall.spv",
      "env_sky_eval.rcall.spv",
      "env_sky_sample.rcall.spv", // NOTICE: Empty, should not use it.
      "env_map_eval.rcall.spv",
      "env_map_sample.rcall.spv",
      "point_light_sample.rcall.spv",
      "directional_light_sample.rcall.spv",
      "spot_light_sample.rcall.spv",
      "quad_light_sample.rcall.spv",
      "sphere_light_sample.rcall.spv",
      "diffuse_bxdf_eval.rcall.spv",
      "diffuse_bxdf_sample.rcall.spv",
      "disney_bxdf_eval.rcall.spv",
      "disney_bxdf_sample.rcall.spv",
    ];
    for callable in callables {
      renderer.push_general_shader_with_file(
        &format!("{}/{}", shaders_dir, callable),
        hala_gfx::HalaShaderStageFlags::CALLABLE,
        hala_gfx::HalaRayTracingShaderGroupType::GENERAL,
        callable)?;
    }

    renderer.load_blue_noise_texture("./assets/textures/blue_noise.png")?;

    let now = std::time::Instant::now();
    renderer.set_scene(&scene)?;
    log::info!("Setup scene used {}ms", now.elapsed().as_millis());

    let now = std::time::Instant::now();
    if !self.config.hdri_file.is_empty() {
      renderer.set_envmap(&self.config.hdri_file, self.config.hdri_rotation)?;
    } else {
      renderer.set_ground_color(glam::Vec4::new(self.config.ground_color[0], self.config.ground_color[1], self.config.ground_color[2], 1.0));
      renderer.set_sky_color(glam::Vec4::new(self.config.sky_color[0] * 4.0, self.config.sky_color[1] * 4.0, self.config.sky_color[2] * 4.0, 1.0));
    }
    renderer.set_env_intensity(self.config.env_intensity);
    log::info!("Load and setup envmap used {}ms", now.elapsed().as_millis());

    renderer.set_exposure_value(self.config.tracer.exposure_value);

    renderer.commit()?;

    self.imgui = Some(HalaImGui::new(
      std::rc::Rc::clone(&(*renderer.resources().context)),
      false,
    )?);

    self.renderer = Some(renderer);

    Ok(())
  }

  /// The after run function.
  fn after_run(&mut self) {
    if let Some(renderer) = &mut self.renderer.take() {
      renderer.wait_idle().expect("Failed to wait the renderer idle.");
      self.imgui.take();
    }
  }

  /// The update function.
  /// param delta_time: The delta time.
  /// return: The result.
  fn update(&mut self, delta_time: f64, width: u32, height: u32) -> Result<()> {
    if let Some(imgui) = self.imgui.as_mut() {
      imgui.begin_frame(
        delta_time,
        width,
        height,
        |ui| {
          ui.window("Path Tracer")
            .position([10.0, 10.0], imgui::Condition::FirstUseEver)
            .build(|| {
              if ui.button_with_size("Save", [100.0, 30.0]) {
                if let Some(renderer) = &mut self.renderer {
                  let scene_path = std::path::Path::new(&self.config.scene_file);
                  let scene_name = scene_path.file_stem().unwrap().to_str().unwrap();
                  let save_path = format!("./out/{}", scene_name);
                  renderer.save_images(save_path).expect("Failed to save the image.");
                }
              }
            }
          );
        }
      )?;
      imgui.end_frame()?;
    }

    if let Some(renderer) = &mut self.renderer {
      renderer.update(
        delta_time,
        width,
        height,
        |index, command_buffers| {
          if let Some(imgui) = self.imgui.as_mut() {
            imgui.draw(index, command_buffers)?;
          }

          Ok(())
        }
      )?;
    }

    Ok(())
  }

  /// The render function.
  /// return: The result.
  fn render(&mut self) -> Result<()> {
    if let Some(renderer) = &mut self.renderer {
      renderer.render()?;
    }

    Ok(())
  }

}

/// The PathTracer renderer command line interface.
fn cli() -> Command {
  Command::new("pathtracer")
    .about("The PathTracer renderer.")
    .arg_required_else_help(true)
    .arg(arg!(-l --log [LOG_FILE] "The file path of the log file. Default is ./logs/pathtracer.log.").required(false))
    .arg(arg!(-c --config <CONFIG_FILE> "The file path of the config file."))
}

/// The normal main function.
fn main() -> Result<()> {
  // Initialize the application.
  let mut app = PathTracerApplication::new()?;
  app.init()?;

  // Run the application.
  app.run()?;

  Ok(())
}