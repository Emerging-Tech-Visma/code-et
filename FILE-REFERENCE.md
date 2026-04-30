# FILE-REFERENCE.md

Map of every component in the code-et plugin. Used by `/code:go` for intake scoping
and as primary context for `/code:plan-issue` (so plans can skip a full codebase sweep).

## Project Overview

| Area | Description | Root path |
|------|-------------|-----------|
| Plugin | Claude Code plugin (commands, hooks, scripts) | `code-et-implementer/` |
| Repo root | Changelog, README, package metadata | `/` |

---

## Plugin — Commands

| Command | Skill name | File | Description |
|---------|------------|------|-------------|
| `/code:grill` | `code:grill` | `code-et-implementer/commands/grill.md` | Interrogate a rough idea into a refined brief |
| `/code:prd` | `code:prd` | `code-et-implementer/commands/prd.md` | Synthesise brief into `plans/YYYY-MM-DD-<slug>.md` (US-N / AC-N.M) |
| `/code:go` | `code:go` | `code-et-implementer/commands/go.md` | Feature/bug intake — scope work, auto-generate this file |
| `/code:plan-issue` | `code:plan-issue` | `code-et-implementer/commands/plan-issue.md` | Research codebase with LSP, create implementation tasks |
| `/code:implement` | `code:implement` | `code-et-implementer/commands/implement.md` | Dispatch each task via `Agent(isolation: "worktree")`, parallel where independent |

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

## Plugin — References

| File | Description |
|------|-------------|
| `code-et-implementer/references/go-reference.md` | Go command workflow and FILE-REFERENCE lifecycle |

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
| `README.md` | Plugin documentation, workflow diagrams, install instructions |
| `CHANGELOG.md` | Version history — leading entry must match `plugin.json` version |
| `package.json` | npm metadata (Next.js scaffold; not the plugin's version) |
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
| Never `git worktree add` from inside `/code:implement` | Use `Agent(isolation: "worktree")` so the subagent forks cleanly |
| Never have a subagent merge its own branch | The subagent has no view of the parent feature branch — orchestrator merges |
| Never serialize independent `/code:implement` tasks | Dispatch them in a single message with multiple `Agent` calls |

## Module Invariants

| Module | Invariant |
|--------|-----------|
| `commands/*.md` | Frontmatter must declare `effort`; coding/research commands use `xhigh` (4.7 default), `/code:grill` is the documented exception (`high`) |
| `commands/implement.md` | Each task → one `Agent(isolation: "worktree")` call; orchestrator owns merge + worktree cleanup, subagent does not |
| `commands/plan-issue.md` | Every task's `metadata.rationale` is mandatory; subagents start cold and need the *why* |
| `hooks/hooks.json` | All script paths use `${CLAUDE_PLUGIN_ROOT}` — never hard-code `code-et-implementer/scripts/...`. Add hooks only when (a) no CLAUDE.md instruction can replace them and (b) the per-event token cost is justified by the value. |
| `FILE-REFERENCE.md` | Refresh only after a PR merges to main with structural changes (`*/page.tsx`, `*/route.ts`, `*/layout.tsx`, new top-level apps/packages). Do not edit on a feature branch — it tracks merged state. |
| `scripts/*.sh` | Must exit 0 on the no-op path; non-zero exit blocks the tool/event they hook into |
| `.claude-plugin/plugin.json` | `version` must match the leading `CHANGELOG.md` entry — bump together or not at all |
| Feature lane tasks | Must carry `user_story: US-N \| AC-N.M \| chore:<reason>`; enforced by `task-created-tag-check.sh` |
