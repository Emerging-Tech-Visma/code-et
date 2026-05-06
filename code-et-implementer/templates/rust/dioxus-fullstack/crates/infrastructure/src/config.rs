use secrecy::SecretString;
use serde::Deserialize;

/// Application config loaded once at boot. Secrets wrapped in `SecretString`
/// so they redact in `Debug` and `tracing` output.
#[derive(Debug, Clone, Deserialize)]
pub struct Config {
    pub database_url: SecretString,
    pub bind_addr: String,
}

impl Config {
    /// Load from environment. In production: secrets come from GCP Secret Manager
    /// via the deployment workflow, exported into the env. Locally: `dotenvy` for `.env`.
    pub fn from_env() -> anyhow::Result<Self> {
        if cfg!(debug_assertions) {
            // Best-effort .env load; ignore missing file in dev.
            let _ = dotenvy::dotenv();
        }
        Ok(Self {
            database_url: std::env::var("DATABASE_URL")
                .map(SecretString::from)
                .map_err(|_| anyhow::anyhow!("DATABASE_URL is required"))?,
            bind_addr: std::env::var("BIND_ADDR").unwrap_or_else(|_| "127.0.0.1:3000".into()),
        })
    }
}
