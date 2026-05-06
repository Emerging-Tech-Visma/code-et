use thiserror::Error;

use domain::DomainError;

#[derive(Debug, Error)]
pub enum ApplicationError {
    #[error(transparent)]
    Domain(#[from] DomainError),

    #[error("repository error: {0}")]
    Repo(String),
}
