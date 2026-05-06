//! Interface layer — Dioxus components + axum handlers.
//!
//! Depends on `application` + `domain` only. NEVER on `infrastructure`.
//! Composition root (`apps/<name>/main.rs`) injects concrete impls.

pub mod components;

#[cfg(feature = "server")]
pub mod http;
