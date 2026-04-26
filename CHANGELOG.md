# Changelog

All notable changes to the code-et plugin will be documented in this file.

## [3.7.3] - 2026-04-26

### Added
- **`.claude/rules/context-hygiene.md`** — new shared rule capturing three token-hygiene observations from real sessions: (1) trim attached payloads from "select-and-attach" — quote back only the slice you act on, never echo siblings or duplicated blocks; (2) Read in slices — files >200 lines must use `Read(offset, limit)`, re-reading the same file twice for different blocks is a red flag; (3) delegate broad exploration — 3+ independent search areas or fix-in-an-unknown-file goes to `Agent(subagent_type: "Explore")`, dispatched in one message for parallelism. Plus a "stop at sufficient" rule (5 sharp tasks beat 15 vague ones).

### Changed
- **Plugin `CLAUDE.md`** gains a Context Hygiene section pointing at the new rule, so it loads in every code-et session alongside brevity.
- **`/code:plan-issue`** Context Budget block deduplicates the read/explore guidance (now defers to the rule file) and adds a token-tight tip: scope to one US/AC per invocation when the context window is hot. Smaller batches let `/code:implement [task-id]` finish before the next plan.
- **`/code:implement`** dispatch prompt template tells subagents to slice-read and delegate breadth to Explore — preventing the Grep-and-Read drift that bloats subagent context when the fix path is unclear.
- **`/code:go`** Rules block points at the new rule file so FILE-REFERENCE rebuilds inherit the same hygiene.

### Notes
- No code change for "select-and-attach" trimming — that's harness-side. Rule #1 is a behavioral instruction to Claude not to echo the attached block back. A genuine fix would require the Claude Code IDE integration to strip siblings before send.
- `/code:implement [task-id]` already supports single-task runs for users who want to drain one issue at a time.

## [3.7.2] - 2026-04-26

### Changed
- **`/code:go`** gains a narrow LSP escape hatch in Step 4 — if the user names a specific function/component/type, the command may use `LSP definition`/`references` once to pin `file:line`. Otherwise FILE-REFERENCE paths stand. Adds `LSP` to the allowed-tools list. Goal: surgical precision on named symbols without putting LSP on the per-call hot path (still `/code:plan-issue`'s job).
- **`/code:go`** new context-budget rule in the Rules block: FILE-REFERENCE is the map, LSP is a scalpel for named symbols only, never read whole files in `/code:go`.
- **`/code:plan-issue`** prefixed with a **Context Budget** section that applies to both Path A and Path B: FILE-REFERENCE is the map (don't re-Glob what it lists); LSP for symbols, not project-wide sweeps; `Read(offset, limit)` for files >200 lines; parallel Explore agents for 3+ independent areas; stop at sufficient (5 sharp tasks beat 15 vague ones). Plan quality = context quality.
- **`.claude-plugin/marketplace.json`** version bumped to `3.7.2` (was stuck at `3.7.0` — the 3.7.1 release missed it).

## [3.7.1] - 2026-04-25

### Fixed
- **`code-et-implementer/.claude-plugin/plugin.json`** bumped to `3.7.1`. The `3.7.0` release tagged the repo and updated the CHANGELOG, but the plugin manifest was left at `3.6.1`, so installs of `code@code-et` continued to report the old version.

### Changed
- **`/code:implement`** now explicitly dispatches each task via the `Agent` tool with `isolation: "worktree"` and `subagent_type: "general-purpose"`. Earlier versions said "subagent in its own worktree" but didn't pin the dispatch shape, leaving room for agents to shell out to `git worktree add` and inherit parent context. Forked subagents (`CLAUDE_CODE_FORK_SUBAGENT=1`) start with a clean process and read only the dispatch prompt — matching the 4.7 cold-start model.
- **`/code:implement`** moves the merge + worktree cleanup from the subagent's deliverables to the orchestrator. Subagents inside an isolated worktree have no view of the parent feature branch; the parent skill now reads the returned worktree path/branch from the `Agent` result, runs `git merge --no-ff`, removes the worktree, and only then marks the task complete via `TaskUpdate`.
- **`/code:go`** template for `FILE-REFERENCE.md` gains five optional sections — **Database Schema**, **Domain Rules / Grammar**, **Hot Paths**, **Landmines**, and **Module Invariants** — each with discovery hints in Step 0. Sections skip-if-empty so projects without (e.g.) a DB don't get noisy stub tables. Goal: make `FILE-REFERENCE.md` rich enough that `/code:plan-issue` can skip a full codebase sweep.

## [3.7.0] - 2026-04-20

### Changed — Opus 4.7 alignment
- **`/code:implement`** now ships an explicit **Dispatch prompt template**. Each worktree subagent starts cold, so the first turn carries intent, PRD context, rationale, `file:line` anchors, expected outcome, verification, constraints, and deliverables — matching the 4.7 "delegate to a capable engineer" model instead of progressive pair-programming.
- **`/code:implement`** bumped to `effort: xhigh` (4.7 recommended default for coding work — previous `medium` was mis-scoped per Anthropic's 4.7 guidance).
- **`/code:implement`** now states explicitly that independent tasks MUST be dispatched in a single concurrent batch. 4.7 spawns subagents more judiciously and requires an explicit parallelism cue.
- **`/code:plan-issue`** task metadata gains a mandatory **`rationale`** field (feature and bug lanes). Captures *why* a task exists — the constraint or decision driving it — so subagents can make judgment calls without round-tripping.
- **`/code:plan-issue`**, **`/code:go`**, **`/code:prd`** bumped to `effort: xhigh`.
- Plugin **`CLAUDE.md`** updated to document the new metadata shape (`rationale` + `user_story` fields + `file:line` anchors).

### Notes
- Requires Claude Opus 4.7 to see the full benefit; older models still run the same flow but without the adaptive-thinking gains.
- `/code:grill` deliberately stays `effort: high` — it's a progressive, one-question-at-a-time flow, which is the exception to 4.7's "batch upfront" guidance.

## [3.6.1] - 2026-04-20

### Fixed
- **`/code:plan-issue`** no longer tries to invoke `/ultraplan` via `Skill("ultraplan", ...)`. `/ultraplan` is a built-in Claude Code command (research preview), not a callable skill, so the delegation in 3.6.0 would fail every run and unconditionally trip the fallback announcement. Feature lane now goes PRD → LSP decomposition directly, with the same `US-N` / `AC-N.M` / `chore:` tagging.
- README, marketplace, and plugin descriptions updated to reflect the LSP-only path. Users who want upstream `/ultraplan` can run it manually and commit the refined plan to `plans/` before `/code:plan-issue`.

## [3.6.0] - 2026-04-20

### Added
- **`/code:grill`** — interrogates a rough idea into a refined brief (one question at a time, codebase-first; "you decide" converges)
- **`/code:prd`** — synthesises the brief into `plans/YYYY-MM-DD-<slug>.md` with user stories (US-N) and acceptance criteria (AC-N.M). Sets session title `feat:<slug>`
- **`SessionStart` hook** — injects a 3-line PRD pointer on branches with a matching PRD
- **`TaskCreated` hook** — enforces `user_story: US-N | AC-N.M | chore:<reason>` tag on feature-lane tasks
- **`PreCompact` hook** — injects open-stories summary before compaction (multi-session continuity)
- **`PostToolUse` hook on `Bash`** — suggests `/ultrareview <PR#> --context plans/<slug>.md` after `gh pr create` when a PRD exists
- **`resolve-prd.sh`** shared helper — branch → `plans/YYYY-MM-DD-<slug>.md`
- **Bats test suite** for hook scripts under `code-et-implementer/tests/`

### Changed
- **`/code:plan-issue`** now detects an active PRD, delegates decomposition to `/ultraplan`, tags every task with `user_story`, and LSP-enriches with `file:line`. Falls back to LSP-only path with a one-line announcement when `/ultraplan` is unreachable
- **`/code:implement`** prefixes commits with `US-N:` / `AC-N.M:` / `chore:` and ticks the PRD checklist when a story completes
- **README** documents the two-lane (bug + feature) workflow

### Notes
- Requires Claude Code ≥ 2.1.94 for `UserPromptSubmit.sessionTitle`
- `/ultraplan` and `/ultrareview` are cloud-hosted Anthropic skills — feature lane degrades gracefully when offline
- Bug lane (`/code:go` → `/code:plan-issue` → `/code:implement`) is unchanged when no PRD exists

## [3.5.1] - 2026-04-11

### Added
- **Brevity rules** (caveman-inspired) — agents drop filler, hedging, and pleasantries; task subjects enforced as `<verb> <object>` ≤50 chars. Rules shipped in `.claude/rules/brevity.md` and injected via `inject-rules.sh` for subagents, `CLAUDE.md` for main agent, and inline in `/code:go` and `/code:plan-issue`
- **Plugin-bundled rules injection** — `inject-rules.sh` now scans both the user's project `.claude/rules/` and the plugin's own `.claude/rules/`, so brevity rules travel with the plugin without requiring user setup

## [3.5.0] - 2026-04-06

### Added
- **`effort` frontmatter** — skills now declare thinking effort: `high` for `/code:go` and `/code:plan-issue` (deep research), `medium` for `/code:implement` (orchestration)
- **`FileChanged` hook** — auto-detects when page/route/layout files change and notifies that `FILE-REFERENCE.md` may be stale, prompting `/code:go update`

## [3.4.0] - 2026-03-27

### Added
- **`/code:go` command** — feature/bug intake assistant that scopes work by identifying exact app, screen, and files. Auto-generates `FILE-REFERENCE.md` on first run by scanning the project; run `/code:go update` to refresh it later
- **`references/go-reference.md`** — documents the go command workflow and FILE-REFERENCE.md lifecycle

## [3.3.0] - 2026-03-14

### Changed
- **Remove `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`** — 1M context is now default for Opus 4.6 and token estimation fixes make the 70% override unnecessary. Let Claude Code use its built-in default.
- **Fix spinner tips** — replace stale `/code:pr` reference with `commit-commands` plugin, remove auto-compact percentage tip

## [3.2.0] - 2026-03-10

### Changed
- **`plan-issue`** — explicit dependency graph reasoning with `blocked_by` for parallel task execution
- **`implement`** — explicit worktree lifecycle: subagent → worktree → test → commit → merge back → remove worktree → mark done

## [3.1.0] - 2026-03-09

### Removed
- **`/code:cleanup` command** — redundant with official `claude-md-management` plugin (`/revise-claude-md`, `/claude-md-improver`). code-et now ships 2 core commands: `plan-issue` and `implement`

## [3.0.0] - 2026-03-09

### Changed
- **Radically simplified commands** — `plan-issue` (95→18 lines), `implement` (115→15 lines), `cleanup` (66→7 lines). Claude already knows how to use LSP, agents, and worktrees — stop over-constraining it
- **Removed `/code:pr`** — use `commit-commands:commit-push-pr` instead (official plugin, better maintained)
- **Removed `/code:setup`** — one-off utility, not core workflow
- **Updated CLAUDE.md** — 3-command table, references companion plugins for commit/PR/review
- **Updated README** — new workflow diagram (plan → implement → `/commit-push-pr`), plugin stack shows 3 commands, companion plugin references

### Removed
- `commands/pr.md` — replaced by `commit-commands` plugin
- `commands/setup.md` — one-off utility removed from core

## [2.4.3] - 2026-03-09

### Fixed
- **Delete `agents/implementer.md`** — Claude was auto-selecting the plugin agent as a single orchestrator instead of spawning per-task agents. Removing the file entirely prevents this; agent memory requires native agent definitions (not plugin `agents/` directory)

## [2.4.2] - 2026-03-09

### Fixed
- **Revert `code:implementer` agent type** — plugins don't support `agents/` directory for custom agent definitions yet; reverted to `general-purpose` with `isolation: "worktree"` in Agent calls to restore one-agent-per-task behavior (was causing single orchestrator fallback)

## [2.4.1] - 2026-03-09

### Fixed
- **inject-rules.sh stdin hang** — added `[ ! -t 0 ]` guard to prevent `cat` blocking on terminal input
- **Implementer Agent recursion risk** — removed `Agent` from implementer tools list (prevents unbounded sub-agent spawning)
- **PermissionRequest hot-path** — switched `auto-approve-readonly.sh` shebang to `#!/bin/sh` for faster process startup

## [2.4.0] - 2026-03-09

### Added
- **PermissionRequest hook** — auto-approves Read, Grep, Glob, LSP for agents (no more permission prompts for read-only ops)
- **TaskCompleted hook** — cmux desktop notification + agent attribution on task completion
- **InstructionsLoaded hook** — diagnostic logging of loaded instruction files
- **agent_id/agent_type tracking** — inject-rules.sh and run-tests.sh now log agent identity for traceability
- **Agent memory (experimental)** — `agents/implementer.md` with `memory: project` for persistent agent memory across sessions; `implement.md` uses `subagent_type: "code:implementer"` with worktree isolation in agent definition

## [2.3.1] - 2026-03-08

### Changed

- **Stronger parallel agent example** — background agent mode now shows explicit example with 3 separate Agent calls in one message, making it unambiguous that each task gets its own agent

## [2.3.0] - 2026-03-08

### Fixed

- **Background agent mode ignored** — Claude was dumping all tasks into a single agent instead of spawning one per task. Made mode selection rules explicit with CRITICAL enforcement note
- **`/simplify` runs after implement** — re-added `Skill("simplify")` call in wrap-up step with `Skill` added to allowed-tools

## [2.2.2] - 2026-03-08

### Fixed

- **CLAUDE.md missing commands** — added setup and cleanup to Commands table (was only showing 3 of 5)
- **pr.md Skill() call blocked** — replaced `Skill("commit-commands:commit")` with direct `git commit` (Skill not in allowed-tools, and depends on external plugin)
- **run-tests.sh timeout bug** — multi-command chains (`bun test && bun run lint`) weren't fully wrapped by timeout; now uses `bash -c` to wrap the entire chain
- **setup.md stale `context: fork`** — removed (deprecated since v1.18.0)

## [2.2.1] - 2026-03-08

### Fixed

- **LSP skipped during planning** — strengthened Phase 2 enforcement from "HARD RULE" to "MANDATORY — DO NOT SKIP" with consequence warning so Claude doesn't skip LSP and create tasks with wrong line numbers
- **Manifest write fails** — added `mkdir -p .claude` before writing manifest file (`.claude/` directory may not exist in target projects)

## [2.2.0] - 2026-03-08

### Fixed

- **SubagentStop hook dead** — matcher `"implementer"` never fired since v2.0.0 deleted that agent type. Changed to `""` to match all subagents, restoring verification gate for background agents
- **Stale `/simplify` reference** in implement.md — removed (belongs to code-review plugin, not code-et)
- **README stale references** — updated hook example from `code:implementer` to `""`, added setup/cleanup to all 5 command listings
- **package.json version** stuck at 1.0.0, synced to 2.2.0
- **Script comments** updated from "Implementer" to "Agent" in verify-gate.sh and run-tests.sh

## [2.1.1] - 2026-03-08

### Fixed

- Fix `code:implementer` agent type not found error — background agent mode now uses `general-purpose` subagent type (the old `code:implementer` agent was removed in v2.0.0)

## [2.1.0] - 2026-03-08

### Added

- Restore `/code:cleanup` skill — refactor CLAUDE.md with progressive disclosure, move rules to `.claude/rules/`, clean auto-memory
- Restore `/code:setup` skill — detect project stack, generate `settings.json` permissions, optionally create deployment scripts
- README updated to document all 5 commands

## [2.0.0] - 2026-03-08

### Changed

- **Radical architecture simplification** — delete orchestrator and implementer agents entirely. The main session IS the orchestrator. 3 layers → 1 flat layer.
- **3 commands only** — `plan-issue`, `implement`, `pr`. Deleted: `workspace`, `cleanup`, `setup`, `bun-init`
- **3 execution modes in implement** — inline (1-2 tasks), background agents with worktree isolation (2-5 tasks), agent swarm (5+ tasks / `--team`). Claude chooses automatically.
- **2 hooks only** — `PreToolUse` (inject rules) and `SubagentStop` (verify gate). Deleted 6 hooks: Stop, SessionEnd, PreCompact, ConfigChange, TeammateIdle, TaskCompleted
- **Simplified CLAUDE.md** — trimmed from 67 lines to 30 lines, 3-command reference table
- **~55k fewer tokens per run** — no orchestrator prompt, no polling loop, no checkpoint management

### Removed

- `agents/orchestrator.md` — main session handles coordination directly
- `agents/implementer.md` — agents get focused 15-line prompts instead of 129-line framework
- `scripts/check-context.sh` — Stop hook removed
- `scripts/session-end.sh` — SessionEnd hook removed
- `scripts/config-validate.sh` — ConfigChange hook removed
- `scripts/pre-compact.sh` — PreCompact hook removed
- `scripts/teammate-idle.sh` — TeammateIdle hook removed
- `scripts/team-task-complete.sh` — TaskCompleted hook removed
- `commands/workspace.md` — cmux workspace setup (use cmux directly)
- `commands/cleanup.md` — CLAUDE.md refactoring (one-off task)
- `commands/setup.md` — stack detection (one-off task)
- `commands/bun-init.md` — project scaffolding (one-off task)
- Orchestrator guard from `inject-rules.sh` — no orchestrator to guard

## [1.22.0] - 2026-03-08

### Fixed

- **LSP enforcement in plan-issue** — `file:line` references now MUST come from LSP calls, not Read/Grep output. Previous advisory "always use LSP" replaced with hard rule + quality gate enforcement
- **Parallel agent support in plan-issue** — add Agent tool, enable Explore agent spawning for multi-area research with anti-polling guardrails

### Changed

- Phase 0.8 rewritten as MANDATORY constraint (was advisory "always use it")
- Phase 1 simplified with LSP-first workflow and parallel mode for 3+ subsystems
- Phase 2.5 quality gate now enforces LSP-sourced line numbers before task creation

## [1.21.0] - 2026-03-07

### Changed

- **Rewrite orchestrator as pure agent spawner** — tools stripped to `Bash(git:*), Agent, TaskOutput, TaskUpdate` only. No Read, Write, or Task management tools. Orchestrator physically cannot implement code directly.
- Remove manifest file management from orchestrator — all state tracked in conversation context, no checkpoint files
- Remove TaskCreate, TaskList, TaskGet from orchestrator — task data passed in prompt, no runtime task discovery
- Bump team mode cap from 8 to 14 concurrent teammates

### Added

- LSP tool for implementer agent — enables `goToDefinition`, `findReferences`, and `hover` for precise code navigation during implementation
- LSP guidance in implementer instructions — prefer LSP over Grep for code structure exploration

### Fixed

- Root cause of `DIRECT_IMPLEMENTATION` — orchestrator had Read/Write tools which enabled it to read/edit source files instead of spawning implementer agents
- Tasks not closing after completion — simplified orchestrator no longer fights with manifest sync and blockedBy chain management

## [1.20.0] - 2026-03-07

### Changed

- Remove `Grep` and `Glob` tools from orchestrator — prevents codebase exploration that leads to direct implementation
- Remove `Edit` tool from implement command — launcher should never edit files
- Add mandatory "First Action" section to orchestrator — forces immediate implementer spawning, no source file reading
- Rewrite cost awareness rule — removed "batch small tasks" which contradicted "always spawn implementer"
- Strengthen orchestrator identity as pure coordinator: spawn agents → poll → merge → repeat

### Fixed

- Root cause of orchestrator implementing code directly: had exploration tools + ambiguous cost rule that encouraged bypassing implementer agents

## [1.19.2] - 2026-03-07

### Fixed

- Orchestrator implementing code directly instead of spawning implementer subagents — burns main session tokens
- Added hard enforcement: orchestrator may only Read/Write manifest and checkpoint JSON, never source files
- Strengthened `DIRECT_IMPLEMENTATION` failure mode with explicit file extension blocklist
- Updated spinner tip to reflect max 14 concurrent implementers

## [1.19.1] - 2026-03-07

### Changed

- Increase max concurrent implementer agents from 5 to 14
- Pass `metadata.files` scope to implementer prompt — agents now only modify listed files
- Add `OUT_OF_SCOPE_FILE` failure mode to implementer — returns BLOCKED instead of editing unrelated files
- Reinforce scope enforcement in implementer input spec and SCOPE_CREEP anti-pattern

### Fixed

- Implementers wandering outside task scope, editing files not in the task's file list
- Excessive token burn from implementers re-analyzing entire codebase instead of focusing on scoped files

## [1.19.0] - 2026-03-07

### Added

- Named failure mode tables in orchestrator and implementer agents — explicit anti-patterns with self-correction actions
- Cost awareness rule in orchestrator — batch tasks, avoid trivial re-spawns
- Adaptive polling — 10s initially, 30s after 2 minutes to reduce token burn
- Quality gates in `run-tests.sh` — detects and runs lint + typecheck alongside tests
- Pre-compact hook re-injects manifest summary + checkpoint context after compaction
- Plan-issue now uses built-in `LSP` tool instead of nonexistent MCP LSP tools — agents always use LSP for code navigation

### Changed

- Consolidated 4 separate jq calls into single invocation in pre-compact hook
- Extracted `_add_gate()` helper in run-tests.sh to eliminate copy-paste bun/npm detection

## [1.18.4] - 2026-03-07

### Added

- Document `@ref` version-pinning syntax in README install section — users can now pin to a specific version with `/plugin marketplace add Emerging-Tech-Visma/code-et@v1.18.4`

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
