use serde::{Deserialize, Serialize};

use domain::{Email, User};

use crate::{ApplicationError, ports::UserRepo};

#[derive(Debug, Clone, Deserialize)]
pub struct CreateUserInput {
    pub email: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct CreateUserOutput {
    pub user: User,
}

/// Create a new user. Pure orchestration over `domain` + a `UserRepo` port.
pub async fn create_user<R: UserRepo + ?Sized>(
    repo: &R,
    input: CreateUserInput,
) -> Result<CreateUserOutput, ApplicationError> {
    let email = Email::new(input.email)?;
    let user = User::new(email);
    repo.save(&user).await?;
    Ok(CreateUserOutput { user })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ports::MockUserRepo;

    #[tokio::test]
    async fn creates_user_with_valid_email() {
        let mut repo = MockUserRepo::new();
        repo.expect_save().times(1).returning(|_| Ok(()));

        let out = create_user(
            &repo,
            CreateUserInput {
                email: "alice@example.com".into(),
            },
        )
        .await
        .unwrap();

        assert_eq!(out.user.email.as_str(), "alice@example.com");
    }

    #[tokio::test]
    async fn rejects_invalid_email() {
        let repo = MockUserRepo::new();
        let err = create_user(
            &repo,
            CreateUserInput {
                email: "not-an-email".into(),
            },
        )
        .await
        .unwrap_err();
        assert!(matches!(err, ApplicationError::Domain(_)));
    }
}
