---
name: architecture
description: Rust Clean Architecture doctrine for code-et. Loaded on demand by /code:bootstrap, /code:go, /code:plan-issue, /code:implement.
applies_to: rust
---

# Rust Clean Architecture (code-et)

The single architecture this plugin scaffolds and enforces. Project shape: `axum + sqlx + dioxus + tokio` full-stack. Frontend: **Dioxus 0.7+ for web, desktop, and mobile from one component tree.** Database: **PostgreSQL on GCP Cloud SQL** for production, **SQLite** for local. Layer enforcement is at the `cargo` level — violating imports fail at `cargo build`, not at runtime.

## Layer model — the four crates

```
crates/
  domain/           Entities, value objects, domain errors. Pure logic.
                    deps: serde, thiserror, uuid, time. NO workspace deps.
  application/      Use cases + ports (traits). Orchestrates domain.
                    deps: domain. async-trait, anyhow.
  infrastructure/   Adapters: sqlx repos, HTTP clients, GCP secret manager.
                    Implements application's port traits.
                    deps: application + domain. sqlx, reqwest, tokio.
  interface/        Dioxus components + axum handlers. Composition lives in apps/.
                    deps: application + domain. dioxus, axum, tower.
                    NEVER depends on infrastructure — apps/ wire the two.
apps/
  server/   bin: axum + dioxus-fullstack SSR.
  desktop/  bin: dioxus-desktop renderer.
  web/      bin: dioxus-web (WASM).
  mobile/   bin: dioxus-mobile (iOS + Android).
```

Each `apps/<name>/main.rs` is the **composition root** — the only place that instantiates concrete `infrastructure` types and wires them into `interface` ports. The Dependency Rule is enforced because `interface/Cargo.toml` does not list `infrastructure` as a dependency. Adding it makes `cargo build` fail.

## The Dependency Rule (from Uncle Bob, verbatim)

> The overriding rule that makes this architecture work is *The Dependency Rule*. This rule says that *source code dependencies* can only point *inwards*. Nothing in an inner circle can know anything at all about something in an outer circle. In particular, the name of something declared in an outer circle must not be mentioned by the code in the an inner circle. That includes, functions, classes. variables, or any other named software entity.
>
> By the same token, data formats used in an outer circle should not be used by an inner circle, especially if those formats are generate by a framework in an outer circle. We don't want anything in an outer circle to impact the inner circles.

Mapped to our four crates:

| Layer (inner → outer) | May depend on | Must not import |
|---|---|---|
| `domain` | (nothing in workspace) | any other workspace crate |
| `application` | `domain` | `infrastructure`, `interface` |
| `infrastructure` | `application`, `domain` | `interface` |
| `interface` | `application`, `domain` | `infrastructure` |

The `Cargo.toml` `[dependencies]` table is the enforcement mechanism. The CI workflow's `layer-deps-validator.sh` adds a defence-in-depth check; the compiler is the primary gate.

## Crossing boundaries

**DTOs only.** When data crosses a boundary, it is a plain struct or function argument — never a `domain::Entity` and never a `sqlx::Row`. `interface` accepts a JSON request, parses it into an `application::Command` DTO, hands it to a use case. The use case returns a `application::Response` DTO that `interface` serialises out.

**DIP at the boundary.** Use cases in `application` declare traits (ports). `infrastructure` implements them. The composition root (`apps/<name>/main.rs`) injects the concrete impl. Example:

```rust
// crates/application/src/ports.rs
#[async_trait]
pub trait UserRepo {
    async fn by_id(&self, id: UserId) -> Result<Option<User>, RepoError>;
}

// crates/application/src/use_cases/get_user.rs
pub struct GetUser<R: UserRepo> { repo: R }

// crates/infrastructure/src/repos/postgres_user_repo.rs
pub struct PostgresUserRepo { pool: PgPool }
#[async_trait]
impl UserRepo for PostgresUserRepo { /* ... */ }

// apps/server/src/main.rs
let repo = PostgresUserRepo::new(pool);
let use_case = GetUser::new(repo);
let app = interface::http::router(use_case);
```

## Frontend — Dioxus everywhere

`crates/interface/src/components/` holds Dioxus components. **One UI codebase, three render targets** via Cargo features:

| Target | Crate feature | App | Build |
|---|---|---|---|
| Web (WASM) | `interface/web` | `apps/web` | `dx build --platform web` |
| Desktop | `interface/desktop` | `apps/desktop` | `dx build --platform desktop` |
| Mobile | `interface/mobile` | `apps/mobile` | `dx build --platform mobile` |
| SSR (axum) | `interface/server` | `apps/server` | `cargo run -p server` |

Server-side rendering uses `dioxus-fullstack` mounted into the axum router. Server components live in `interface::http::ssr`; client islands hydrate from `interface::components`.

**Mobile is best-effort.** Dioxus mobile (iOS/Android) is newer than web/desktop. CI tests web + desktop builds on every PR. Mobile builds run locally when xcode/android-ndk are present; opt into CI mobile builds with a separate workflow once the project's mobile surface is stable.

## Database

### Production: PostgreSQL on GCP Cloud SQL

- **Connection.** Use the **Cloud SQL Auth Proxy** + **IAM database authentication** — never raw username/password in env vars. The proxy gives short-lived OAuth tokens; the IAM principal is the workload identity bound to the service account.
- **Pool sizing.** `sqlx::PgPool` with `max_connections = min(num_cpus × 2, 25)` for typical Cloud SQL `db-custom` tiers. Tune from `pg_stat_activity`.
- **Migrations.** `sqlx::migrate!("./migrations")` from `apps/server/src/main.rs` at boot, **after** acquiring the IAM token. Forward-only; rollback is an *additional* migration that undoes the previous step. Each migration ships with a `recovery.md` next to the SQL file describing how to manually reverse it if the rollback migration itself is faulty.
- **Compile-time safety.** All queries use `sqlx::query!` / `query_as!` (compile-time-checked against the live schema via `DATABASE_URL` or against a committed `sqlx-data.json` for offline builds). Raw `sqlx::query` (no macro) is forbidden in production code.

### Local & small projects: SQLite

- Same `sqlx` interface; `sqlx::Pool<Sqlite>`. SQLite file path is `DATABASE_URL=sqlite:./dev.db`. In-memory for tests: `DATABASE_URL=sqlite::memory:`.
- Migrations dir is shared. Write SQL that is portable (`TEXT`, `INTEGER`, `REAL`, `BLOB` types; avoid `SERIAL`, use `INTEGER PRIMARY KEY AUTOINCREMENT` with a Postgres-compatible CTE pattern, or split into per-engine migrations under `migrations/postgres/` and `migrations/sqlite/` — choose one approach, document it).
- Switching engines is a config change: set `DATABASE_URL`, re-run `cargo sqlx prepare` against the target.

### Repo placement

`infrastructure/repos/` is the **only** module that imports `sqlx`. Use cases see ports (traits) only. Tests for repos use `#[sqlx::test]` with the appropriate engine.

## Secrets baseline

- **Production:** GCP Secret Manager. Service-account-scoped access via workload identity. Secrets are fetched at boot into a typed `Config` struct in `infrastructure/config/`; never re-fetched on the hot path.
- **Local:** `.env` file loaded with `dotenvy` only when `cfg!(debug_assertions)`. `.env` is gitignored. `.env.example` ships with placeholder names and no real values.
- **CI:** Secrets via GitHub Actions encrypted secrets — never echoed in workflow logs. The `code-et-audit.yml` workflow uses `DATABASE_URL=sqlite::memory:` for tests; production secrets stay in deployment workflows.
- **Never:** secrets in code, in `Cargo.toml`, in `Dioxus.toml`, in `tracing` logs (use `secrecy::Secret<T>` to get redaction in `Debug`).

## Rust security checklist

Run through this list at PR time. The CI gate catches the deterministic items; the human pass (engineering plugin's `code-review` skill) catches the rest.

| # | Check | Tool / How |
|---|---|---|
| 1 | No `unsafe` without justification comment | `grep -r "unsafe " crates/` — every block has a `// SAFETY:` line above it explaining the invariant. `cargo-geiger` for project-wide unsafe count. |
| 2 | All `serde::Deserialize` of untrusted input has bounded sizes | Code review. `serde_json::from_str` on request bodies has `axum::extract::Json<T>` with `T` bounded by deny-on-overflow types (e.g. `String` in DTOs is wrapped in a `BoundedString<N>`). |
| 3 | No raw SQL — `query!` / `query_as!` only | `grep -rn "sqlx::query(" crates/infrastructure/` should return nothing. |
| 4 | No FFI without `extern "C"` audit | Code review; if any FFI exists, document the foreign contract in a `// FFI CONTRACT:` block. |
| 5 | Secrets wrapped in `secrecy::Secret<T>` | `grep -rn "Secret<" crates/infrastructure/config/`. |
| 6 | Dependency advisories clean | `cargo audit` (CI). |
| 7 | License + source bans clean | `cargo deny check` (CI, with `deny.toml`). |
| 8 | No floating dependencies (every dep pinned to a major or minor) | Visible in `Cargo.toml` review. |
| 9 | Auth at every interface entry point | `axum` route table review: every route has either a public marker or a middleware that asserts auth. |
| 10 | Input validation lives in `application` (use case), not `interface` | `interface` parses, `application` validates business rules. Code review. |

## Where things live — quick reference

| Concern | Crate | Module |
|---|---|---|
| Entities (`User`, `Order`, …) | `domain` | `entities/` |
| Value objects (`Email`, `Money`, …) | `domain` | `value_objects/` |
| Domain errors | `domain` | `errors.rs` |
| Use cases (`CreateUser`, `GetOrder`, …) | `application` | `use_cases/` |
| Ports (traits) | `application` | `ports.rs` |
| Application errors (mapped to HTTP) | `application` | `errors.rs` |
| Repository implementations | `infrastructure` | `repos/` |
| HTTP clients (third-party APIs) | `infrastructure` | `http_clients/` |
| Configuration loading + secrets | `infrastructure` | `config/` |
| HTTP handlers (axum) | `interface` | `http/handlers/` |
| Routes + middleware | `interface` | `http/router.rs` |
| Dioxus components | `interface` | `components/` |
| Composition root | `apps/<name>/` | `main.rs` |

## When to deviate

The four-crate split is the default. Add more crates when a clear sub-bounded-context emerges (`crates/billing/{domain,application,…}`). Never add fewer — collapsing `application` into `interface` means losing the test seam at the most valuable boundary.

## See also

- [`docs/anti-slop.md`](anti-slop.md) — the anti-slop framework + 5 categories the CI gate enforces.
- [`docs/testing.md`](testing.md) — per-layer test matrix (domain unit / application use-case / infrastructure integration / interface e2e).
- Engineering plugin's `system-design` skill — for ADR / trade-off framing when a major decision is on the table.
