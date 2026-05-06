use domain::{User, UserId};

use crate::{ApplicationError, ports::UserRepo};

/// Fetch a user by id. Pure orchestration over `domain` + a `UserRepo` port.
pub async fn get_user<R: UserRepo + ?Sized>(
    repo: &R,
    id: UserId,
) -> Result<Option<User>, ApplicationError> {
    repo.by_id(id).await
}
