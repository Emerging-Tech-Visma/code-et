use thiserror::Error;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum DomainError {
    #[error("invalid email: {0}")]
    InvalidEmail(String),

    #[error("user not found")]
    UserNotFound,
}
