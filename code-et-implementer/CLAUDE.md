# code-et v4.x

Pure-Rust Clean Architecture workflow. Stack: `axum + sqlx + Dioxus 0.7+ + tokio`. One frontend codebase renders to web, desktop, and mobile.

## Git Rules

- **Never push directly to main** — always create a feature branch and PR.
- **Branch naming:** `feature/<name>`, `fix/<name>`, `chore/<name>`.
- **Never force push** — rebase locally, push normally.

## Commands

| Task | Command |
|------|---------|
| Scaffold a new project | `/code:start <name>` |
| Add CI to existing repo | `/code:install-ci` |
| Single bug fix | `/code:fix` (intake → Task Brief; you implement) |
| Feature, end-to-end | `/code:plan` (idea → PRD → tasks) → `/code:ship` (parallel agents + audit) |
| Pre-merge gate | `/code:review` (audit + diff review) |

For commits and PRs use `commit-commands` plugin (`/commit`, `/commit-push-pr`).

## Workflow — two lanes

**Bug lane.** `/code:fix` produces a Task Brief and stops. Most bugs are 1-3 file edits — no orchestration needed. If the work spans multiple coherent vertical slices (UI ↔ logic ↔ API ↔ DB), it's a feature in disguise — write a PRD instead.

**Feature lane.** `/code:plan` (one extended turn: refined brief → PRD on disk → vertical-slice tasks) → `/code:ship` (parallel worktree agents + post-merge audit + 1 auto-retry on CRITICAL/HIGH) → `/code:review` (pre-merge gate) → `/commit-push-pr`.

Each task is a **vertical slice**: UI ↔ logic ↔ API ↔ DB, end-to-end testable. When a slice supersedes existing code, deletion of the old code is part of the same commit — no parallel utilities, no `// TODO: remove old X`.

## Task Metadata Convention

Tasks created with `TaskCreate` carry:

```
metadata: {
  verification: "cargo nextest run && cargo clippy --all-targets -- -D warnings",
  files: ["crates/<layer>/src/path/to/file.rs:42"],
  expected_outcome: "what success looks like",
  rationale: "why this task exists — the constraint or decision driving it",
  user_story: "US-N" | "AC-N.M" | "chore:<reason>",
  layer: "domain" | "application" | "infrastructure" | "interface" | "chore"
}
```

`rationale` is mandatory. Subagents in `/code:ship` start cold — they need the *why*, not just the *what*, to make judgment calls.

`layer` is mandatory. Each *file* declares its layer; vertical slices may span layers.

## Code Standards

- Rust 2024 edition; `cargo clippy --all-targets -- -D warnings`; `cargo fmt --check`.
- Max 600 lines per file.
- Compose at app boundaries (`apps/<name>/main.rs`); never instantiate `infrastructure` inside `interface` — pass via constructor or DI trait.
- All SQL through `sqlx::query!` / `query_as!` (compile-time-checked). Raw `sqlx::query` is forbidden in production code.
- Forward-only migrations under `migrations/`. Each rollback is its own forward migration.

## Clean Architecture — controlling rules

Apply Clean Architecture per [`docs/architecture.md`](docs/architecture.md). Each new or modified file declares its layer (`domain` | `application` | `infrastructure` | `interface` | `chore`) in `metadata.layer`. Imports point inward; the workspace `Cargo.toml` deps already enforce this — violating imports fail at `cargo build`.

UI: Dioxus 0.7+ for web, desktop, and mobile from one component tree. DB: Postgres on GCP Cloud SQL for prod, SQLite for local. `sqlx` with `query!` (compile-time-checked); never raw SQL. Forward-only migrations.

Delegation map for human-judgment passes (engineering plugin: `knowledge-work-plugins/engineering`):
- security / code review → `code-review` skill
- testing strategy → `testing-strategy` skill
- tech-debt triage → `tech-debt` skill
- ADR / system design → `system-design` skill or `/architecture`
- LSP precision → `rust-analyzer-lsp` companion plugin

Anti-slop hard rules: see [`docs/anti-slop.md`](docs/anti-slop.md). Rule of Three. No mirror tests. No defensive validation at trusted boundaries.

## Brevity

Drop filler ("just", "simply", "really"), hedging ("perhaps", "maybe"), pleasantries ("Sure!", "Happy to help"). Fragments over sentences when meaning is clear. Pattern: `[thing] [action] [reason]. [next].`

Task subjects: `<verb> <object>` ≤50 chars. ✗ "I will implement the auth middleware". ✓ "add auth middleware in interface/http/middleware.rs".

Never compress: code, file paths, URLs, error messages, security warnings.

## Context Hygiene

Token waste = worse plans + worse code.

1. **Trim attachments.** Quote back only the slice you act on. Ignore siblings the harness attached. Duplicate blocks count once.
2. **Read in slices.** Files >200 lines: Grep first, then `Read(offset, limit)` for a window. Re-reading the same file twice = first read should have been a slice.
3. **Delegate breadth.** 3+ independent areas, or fix in an unknown file → `Agent(subagent_type: "Explore")`. Parallel queries → one message, multiple Agent calls. Don't delegate AND search. Specify thoroughness: `quick` | `medium` | `very thorough`.
4. **Stop at sufficient.** `file:line` + rationale per task is enough. 5 sharp tasks > 15 vague ones.

## FILE-REFERENCE.md Lifecycle

`FILE-REFERENCE.md` is updated **only after a PR merges to main** that touched structural files: `crates/*/Cargo.toml`, `apps/*/Cargo.toml`, root `Cargo.toml`, `migrations/*`, or new top-level apps/crates. Workflow:

1. All changes start on a branch (`feature/`, `fix/`, `chore/`) and ship via PR.
2. After merging the PR to main, if the diff touched structural files, run `/code:fix update` to refresh `FILE-REFERENCE.md`. Commit the refresh on a follow-up branch + PR.
3. On a feature branch, do **not** edit `FILE-REFERENCE.md` — it tracks merged-to-main reality, not in-flight work.

## Always-latest dependencies

`/code:start` runs `cargo update` post-scaffold so every dep is at its latest semver-compatible patch. Major bumps (e.g., dioxus 0.7→0.8 once it ships) need a manual `cargo upgrade` (cargo-edit) and a `just audit` smoke. The CI gate's `cargo audit` step catches yanked or vulnerable pins on every PR.
