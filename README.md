# code-et

Pure-Rust Clean Architecture workflow for Claude Code. **One stack, six commands, no slop.**

Stack: `axum + sqlx + Dioxus 0.7+ + tokio`. One frontend codebase renders to web, desktop, and mobile. Database: SQLite for local, Postgres on GCP Cloud SQL for prod. Always-latest semver-compatible deps via post-scaffold `cargo update`.

> v4.0.0 is a deliberate rewrite. The plugin is biased toward starting fresh: `/code:start` scaffolds the four-crate workspace; the rest of the commands keep you in flow.

## The six commands

| Command | What it does |
|---|---|
| `/code:start <name>` | Scaffold a new pure-Rust full-stack project — 4 crates (`domain`, `application`, `infrastructure`, `interface`), 4 apps (`server`, `web`, `desktop`, `mobile`), CI gate, latest deps. |
| `/code:install-ci` | Drop the audit GitHub workflow + layer-deps validator into an existing Rust repo. |
| `/code:fix "<bug>"` | Single-bug intake → Task Brief (with per-file `Layer`). You implement directly. |
| `/code:plan "<idea>"` | One extended turn: refined brief → PRD on disk → vertical-slice tasks. Three checkpoints — interrupt at any. |
| `/code:ship` | Execute pending tasks in parallel worktree-isolated agents → audit → 1 auto-retry on CRITICAL/HIGH. |
| `/code:review` | Pre-merge gate: full local audit + diff review. Delegates to engineering plugin's `code-review` skill. |

That's it. `/commit-push-pr` (from the `commit-commands` plugin) ships the PR.

## Workflow

```
NEW PROJECT (one-time)
  /code:start myapp [--db sqlite|postgres] [--targets web,desktop,mobile,server]
     ↓
  cd myapp && cp .env.example .env && just db-migrate && just run-server

DAILY

  Bug?       /code:fix "..."  →  user implements 1-3 files  →  /commit-push-pr
  Feature?   /code:plan "..."  →  /code:ship  →  /code:review  →  /commit-push-pr
                                       ↓
                                 audit auto-runs
                                       ↓
                              ✓ green → ready to push
                              ✗ red   → 1 retry → if still red, surface findings
```

Two lanes. No mid-points. `/code:fix` does **not** chain into `/code:plan` or `/code:ship` — bugs that span vertical slices are features in disguise; write a PRD.

## Architecture (enforced)

The four-crate workspace **is** the architecture. Imports point inward; the `Cargo.toml` deps enforce it.

```
crates/
  domain/          Entities, value objects, errors. Pure logic. NO workspace deps.
  application/     Use cases + ports (traits). Orchestrates domain.
  infrastructure/  Adapters: sqlx repos, HTTP clients, secrets. Implements ports.
  interface/       axum handlers + Dioxus components. Composition lives in apps/.

apps/
  server/   axum + dioxus-fullstack SSR (always present)
  web/      dioxus-web (WASM)
  desktop/  dioxus-desktop
  mobile/   dioxus-mobile (best-effort)
```

Each `apps/<name>/main.rs` is the **composition root** — the only place that instantiates concrete `infrastructure` types and wires them into `interface` ports.

Doctrine lives in [`code-et-implementer/docs/`](code-et-implementer/docs/):

- [`architecture.md`](code-et-implementer/docs/architecture.md) — Clean Architecture, dependency rule, secrets, security checklist.
- [`anti-slop.md`](code-et-implementer/docs/anti-slop.md) — 4 elements (dead code, duplication, complexity, drift) + 5 categories + 6 hard rules.
- [`testing.md`](code-et-implementer/docs/testing.md) — per-layer test matrix, mirror-test ban, contract tests at boundaries.

## CI gate

`.github/workflows/code-et-audit.yml` runs on every PR + push to main:

1. `cargo fmt --check`
2. `cargo clippy --workspace --all-targets --all-features -- -D warnings`
3. `scripts/layer-deps-validator.sh` (defence-in-depth on the layer rule)
4. `cargo machete` (unused deps)
5. `cargo audit` (security advisories)
6. `cargo deny check` (license + bans + sources)
7. `cargo nextest run --workspace --all-features`

Local mirror: `just audit`. `/code:ship` runs the same pipeline post-merge with a 1-pass auto-fix retry on CRITICAL/HIGH findings. **A green audit is the merge gate** — no manual override.

> **GitHub Actions:** the workflow uses public actions (`actions/checkout`, `dtolnay/rust-toolchain`, `Swatinem/rust-cache`, `taiki-e/install-action`, `bnjbvr/cargo-machete`, `rustsec/audit-check`, `EmbarkStudios/cargo-deny-action`). GitHub fetches them automatically on first run — nothing to install. `secrets.GITHUB_TOKEN` is auto-provided. Just push the repo and the gate runs.

## Install

```
# Required companions
/plugin marketplace add knowledge-work-plugins
/plugin install engineering@knowledge-work-plugins
/plugin install rust-analyzer-lsp@claude-plugins-official

# Recommended
/plugin install commit-commands@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install claude-md-management@claude-plugins-official

# code-et
/plugin marketplace add Emerging-Tech-Visma/code-et
/plugin install code@code-et
```

The `engineering` plugin provides `code-review`, `tech-debt`, `testing-strategy`, `system-design` skills that code-et delegates to. `rust-analyzer-lsp` powers symbol-level precision in `/code:fix` and `/code:plan`.

### Local development

Test plugin changes without the install/update/restart cycle:

```bash
claude --plugin-dir /path/to/code-et/code-et-implementer
```

Type `/code:` to confirm all six commands appear.

## Prerequisites

- **Claude Code** — `npm install -g @anthropic-ai/claude-code`
- **Rust toolchain** — `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh` (Rust 2024 / 1.85+)
- **GitHub CLI (`gh`)** — for PRs and issues ([install](https://cli.github.com/))
- **Audit tools**:
  ```
  cargo install --locked cargo-machete cargo-audit cargo-deny cargo-nextest sqlx-cli dioxus-cli
  ```
  Or pass `--install-tools` to `/code:start` and the bootstrap will run this for you.

### LSP (recommended)

Add to `~/.claude/settings.json`:

```json
{
  "env": { "ENABLE_LSP_TOOL": "1" }
}
```

Install `rust-analyzer`:

```
rustup component add rust-analyzer
# or: brew install rust-analyzer
```

Verify with: *"use LSP to find the definition of `<symbol>`"* — if it returns a `file:line`, all three layers (env var, plugin, binary) are wired.

## Always-latest dependencies

`/code:start` runs `cargo update` post-scaffold so every dep is at its latest semver-compatible patch. Caret pins (`dioxus = "0.7"`, `axum = "0.8"`, `sqlx = "0.8"`, `tokio = "1"`, `tower = "0.5"`, etc.) deliver the latest minor/patch automatically.

**Major bumps** (e.g., `dioxus 0.7 → 0.8` once it ships) need a manual `cargo upgrade` (cargo-edit) and a smoke test:

```bash
cargo install cargo-edit
cargo upgrade --workspace
just audit   # smoke
```

`cargo audit` (CI step 5) catches yanked or vulnerable pins on every PR. `cargo machete` (step 4) catches accumulating unused deps.

## Settings

```json
{
  "env": {
    "ENABLE_LSP_TOOL": "1",
    "CLAUDE_CODE_TASK_LIST_ID": "<your-project-tasks>"
  }
}
```

`CLAUDE_CODE_TASK_LIST_ID` lets `/code:ship` resume interrupted work across sessions via `.claude/<id>.json`.

## Companion plugin map

| Plugin | What it gives you |
|---|---|
| `engineering` (knowledge-work-plugins) | `code-review`, `tech-debt`, `testing-strategy`, `system-design` skills — delegated to from code-et's CLAUDE.md |
| `rust-analyzer-lsp` (official) | Symbol-level precision for `/code:fix` and `/code:plan` |
| `commit-commands` (official) | `/commit`, `/commit-push-pr`, `/clean_gone` |
| `code-review` (official) | Multi-agent PR review |
| `claude-md-management` (official) | `/revise-claude-md`, `/claude-md-improver` |

## Deploy & upload — always via scripts

`/code:start` ships `scripts/deploy.sh` and `scripts/upload.sh` in every scaffolded project, plus `just deploy <env>` and `just upload <kind> <env>` targets in the justfile. **All deploys and uploads go through these scripts** — never raw `cargo`, `docker`, `gcloud`, or `gsutil` typed into a shell.

The scripts are starting points: pre-flight (clean tree + audit gate) → build container → run migrations → roll out → smoke check. Host-specific lines (`gcloud run deploy …`, `gsutil rsync …`, `flyctl deploy …`) are marked `# TODO:` blocks — fill in once for your project. From then on every deploy is one command:

```
just deploy staging
just deploy prod
just upload web prod
```

The bundled CLAUDE.md template encodes the rule: *if you find yourself typing the underlying command directly, stop and add the missing step to the script instead.*

## How it stays simple

1. **One stack.** axum + sqlx + Dioxus + tokio. No flags for "TS or Rust", no legacy branches.
2. **Six commands.** Most days you use three (`/code:fix`, `/code:plan`, `/code:ship`).
3. **Doctrine, not docs.** Three short markdown files (`architecture`, `anti-slop`, `testing`) loaded on demand.
4. **CI is the gate.** Local hooks give fast feedback; a green CI is the merge requirement. No process can override it.
5. **Vertical slices, not layers as tasks.** Each task touches every layer it needs to touch — `/code:plan` rejects horizontal tasks at decomposition time.

## Migrating from v3.x

| v3.x command | v4.x replacement |
|---|---|
| `/code:bootstrap` | `/code:start` |
| `/code:go` | `/code:fix` |
| `/code:grill` + `/code:prd` + `/code:plan-issue` | `/code:plan` (one extended turn, three checkpoints) |
| `/code:implement` | `/code:ship` |
| `/code:audit` | `just audit` (or runs automatically inside `/code:ship`) |
| `/code:install-ci` | `/code:install-ci` (unchanged) |

The doctrine files (`docs/architecture.md`, `docs/anti-slop.md`, `docs/testing.md`) and the CI gate template are unchanged — same architecture, fewer commands.

## License

MIT. See [LICENSE](LICENSE).
