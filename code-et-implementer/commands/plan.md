---
tools: Read, Write, Edit, Grep, Glob, Bash, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, AskUserQuestion
description: "Refine an idea, write a PRD, decompose into vertical-slice tasks. One extended turn — three checkpoints (brief, PRD on disk, tasks)."
argument-hint: "[rough idea | @path/to/brief.md]"
effort: xhigh
---

# Plan — Idea → PRD → Tasks

One command, three checkpoints. At each, the artifact lands on disk before the next phase starts — you can interrupt, edit, and resume.

```
Phase 1: Refined Brief        →  printed to chat
Phase 2: PRD                  →  written to plans/YYYY-MM-DD-<slug>.md, ask "continue?"
Phase 3: Vertical-slice tasks →  TaskCreate with metadata.module + rationale
```

Architecture vocabulary: **module / interface / seam / adapter** (see [`docs/architecture.md`](../docs/architecture.md)). Each task carries `metadata.module` — the deep module the slice mostly lives in. No fixed layer taxonomy; modules grow around interfaces.

## Phase 1 — Refined Brief (interrogation)

Resolve every open decision *before* writing anything to disk. Cost: ~10 questions max, usually fewer when the codebase has the answer.

**Rules:**

1. **If a question can be answered from the codebase, answer it yourself.** Run `Read`/`Grep`/`Glob`/`git log`. Don't ask the user.
2. **One question per message.** Number it. Include a recommended answer + 1-sentence rationale.
3. **Accept "you decide"** — record the recommendation as the decision; don't re-ask.
4. **Accept "defer: <reason>"** — mark deferred, move on.
5. **Stop rule:** when every ledger item is `answered | recommended-accepted | deferred`, print the refined brief and proceed to Phase 2.

Show ledger summary every 3 answered items.

**Process:**

- Parse `$ARGUMENTS`. If `@path`, read the file. Otherwise treat as the rough idea.
- Glob `plans/**/*.md` for prior plans; `git log --oneline -20` for recent work.
- Read `CONTEXT.md` (domain glossary) if present — use its vocabulary throughout.
- Read any `docs/adr/*.md` near the area being touched — respect ADR decisions; flag a conflict only when the friction is real enough to warrant revisiting.
- Seed 5–10 open decisions across: scope, actors, data model, the seam this lives on, dependencies (in-process / local-substitutable / remote-but-owned / true-external — see `docs/architecture.md`), non-goals, success criteria.
- Interrogate. Resolve from the codebase first.

**Output of Phase 1** (printed to chat):

```
## Refined Brief

**Idea:** <1 sentence>
**Actors:** <list>
**Scope:** <in / out>
**Key decisions:**
- D-1: <q> → <answer>
- D-2: …

**Suggested slug:** <kebab-case>
```

Confirm the slug with one `AskUserQuestion` unless `$ARGUMENTS` already supplied one.

## Phase 2 — PRD on disk

1. **Branch.** If on `main` or `master`, create `feature/<slug>`:

   ```
   Bash('branch="$(git rev-parse --abbrev-ref HEAD)" && [ "$branch" = "main" ] || [ "$branch" = "master" ] && git checkout -b "feature/<slug>"')
   ```

2. **Write** `plans/$(date +%Y-%m-%d)-<slug>.md`. Replace every `<…>`; no TBDs.

```markdown
# <Feature Title>

**Date:** <YYYY-MM-DD>
**Slug:** <slug>
**Status:** Draft

## Problem Statement

<User-facing. 2–4 sentences.>

## Solution

<User-facing. 2–4 sentences.>

## User Stories

1. US-1: As a <actor>, I want <feature>, so that <benefit>.
2. US-2: …

## Acceptance Criteria

### US-1
- AC-1.1: <observable behaviour>
- AC-1.2: …

### US-2
- AC-2.1: …

## Modules

A list of the deep modules involved. For each new or modified module:

- **<module name>** — interface shape (top-level exports), what sits behind the seam, dependency category (in-process / local-substitutable / remote-but-owned / true-external).

Apply the deletion test before proposing any new module: would deleting it concentrate complexity, or just move it?

## Implementation Decisions

Module-level. No file paths. No code snippets. Cover: schema changes, ports + adapters, integration points, error modes at seams. Exception: a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape) is allowed — trim to the decision-rich parts.

## Testing Decisions

Per the test matrix in [`docs/testing.md`](../../code-et-implementer/docs/testing.md): module-interface / HTTP-seam / e2e. Reference similar tests in the codebase by module name. External behaviour only.

## Out of Scope

<Bullets.>

## Story Checklist

- [ ] US-1
- [ ] US-2
…
```

3. **Pause and ask** via `AskUserQuestion`: *"PRD written to `<path>`. Continue to task decomposition, or pause to edit?"* Choices: `Continue | Pause`. On `Pause`: *"Resume with `/code:plan` once edits are saved."* and stop.

## Phase 3 — Vertical-slice task decomposition

Read the PRD (it is the authoritative spec).

### Decomposition rules

**Vertical slicing — non-negotiable.** Each task implements **one full vertical slice**: HTTP seam → module → DB (or whatever the slice's path actually traverses), end-to-end and testable. A task that touches only one shallow concern is wrong — split or merge.

- ✗ "Add API endpoint" + "Wire UI button" + "Migrate schema" — three half-tasks
- ✓ "Submit-feedback flow: form → POST /feedback → `feedback` row → email confirmation" — one slice

`metadata.verification` exercises the full slice end-to-end.

**Replace, don't accumulate.** When a slice supersedes existing logic, the task scope **includes deletion of the superseded code**. State the `path:line` being replaced in `metadata.rationale`. No parallel utilities, no `// TODO: remove old X`.

**Module ownership.** Each task names the **primary module** the slice mostly lives in (`metadata.module`). Slices typically touch the HTTP seam + 1–2 modules; `metadata.files[]` carries per-file paths.

### Anti-slop self-critique (before TaskCreate)

After drafting tasks, walk the list once and **reject** any task that:

- Touches only one shallow concern → split or merge into a vertical slice.
- Rationale "because the PRD says so" → restate the underlying constraint.
- Adds a duplicate utility instead of extracting (Rule of Three) → the third occurrence triggers refactor in the same task.
- Adds defensive validation between trusted modules (HTTP-seam is the only validation boundary) → drop.
- Adds a mirror test (assert on internal call shapes / `toBeCalledWith` on a stand-in) → reframe to assert observable behaviour.
- Has no test for at least one acceptance criterion → fix.
- Proposes a new extracted helper without applying the deletion test → re-evaluate.

The full list lives in [`docs/anti-slop.md`](../docs/anti-slop.md); the summary above is enough for plan-time review.

### TaskCreate metadata

```json
{
  "verification": "<cmd that exercises the slice end-to-end>",
  "files": [
    {"path": "src/modules/<m>/index.ts", "symbol": "Orders.place", "line": 42, "op": "modify"},
    {"path": "src/http/routes/orders.ts", "symbol": "placeOrder", "op": "add"},
    {"path": "src/modules/<m>/legacy.ts", "symbol": "oldPlace", "line": 89, "op": "delete"}
  ],
  "expected_outcome": "<observable end-to-end behaviour>",
  "rationale": "<1–2 sentences: why this slice exists, the constraint driving it>",
  "user_story": "US-1",
  "module": "orders"
}
```

**`user_story` — pick exactly one tag.** Allowed forms:

- `US-<N>` — the primary user story this slice delivers.
- `AC-<N>.<M>` — a single acceptance criterion when the slice is narrower than a full story.
- `chore:<reason>` — non-PRD work.

Do **not** emit alternation values like `"US-1 | AC-1.1, AC-1.2"`. The pipes/commas in this doc are reading aids, not value separators.

**`module` — free-form, lowercase.** The primary module name (e.g. `orders`, `payments`, `auth`). For chores, `module: "chore"`. There is no enforced taxonomy — pick the module the slice mostly lives in and name it the same way it's named in `src/modules/`.

**`files[]` entry shape:**

| Field | Required | Notes |
|---|---|---|
| `path` | always | Workspace-relative. |
| `op` | always | `add` (create symbol), `modify` (edit body), `replace` (full rewrite — pair with sibling `delete` if cross-file supersession), `delete` (remove symbol). |
| `symbol` | for `modify\|replace\|delete`; recommended for `add` | Qualified TS path: `Orders.place`, `placeOrder`, `module#export`. |
| `line` | optional hint | Current line at plan time; drift-tolerant — `symbol` is the contract. |

`rationale` is mandatory — the implementer subagent starts cold. Set dependencies with `TaskUpdate(addBlockedBy)`. Independent slices stay parallel.

### Output

```
Plan complete: N tasks created. Run /code:ship to execute.
```

## Brevity

Drop filler ("just", "simply"), hedging ("perhaps", "maybe"), pleasantries. Fragments over sentences when meaning is clear. Question messages ≤ 2 sentences. Recommendation rationale ≤ 1 sentence.

## When to skip phases

- User pasted a refined brief / linked an existing PRD → skip Phase 1, jump to Phase 2.
- User says "just give me the tasks for `<existing PRD path>`" → read the PRD, jump to Phase 3.
- Bug-shaped request — route to `/code:fix`. Don't write a PRD for a 2-file change.
