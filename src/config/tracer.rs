use anyhow::Result;
use serde::Deserialize;

#[derive(Debug, Deserialize, Default, Clone)]
pub struct TonemapConfig {
  pub enable: bool,
  pub enable_aces: bool,
  pub use_simple_aces: bool,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct TracerConfig {
  pub max_depth: u16,
  pub rr_depth: u16,
  pub tonemap: TonemapConfig,
  pub max_samples: u32,
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
