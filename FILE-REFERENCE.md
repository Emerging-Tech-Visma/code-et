# FILE-REFERENCE.md

Map of every component in the code-et plugin. Used by `/code:fix` for intake scoping
and as primary context for `/code:plan` (so plans can skip a full codebase sweep).

## Project Overview

| Area | Description | Root path |
|------|-------------|-----------|
| Plugin | Claude Code plugin (commands, hooks, scripts) | `code-et-implementer/` |
| Repo root | Changelog, README, package metadata | `/` |

---

## Plugin — Commands (v4.0)

| Command | Skill name | File | Description |
|---------|------------|------|-------------|
| `/code:start` | `code:start` | `code-et-implementer/commands/start.md` | Scaffold a new pure-Rust full-stack project; runs `cargo update` post-scaffold |
| `/code:install-ci` | `code:install-ci` | `code-et-implementer/commands/install-ci.md` | Retrofit the CI audit gate onto an existing Rust repo |
| `/code:fix` | `code:fix` | `code-et-implementer/commands/fix.md` | Single-bug intake → Task Brief; user implements directly |
| `/code:plan` | `code:plan` | `code-et-implementer/commands/plan.md` | One extended turn: refined brief → PRD on disk → vertical-slice tasks (3 checkpoints) |
| `/code:ship` | `code:ship` | `code-et-implementer/commands/ship.md` | Parallel worktree agents + post-merge audit + 1-pass auto-retry on CRITICAL/HIGH |
| `/code:review` | `code:review` | `code-et-implementer/commands/review.md` | Pre-merge gate — full audit + diff review (delegates to engineering plugin) |

## Plugin — Hooks

| File | Description |
|------|-------------|
| `code-et-implementer/hooks/hooks.json` | Hook bindings: `PermissionRequest`, `SubagentStop`, `SessionStart`, `TaskCreated`, `TaskCompleted`, `PreCompact` |

## Plugin — Scripts

| Script | File | Description |
|--------|------|-------------|
| Auto-approve readonly | `code-et-implementer/scripts/auto-approve-readonly.sh` | Auto-approves Read/Grep/Glob/LSP for agents |
| Pre-compact PRD | `code-et-implementer/scripts/pre-compact-prd.sh` | Injects open-stories summary before compaction |
| Resolve PRD | `code-et-implementer/scripts/resolve-prd.sh` | Branch → `plans/YYYY-MM-DD-<slug>.md` lookup |
| Run tests | `code-et-implementer/scripts/run-tests.sh` | Runs test + lint with timeout and cmux notifications |
| Session start PRD | `code-et-implementer/scripts/session-start-prd.sh` | Injects 3-line PRD pointer at session start |
| Task complete | `code-et-implementer/scripts/task-complete.sh` | Desktop notification + agent attribution on task done |
| Task-created tag check | `code-et-implementer/scripts/task-created-tag-check.sh` | Enforces `user_story` tag on feature-lane tasks |
| Verify gate | `code-et-implementer/scripts/verify-gate.sh` | SubagentStop verification gate |

## Plugin — Tests

| Path | Description |
|------|-------------|
| `code-et-implementer/tests/` | Bats test suite for hook scripts |

## Plugin — Config

| File | Description |
|------|-------------|
| `code-et-implementer/.claude-plugin/plugin.json` | Plugin manifest (name, version, description) — **must stay in sync with CHANGELOG version** |
| `code-et-implementer/.claude-plugin/settings.json` | Plugin settings |
| `code-et-implementer/CLAUDE.md` | Plugin-level Claude instructions |

## Repo Root

| File | Description |
|------|-------------|
| `README.md` | Plugin documentation, workflow diagrams, install instructions (≤210 lines) |
| `CHANGELOG.md` | Version history — leading entry must match `plugin.json` version |
| `.claude-plugin/marketplace.json` | Marketplace manifest (points at `code-et-implementer/`) |
| `.claude/settings.json` | Project-level Claude Code settings |
| `.claude/settings.local.json` | Local-only Claude Code settings |
| `plans/` | PRDs and plan artifacts (`YYYY-MM-DD-<slug>.md`) |

---

## Hot Paths

Files that run on every primary user action vs files that run once per session/install.
Used to gauge blast radius of a change.

| Path type | Files |
|-----------|-------|
| Per-readonly-permission-request (Read/Grep/Glob/LSP) | `scripts/auto-approve-readonly.sh` |
| Per-task-creation | `scripts/task-created-tag-check.sh` |
| Per-task-completion | `scripts/task-complete.sh` |
| Per-subagent-stop | `scripts/verify-gate.sh` → `scripts/run-tests.sh` |
| Per-session-start | `scripts/session-start-prd.sh` |
| Per-compact (rare) | `scripts/pre-compact-prd.sh` |
| Per-`/code:*`-invocation | `commands/<name>.md` |
| Once on install | `.claude-plugin/plugin.json`, `.claude-plugin/settings.json` |

A regression in `auto-approve-readonly.sh` blocks every read permission prompt; a regression in `verify-gate.sh` blocks every subagent finish. Treat changes to either as wide-blast-radius — run the bats suite under `tests/` before commit.

## Landmines

| Rule | Why |
|------|-----|
| Never push directly to `main` | Branch + PR only — see `code-et-implementer/CLAUDE.md` |
| Never force push | Rebase locally, push normally |
| Never bump only `CHANGELOG.md` without `plugin.json` | The 3.7.0 release shipped with manifest stuck on 3.6.1 — installs reported the old version |
| Never call `/ultraplan` via `Skill("ultraplan", …)` | It's a built-in Claude Code command, not a callable skill (3.6.1 fix) |
| Never `git worktree add` from inside `/code:ship` | Use `Agent(isolation: "worktree")` so the subagent forks cleanly |
| Never have a subagent merge its own branch | The subagent has no view of the parent feature branch — orchestrator merges |
| Never serialize independent `/code:ship` tasks | Dispatch them in a single message with multiple `Agent` calls |

## Module Invariants

| Module | Invariant |
|--------|-----------|
| `commands/*.md` | Frontmatter must declare `effort`; commands default to `xhigh` (4.7 default); `/code:install-ci` and `/code:review` are the documented exceptions (`high`) |
| `commands/ship.md` | Each task → one `Agent(isolation: "worktree")` call; orchestrator owns merge + worktree cleanup, subagent does not. Post-merge audit auto-retries once on CRITICAL/HIGH. |
| `commands/plan.md` | Every task's `metadata.rationale` is mandatory; subagents start cold and need the *why*. PRD lands on disk before task decomposition (Phase 2 → Phase 3 checkpoint). |
| `hooks/hooks.json` | All script paths use `${CLAUDE_PLUGIN_ROOT}` — never hard-code `code-et-implementer/scripts/...`. Add hooks only when (a) no CLAUDE.md instruction can replace them and (b) the per-event token cost is justified by the value. |
| `FILE-REFERENCE.md` | Refresh only after a PR merges to main with structural changes (`*/page.tsx`, `*/route.ts`, `*/layout.tsx`, new top-level apps/packages). Do not edit on a feature branch — it tracks merged state. |
| `scripts/*.sh` | Must exit 0 on the no-op path; non-zero exit blocks the tool/event they hook into |
| `.claude-plugin/plugin.json` | `version` must match the leading `CHANGELOG.md` entry — bump together or not at all |
| Feature lane tasks | Must carry `user_story: US-N \| AC-N.M \| chore:<reason>`; enforced by `task-created-tag-check.sh` |
