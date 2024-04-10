use anyhow::Result;
use serde::Deserialize;

#[derive(Debug, Deserialize, Default, Clone)]
pub struct TonemapConfig {
  #[serde(default)]
  pub enable: bool,
  #[serde(default)]
  pub enable_aces: bool,
  #[serde(default)]
  pub use_simple_aces: bool,
}

#[derive(Debug, Deserialize, Clone)]
pub struct TracerConfig {
  #[serde(default)]
  pub max_depth: u16,
  #[serde(default)]
  pub rr_depth: u16,
  #[serde(default)]
  pub exposure_value: f32,
  #[serde(default)]
  pub tonemap: TonemapConfig,
  #[serde(default)]
  pub max_samples: u32,
}

impl Default for TracerConfig {
  fn default() -> Self {
    Self {
      max_depth: 1,
      rr_depth: 0,
      exposure_value: 0.0,
      tonemap: TonemapConfig::default(),
      max_samples: 0,
    }
  }
}

/// Validate the window configure.
/// param: config: the configure.
/// return: the result of the validation.
pub fn validate_tracer_config(config: &TracerConfig) -> Result<()> {
  if config.rr_depth > config.max_depth {
    return Err(anyhow::anyhow!("The Russian Roulette depth is greater than the max depth."));
  }

  Ok(())
}
