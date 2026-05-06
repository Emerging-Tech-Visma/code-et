//! Domain layer — entities, value objects, errors. Pure logic. Zero workspace deps.
//!
//! See `code-et-implementer/docs/architecture.md` §"Layer model" for the full rules.

pub mod errors;
pub mod user;

pub use errors::DomainError;
pub use user::{Email, User, UserId};
