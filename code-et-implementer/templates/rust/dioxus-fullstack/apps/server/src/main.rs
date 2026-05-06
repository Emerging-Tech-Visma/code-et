//! Composition root for the axum + dioxus-fullstack server.
//! Wires `infrastructure` impls into `interface` ports.

use std::sync::Arc;

use anyhow::Context;
use secrecy::ExposeSecret;
use sqlx::SqlitePool;
use tracing_subscriber::{EnvFilter, layer::SubscriberExt, util::SubscriberInitExt};

use infrastructure::{config::Config, repos::SqliteUserRepo};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    init_tracing();
    let cfg = Config::from_env().context("config")?;

    let pool = SqlitePool::connect(cfg.database_url.expose_secret())
        .await
        .context("db connect")?;
    sqlx::migrate!("../../migrations")
        .run(&pool)
        .await
        .context("migrate")?;

    let repo = Arc::new(SqliteUserRepo::new(pool));
    let app = interface::http::router(repo);

    let listener = tokio::net::TcpListener::bind(&cfg.bind_addr).await?;
    tracing::info!(addr = %cfg.bind_addr, "server listening");
    axum::serve(listener, app).await?;
    Ok(())
}

fn init_tracing() {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(tracing_subscriber::fmt::layer())
        .init();
}
