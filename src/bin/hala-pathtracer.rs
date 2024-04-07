use anyhow::{
  Result,
  Context,
};
use log::LevelFilter;
use log4rs::append::console::ConsoleAppender;
use log4rs::append::rolling_file::RollingFileAppender;
use log4rs::encode::pattern::PatternEncoder;
use log4rs::config::{Appender, Config, Root};
use clap::{arg, Command};

use hala_pathtracer::{
  config,
  application,
};

use hala_renderer::{
  rt_renderer,
  scene,
};

/// The PathTracer renderer application.
struct PathTracerApplication {
  config: config::AppConfig,
  renderer: Option<rt_renderer::HalaRenderer>,
}

/// The implementation of the PathTracer renderer application.
impl PathTracerApplication {
  pub fn new(config: config::AppConfig) -> Self {
    Self {
      config,
      renderer: None,
    }
  }
}

/// The implementation of the application trait for the PathTracer renderer application.
impl application::Application for PathTracerApplication {
  /// The before run function.
  /// param width: The width of the window.
  /// param height: The height of the window.
  /// param window: The window.
  /// return: The result.
  fn before_run(&mut self, _width: u16, _height: u16, window: &winit::window::Window) -> Result<()> {
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

    let mut renderer = rt_renderer::HalaRenderer::new(
      "PathTracer",
      &gpu_req,
      window,
      true,
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
      "env_radiance.rcall.spv",
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
    log::info!("Load and setup envmap used {}ms", now.elapsed().as_millis());

    renderer.commit()?;

    self.renderer = Some(renderer);

    Ok(())
  }

  /// The after run function.
  fn after_run(&mut self) {
    if let Some(renderer) = &mut self.renderer {
      renderer.wait_idle().expect("Failed to wait the renderer idle.");
    }
    self.renderer.take();
  }

  /// The update function.
  /// param delta_time: The delta time.
  /// return: The result.
  fn update(&mut self, delta_time: f64, width: u16, height: u16) -> Result<()> {
    if let Some(renderer) = &mut self.renderer {
      renderer.update(delta_time, width as u32, height as u32)?;
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

  /// The key pressed function.
  /// param key: The key.
  fn key_pressed(&mut self, key: winit::keyboard::Key) {
    if key == "s" {
      if let Some(renderer) = &mut self.renderer {
        let scene_path = std::path::Path::new(&self.config.scene_file);
        let scene_name = scene_path.file_stem().unwrap().to_str().unwrap();
        let save_path = format!("./out/{}", scene_name);
        renderer.save_images(save_path).expect("Failed to save the image.");
      }
    }
  }

  /// The key released function.
  /// param key: The key.
  fn key_released(&mut self, _key: winit::keyboard::Key) {
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
  // Parse the command line arguments.
  let matches = cli().get_matches();
  let log_file = match matches.get_one::<String>("log") {
    Some(log_file) => log_file,
    None => "./logs/pathtracer.log"
  };
  let config_file = matches.get_one::<String>("config").with_context(|| "Failed to get the config file path.")?;

  // Setup the log4rs config.
  let console_encoder = Box::new(PatternEncoder::new("{d(%H:%M:%S)} {h({l:<5})} {t:<20.20} - {m}{n}"));
  let file_encoder = Box::new(PatternEncoder::new("{d(%Y-%m-%d %H:%M:%S)} {h({l:<5})} {f}:{L} - {m}{n}"));
  let stdout = ConsoleAppender::builder()
    .encoder(console_encoder)
    .build();
  let rolling_file = RollingFileAppender::builder()
    .encoder(file_encoder)
    .append(true)
    .build(log_file, Box::new(log4rs::append::rolling_file::policy::compound::CompoundPolicy::new(
      Box::new(log4rs::append::rolling_file::policy::compound::trigger::size::SizeTrigger::new(1024 * 1024 /* 1MB */)),
      Box::new(log4rs::append::rolling_file::policy::compound::roll::fixed_window::FixedWindowRoller::builder()
        .build(&format!("{}.{}.gz", log_file, "{}"), 5)
        .context("Failed to create the rolling file policy.")?)),
    )).context("Failed to create the rolling file appender.")?;
  let config = Config::builder()
    .appender(Appender::builder().build("stdout", Box::new(stdout)))
    .appender(Appender::builder().build("rolling_file", Box::new(rolling_file)));
  let config = if cfg!(debug_assertions) {
    config.build(Root::builder().appenders(["stdout", "rolling_file"]).build(LevelFilter::Debug))
  } else {
    config.build(Root::builder().appenders(["stdout", "rolling_file"]).build(LevelFilter::Info))
  }.context("Failed to build the log4rs config.")?;

  let _ = log4rs::init_config(config).context("Failed to initialize the log4rs config.")?;
  log::info!("Starting PathTracer renderer...");

  // Load the configure.
  let config = config::load_app_config(config_file)?;
  log::debug!("Config: {:?}", config);
  config::validate_app_config(&config)?;

  // Create out directory.
  std::fs::create_dir_all("./out")
    .with_context(|| "Failed to create the output directory: ./out")?;

  // Initialize the application.
  let main_loop = application::MainLoop::new("PathTracer", &config);
  let pathtracer = Box::new(PathTracerApplication::new(config));
  main_loop.run(Box::leak(pathtracer))?;

  Ok(())
}