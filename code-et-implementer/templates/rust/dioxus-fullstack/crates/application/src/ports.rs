//! Ports — traits implemented by `infrastructure`, used by `use_cases`.
//! `mockall` generates fakes for tests.

use async_trait::async_trait;

use domain::{User, UserId};

use crate::ApplicationError;

#[cfg_attr(test, mockall::automock)]
#[async_trait]
pub trait UserRepo: Send + Sync {
    async fn save(&self, user: &User) -> Result<(), ApplicationError>;
    async fn by_id(&self, id: UserId) -> Result<Option<User>, ApplicationError>;
}
