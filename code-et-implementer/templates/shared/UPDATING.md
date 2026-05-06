# Template Updating Checklist

How to keep `templates/rust/dioxus-fullstack/` and `templates/shared/` aligned with the upstream Rust ecosystem.

## When to update

- A pinned crate has a new minor (axum 0.8 → 0.9, dioxus 0.7 → 0.8, sqlx 0.8 → 0.9).
- A pinned GitHub Action has a new major (`actions/checkout@v4` → `@v5`).
- The Rust edition advances (2024 → 2027).
- A security advisory affects a templated dependency.

Cadence: review every quarter even if nothing has shipped. Rust crate ecosystems move fast, especially Dioxus.

## Update procedure

1. **Branch.** `feature/templates-refresh-YYYY-MM`.
2. **Bump versions.** Update each `Cargo.toml` under `templates/rust/dioxus-fullstack/`:
   - `crates/domain/Cargo.toml` — `serde`, `thiserror`, `uuid`, `time`.
   - `crates/application/Cargo.toml` — `async-trait`, `anyhow`, `mockall` (dev).
   - `crates/infrastructure/Cargo.toml` — `sqlx`, `reqwest`, `tokio`, `secrecy`.
   - `crates/interface/Cargo.toml` — `dioxus`, `axum`, `tower`.
   - `apps/server/Cargo.toml` — `dioxus-fullstack`, `tokio`.
   - `apps/desktop/Cargo.toml` — `dioxus-desktop`.
   - `apps/web/Cargo.toml` — `dioxus-web`.
   - `apps/mobile/Cargo.toml` — `dioxus-mobile`.
3. **Bump GitHub Actions** in `templates/shared/.github/workflows/code-et-audit.yml`. Pin to majors (`@v4`); avoid floating `@latest`.
4. **Smoke-test.** Scaffold a fresh project from the updated template into `/tmp/upgrade-smoke`, run `cargo check --workspace --all-features` and `cargo nextest run`. Both must pass.
5. **CI smoke.** Push to a temp repo or run `act` against the workflow; the audit job must pass clean.
6. **Validator.** `bash templates/shared/scripts/layer-deps-validator.sh` (in the smoke project) must exit 0.
7. **Bump plugin patch version** (e.g. `3.9.x → 3.9.x+1`), update `CHANGELOG.md`. The user-facing change is "templates refreshed for axum 0.9 / dioxus 0.8".

## Pinning policy

- **Crates:** pin to minor (`"^0.8"` for sqlx, `"^0.7"` for dioxus). Patch updates flow through `cargo update`.
- **Actions:** pin to major (`@v4`). Major bumps require manual smoke + a CHANGELOG note.
- **Rust toolchain:** `rust-toolchain.toml` pins to `stable` channel; nightly is gated on `cargo-udeps` opt-in.

## Risk register

| Risk | Mitigation |
|---|---|
| Dioxus 0.x breaking changes between minors | The smoke project's `apps/{web,desktop,mobile}/main.rs` is the canary; if any fails to build, hold the bump until reviewed. |
| `sqlx` schema incompatibility on bump | The smoke project's `migrations/20250101000000_init.sql` runs against both Postgres and SQLite in CI; if either fails, fix the migration before merging the template bump. |
| GHA action removal | Pin majors; check the action's repo for archived/deprecated status before bumping. |
| Mobile target moves faster than web/desktop | If the bump breaks only mobile, gate the mobile app behind a feature flag in the bump PR. The `--targets` flag in `/code:bootstrap` already supports excluding mobile. |
