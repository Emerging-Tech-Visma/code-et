use std::sync::Arc;

use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use serde::Deserialize;

use application::{
    ApplicationError,
    ports::UserRepo,
    use_cases::{CreateUserInput, create_user, get_user},
};
use domain::UserId;

#[derive(Debug, Deserialize)]
pub struct CreateUserBody {
    pub email: String,
}

pub async fn health() -> &'static str {
    "ok"
}

pub async fn create_user_handler<R: UserRepo + 'static>(
    State(repo): State<Arc<R>>,
    Json(body): Json<CreateUserBody>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let out = create_user(repo.as_ref(), CreateUserInput { email: body.email })
        .await
        .map_err(map_err)?;
    Ok(Json(serde_json::to_value(out.user).unwrap()))
}

pub async fn get_user_handler<R: UserRepo + 'static>(
    State(repo): State<Arc<R>>,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let user = get_user(repo.as_ref(), UserId(id))
        .await
        .map_err(map_err)?
        .ok_or((StatusCode::NOT_FOUND, "user not found".into()))?;
    Ok(Json(serde_json::to_value(user).unwrap()))
}

fn map_err(e: ApplicationError) -> (StatusCode, String) {
    match e {
        ApplicationError::Domain(d) => (StatusCode::BAD_REQUEST, d.to_string()),
        ApplicationError::Repo(r) => (StatusCode::INTERNAL_SERVER_ERROR, r),
    }
}
