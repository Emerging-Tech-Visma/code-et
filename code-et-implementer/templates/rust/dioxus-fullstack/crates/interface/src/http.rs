//! axum handlers — the HTTP boundary. Composition wires repos at startup.

pub mod handlers;
pub mod router;

pub use router::router;
