# Changelog

All notable changes to the code-et plugin will be documented in this file.

## [1.18.3] - 2026-03-07

### Added

- Auto-create feature branch in `/code:implement` — if on `main`, derives a branch name from the first task subject and checks it out before spawning the orchestrator (prevents accidental pushes to main)

## [1.18.2] - 2026-03-06

### Fixed

- Prevent implement command from entering plan mode — added explicit "No Plan Mode" instruction so it proceeds directly to launching the orchestrator

### Added

- "When to use" note in README — helps users understand when to reach for code-et vs. vanilla Claude Code

## [1.18.1] - 2026-03-06

### Fixed

- Add `TaskCreate` to orchestrator tools — needed for restoring tasks on startup
- Add merge error handling in orchestrator poll loop — failed merges now mark task as "blocked" instead of silently proceeding
- Fix `update_manifest()` to fall back to subject match when task IDs differ between manifest and native TaskList

## [1.18.0] - 2026-03-06

### Changed

- Modernize agent frontmatter: `allowed-tools` → `tools`, remove `context: fork`, `Task` → `Agent`
- Implementer now commits in worktree — orchestrator merges branch back instead of calling /commit
- Worktree isolation is now always-on via declarative `isolation: worktree` in implementer frontmatter
- Remove `--worktree` opt-in flag from `/code:implement` — worktrees are the default

### Fixed

- Add `TaskOutput` to orchestrator tools (was missing, needed for polling)

## [1.17.0] - 2026-03-06

### Changed

- `/code:plan-issue` is now fully non-interactive — evaluates approaches internally, no user prompts required
- Remove standalone mode from `/code:implement` — always delegates to subagent orchestrator (even for 1-2 tasks)
- Orchestrator poll interval increased from 5s to 10s with minimal output (logs only state changes)
- Orchestrator auto-compacts at 50% context (was 70%) with checkpoint file for state recovery

### Added

- cmux notifications in skill orchestration layer: plan complete, implement started, task done, all complete
- Orchestrator checkpoint file (`.claude/orchestrator-checkpoint.json`) preserves in-flight state across compactions

### Removed

- `AskUserQuestion` from `/code:plan-issue` allowed-tools — no longer needed
- Standalone mode (Step 3a) from `/code:implement` — subagent mode handles all cases

## [1.16.2] - 2026-03-06

### Added

- Document `CLAUDE_CODE_TASK_LIST_ID` setup in README — enables task persistence and recovery across sessions

## [1.16.1] - 2026-03-05

### Added

- Document `--plugin-dir` for local development in README — test plugin changes instantly without install/update/restart
- Add tip about `--plugin-dir` in "Building a Plugin" Step 8

## [1.16.0] - 2026-03-05

### Changed

- Drop `activeForm` from task creation and manifests — no longer required since Claude Code 2.1.69
- Remove `Edit` from orchestrator's `allowed-tools` — enforces "never implement code directly" at system level
- `inject-rules.sh` now reads `agent_type` from hook stdin — returns warning instead of rules for orchestrator agents
- `pre-compact.sh` reads `worktree.branch` from hook event data instead of spawning `git branch`
- Trimmed agent report verbosity: implementer returns 1-line COMPLETE, orchestrator uses concise progress/final reports

## [1.15.0] - 2026-03-04

### Added

- cmux-aware notifications in `run-tests.sh` — sends desktop notifications on test pass, fail, and timeout when running inside cmux
- cmux notification in `teammate-idle.sh` — alerts when an implementer appears stuck
- `/code:workspace` skill — sets up a cmux workspace named after the current git branch with optional browser pane split
- cmux integration section in CLAUDE.md documenting hook behavior

### Notes

- All cmux calls are guarded with `command -v cmux && $CMUX_SOCKET_PATH` — zero impact for non-cmux users

## [1.14.0] - 2026-03-04

### Added

- Smart execution mode for `/code:implement` — automatically chooses standalone, subagent, or team mode based on task count and complexity
- Standalone mode: 1-2 simple tasks (no deps, ≤3 files each) run inline without spawning orchestrator/implementer agents
- Decision logic evaluates `total`, `has_deps`, and `is_complex` after task loading

### Changed

- Subagent mode (previously default for all cases) is now Step 3b, triggered for 3+ tasks, dependencies, or complex tasks
- Team mode renumbered to Step 3c (content unchanged)
- `--team` flag always overrides automatic mode selection

## [1.13.0] - 2026-03-04

### Added

- File-based task persistence via `.claude/code-et-tasks.json` manifest
- `/code:plan-issue` now writes task manifest after creating native tasks (Phase 4.5)
- `/code:implement` two-source loader: tries native TaskList first, falls back to manifest file for cross-session restore
- Orchestrator accepts full task payload in prompt — solves `context: fork` visibility problem
- Orchestrator updates both native TaskList and manifest file on task completion (dual tracking)

### Changed

- `/code:implement` passes full task JSON payload to orchestrator/teammate prompts instead of relying on TaskList discovery
- Orchestrator context management reads manifest as ground truth on re-spawn

## [1.12.1] - 2026-03-03

### Fixed

- Add `Edit` and `Write` to plugin permissions so background agents (orchestrator/implementer) can modify files without user prompts

## [1.12.0] - 2026-03-03

### Added

- PreToolUse hook — injects `.claude/rules/*.md` as `additionalContext` before Write/Edit, ensuring forked agents see project conventions
- Orchestrator agent now has `memory: project` to persist learnings (test commands, patterns) across sessions

### Changed

- `run-tests.sh` uses `jq` for robust `last_assistant_message` JSON parsing (falls back to grep)
- Verify gate now detects abnormal agent exits (neither COMPLETE nor BLOCKED) and logs a warning
- BLOCKED claim output truncated to 200 chars for cleaner orchestrator logs

## [1.11.0] - 2026-03-03

### Changed

- Remove default worktree isolation from implementer agent — was causing file write failures
- Worktree isolation is now opt-in via `--worktree` flag on `/code:implement`
- Orchestrator checks `metadata.files` overlap between concurrent tasks before using worktrees
- Tasks with overlapping files or missing file metadata always run in the main working tree

## [1.10.0] - 2026-03-03

### Added

- `/code:plan-issue` command — research codebase with LSP precision (TypeScript/Python/Rust), explore approaches with user selection, and create native tasks with `file:line` references and dependencies
- Multi-language LSP detection: auto-selects `typescript-lsp`, `pyright-lsp`, or `rust-analyzer-lsp` based on project files
- Quality gate phase ensuring every task has file:line refs, verification command, and success criteria
- `expected_outcome` field in task metadata (backwards compatible with `/code:implement`)

## [1.0.0] - 2026-03-02

### Added

- `/code:implement` — orchestrator + parallel implementers in worktrees
- `/code:setup` — stack detection and settings generation
- `/code:pr` — GitHub PR creation
- `/code:cleanup` — CLAUDE.md refactoring
- `/code:bun-init` — Bun + Next.js project scaffolding
- Team mode (`--team`) with Agent Swarm support
- Verification gate hooks for implementer subagents
