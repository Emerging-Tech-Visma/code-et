use async_trait::async_trait;
use sqlx::SqlitePool;

use application::{ApplicationError, ports::UserRepo};
use domain::{Email, User, UserId};

pub struct SqliteUserRepo {
    pool: SqlitePool,
}

impl SqliteUserRepo {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl UserRepo for SqliteUserRepo {
    async fn save(&self, user: &User) -> Result<(), ApplicationError> {
        // Goal: migrate to `sqlx::query!` once `cargo sqlx prepare` has run against the schema.
        sqlx::query("INSERT INTO users (id, email) VALUES (?1, ?2)")
            .bind(user.id.0.to_string())
            .bind(user.email.as_str())
            .execute(&self.pool)
            .await
            .map_err(|e| ApplicationError::Repo(e.to_string()))?;
        Ok(())
    }

    async fn by_id(&self, id: UserId) -> Result<Option<User>, ApplicationError> {
        let row: Option<(String, String)> =
            sqlx::query_as("SELECT id, email FROM users WHERE id = ?1")
                .bind(id.0.to_string())
                .fetch_optional(&self.pool)
                .await
                .map_err(|e| ApplicationError::Repo(e.to_string()))?;

        match row {
            Some((id_str, email_str)) => {
                let parsed_id = uuid::Uuid::parse_str(&id_str)
                    .map_err(|e: uuid::Error| ApplicationError::Repo(e.to_string()))?;
                let email = Email::new(email_str)?;
                Ok(Some(User {
                    id: UserId(parsed_id),
                    email,
                }))
            }
            None => Ok(None),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[sqlx::test(migrations = "../../migrations")]
    async fn round_trips_a_user(pool: SqlitePool) {
        let repo = SqliteUserRepo::new(pool);
        let user = User::new(Email::new("alice@example.com").unwrap());
        repo.save(&user).await.unwrap();
        let fetched = repo.by_id(user.id).await.unwrap().unwrap();
        assert_eq!(fetched, user);
    }
}
