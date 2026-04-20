# Feature Lane Workflow — Design Spec

**Date:** 2026-04-20
**Target version:** code-et v3.6.0
**Status:** Draft — awaiting user review

## Problem Statement

From the user's perspective (sole maintainer, non-developer relying heavily on AI):

> "I use `/code:go` a lot but I miss refining my idea before a solid PRD. Then I need a plan and implementation that keeps track of the plan with the user story over multiple sessions."

Today `code-et` has one lane: intake (`/code:go`) → plan (`/code:plan-issue`) → implement (`/code:implement`) → ship (`/commit-push-pr`). This lane is excellent for **bugs and small features** where the scope is already clear. It breaks down on **larger features** in two ways:

1. **No idea-refinement step.** The user arrives with a rough idea. There is no command that relentlessly interrogates the idea to surface hidden decisions before planning begins. Plans get built on unexamined assumptions.
2. **No multi-session continuity.** Tasks exist only within one session. If work spans multiple sessions (days, weeks), there is no persistent spec describing the user stories, no automatic re-orientation when resuming, and no way to know which parts of the plan are done.

## Solution

Add a **feature lane** alongside the existing bug lane. Two new commands, three new hooks, small updates to two existing commands. The feature lane produces a persistent PRD in `plans/` with numbered user stories; every task created downstream is tagged with its user story; hooks re-inject context on session start and enforce tagging automatically.

**Delegate heavy thinking to `/ultraplan`** (Anthropic-maintained cloud multi-agent decomposition). Delegate review to `/ultrareview` at PR time. Keep the wrapper thin so the user benefits from upstream improvements.

## User Stories

1. As a non-developer product owner, I want to run `/code:grill <idea>` and be interviewed one question at a time with recommended answers, so that my vague idea becomes a refined brief I could hand to any planner.
2. As a non-developer, I want `/code:grill` to stop automatically once every open decision has been answered or explicitly deferred, so that I do not get stuck answering forty questions.
3. As a non-developer, I want to say "you decide" to a grill question and have that recorded as a final answer (not re-asked), so that the interview converges even when I lack opinions.
4. As a product owner, I want `/code:grill` to explore the codebase for any question the AI could answer from code, so that I am only asked questions that genuinely need my judgement.
5. As a product owner, I want `/code:prd` to synthesise the grill output into a PRD file under `plans/YYYY-MM-DD-<slug>.md`, so that the spec survives across sessions without relying on GitHub issues.
6. As a product owner, I want the PRD to contain a long numbered list of user stories (US-1 … US-N) with acceptance criteria (AC-N.M), so that every downstream task can reference a concrete story.
7. As a product owner, I want the PRD to contain no file paths or code snippets, so that it does not rot when the codebase changes.
8. As a product owner, I want `/code:prd` to set the Claude Code session title to `feat:<slug>`, so that `/resume` shows me which feature each session belongs to.
9. As a planner, I want `/code:plan-issue` to detect when a PRD exists for the current branch, read it, and call `/ultraplan` with the PRD as input, so that decomposition benefits from Anthropic-maintained multi-agent planning.
10. As a planner, I want `/code:plan-issue` to fall back to its existing LSP-only path if `/ultraplan` is unreachable, and to announce the fallback once, so that I always get a plan and I know when it is the lesser path.
11. As a planner, I want `/code:plan-issue` to post-process `/ultraplan` output by tagging every task with `user_story: US-N` (or `AC-N.M`, or `chore:<reason>`), so that every task is traceable to a story.
12. As a planner, I want `/code:plan-issue` to enrich tasks with LSP-derived file:line references, so that implementation agents have concrete anchors.
13. As an implementer, I want `/code:implement` to include the user-story tag in every agent commit message prefix (e.g. `US-3: add toggle component`), so that git history reveals which stories landed in which commits.
14. As an implementer, I want `/code:implement` to tick the matching checkbox in the PRD file when a task completes (e.g. `- [x] US-3 …`), so that the PRD itself is the progress record.
15. As a returning user, I want a `SessionStart` hook that detects the PRD for the current git branch and injects a 3-line pointer (active PRD path, open story list), so that Claude re-orients automatically without burning context on the full PRD.
16. As a returning user, I want the PRD to live at `plans/YYYY-MM-DD-<branch-slug>.md` and be resolved by matching the current branch name, so that multiple features in flight simultaneously each have their own PRD.
17. As a maintainer, I want a `TaskCreated` hook that rejects any task missing a `user_story` / `AC-N` / `chore:<reason>` tag, so that the tagging invariant cannot silently decay.
18. As a maintainer, I want a `PreCompact` hook that injects a summary of the active PRD's open stories before compaction, so that long sessions do not lose the thread mid-feature.
19. As a maintainer, I want `/commit-push-pr` to offer (not require) `/ultrareview <PR#> --context plans/<slug>.md` when a PRD exists, so that feature PRs can be reviewed against acceptance criteria without cost on bug PRs.
20. As a maintainer, I want the bug lane (`/code:go` → `/code:plan-issue` → `/code:implement` → `/commit-push-pr`) to remain unchanged for the case where no PRD exists, so that small fixes keep their current low-ceremony flow.
21. As a maintainer, I want the version bumped to 3.6.0, the README updated with the feature lane diagram, and a CHANGELOG entry, so that the new workflow is documented before release.

## Implementation Decisions

### New command: `/code:grill`

- **Effort:** `high` (heavy reasoning).
- **Input:** rough idea, either from args or from an existing `/code:go` Task Brief.
- **Behaviour:**
  - Maintains an in-session **decisions ledger** — a list of open decision points, each with state `answered` | `recommended-accepted` | `deferred`.
  - Asks one question at a time, provides a recommended answer with each question.
  - For any question answerable from the codebase (file structure, existing patterns, library versions, etc.), does not ask the user — answers it from exploration and records it as `answered`.
  - Accepts "you decide" as a final answer — records the recommendation as `recommended-accepted` and does not re-ask.
  - Accepts "defer: <reason>" — marks `deferred`, moves on.
  - **Stop rule:** when every item in the ledger has a non-pending state, announce completion and print the refined brief.
- **Output:** a refined brief in-session (no file written). The next command (`/code:prd`) consumes it.

### New command: `/code:prd`

- **Effort:** `high`.
- **Input:** current conversation context (ideally includes a grill output).
- **Behaviour:**
  - Derives a slug from the refined brief (short kebab-case, e.g. `dark-mode-toggle`).
  - Writes `plans/YYYY-MM-DD-<slug>.md` using the template below.
  - Sets session title via `UserPromptSubmit` hook's `sessionTitle` mechanism to `feat:<slug>`.
- **Template:**
  - Problem Statement (user's perspective).
  - Solution (user's perspective).
  - User Stories (long numbered list, format `US-N: As <actor>, I want <feature>, so that <benefit>`).
  - Acceptance Criteria per story (format `AC-N.M`).
  - Implementation Decisions (module-level, no file paths).
  - Testing Decisions (what to test, similar tests in the codebase by module reference).
  - Out of Scope.
  - Further Notes.
  - **Story checklist** at the bottom as `- [ ] US-N …` — ticked by `/code:implement`.
- **Does not create a GitHub issue.** Local file only.

### Modified command: `/code:plan-issue` (wrapper around `/ultraplan`)

- Detects whether a PRD exists for the current branch (see PRD-resolution rule below).
- If PRD exists:
  1. Reads the PRD file.
  2. Invokes `/ultraplan` with the PRD contents. If `/ultraplan`'s invocation contract accepts a file path directly, use it; otherwise pass the PRD text inline.
  3. On `/ultraplan` unreachable: announce `"/ultraplan unreachable — using local LSP decomposition. Plan may be less thorough for large PRDs."` and fall through to the existing LSP-only path.
  4. Post-processes `/ultraplan` output: every task gets a `user_story` tag matching a US-N in the PRD, or `AC-N.M` for a specific criterion, or `chore:<reason>` for non-story work (build config, refactors required to enable a story).
  5. LSP-enriches each task with file:line references via the existing `typescript-lsp` plugin calls.
- If no PRD exists: runs the existing LSP-only path unchanged (preserves bug lane behaviour).

### Modified command: `/code:implement`

- When executing a task that carries a `user_story` tag, each agent's commit message is prefixed `US-N: <subject>` (or `AC-N.M:` / `chore:`).
- On successful task completion, updates the PRD file: finds the matching checklist line and flips `- [ ]` to `- [x]`. The file change is committed as part of the agent's commit.

### PRD-resolution rule for hooks

- Input: current git branch name (e.g. `feature/dark-mode`).
- Derive slug by stripping the branch prefix (`feature/`, `fix/`, `chore/`).
- Match: find `plans/YYYY-MM-DD-<slug>.md` where `<slug>` equals the derived slug. If multiple dates exist for the same slug, use the most recent.
- If no match: no active PRD; hooks do nothing.

### New hook: `SessionStart`

- On session start, resolve the PRD for the current branch.
- If found: inject exactly 3 lines into Claude's context — the PRD path, the open-story list (unchecked US-N lines), and a hint to read the file when starting planning or implementation work.
- If not found: inject nothing. Bug-lane sessions are untouched.

### New hook: `TaskCreated`

- On every `TaskCreate` tool call, inspect metadata.
- If `user_story` field is missing OR its value does not match `US-\d+` | `AC-\d+\.\d+` | `chore:.+`: **reject** the task creation and emit an error telling the caller to add a tag.
- If the current branch has no PRD, exception: `user_story: none` is accepted (bug lane).

### New hook: `PreCompact`

- Before compaction, resolve the PRD for the current branch.
- If found: inject a summary block containing the PRD's open-story checklist (unchecked items only) + any in-flight task subjects.
- If not found: no-op.

### Modified: `/commit-push-pr` (via a hook, not editing the plugin)

- Use a `PostToolUse` or similar hook that fires after a PR is created.
- If a PRD exists for the branch: print a one-liner suggesting `/ultrareview <PR#> --context plans/<slug>.md`.
- User-facing only; does not auto-invoke.

### Version + docs

- Bump `code-et-implementer/.claude-plugin/plugin.json` to `3.6.0`.
- Bump `marketplace.json` metadata version to match.
- Add CHANGELOG entry under `## [3.6.0] - 2026-04-20` covering the four new commands/hooks, the `/ultraplan` wrapper, and branch-matched PRD resolution.
- Update README:
  - Replace the single-lane ASCII diagram with the two-lane (bug + feature) diagram from the design discussion.
  - Add a "Feature lane" section describing the `/grill → /prd → /plan-issue → /implement` chain and PRD location.
  - Note that `/ultraplan` is cloud-based and requires network access; the plugin degrades gracefully.

## Testing Decisions

Tests that matter (external behaviour, not implementation details):

- **Grill stop rule:** given an idea and a ledger with all items resolved, the skill stops and prints the refined brief. Given one pending item, it asks the next question.
- **Grill codebase-first:** given a question answerable from code (e.g. "which framework does this project use"), the skill does not ask the user.
- **PRD slug derivation:** given a branch `feature/dark-mode-toggle`, `/code:prd` writes `plans/YYYY-MM-DD-dark-mode-toggle.md` and `SessionStart` re-resolves it.
- **TaskCreated enforcement:** a `TaskCreate` call without `user_story` on a branch with an active PRD is rejected; the same call on a branch without a PRD succeeds.
- **PRD checkbox update:** after `/code:implement` completes a task tagged `US-3`, the file has `- [x] US-3 …`.
- **`/ultraplan` fallback:** when `/ultraplan` is unreachable, `/code:plan-issue` announces and proceeds with the LSP path.
- **Branch-match PRD resolution:** switching branches changes which PRD `SessionStart` injects.

No tests for: exact PRD template formatting, exact hook injection wording, `/ultraplan`'s internal behaviour.

Prior art: existing code-et verification gates in `/code:implement` (`bun test && bun run lint`) — the new hooks should follow the same shell-script pattern under `code-et-implementer/scripts/`.

## Out of Scope

- Creating GitHub issues. The PRD is a local file; the plugin's "no GitHub issues" philosophy stands.
- Replacing `/code:plan-issue` or `/code:implement`. Both remain; they are wrapped/extended, not rewritten.
- Replacing `/code-review` (official plugin). `/ultrareview` is additive, opt-in at PR time.
- Any change to the bug lane when no PRD exists.
- Subagent `initialPrompt` frontmatter usage — task metadata is sufficient context for implementation agents.
- `/loop`, scheduled tasks, cron integration — feature work is not periodic.
- Remote PRDs (multi-repo, cross-project) — single-repo only.

## Risks and Unknowns

1. **`/ultraplan` invocation contract is not fully documented.** Unclear whether it takes a file path argument or only inline prompt text, and unclear what output shape it returns. Mitigation: the wrapper handles both invocation styles and the fallback path is the existing LSP-only implementation, so a parse failure degrades safely. This must be verified at implementation time, not assumed.
2. **Branch-slug collisions.** Two branches named similarly (`feature/dark-mode` vs `feature/dark-mode-settings`) could produce ambiguous PRD matches. Mitigation: require exact slug match after branch-prefix stripping; document the convention in README.
3. **`PreCompact` injection size.** If a PRD has 30 open stories, the injection could be large. Mitigation: cap at 20 stories; if more, summarise as "N open stories; see plans/<slug>.md".
4. **`TaskCreated` rejection UX.** A rejected task creation could confuse the user or the AI. Mitigation: error message must state the exact required tag format and point to the current PRD's US-N list.
5. **Session title via hook.** The `UserPromptSubmit` hook's `sessionTitle` field was added in v2.1.94. Requires Claude Code ≥ 2.1.94. Document this as a minimum version.

## Further Notes

- The bug lane and feature lane share every command from the midpoint onward. Only the front end differs: `/code:go` (bug) vs `/code:grill` + `/code:prd` (feature).
- The design deliberately avoids introducing a `/code:status` command. The PRD file with its checklist IS the status — readable by the user directly, no command needed.
- If the non-developer maintainer later wants a richer status view, it can be added in a future minor version without breaking anything. YAGNI for now.
