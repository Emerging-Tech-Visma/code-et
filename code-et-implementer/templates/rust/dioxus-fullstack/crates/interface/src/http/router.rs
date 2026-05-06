use std::sync::Arc;

use axum::{
    Router,
    routing::{get, post},
};

use application::ports::UserRepo;

use crate::http::handlers;

/// Composition entrypoint for axum routes. The repo is injected by `apps/server/main.rs`.
pub fn router<R>(repo: Arc<R>) -> Router
where
    R: UserRepo + 'static,
{
    Router::new()
        .route("/health", get(handlers::health))
        .route("/users", post(handlers::create_user_handler::<R>))
        .route("/users/{id}", get(handlers::get_user_handler::<R>))
        .with_state(repo)
}
