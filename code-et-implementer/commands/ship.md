---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Edit, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: "Execute pending tasks in parallel worktrees, then audit. Auto-retries 1 fix-pass on CRITICAL/HIGH findings."
argument-hint: "[task-id]"
effort: xhigh
---

# Ship — Execute + Audit

Loads pending tasks from `TaskList`, dispatches them as parallel worktree-isolated subagents, then runs the local audit gate. On CRITICAL or HIGH findings, dispatches one fix-pass and re-audits. After 1 retry the chain halts and surfaces findings.

If the current branch is `main` or `master`, create `feature/<slug-from-prd-or-tasks>` first.

## Pre-dispatch — scope the queue to this branch's PRD

`TaskList` is global across the project, not branch-scoped — pending tasks from prior PRDs leak in and would otherwise re-execute against stale spec.

1. **Find the active PRD.** Glob `plans/*.md` whose filename slug matches the current branch's slug (after the `feature/`/`fix/`/`chore/` prefix). If exactly one match: that's the PRD. Multiple matches: pick the most recent date. Zero matches: bug lane → ship whatever pending tasks exist (their tags should be `chore:*`).
2. **Parse the PRD's `## Story Checklist`** to enumerate US tags (`US-1`, `US-2`, …). A pending task belongs to this branch iff one of:
   - `metadata.user_story` matches a `US-<N>` in the set, or
   - `metadata.user_story` is `AC-<N>.<M>` whose `<N>` is in the set, or
   - `metadata.user_story` starts with `chore:`.

   All other pending tasks are stale-from-another-branch — **skip** them; don't dispatch, don't mark completed; leave them for their owning branch.
3. Build the dispatch queue from the scoped subset only.

**Empty-queue diagnostics — never exit silently.**

| Condition | Surface |
|---|---|
| PRD found, no pending tasks match its US tags | `Active PRD: <path>. 0 tasks tied to its user stories. Run /code:plan to decompose the PRD before /code:ship.` |
| PRD found, pending tasks belong to a *different* PRD | `Active PRD: <path>. Pending tasks (<count>) belong to a different PRD (<their tags>). Switch branch or run /code:plan on this branch.` |
| No PRD, no pending tasks | `No PRD for this branch and no pending tasks. Nothing to ship — run /code:fix or /code:plan first.` |

In every case, **stop**.

## Dispatch

Every task runs as a forked subagent in its own worktree: `Agent(isolation: "worktree", subagent_type: "general-purpose", model: "sonnet")`. Sonnet 4.6 — routine vertical-slice coding from a complete brief.

Independent tasks **must** dispatch in a single message with multiple `Agent` calls so they run concurrently — never serialize what could fan out. Dependency graph from `TaskGet` drives order.

### Model assignments

| Role | Model | Why |
|---|---|---|
| Orchestrator (this skill) | inherits (Opus 4.7) | Multi-step coordination + partial-failure decisions. |
| Per-task implementer | `sonnet` (4.6) | Routine slice coding from a complete brief. |
| Per-task reviewer fork | `opus` (4.7) | Catching missed bugs is high-leverage; reviewer errors fail silently. |
| Per-task review fix-pass | `opus` (4.7) | Same judgment as the reviewer for find/fix consistency. |
| Post-audit fix-pass | `opus` (4.7) | Audit-gate findings often need judgment. |
| Explore (when delegated) | `haiku` (4.5) | Cheap breadth searches for cold areas. |

### Dispatch prompt template

Each subagent starts cold. Send one comprehensive first turn — intent, constraints, acceptance criteria, `file:line` anchors, verification, rationale.

```
# Task <id>: <title>

## Tag
<metadata.user_story — one of: US-N | AC-N.M | chore:<reason>>

## PRD context (if US-N or AC-N.M)
<Paste the matching US-N / AC-N.M block from the active PRD. Include the parent
User Story and all its ACs so the agent sees full intent.>

## Rationale
<metadata.rationale — verbatim. The why, not the what.>

## Files to touch
<For each metadata.files[] entry, render:
  - <op> <path>[:<line>] → <symbol>
Examples:
  - modify src/modules/orders/index.ts:42 → Orders.place
  - add src/http/routes/orders.ts → placeOrder
  - delete src/modules/orders/legacy.ts:89 → oldPlace
Read each entry's file (sliced) before editing. `line` is a hint — if the symbol
moved, re-resolve via Grep/LSP; `symbol` is the contract. Apply each op exactly.>

## Module
<metadata.module — the primary module this slice mostly lives in. Free-form;
matches src/modules/<name>/.>

## Expected outcome
<metadata.expected_outcome — observable success criterion.>

## Verification
Run `<metadata.verification>`. Must exit 0. All existing tests must still pass.

## Constraints
- Architecture: deep modules (see code-et-implementer/docs/architecture.md). No
  fixed layer taxonomy; modules grow around interfaces. The interface is the
  test surface — assert behaviour through it, not past it.
- Anti-slop hard rules: code-et-implementer/docs/anti-slop.md. Apply the deletion
  test before any new extraction.
- Test matrix: code-et-implementer/docs/testing.md.
- Read in slices (Read(offset, limit)) for files > 200 lines.
- Delegate breadth: Agent(subagent_type: "Explore", model: "haiku") for unknown
  territory instead of Grep-and-Read tours.
- Every acceptance criterion gets a corresponding test.
- No scope expansion — implement exactly what the task specifies; flag adjacent
  issues, don't fix inline.
- Supersession deletion in the same commit. No parallel utilities, no `// TODO:
  remove old X`.
- HTTP input parsed with Zod at the seam. Modules trust their callers within the
  process boundary.
- Commit format: `<prefix>: <subject>` where prefix is US-N | AC-N.M | chore.

## Deliverables
1. Code changes committed in the isolated worktree.
2. `metadata.verification` exits 0.
3. Single commit with correct prefix.
4. PRD checkbox ticked (if `US-N`) — flip `- [ ] US-N` to `- [x] US-N` and stage
   with the commit.
5. Final report: commit SHA, branch name, worktree path.

Do not merge back; the orchestrator handles that. Do not ask clarifying questions.
If blocked, flag in the final report with a file:line reference.
```

### Per-subagent contract

1. Implement the task. Every acceptance criterion has a test.
2. Run `metadata.verification`. Must compile, tests must pass.
3. Single commit with the right prefix:
   - `US-N: <subject>` when tag is `US-N`
   - `AC-N.M: <subject>` when tag is `AC-N.M`
   - `chore: <subject>` when tag starts with `chore:`
4. **Tick the PRD checkbox** if `metadata.user_story` is `US-N`: `Edit` the PRD to flip the checkbox; stage with the commit.

The subagent stops after step 4 and returns. It must **not** merge or remove its worktree.

## Per-task review (before merge)

Two review passes: per-task (here, shift-left) and across the full branch at `/code:review`. Per-task review catches logic bugs at the smallest possible diff.

### Step 1 — Capture the diff

```
diff="$(git -C <worktree_path> diff $(git merge-base HEAD <subagent_branch>)..<subagent_branch>)"
```

Empty diff = implementer didn't write code. Halt that task and surface to the user.

### Step 2 — Dispatch the reviewer (Opus 4.7)

Reviewer is a fork — `Agent(model: "opus")` with no `subagent_type` and no `isolation`. Works against the diff payload, not the worktree.

If the diff exceeds **1500 lines**, halt this task and surface a "task too large — split or escalate to `/code:review` only" warning instead of dispatching. A vertical slice that big is almost always two slices in disguise.

Reviewer prompt:

```
# Per-task review for <task-id>: <title>

## Diff (against parent feature branch)
<diff content — full payload, ≤1500 lines>

## Rationale
<metadata.rationale>

## Expected outcome
<metadata.expected_outcome>

## Module
<metadata.module>

Review the diff against the rationale + expected outcome.

**Step A — Try the engineering plugin's code-review skill:**
```
Skill("code-review")
```
If it returns findings, use them. If the skill is not installed, fall back to Step B.

**Step B — Inline 5-area review:**
1. **Deep-module shape** — does any new module pass the deletion test? Is anything
   extracted as a shallow pass-through? (code-et-implementer/docs/architecture.md)
2. **Anti-slop** — Rule of Three duplicates, mirror tests, defensive validation,
   dead re-exports. (code-et-implementer/docs/anti-slop.md §"Hard rules")
3. **Test coverage** — every acceptance criterion has a test; tests assert through
   the interface, not past it. (code-et-implementer/docs/testing.md)
4. **Security** — Zod at HTTP seams; secrets not in logs; auth on mutating routes.
5. **Slice integrity** — coherent vertical slice; superseded code deleted same
   commit; no `// TODO: remove old X`.

**Output format — strict.** Output ONLY the JSON array. No preamble, no code
fences. If no CRITICAL or HIGH findings, output exactly: `[]`

Schema: [{"severity": "CRITICAL|HIGH", "file": "path:line", "issue": "<one sentence>"}]

Drop MEDIUM/LOW — those are for /code:review. Do not modify code.
```

### Step 3 — On CRITICAL/HIGH findings, dispatch ONE review fix-pass

`Agent(subagent_type: "general-purpose", model: "opus")` with no isolation. Prompt directs it to operate via `git -C <worktree_path>` and explicit paths inside `<worktree_path>`:

```
# Review fix-pass for <task-id>

The per-task reviewer flagged these CRITICAL/HIGH findings on the diff in
worktree <worktree_path>:

<findings JSON>

Fix each finding. After fixing, re-run `<metadata.verification>` from inside
<worktree_path> (must exit 0). Commit the fix-up with subject "fix-up: <task tag>".
Return the new HEAD SHA.

No scope expansion — fix the findings only.
```

After the fix-pass returns, **do not re-review**. One cycle max. If `verification` still fails, halt that task and surface to the user (leave the worktree in place).

## Orchestrator (this skill)

After each `Agent` call returns:

1. Read the worktree path and branch from the tool result.
2. Run **Per-task review** (above). On CRITICAL/HIGH, dispatch one review fix-pass.
3. From the parent feature branch: `git merge --no-ff <subagent-branch>`.
4. `git worktree remove <path>` (auto-cleaned if empty, but populated worktrees need explicit removal).
5. Mark the task completed via `TaskUpdate` only after the merge lands.

On a failure (subagent reports blocked, or fix-pass can't resolve), leave the worktree in place — do not auto-discard.

## After all tasks land — audit

```
Bash('bun run audit')
```

The audit mirrors the CI gate: `biome check`, `tsc --noEmit`, `bun audit`, `bun test`. Report appended to `.claude/audit-<UTC>.md`.

Optionally run `Skill("simplify")` first if the engineering plugin's simplify skill is installed — a changed-code refactor pass before the static gate.

### Auto-retry on CRITICAL/HIGH (max 1 pass)

If audit exits non-zero with CRITICAL or HIGH findings:

1. Read `.claude/audit-<UTC>.md` — extract highest-severity `path:line` + message.
2. Dispatch **one** fix-pass via `Agent(subagent_type: "general-purpose", model: "opus")` (no isolation — work on the feature branch since tasks merged):

   ```
   # Audit fix-pass
   The post-implement audit returned <severity> at <path:line>: <message>.
   Read the report at .claude/audit-<UTC>.md for full context.
   Fix the finding(s). Then re-run `bun run audit`.
   No scope expansion — fix the audit findings, nothing else.
   ```

3. Wait for fix-pass to return.
4. Re-run audit once. If still failing, **stop**:

   ```
   Audit still failing after 1 fix-pass. Latest report: .claude/audit-<UTC>.md
   Highest finding: <severity> <path:line> — <message>
   Inspect, fix manually, then re-run /code:ship to retry the audit step only.
   ```

Never loop more than once.

### On clean audit

```
✓ All tasks landed. Audit clean.
Next: /code:review (or /commit-push-pr to ship).
```

## Notes

- The audit is **the** anti-slop enforcement. Never tweak findings to make it pass — fix the code, or accept a `LOW` when a tool is genuinely missing on the host.
