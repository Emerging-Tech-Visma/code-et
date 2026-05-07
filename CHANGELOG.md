# Changelog

All notable changes to the code-et plugin will be documented in this file.

## [4.0.1] - 2026-05-07

### Changed — `/code:fix` Task Brief now states Goal + Verification

The `/code:fix` Task Brief template (`code-et-implementer/commands/fix.md`) gains two mandatory lines after `Description`:

- **Goal** — observable success criterion ("what's true after the fix that wasn't before").
- **Verification** — runnable cmd + expected outcome (or manual repro steps for visual fixes).

`/code:plan` already encoded this through `metadata.expected_outcome` + `metadata.verification`, which `/code:ship` injects into every dispatched subagent and enforces in the per-subagent contract. `/code:fix` hands the Brief straight to a human implementer — no orchestrator, no `SubagentStop` hook — so the goal-and-test pair belongs in the Brief itself. With the addition both lanes (bug + feature) close the "did we achieve it" loop symmetrically.

The Rules section also gains: "If you can't state Verification, the bug isn't scoped tightly enough — ask another clarifying question."

No changes to `/code:plan`, `/code:ship`, or the Clean Architecture rules — fix.md already references `code-et-implementer/docs/architecture.md` and the Layer column in the Files-to-touch table already enforces the Dependency Rule by inspection.

## [4.0.0] - 2026-05-06

**Breaking restructure** — the plugin is now pure-Rust only and condenses to six commands. Existing PRDs and tasks under `plans/` and `.claude/<id>.json` continue to work, but the entry-point command names have changed. See the migration table below.

### Changed — six commands, two lanes

The v3.x command set (`/code:bootstrap`, `/code:go`, `/code:grill`, `/code:prd`, `/code:plan-issue`, `/code:implement`, `/code:audit`, `/code:install-ci`) collapses to:

| v3.x | v4.0 | Why |
|---|---|---|
| `/code:bootstrap` | `/code:start` | Same behavior; renamed for "what you do day one". Now runs `cargo update` post-scaffold so every dep is at its latest semver-compatible patch. |
| `/code:go` | `/code:fix` | Same behavior; renamed for "what you do when something is broken". Pure-Rust now — no more "Rust projects only" conditionals. |
| `/code:grill` + `/code:prd` + `/code:plan-issue` | `/code:plan` | One extended turn (refined brief → PRD on disk → vertical-slice tasks) with three checkpoints. PRD lands on disk before task decomposition starts so you can interrupt and edit. Includes inline anti-slop self-critique before `TaskCreate`. |
| `/code:implement` | `/code:ship` | Same parallel-worktree dispatch logic, but the post-merge audit is now built in. On CRITICAL/HIGH findings, dispatches **one** auto-retry fix-pass; if still failing, halts and surfaces the highest finding. No infinite loops. |
| `/code:audit` (top-level) | `just audit` (in scaffolded projects) and the inner step of `/code:ship` | The standalone `/code:audit` command is gone. The `audit.sh` script and the CI workflow are unchanged — they run via `just audit`, the `SubagentStop` hook, and `/code:ship`'s tail step. |
| (none) | `/code:review` | New — pre-merge gate that runs the full audit + diff review against `<merge-base>..HEAD`. Delegates to engineering plugin's `code-review` skill if installed; falls back to a 5-area inline checklist (layer compliance, anti-slop, test coverage, security, slice integrity). |
| `/code:install-ci` | `/code:install-ci` | Unchanged — retrofit the audit gate onto an existing Rust repo. |

### Changed — plugin posture

- **Pure-Rust only.** Dropped all "if Rust" / "if TS legacy" conditionals from commands, CLAUDE.md, and metadata. Every project that uses code-et follows the four-crate Clean Architecture workspace.
- **Always-latest deps.** `/code:start` runs `cargo update` post-scaffold. Caret pins (`dioxus = "0.7"`, `axum = "0.8"`, `sqlx = "0.8"`, `tokio = "1"`, `tower = "0.5"`) deliver latest minor/patch automatically. Major bumps documented as a manual `cargo upgrade` flow.
- **README cut from 605 to 203 lines.** Single page: workflow diagram, six commands, install, prereqs, doctrine links, migration table. The "Building a Plugin from Scratch" section is removed — it belonged in a separate guide, not the user-facing README.
- **CLAUDE.md trimmed** — dropped TS-legacy paragraphs and "if Rust" conditionals; everything assumes the four-crate stack.

### Changed — `/code:ship` adds an auto-retry contract

After all task subagents land and merge, `/code:ship`:
1. Runs `Skill("simplify")` for changed-code refactor pass.
2. Runs `bash audit.sh` (full seven-stage gate).
3. On CRITICAL/HIGH, dispatches **one** fix-pass subagent on the feature branch (no worktree isolation, since the swarm already merged), then re-audits.
4. After 1 retry, halts and surfaces the highest finding. No infinite loops.

This makes `/code:ship` self-healing for routine misses (a missed `cargo fmt`, a single clippy warning, a layer slip) without burning tokens on stuck audits.

### Changed — `/code:plan` adds inline anti-slop self-critique

Before `TaskCreate`, `/code:plan` walks the drafted task list and **rejects** any task that:
- Touches only one layer (split or merge into a vertical slice).
- Has rationale "because the PRD says so" (restate the underlying constraint).
- Adds a duplicate utility instead of extracting (Rule of Three triggers refactor in the same task).
- Adds defensive validation between trusted modules (`interface↔application` is the only validation boundary).
- Adds a mirror test (assert observable behaviour, not implementation calls).
- Has no test for at least one acceptance criterion.

The full list lives in `code-et-implementer/docs/anti-slop.md`. The inline summary keeps the model focused at plan time without an extra file read.

### Added — deploy & upload via scripts

- **`scripts/deploy.sh`** in every scaffolded project — single entry point for shipping the server. Pre-flight (clean tree + audit) → build container → run migrations → roll out → smoke check. Host-specific lines (`gcloud run deploy`, `kubectl set image`, `flyctl deploy`) are `# TODO:` placeholders to fill in once per project.
- **`scripts/upload.sh`** — single entry point for uploading static artifacts (web bundle / desktop binaries / mobile builds) to CDN / object store / app store. Same discipline as deploy.
- **`just deploy <env>`** and **`just upload <kind> <env>`** justfile targets wrap the scripts.
- **CLAUDE.md template** encodes the rule: never deploy/upload via raw `cargo`/`docker`/`gcloud`/`gsutil` commands. If you find yourself typing the underlying command, add the missing step to the script instead.

### Unchanged

- **Doctrine** (`docs/architecture.md`, `docs/anti-slop.md`, `docs/testing.md`) — already lean and sharp.
- **Hooks** (`PermissionRequest`, `SubagentStop`, `SessionStart`, `TaskCreated`, `TaskCompleted`, `PreCompact`) — net-positive, low cost.
- **Templates** (`templates/rust/dioxus-fullstack/`, `templates/shared/`) — same scaffold; `/code:start` now runs `cargo update` after copying.
- **CI gate** (`code-et-audit.yml`, `layer-deps-validator.sh`) — unchanged. `audit.sh` parses the yaml at runtime so local and CI cannot drift.

### Migration

| If you used v3.x for | In v4.0 do |
|---|---|
| Bootstrap | `/code:start <name>` |
| Single bug | `/code:fix "<bug>"` |
| Feature (full lane) | `/code:plan "<idea>"` → `/code:ship` → `/code:review` |
| Pre-merge audit | `/code:review` (or `just audit` for static-only) |
| Standalone audit | `bash scripts/audit.sh` or `just audit` (no slash command) |
| CI retrofit | `/code:install-ci` (unchanged) |

PRD files under `plans/YYYY-MM-DD-<slug>.md` continue to work with `/code:plan` (Phase 3 takes an existing PRD and jumps straight to task decomposition).

## [3.9.0] - 2026-05-06

### Added — Pure-Rust Clean Architecture

- **`/code:bootstrap`** — scaffold a pure-Rust full-stack project (`axum + sqlx + Dioxus 0.7+ + tokio`) with the 4-crate Clean Architecture workspace (`domain`, `application`, `infrastructure`, `interface`) + 4 apps (`server`, `desktop`, `web`, `mobile`). One UI codebase via Dioxus features renders on web, desktop, and mobile. Refuses to run if CWD has `Cargo.toml`/`package.json` (use `--force` to overlay). Tool installs are opt-in via `--install-tools`; default prints a checklist. Targets configurable via `--targets web,desktop,mobile`; database via `--db sqlite|postgres`.
- **`/code:install-ci`** — drop the audit GitHub workflow + layer-deps validator into an existing Rust repo. Idempotent; `--force` to overwrite. Validator is no-op safe on projects without `crates/<layer>/` structure.
- **Doctrine layer** at `code-et-implementer/docs/`:
  - `architecture.md` — Rust Clean Architecture, 4-crate workspace, Dioxus 0.7+ targets matrix, GCP Cloud SQL + IAM auth, SQLite for local, sqlx with parameter binding (`query!` as the goal), forward-only migrations, GCP Secret Manager + `secrecy::Secret<T>`, Rust security checklist (10 items), Uncle Bob's Clean Architecture excerpt verbatim.
  - `anti-slop.md` — 4-element framework (dead code, duplication, complexity, drift), 5 slop categories (Superficial Competence, Unnecessary Complexity, Defensive Over-Programming, Mirror Tests, Inconsistent Styling), 4-stage CI verification loop, 6 hard rules.
  - `testing.md` — per-layer test matrix (`#[cfg(test)]` for domain, `mockall` for application, `#[sqlx::test]` for infrastructure, `axum-test` + `dioxus-testing` for interface), contract tests at every port, security test cases at every interface boundary, mirror-test ban with concrete examples.

### Added — CI gate as the authoritative enforcement layer

- `templates/shared/.github/workflows/code-et-audit.yml` — runs on every PR + push to main. Pipeline: `cargo fmt --check`, `cargo clippy --all-targets --all-features -- -D warnings`, `scripts/layer-deps-validator.sh`, `cargo machete`, `cargo audit`, `cargo deny check`, `cargo nextest run --workspace --all-features`. Postgres service container available for tests; SQLite default for unit tests.
- `templates/shared/scripts/layer-deps-validator.sh` — 30-line bash that reads each crate's `[dependencies]` and asserts the inward dependency rule. Defence-in-depth: the `cargo` build is the primary gate; the validator emits an explicit error message when a `[dependencies]` table drifts.
- `templates/shared/CLAUDE.md.template` — seeded into bootstrapped projects; references plugin doctrine + names `engineering` plugin and `rust-analyzer-lsp` as recommended companions.
- `templates/shared/UPDATING.md` — checklist for keeping templates aligned with upstream (axum, sqlx, dioxus minor bumps; GHA action majors).
- `templates/rust/dioxus-fullstack/` — full working sample: `User` entity in `domain`, `CreateUser`/`GetUser` use cases + `UserRepo` port in `application`, `SqliteUserRepo` impl in `infrastructure`, axum router + Dioxus `App`/`UserCard` components in `interface`, composition roots in `apps/{server,desktop,web,mobile}/main.rs`. `clippy.toml` with cognitive-complexity threshold 15. `deny.toml` with license + source policies. `rust-toolchain.toml` pinned to stable. `Dioxus.toml`, `justfile` with `just audit` mirroring CI, `migrations/20250101000000_init.sql` (SQLite + Postgres compatible).

### Changed — CLAUDE.md as the lean control plane

- **`code-et-implementer/CLAUDE.md`** re-flavoured to Rust:
  - `verification` example: `bun test && bun run lint` → `cargo nextest run && cargo clippy --all-targets -- -D warnings`.
  - Code Standards: TypeScript strict / server components → Rust 2024 edition / `clippy --deny warnings` / `cargo fmt --check` / "compose at app boundaries".
  - File-path examples: `src/path/to/file.ts:42` → `crates/<layer>/src/path/to/file.rs:42`.
  - Task subject example: `api/middleware.ts` → `interface/http/middleware.rs`.
  - FILE-REFERENCE.md lifecycle: structural file globs now include `crates/*/Cargo.toml`, `apps/*/Cargo.toml`, root `Cargo.toml`, `migrations/*` for Rust projects (TS legacy globs retained for non-Rust repos).
- **New "Clean Architecture (Rust) — controlling rules" section** (≤ 12 lines): names the four layers, the Dependency Rule (cargo enforces it), Dioxus 0.7+ for web/desktop/mobile, sqlx + Postgres-on-GCP / SQLite, and a delegation map naming the engineering plugin's skills (`code-review`, `tech-debt`, `testing-strategy`, `system-design`) and `rust-analyzer-lsp` as the human-judgment + LSP companions.
- **`Task Metadata Convention`** gains `metadata.layer` (`domain` | `application` | `infrastructure` | `interface` | `chore`). Mandatory on Rust projects (CWD has `Cargo.toml`); optional on legacy TS.

### Changed — command + hook integration

- **`commands/go.md`** — Task Brief gains a `Layer` column on Rust projects. 1-line pointer to CLAUDE.md §"Clean Architecture (Rust)" near the scoping step.
- **`commands/plan-issue.md`** — `metadata.layer` is mandatory on Rust projects; layer-violating import directions are rejected at planning time. LSP guidance now names `rust-analyzer-lsp` (Rust) alongside the legacy `typescript-lsp` mention. 1-line pointer to CLAUDE.md.
- **`commands/implement.md`** — Constraints block references the Rust controlling rules and `docs/architecture.md` / `docs/anti-slop.md` instead of "TypeScript strict". Subagents respect per-file `metadata.layer`.
- **`scripts/task-created-tag-check.sh`** — extends the existing `user_story` check to additionally require `metadata.layer ∈ {domain, application, infrastructure, interface, chore}` on Rust projects (detected via `Cargo.toml` at repo root). Non-Rust projects unaffected.
- **`run-tests.sh` / `verify-gate.sh` unchanged** — `run-tests.sh` already auto-detects `Cargo.toml` and runs `cargo test`. The CI gate is the strongest enforcement; local hooks remain for fast feedback.

### Changed — README + companion plugin posture

- **README.md** — new top section describes the Rust Clean Architecture focus + v3.9.0 highlights. New "Required companions" block: `knowledge-work-plugins/engineering` and `rust-analyzer-lsp` (replaces the broad `typescript-lsp` recommendation as the default LSP). Skills Reference table gains rows for `/code:bootstrap` and `/code:install-ci`. Prerequisites now list Rust toolchain + audit tools instead of Bun. Getting Started flow uses `/code:bootstrap` (greenfield) or `/code:install-ci` (existing repo).

### Removed — legacy Next.js scaffold at repo root

- **Deleted `package.json`** at the repo root (last touched at v2.3.1, Next.js scaffold). The plugin manifest lives in `code-et-implementer/.claude-plugin/plugin.json`; the root `package.json` was unused since v3.x.

### Reference inputs baked in

- User notes: `Rust Code Quality and Review Tools.md` — the 4-element framework, 5 slop categories, and Uncle Bob's Clean Architecture excerpt are embedded in `docs/anti-slop.md` and `docs/architecture.md`.
- Tool reality verified during planning: `cargo-coupling`, `loctree`, `rustqual` from the user's notes do not exist on crates.io and were replaced with verified tools (`cargo-machete`, `cargo-deny`, `cargo-audit`, `cargo-nextest`, `clippy::cognitive_complexity`, `cargo-modules`, `dioxus-cli`).

### Migration

- Existing user projects on `code-et` v3.8.x continue to work unchanged. To adopt the audit gate on an existing Rust repo: `/code:install-ci`. To start a new project: `/code:bootstrap`.
- The TypeScript path is gone from the workflow output, but the plugin's own runtime/tests are unchanged. Legacy TS projects can still use `/code:go`, `/code:grill`, `/code:prd`, `/code:plan-issue`, `/code:implement` — the `metadata.layer` requirement only fires when the project's repo root has `Cargo.toml`.

### v3.10.0 preview

- `/code:audit` will mirror the CI gate locally for fast feedback before pushing. Single source of truth: the CI yaml shipped here.

## [3.8.1] - 2026-04-30

### Changed — `/code:go` portability

- **`/code:go` no longer hardcodes Visma-specific app names.** Step 2 ("Which app(s)") and the Step 4 Task Brief template now reference the dynamic `Apps Overview` from `FILE-REFERENCE.md` instead of `CMS / Content Studio / Course Studio / Survey Studio`. The plugin is general-purpose and used across multiple repos; the hardcoded list contradicted Step 0's dynamic-discovery design.
- **Removed `feature` from the Task Brief Type list.** The scope guard at the top of `/code:go` already routes multi-slice features to `/code:prd → /code:plan-issue → /code:implement`, but the output template still listed `feature` as a valid type, contradicting the guard. Type list is now `[bug fix / styling / refactor / API change]`.
- **Synced `marketplace.json` version** with `plugin.json` (was stale at 3.7.4).

### Removed — dead documentation

- **Deleted `code-et-implementer/references/go-reference.md`** (and the now-empty `references/` directory). No active command, script, or CLAUDE.md referenced it; its content (workflow position + FILE-REFERENCE lifecycle) is already documented in `code-et-implementer/CLAUDE.md`. Removed the corresponding stale row from the project-root `FILE-REFERENCE.md`.
- **Deleted `plans/2026-04-20-feature-lane-workflow.md`** and **`plans/2026-04-20-feature-lane-workflow-plan.md`** — completed PRDs from the feature-lane work that shipped in v3.7.0. Not referenced by any active code; the architecture they describe is now the implementation, documented in `code-et-implementer/CLAUDE.md`. Git history retains the originals.

## [3.8.0] - 2026-04-30

### Removed — low-value / high-token hooks

- **Dropped `PreToolUse Write|Edit` → `inject-rules.sh`.** Re-injected `.claude/rules/*.md` into context on every Write/Edit (~250 tok/call, dominant token cost in long sessions). Rules now live in `code-et-implementer/CLAUDE.md` (loaded once per session); subagents spawned by `/code:implement` inherit them via the dispatch prompt.
- **Dropped `PostToolUse Bash` → `pr-created-suggest-review.sh`.** Suggested `/ultrareview` after `gh pr create`; Claude can suggest this from CLAUDE.md context without a hook.
- **Dropped `FileChanged` → `refresh-file-reference.sh`.** Fired on every save of `*/page.tsx`/`*/route.ts`/`*/layout.tsx`, even mid-edit. Replaced by an explicit lifecycle: `FILE-REFERENCE.md` is refreshed **only after a PR merges to main** that touched structural files. Documented in `code-et-implementer/CLAUDE.md` under "FILE-REFERENCE.md Lifecycle".
- **Dropped `InstructionsLoaded` → `log-instructions.sh`.** Pure diagnostic, no behavioral effect.
- **Deleted `code-et-implementer/.claude/rules/` directory** (`brevity.md`, `context-hygiene.md`). Content inlined into `code-et-implementer/CLAUDE.md` so it loads once per session instead of per Write/Edit. Commands that referenced `.claude/rules/*.md` (`go.md`, `plan-issue.md`, `implement.md`) now reference the CLAUDE.md sections directly.

### Kept hooks (low cost / real value)

- `PermissionRequest` — `auto-approve-readonly.sh`: silent, no-token UX.
- `SubagentStop` — `verify-gate.sh`: real automation (runs `bun test && bun run lint`).
- `SessionStart` — `session-start-prd.sh`: ~30 tok/session, branch-aware PRD pointer.
- `TaskCreated` — `task-created-tag-check.sh`: silent on pass; enforces `user_story` tag.
- `TaskCompleted` — `task-complete.sh`: cmux desktop notify + 1-line info.
- `PreCompact` — `pre-compact-prd.sh`: rare, useful PRD reminder before compaction.

### Notes

- `bats` test suite under `tests/` already only covers kept scripts (`pre-compact-prd`, `resolve-prd`, `session-start-prd`, `task-created-tag-check`); no test changes required.
- All structural changes start on a branch (`feature/`, `fix/`, `chore/`) and ship via PR — same git rules as before, just newly explicit in CLAUDE.md as the substitute for the deleted FileChanged hook.

## [3.7.4] - 2026-04-29

### Changed — workflow shape

- **Two distinct lanes, no implicit chaining.** `/code:go` is now scoped explicitly to single-bug intake — it produces a Task Brief and stops. Multi-slice work routes through `/code:prd` → `/code:plan-issue` → `/code:implement`. `/code:go` does NOT auto-chain into the planner or implementer; the user reads the brief and decides next steps.
- **`/code:go`** frontmatter and intro reframed as "Single-Bug Intake". Step 2 ("kind of work") narrowed from feature/bug to bug-class only. New scope guard at top: if the work is multi-slice, stop and route to `/code:prd`.
- **`/code:plan-issue`** is now **PRD-only**. Path B (the "no PRD, bug lane" fallback) is removed — bugs go to `/code:go`. If no PRD is found, the command tells the user to run `/code:prd` (or `/code:go` for a single bug) and stops. Frontmatter description and argument-hint updated.
- **`/code:plan-issue`** new `Decomposition Rules` section between Context Budget and the procedure: (1) **vertical slicing is non-negotiable** — each task implements one full slice (UI ↔ logic ↔ API ↔ DB, end-to-end testable); a task touching only one layer is wrong; (2) **replace, don't accumulate** — when a slice supersedes existing logic, deletion of the old code is in the task scope and named in `metadata.rationale`. No parallel utilities, no `// TODO: remove old X`.
- **`/code:implement`** dispatch prompt Constraints gain a delete-old-code rule: superseded code is removed in the same commit as the new slice. Stale "(bug lane)" parenthetical on the no-prefix branch updated to "(ad-hoc task)" — the bug lane no longer exists in the planner.
- **`references/go-reference.md`** workflow diagram replaced — was the single chain `/code:go → /code:plan-issue → /code:implement`; now shows the two lanes explicitly with the rationale for not chaining.
- **`code-et-implementer/CLAUDE.md`** Commands table now lists all five commands (`/code:go`, `/code:grill`, `/code:prd`, `/code:plan-issue`, `/code:implement`) instead of just plan + implement. Workflow section rewritten as two-lane.

### Changed — FILE-REFERENCE.md slimming

- **`/code:go`** `FILE-REFERENCE.md` now stores **non-derivable knowledge only** — apps overview, hot paths, landmines, module invariants, schema purposes, domain rules. The Step 0 template no longer enumerates routes, components, screens, or API endpoints; these are reachable via on-demand `Glob '**/page.tsx'`/`Glob '**/route.ts'` at planning time. Goal: cut FILE-REFERENCE token cost by dropping the parts that duplicate the filesystem and go stale fastest.
- **`/code:go`** Step 3 (clarifying questions) Glob-discovers concrete screens for the picked app instead of expecting them in FILE-REFERENCE.
- **`/code:go`** Step 4 (Task Brief) sources file paths from `Glob`/`Grep`; FILE-REFERENCE is consulted for app names, hot paths, and landmine flags.
- **`/code:plan-issue`** Context Budget block reframed: FILE-REFERENCE = constraints + orientation, **not** a file inventory. Explicit order-of-ops added: read FILE-REFERENCE → Glob the affected area → LSP to pin symbols.
- **`references/go-reference.md`** structure listing reflects what stays (apps, hot paths, landmines, invariants, optional schema/DSL) and what's deferred to Glob (routes, components, screens, API endpoints).

### Changed — rule files

- **`.claude/rules/brevity.md`** and **`.claude/rules/context-hygiene.md`** compressed ~50%. Both files are re-injected on every Write/Edit; verbose framing (section headers, multi-bullet expansions of single rules) was paying tokens for no signal gain. Same rules, half the surface.

### Notes
- Existing `FILE-REFERENCE.md` files won't be auto-rewritten. Run `/code:go update` to regenerate in the leaner shape.
- Why not JSON/JSONB: JSON repeats keys per row (more tokens than markdown for tables); JSONB is a Postgres binary format, not LLM-readable. The token win comes from dropping derivable content, not switching format.

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
