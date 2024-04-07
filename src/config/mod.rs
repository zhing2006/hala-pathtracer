use anyhow::{Result, Context};
use serde::Deserialize;

mod window;
mod tracer;

pub use window::*;
pub use tracer::*;

fn default_ground_color() -> [f32; 3] {
  [0.5, 0.5, 0.5]
}

fn default_sky_color() -> [f32; 3] {
  [0.5, 0.5, 0.5]
}

/// The application configure.
#[derive(Debug, Deserialize, Default, Clone)]
pub struct AppConfig {
  pub window: WindowConfig,
  pub tracer: TracerConfig,
  pub scene_file: String,
  pub hdri_file: String,
  pub hdri_rotation: f32,
  #[serde(default = "default_ground_color")]
  pub ground_color: [f32; 3],
  #[serde(default = "default_sky_color")]
  pub sky_color: [f32; 3],
}

/// Validate the application configure.
/// param: config: the configure.
/// return: the result of the validation.
pub fn validate_app_config(config: &AppConfig) -> Result<()> {
  validate_window_config(&config.window)?;
  validate_tracer_config(&config.tracer)?;
  if !std::path::Path::new(&config.scene_file).exists() {
    return Err(anyhow::anyhow!("The scene file is not found."));
  }
  Ok(())
}

/// Load the application configure.
/// param: config_file: the configure file path.
/// return: the application configure.
pub fn load_app_config(config_file: &str) -> Result<AppConfig> {
  let config_str = std::fs::read_to_string(config_file)
    .with_context(|| format!("Failed to read the config file: {}", config_file))?;
  let config: AppConfig = serde_yaml::from_str(&config_str)
    .with_context(|| format!("Failed to parse the config file: {}", config_file))?;
  Ok(config)
}