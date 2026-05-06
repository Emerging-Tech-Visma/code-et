//! Repository implementations. The only place `sqlx` is imported.
//!
//! Doctrine: parameter binding is mandatory; `query!` / `query_as!` macros are the
//! goal for compile-time schema check. The template ships with `query_as` (runtime-checked)
//! so it compiles before `cargo sqlx prepare` is run; migrate per repo as the schema stabilises.

pub mod sqlite_user_repo;

pub use sqlite_user_repo::SqliteUserRepo;
