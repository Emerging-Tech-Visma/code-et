# FILE-REFERENCE.md

Map of every component in the code-et plugin (v5). Used by `/code:fix` for intake scoping and as primary context for `/code:plan` (so plans can skip a full codebase sweep).

## Project Overview

| Area | Description | Root path |
|------|-------------|-----------|
| Plugin | Claude Code plugin (commands, hooks, scripts, templates) | `code-et-implementer/` |
| Repo root | Changelog, README, marketplace manifest | `/` |

---

## Plugin — Commands (v5.0)

| Command | Skill name | File | Description |
|---------|------------|------|-------------|
| `/code:start` | `code:start` | `code-et-implementer/commands/start.md` | Scaffold a new Bun + Hono + Drizzle TypeScript project; deep-modules shape |
| `/code:install-ci` | `code:install-ci` | `code-et-implementer/commands/install-ci.md` | Drop the audit GitHub workflow into an existing TS repo |
| `/code:fix` | `code:fix` | `code-et-implementer/commands/fix.md` | Single-bug intake → Task Brief; user implements directly |
| `/code:plan` | `code:plan` | `code-et-implementer/commands/plan.md` | Refined brief → PRD on disk → vertical-slice tasks (3 checkpoints) |
| `/code:ship` | `code:ship` | `code-et-implementer/commands/ship.md` | Parallel worktree agents + post-merge audit + 1-pass auto-retry on CRITICAL/HIGH |
| `/code:review` | `code:review` | `code-et-implementer/commands/review.md` | Pre-merge gate — local audit + diff review (delegates to engineering plugin) |

## Plugin — Doctrine

| File | Description |
|------|-------------|
| `code-et-implementer/docs/architecture.md` | Deep modules, dependency categories, seam discipline. Vocabulary from Ousterhout (deep modules) and Feathers (seams). |
| `code-et-implementer/docs/anti-slop.md` | 4 elements (shallow modules, duplication, defensive over-programming, drift), 5 categories, 8 hard rules. |
| `code-et-implementer/docs/testing.md` | Interface-as-test-surface; module-interface, HTTP-seam, e2e patterns with `bun test`. Mirror-test ban. |

## Plugin — Hooks

| File | Description |
|------|-------------|
| `code-et-implementer/hooks/hooks.json` | One hook: `PermissionRequest` auto-approves Read/Grep/Glob/LSP. v4's TaskCreate regex, PRD-resume, SubagentStop audit, etc. all dropped — trust-the-model. |

## Plugin — Scripts

| Script | File | Description |
|--------|------|-------------|
| Auto-approve readonly | `code-et-implementer/scripts/auto-approve-readonly.sh` | Auto-approves Read/Grep/Glob/LSP for agents |

## Plugin — Templates

| Path | Description |
|------|-------------|
| `code-et-implementer/templates/typescript/` | The full TS scaffold copied by `/code:start`. `package.json`, `tsconfig.json`, `biome.json`, `drizzle.config.ts`, an example `greetings` module + HTTP route + tests, and a composition-root `main.ts`. |
| `code-et-implementer/templates/shared/.github/workflows/code-et-audit.yml` | CI workflow — Bun + Biome + tsc + bun audit + bun test. |
| `code-et-implementer/templates/shared/CLAUDE.md.template` | Per-project CLAUDE.md scaffolded into each new project. |
| `code-et-implementer/templates/shared/UPDATING.md` | Maintainer checklist for keeping the template aligned with upstream TS ecosystem. |

## Plugin — Config

| File | Description |
|------|-------------|
| `code-et-implementer/.claude-plugin/plugin.json` | Plugin manifest (name, version, description) — **must stay in sync with CHANGELOG version**. |
| `code-et-implementer/.claude-plugin/settings.json` | Plugin settings (plans dir, permissions, spinner tips). |
| `code-et-implementer/CLAUDE.md` | Plugin-level Claude instructions. |

## Repo Root

| File | Description |
|------|-------------|
| `README.md` | Plugin documentation, workflow diagrams, install instructions. |
| `CHANGELOG.md` | Version history — leading entry must match `plugin.json` version. |
| `.claude-plugin/marketplace.json` | Marketplace manifest (points at `code-et-implementer/`). |
| `plans/` | PRDs and plan artifacts (`YYYY-MM-DD-<slug>.md`). |

---

## Hot Paths

| Path type | Files |
|-----------|-------|
| Per-readonly-permission-request (Read/Grep/Glob/LSP) | `scripts/auto-approve-readonly.sh` |
| Per-`/code:*`-invocation | `commands/<name>.md` |
| Once on install | `.claude-plugin/plugin.json`, `.claude-plugin/settings.json` |

A regression in `auto-approve-readonly.sh` blocks every read permission prompt — treat changes there as wide-blast-radius.

## Landmines

| Rule | Why |
|------|-----|
| Never push directly to `main` | Branch + PR only — see `code-et-implementer/CLAUDE.md` |
| Never force push | Rebase locally, push normally |
| Never bump only `CHANGELOG.md` without `plugin.json` | The 3.7.0 release shipped with manifest stuck on 3.6.1 — installs reported the old version |
| Never call `/ultraplan` via `Skill("ultraplan", …)` | It's a built-in Claude Code command, not a callable skill |
| Never `git worktree add` from inside `/code:ship` | Use `Agent(isolation: "worktree")` so the subagent forks cleanly |
| Never have a subagent merge its own branch | The subagent has no view of the parent feature branch — orchestrator merges |
| Never serialize independent `/code:ship` tasks | Dispatch in a single message with multiple `Agent` calls |
| Never extract a shallow helper "for testability" | Apply the deletion test first — would removal concentrate complexity, or just move it? |

## Module Invariants

| Module | Invariant |
|--------|-----------|
| `commands/*.md` | Frontmatter must declare `effort`; defaults to `xhigh` for plan/ship/start, `high` for fix/review/install-ci. |
| `commands/ship.md` | Each task → one `Agent(isolation: "worktree")` call; orchestrator owns merge + worktree cleanup, subagent does not. Post-merge audit auto-retries once on CRITICAL/HIGH. |
| `commands/plan.md` | Every task's `metadata.rationale` is mandatory; subagents start cold and need the *why*. PRD lands on disk before task decomposition (Phase 2 → Phase 3 checkpoint). |
| `docs/architecture.md` | Vocabulary is non-negotiable: module / interface / seam / adapter / depth / leverage / locality. Don't drift into "component" / "service" / "API" / "boundary". |
| `hooks/hooks.json` | All script paths use `${CLAUDE_PLUGIN_ROOT}`. Add hooks only when (a) no doctrine/skill instruction can replace them and (b) the per-event token cost is justified by the value. |
| `templates/typescript/` | The `greetings` module is the canary: any template change must keep `bun run audit` green after `/code:start` runs. |
| `.claude-plugin/plugin.json` | `version` must match the leading `CHANGELOG.md` entry. |
| Feature lane tasks | Must carry `user_story: US-N \| AC-N.M \| chore:<reason>` (one tag, not alternation). |
