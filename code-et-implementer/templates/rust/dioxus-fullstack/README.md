# {{name}}

Pure-Rust full-stack project bootstrapped with [code-et](https://github.com/Emerging-Tech-Visma/code-et) v3.9.0+.

**Stack:** axum + sqlx + Dioxus 0.7+ + tokio. **Frontend:** Dioxus on web, desktop, and mobile from one component tree. **Database:** SQLite for local, PostgreSQL on GCP Cloud SQL for production.

## Layout

```
crates/
  domain/           Entities, value objects, errors. Pure logic. No workspace deps.
  application/      Use cases + ports (traits). Depends on domain.
  infrastructure/   sqlx repos, HTTP clients, config. Depends on application + domain.
  interface/        Dioxus components + axum handlers. Depends on application + domain.
apps/
  server/   axum + dioxus-fullstack SSR server.
  desktop/  dioxus-desktop window.
  web/      dioxus-web (WASM).
  mobile/   dioxus-mobile (iOS + Android).
migrations/         sqlx::migrate! source. Forward-only. SQLite + Postgres compatible.
.github/workflows/  CI gate (clippy, layer validator, machete, audit, deny, nextest).
scripts/            layer-deps-validator.sh.
```

The Dependency Rule is enforced by `Cargo.toml` workspace deps. Adding `infrastructure` to `crates/domain/Cargo.toml` makes `cargo build` fail. The validator script is defence-in-depth.

## Quick start

```bash
cp .env.example .env
just db-migrate
just run-server     # axum + dioxus-fullstack on :3000
just run-web        # dioxus-web (WASM) on :8080
just run-desktop    # dioxus-desktop window
just test
just audit          # local mirror of the CI gate
```

## Required tools (one-time)

```bash
cargo install cargo-machete cargo-audit cargo-deny cargo-nextest sqlx-cli
cargo install dioxus-cli
# optional, requires nightly toolchain
cargo install cargo-udeps
```

If `/code:bootstrap` was invoked with `--install-tools`, these are already on your machine.

## Adding a feature

Use code-et's feature lane:

```
/code:grill              # refine the idea
/code:prd                # write a PRD into plans/<slug>.md
/code:plan-issue         # break PRD into vertical-slice tasks
/code:implement          # parallel agents in worktrees
/commit-push-pr          # PR; CI runs the audit gate
```

Each task carries `metadata.layer ∈ {domain, application, infrastructure, interface, chore}`. Vertical slices may span layers; each *file* belongs to exactly one. Imports point inward.

## Doctrine

- [`docs/architecture.md`](https://github.com/Emerging-Tech-Visma/code-et/blob/main/code-et-implementer/docs/architecture.md) — Clean Architecture details
- [`docs/anti-slop.md`](https://github.com/Emerging-Tech-Visma/code-et/blob/main/code-et-implementer/docs/anti-slop.md) — what the audit catches
- [`docs/testing.md`](https://github.com/Emerging-Tech-Visma/code-et/blob/main/code-et-implementer/docs/testing.md) — per-layer test matrix
