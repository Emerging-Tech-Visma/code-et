---
tools: Read, Write, Edit, Grep, Glob, Bash, LSP, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, AskUserQuestion
description: "Refine an idea, write a PRD, and decompose into vertical-slice tasks. One extended turn — three checkpoints (brief, PRD on disk, tasks)."
argument-hint: "[rough idea | @path/to/brief.md]"
effort: xhigh
---

# Plan — Idea → PRD → Tasks

A single command that walks the feature lane end-to-end. Three checkpoints — at each, the artifact lands on disk before the next phase starts so you can interrupt, edit, and resume.

```
Phase 1: Refined Brief        →  print to chat
Phase 2: PRD                  →  write plans/YYYY-MM-DD-<slug>.md, ask "continue?"
Phase 3: Tasks                →  TaskCreate with metadata.layer + rationale
```

Pure-Rust four-crate Clean Architecture from `code-et-implementer/docs/architecture.md`. Each task carries `metadata.layer ∈ {domain, application, infrastructure, interface, chore}`. The Dependency Rule is enforced at the `Cargo.toml` level — flag layer-violating import directions at planning time, not at `cargo build`.

## Phase 1 — Refined Brief (interrogation)

Goal: every open decision resolved before any document is written. Cost: ~10 questions max, almost always fewer when the codebase has the answer.

**Rules:**

1. **If a question can be answered from the codebase, answer it yourself.** Run `Read`/`Grep`/`Glob`/`git log`. Do not ask the user.
2. **One question per message.** Number it. Include a recommended answer + 1-sentence rationale.
3. **Accept "you decide"** — record the recommendation as the decision; do not re-ask.
4. **Accept "defer: <reason>"** — mark deferred, move on.
5. **Stop rule:** when every ledger item is `answered | recommended-accepted | deferred`, print the refined brief and proceed to Phase 2.

**Decisions ledger** (in-session). Each entry: `id` (D-1, D-2, …), `question`, `recommendation`, `state`, `final_answer`. Show ledger summary every 3 answered items.

**Process:**
- Parse `$ARGUMENTS`. If `@path`, read the file. Otherwise treat as the rough idea.
- Glob `plans/**/*.md` for prior plans, `git log --oneline -20` for recent work.
- Seed 5-10 open decisions across: scope, actors, data model, UI surface, integration points, non-goals, success criteria.
- Interrogate. Resolve from the codebase first.

**Output of Phase 1** (printed to chat):

```
## Refined Brief

**Idea:** <1-sentence>
**Actors:** <list>
**Scope:** <in / out>
**Key decisions:**
- D-1: <q> → <answer>
- D-2: …

**Suggested slug:** <kebab-case>
```

Pause. Confirm the slug with the user (one `AskUserQuestion`) unless `$ARGUMENTS` already supplied one.

## Phase 2 — PRD on disk

1. **Branch.** If on `main` or `master`, create `feature/<slug>`:
   ```
   Bash('branch="$(git rev-parse --abbrev-ref HEAD)" && [ "$branch" = "main" ] || [ "$branch" = "master" ] && git checkout -b "feature/<slug>"')
   ```

2. **Write** `plans/$(date +%Y-%m-%d)-<slug>.md` using this template — replace every `<…>` placeholder; do **not** leave TBDs:

```markdown
# <Feature Title>

**Date:** <YYYY-MM-DD>
**Slug:** <slug>
**Status:** Draft

## Problem Statement

<User-facing. 2-4 sentences.>

## Solution

<User-facing. 2-4 sentences.>

## User Stories

1. US-1: As a <actor>, I want <feature>, so that <benefit>.
2. US-2: …

## Acceptance Criteria

### US-1
- AC-1.1: <observable behaviour>
- AC-1.2: …

### US-2
- AC-2.1: …

## Implementation Decisions

<Module-level. NO file paths. NO code snippets. Cover: crates affected, ports/use cases, data shape, integration points.>

## Testing Decisions

<Per-layer test matrix from docs/testing.md: domain unit / application use-case / infrastructure integration / interface e2e. Reference similar tests in the codebase by module name, not path. External behaviour only.>

## Out of Scope

<Bullets.>

## Story Checklist

- [ ] US-1
- [ ] US-2
…
```

3. **Set session title** by emitting `{"sessionTitle": "feat:<slug>"}` to stdout (Claude Code's `UserPromptSubmit` JSON channel).

4. **Pause and ask** the user via `AskUserQuestion`: *"PRD written to `<path>`. Continue to task decomposition, or pause to edit?"* Choices: `Continue | Pause`. On `Pause`, print *"Resume with `/code:plan` once edits are saved."* and stop.

## Phase 3 — Vertical-slice task decomposition

Read the PRD (it is the authoritative spec).

### Decomposition rules

**Vertical slicing — non-negotiable.** Each task implements **one full vertical slice** UI ↔ logic ↔ API ↔ DB, end-to-end and testable. A task that touches only one layer is wrong — split or merge.

- ✗ "Add API endpoint" + "Wire UI button" + "Migrate schema" — three half-tasks
- ✓ "Submit-feedback flow: form → API → `feedback` row → email confirmation" — one slice

`metadata.verification` exercises the full slice end-to-end.

**Replace, don't accumulate.** When a slice supersedes existing logic, the task scope **includes deletion of the superseded code**. State the `path:line` being replaced in `metadata.rationale`. No parallel utilities, no `// TODO: remove old X`.

**LSP for symbols.** Use `documentSymbol` / `findReferences` / `definition` to resolve each US/AC to a `{path, symbol, line, op}` entry — persist the result in `metadata.files[]` (schema below). Do not throw away the symbol name; that's the contract the subagent edits against if `line` drifts. Grep/Glob for discovery; LSP for precision. Never use LSP to enumerate the project. For 3+ independent areas, spawn parallel `Agent(subagent_type: "Explore", model: "haiku")` queries in a single message — Haiku 4.5 is the right tier for breadth scans.

**Path validation.** Before `TaskCreate`, validate every `files[].path`:
- `op ∈ {modify, replace, delete}` → path must appear in `git ls-files`. If not, the symbol moved or was deleted — re-resolve via LSP or drop the entry.
- `op = add` → path must either appear in `git ls-files` (append to existing file) or, if `FILE-REFERENCE.md` exists at repo root, sit under a documented top-level area there. Reject paths under undocumented top-level directories when `FILE-REFERENCE.md` is present; otherwise accept any path the workspace `Cargo.toml` covers.

Path drift caught at plan time is one less wasted subagent dispatch.

### Anti-slop self-critique (before TaskCreate)

After drafting tasks, walk the list once and **reject** any task that:

- Touches only one layer → split or merge into a vertical slice.
- Has rationale "because the PRD says so" → restate the underlying constraint.
- Adds a duplicate utility instead of extracting (Rule of Three) → the third occurrence triggers refactor in the same task.
- Adds defensive validation between trusted modules (interface↔application is the only validation boundary) → drop.
- Adds a mirror test (`assert_eq!(format!("{:?}", err), "DomainError::NotFound")` style) → reframe to assert observable behaviour.
- Has no test for at least one acceptance criterion → fix.

The list lives in `code-et-implementer/docs/anti-slop.md`; the inline summary above is enough for plan-time review.

### TaskCreate metadata

```json
{
  "verification": "<cmd that exercises the slice end-to-end>",
  "files": [
    {"path": "crates/<layer>/src/path.rs", "symbol": "Type::method", "line": 42, "op": "modify"},
    {"path": "crates/<layer>/src/new_file.rs", "symbol": "NewType", "op": "add"},
    {"path": "crates/<layer>/src/legacy.rs", "symbol": "deprecated_fn", "line": 89, "op": "delete"}
  ],
  "expected_outcome": "<observable end-to-end behaviour>",
  "rationale": "<1-2 sentences: why this slice exists, the constraint driving it.>",
  "user_story": "US-N | AC-N.M | chore:<reason>",
  "layer": "domain | application | infrastructure | interface | chore"
}
```

**`files[]` entry shape:**

| Field | Required | Notes |
|---|---|---|
| `path` | always | Workspace-relative. Validated against `git ls-files` (`modify\|replace\|delete`) or `FILE-REFERENCE.md` modules (`add`). |
| `op` | always | `add` (create symbol), `modify` (edit body), `replace` (full rewrite — pair with sibling `delete` if cross-file supersession), `delete` (remove symbol). |
| `symbol` | for `modify\|replace\|delete`; recommended for `add` | Qualified Rust path: `User::validate`, `db::pool`, `routes::auth::login`. Resolved via LSP `documentSymbol`. |
| `line` | optional hint | Current line at plan time. Implementer re-resolves via LSP if it drifts. Omit for `add` on a new file. |

`rationale` is mandatory — the subagent starts cold and needs the *why*. `layer` is mandatory; the per-file layer also feeds the validator on every file the task touches. Deletion of superseded code is encoded as explicit `op: "delete"` entries in `files[]`, not prose in `rationale`. `verification` exercises the full slice — `cargo nextest run -p <crate>` for unit, `cargo nextest run --workspace` for cross-layer.

Set dependencies with `TaskUpdate(addBlockedBy)`. Independent slices stay parallel.

Save manifest to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`.

### Output

```
Plan complete: N tasks created. Run /code:ship to execute.
```

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Plan ready' --subtitle 'N tasks' || true")
```

## Brevity

Drop filler ("just", "simply"), hedging ("perhaps", "maybe"), pleasantries ("Sure!"). Fragments over sentences when meaning is clear. Pattern: `[thing] [action] [reason]. [next].` Question messages ≤2 sentences. Recommendation rationale ≤1 sentence.

## When to skip phases

- User pasted a refined brief / linked an existing PRD → skip Phase 1, jump to Phase 2 confirmation step (or Phase 3 if PRD already on disk).
- User says "just give me the tasks for `<existing PRD path>`" → resolve PRD via `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh")`, jump to Phase 3.
- Bug-shaped request — route to `/code:fix`. Don't write a PRD for a 2-file change.
