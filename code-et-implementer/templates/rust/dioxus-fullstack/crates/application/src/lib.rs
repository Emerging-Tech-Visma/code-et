//! Application layer — use cases + ports (traits). Orchestrates domain.
//!
//! See `code-et-implementer/docs/architecture.md` §"Crossing boundaries" for DTO/DIP rules.

pub mod errors;
pub mod ports;
pub mod use_cases;

pub use errors::ApplicationError;
