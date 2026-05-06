---
name: testing
description: Per-layer Rust testing matrix. Mirror-test ban. Contract + security tests at boundaries. cargo-nextest as the runner.
applies_to: rust
---

# Rust Testing Doctrine (code-et)

Tests assert **observable behaviour at boundaries**, not implementation calls. The pyramid is steep: many fast unit tests in `domain` and `application`, fewer integration tests in `infrastructure`, very few e2e tests in `interface`. Mirror tests are banned.

For the general pyramid + what-to-cover guidance, see the engineering plugin's `testing-strategy` skill. This document is the *Rust-specific* delta.

## Per-layer test matrix

| Layer | Test type | Where | Runner | What to assert | What NOT to assert |
|---|---|---|---|---|---|
| `domain` | Unit | `crates/domain/src/**` `#[cfg(test)] mod tests` | `cargo nextest` | Pure-logic invariants, value-object construction, error variants. | Anything that requires a runtime, DB, network. |
| `application` | Use-case | `crates/application/tests/` (integration test crate) or `#[cfg(test)]` | `cargo nextest` | Use-case behaviour with `mockall` fakes for ports. Inputs at use-case API → outputs at use-case API. | Repository SQL. HTTP handlers. Dioxus rendering. |
| `infrastructure` | Integration | `crates/infrastructure/tests/` | `cargo nextest` + `#[sqlx::test]` | Repository methods against a real DB (SQLite for unit, Postgres in CI service container). HTTP clients against a recorded fixture (`wiremock`). | Use-case logic. UI behaviour. |
| `interface` | E2E | `apps/server/tests/` for HTTP, `crates/interface/tests/` for dioxus components | `cargo nextest` + `axum-test` + `dioxus-testing` | Round-trip: HTTP request → router → use case → repo → response. Dioxus component renders the right tree given props. | Internal call shapes. Error stack traces verbatim. |

## Concrete patterns

### `domain` — pure unit tests

```rust
// crates/domain/src/value_objects/email.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_missing_at_sign() {
        assert!(Email::new("not-an-email").is_err());
    }

    #[test]
    fn accepts_simple_address() {
        let e = Email::new("user@example.com").unwrap();
        assert_eq!(e.as_str(), "user@example.com");
    }
}
```

No fixtures, no mocks, no async. If a domain test needs setup beyond `let x = Foo::new(...)`, the abstraction is wrong.

### `application` — use cases with `mockall`

```rust
// crates/application/src/use_cases/get_user.rs
#[cfg(test)]
mod tests {
    use super::*;
    use crate::ports::MockUserRepo;
    use mockall::predicate::eq;

    #[tokio::test]
    async fn returns_user_when_repo_finds_one() {
        let mut repo = MockUserRepo::new();
        repo.expect_by_id()
            .with(eq(UserId::from(42)))
            .returning(|_| Ok(Some(User::sample())));
        let use_case = GetUser::new(repo);

        let result = use_case.execute(UserId::from(42)).await.unwrap();

        assert_eq!(result.id, UserId::from(42));
    }
}
```

`mockall` generates the mock from the trait. **Assert observable inputs/outputs of the use case** — never `verify` that a specific repo method was called N times. If you find yourself doing that, the use case is leaking implementation detail.

### `infrastructure` — `#[sqlx::test]` against a real DB

```rust
// crates/infrastructure/src/repos/postgres_user_repo.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[sqlx::test]
    async fn round_trips_a_user(pool: PgPool) {
        let repo = PostgresUserRepo::new(pool);
        let user = User::sample();

        repo.save(&user).await.unwrap();
        let fetched = repo.by_id(user.id).await.unwrap().unwrap();

        assert_eq!(fetched, user);
    }
}
```

`#[sqlx::test]` provisions a fresh test database for each test (in Postgres) or an in-memory file (in SQLite). Run with `DATABASE_URL=sqlite::memory:` for unit-speed; against a Postgres service container in CI.

### `interface` — HTTP e2e via `axum-test`

```rust
// apps/server/tests/users_api.rs
use axum_test::TestServer;

#[tokio::test]
async fn get_user_returns_200_with_user_json() {
    let app = test_app().await;
    let server = TestServer::new(app).unwrap();

    let response = server.get("/users/42").await;

    response.assert_status_ok();
    response.assert_json(&serde_json::json!({ "id": 42, "email": "..." }));
}
```

`test_app()` is a helper that builds the full router with **fake repos** (mockall) for fast tests, or **real repos** (in-memory SQLite) for round-trip tests. Both are valuable; favour the fast variant for breadth, the round-trip for the happy path.

### `interface` — Dioxus component tests

```rust
// crates/interface/src/components/user_card.rs
#[cfg(test)]
mod tests {
    use super::*;
    use dioxus_testing::*;

    #[test]
    fn renders_user_email_when_present() {
        let dom = render(UserCard {
            user: User::sample_with_email("alice@example.com"),
        });
        assert!(dom.text().contains("alice@example.com"));
    }
}
```

Test props in, rendered text/structure out. Don't assert on internal hook order.

## Contract tests at boundaries

Every port (trait in `application`) has a **contract test** that runs against every implementation. The trait-level test lives in `crates/application/tests/contracts/<port>.rs`; each `infrastructure` impl includes the test.

```rust
// crates/application/tests/contracts/user_repo.rs
pub fn user_repo_contract<R: UserRepo + Clone>(repo: R) {
    // Exercises: save → by_id → modify → save → by_id again.
    // Asserts only the trait's behavioural contract, not impl detail.
}

// crates/infrastructure/tests/postgres_user_repo.rs
#[sqlx::test]
async fn obeys_user_repo_contract(pool: PgPool) {
    user_repo_contract(PostgresUserRepo::new(pool));
}

// crates/infrastructure/tests/sqlite_user_repo.rs
#[sqlx::test]
async fn obeys_user_repo_contract(pool: SqlitePool) {
    user_repo_contract(SqliteUserRepo::new(pool));
}
```

If both impls pass the contract, you can swap them in production. This is the test seam Clean Architecture exists to give you.

## Security test cases

Each `interface` boundary gets at least these tests:

| Boundary | Test |
|---|---|
| HTTP routes that mutate | An unauthenticated request returns 401; an authenticated request as the wrong user returns 403; a malformed body returns 400 with no leaked internal detail. |
| HTTP routes that read | The same auth checks. Sensitive fields (password hashes, secrets) are never in response JSON. |
| SQL queries | A test passes a string with `'; DROP TABLE …` characters as a parameter. The query treats it as data. (`sqlx::query!` makes this impossible structurally — the test is documentation more than enforcement.) |
| Deserialization | A request body 10× the expected size is rejected at the parsing layer with 400, not OOM. |
| File uploads (if any) | A path-traversal filename (`../../etc/passwd`) is rejected. |

## Mirror-test ban

A mirror test is one whose pass condition mirrors the implementation rather than the caller's contract. They pass for any code that compiles and break only when the implementation is rewritten — making the test useless during refactors.

| ✗ Mirror | ✓ Behavioural |
|---|---|
| `assert_eq!(add(2, 3), 2 + 3);` | `assert_eq!(add(2, 3), 5);` |
| `verify(repo.save_called_with(&user));` | `assert_eq!(use_case.execute(user.clone()).await?, user);` |
| `assert_eq!(format!("{:?}", err), "DomainError::NotFound");` | `assert!(matches!(err, DomainError::NotFound));` |

If a test is hard to write without referencing implementation detail, the implementation is wrong (too coupled, too leaky) — fix the code, not the test.

## The runner: `cargo-nextest`

`cargo nextest run --workspace` is the default. It runs tests in parallel processes (faster than `cargo test`), retries flaky tests with the right config, and emits machine-readable output for CI. The CI workflow uses it; local `justfile` exposes `just test`.

## See also

- [`docs/architecture.md`](architecture.md) — the layer model the test matrix mirrors.
- [`docs/anti-slop.md`](anti-slop.md) — Rule of Three, mirror-test ban (cross-referenced here).
- Engineering plugin's `testing-strategy` skill — for the pyramid + general what-to-cover.
