//! Infrastructure layer — adapters: sqlx repos, HTTP clients, config.
//! Implements `application` ports. Composition lives in `apps/<name>/main.rs`.
//!
//! See `code-et-implementer/docs/architecture.md` §"Database" for the sqlx rules.

pub mod config;
pub mod repos;
