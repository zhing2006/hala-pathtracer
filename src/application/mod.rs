use anyhow::{Result, Context};
use winit::{
  event::{Event, WindowEvent},
  event_loop::{ControlFlow, EventLoop},
  window::{WindowBuilder, WindowButtons},
};

use super::config;

/// The application.
#[derive(Default)]
pub struct MainLoop {
  pub name: String,
  pub win_config: config::WindowConfig,
}

/// The trait of the application.
pub trait Application {
  fn before_run(&mut self, width: u16, height: u16, window: &winit::window::Window) -> Result<()>;
  fn after_run(&mut self);
  fn update(&mut self, delta_time: f64, width: u16, height: u16) -> Result<()>;
  fn render(&mut self) -> Result<()>;
  fn key_pressed(&mut self, key: winit::keyboard::Key);
  fn key_released(&mut self, key: winit::keyboard::Key);
}

/// The implementation of the application.
impl MainLoop {
  /// Create a new application.
  pub fn new(name: &str, config: &config::AppConfig) -> Self {
    log::debug!("Create a new application \"{}\".", name);

    Self {
      name: name.to_string(),
      win_config: config.window.clone(),
    }
  }

  /// Run the application.
  /// param name: The name of the application.
  /// param config: The config of the application.
  pub fn run(&self, app_impl: &'static mut impl Application) -> Result<()> {
    // Create window.
    let event_loop = EventLoop::new().unwrap();
    let window = WindowBuilder::new()
      .with_title(&self.name)
      .with_inner_size(winit::dpi::PhysicalSize::new(self.win_config.width, self.win_config.height))
      .with_resizable(false)
      .with_enabled_buttons(WindowButtons::CLOSE)
      .build(&event_loop)
      .with_context(|| "Failed to create a new window.")?;

    app_impl.before_run(self.win_config.width, self.win_config.height, &window)
      .with_context(|| "Failed to run the application.")?;

    let mut last_time = std::time::Instant::now();

    event_loop.run(move |event, elwt| {
      elwt.set_control_flow(ControlFlow::Poll);
      match event {
        Event::WindowEvent {
          event,
          window_id,
        } => match event {
          WindowEvent::KeyboardInput { event, is_synthetic, .. } if window_id == window.id() => {
            if !is_synthetic {
              if event.state == winit::event::ElementState::Released {
                app_impl.key_released(event.logical_key);
              } else {
                app_impl.key_pressed(event.logical_key);
              }
            }
          },
          WindowEvent::CloseRequested if window_id == window.id() => {
            app_impl.after_run();
            unsafe {
              let b = Box::from_raw(app_impl);
              drop(b);
            }
            elwt.exit()
          },
          WindowEvent::RedrawRequested if window_id == window.id() => {
            let now = std::time::Instant::now();
            let duration = now - last_time;
            let delta_time = duration.as_secs_f64();
            last_time = std::time::Instant::now();
            let window_size = window.inner_size();
            match app_impl.update(delta_time, window_size.width as u16, window_size.height as u16) {
              Ok(_) => {
                match app_impl.render() {
                  Ok(_) => (),
                  Err(e) => {
                    log::error!("Failed to render the application: {}", e);
                    elwt.exit()
                  },
                }
              },
              Err(e) => {
                log::error!("Failed to update the application: {}", e);
                elwt.exit()
              },
            }
          },
          _ => (),
        },
        Event::AboutToWait => window.request_redraw(),
        _ => (),
      }
    })?;

    Ok(())
  }
}