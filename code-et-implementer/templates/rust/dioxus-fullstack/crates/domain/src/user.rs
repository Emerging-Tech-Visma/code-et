use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::DomainError;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct UserId(pub Uuid);

impl UserId {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

impl Default for UserId {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Email(String);

impl Email {
    pub fn new(raw: impl Into<String>) -> Result<Self, DomainError> {
        let raw = raw.into();
        if raw.contains('@') && raw.len() <= 254 {
            Ok(Self(raw))
        } else {
            Err(DomainError::InvalidEmail(raw))
        }
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct User {
    pub id: UserId,
    pub email: Email,
}

impl User {
    pub fn new(email: Email) -> Self {
        Self {
            id: UserId::new(),
            email,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn email_rejects_missing_at_sign() {
        assert!(Email::new("not-an-email").is_err());
    }

    #[test]
    fn email_accepts_simple_address() {
        let e = Email::new("user@example.com").unwrap();
        assert_eq!(e.as_str(), "user@example.com");
    }

    #[test]
    fn email_rejects_oversized_input() {
        let huge = "a".repeat(300) + "@example.com";
        assert!(Email::new(huge).is_err());
    }
}
