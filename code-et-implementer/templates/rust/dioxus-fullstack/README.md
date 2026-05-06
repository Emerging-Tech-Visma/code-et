# {{name}}

Pure-Rust full-stack project bootstrapped with [code-et](https://github.com/Emerging-Tech-Visma/code-et) v4.0+.

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

If `/code:start` was invoked with `--install-tools`, these are already on your machine.

## Daily workflow

```
# Bug
/code:fix "<one-line bug>"   # intake → Task Brief → you implement → /commit-push-pr

# Feature
/code:plan "<idea>"          # refined brief → PRD on disk → vertical-slice tasks
/code:ship                   # parallel worktree agents + post-merge audit (1 auto-retry)
/code:review                 # full audit + diff review (pre-merge gate)
/commit-push-pr              # PR; CI runs the same audit pipeline
```

Each task carries `metadata.layer ∈ {domain, application, infrastructure, interface, chore}`. Vertical slices may span layers; each *file* belongs to exactly one. Imports point inward.

## Deploy & upload — always via scripts

**Discipline:** never deploy or upload {{name}} via raw `cargo run`, `docker push`, `gcloud run deploy`, `gsutil cp`, `scp`, or any other ad-hoc command typed into a shell. All paths route through:

```
just deploy staging                # bash scripts/deploy.sh staging
just deploy prod                   # bash scripts/deploy.sh prod
just upload web staging            # bash scripts/upload.sh web staging
just upload desktop prod           # bash scripts/upload.sh desktop prod
```

The scripts are starting points — host-specific commands are marked `# TODO:` blocks (Cloud Run / GKE / Fly / your VM). Fill them in once for your project; after that, every deploy is:

1. **Pre-flight:** clean tree, audit gate green, required tools on PATH.
2. **Build:** container image tagged with `git rev-parse --short HEAD`.
3. **Migrate:** `sqlx migrate run` against the target DB (Cloud SQL Auth Proxy + IAM token in prod).
4. **Roll out:** push image, update Cloud Run revision (or your equivalent).
5. **Smoke check:** curl `/healthz`, expect 200.

This is the only sane way to ship Rust workspaces with `sqlx::query!` macros — the build needs the right `DATABASE_URL` (or offline `sqlx-data.json`), and the deploy needs migrations to land before the new image gets traffic. A script enforces that order; ad-hoc commands forget it.

## Doctrine

- [`docs/architecture.md`](https://github.com/Emerging-Tech-Visma/code-et/blob/main/code-et-implementer/docs/architecture.md) — Clean Architecture details
- [`docs/anti-slop.md`](https://github.com/Emerging-Tech-Visma/code-et/blob/main/code-et-implementer/docs/anti-slop.md) — what the audit catches
- [`docs/testing.md`](https://github.com/Emerging-Tech-Visma/code-et/blob/main/code-et-implementer/docs/testing.md) — per-layer test matrix
