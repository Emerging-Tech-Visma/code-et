---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Edit, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: Implement pending tasks with parallel agents. Tags commits with US-N. Ticks PRD checklist.
argument-hint: [task-id]
effort: xhigh
---

Load pending tasks from `TaskList` or `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`. If on main, create a feature branch.

Every task runs as a forked subagent in its own worktree. Dispatch via the `Agent` tool with `isolation: "worktree"` and `subagent_type: "general-purpose"`, passing the prompt template below as the agent's first (and only) turn. Do NOT shell out to `git worktree add` — `isolation: "worktree"` handles it and the fork inherits no parent process state (requires `CLAUDE_CODE_FORK_SUBAGENT=1` on external builds; already on by default in the harness this skill ships under).

Use the dependency graph to run independent tasks in parallel. Independent tasks MUST be dispatched in a single message with multiple `Agent` tool calls so they run concurrently — never serialize what could fan out.

## Dispatch prompt template

Each subagent starts cold. Send one comprehensive first turn — intent, constraints, acceptance criteria, `file:line` anchors, verification, and rationale — so the subagent can operate autonomously without back-and-forth. Use this template verbatim (fill `<…>` from task metadata and PRD):

```
# Task <id>: <title>

## Tag
<metadata.user_story — one of: US-N | AC-N.M | chore:<reason> | none>

## PRD context (if US-N or AC-N.M)
<Paste the matching US-N / AC-N.M block from the active PRD, resolved via ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh. Include the parent User Story and all its ACs so the agent sees the full intent.>

## Rationale
<metadata.rationale — why this task exists; the constraint or decision driving it. Verbatim from plan.>

## Files to touch
<metadata.files — exact file:line anchors from LSP. Read these before editing.>

## Expected outcome
<metadata.expected_outcome — observable success criterion.>

## Verification
Run `<metadata.verification>`. Must exit 0. All existing tests must still pass.

## Constraints
- Follow rules in `code-et-implementer/CLAUDE.md` (Brevity, Context Hygiene, Clean Architecture (Rust) controlling rules, ≤600 lines/file). For Rust projects, see `code-et-implementer/docs/architecture.md` for layer rules and `code-et-implementer/docs/anti-slop.md` for the anti-slop hard rules
- Each new or modified file belongs to exactly one layer (`domain` | `application` | `infrastructure` | `interface` | `chore`); imports point inward
- Read in slices: `Read(offset, limit)` for files >200 lines; never re-read the same file twice for different blocks
- Delegate breadth to `Agent(subagent_type: "Explore")` if the fix path is unclear — do not Grep-and-Read your way through unknown territory
- Every acceptance criterion must have a corresponding test
- No scope expansion — implement exactly what the task specifies; flag adjacent issues instead of fixing inline
- If the slice supersedes existing code, delete the superseded code in the same commit. No parallel utilities, no `// TODO: remove old X`. New code obsoletes old.
- Commit format: `<prefix>: <subject>` where prefix is US-N | AC-N.M | chore (or no prefix if tag is `none`)

## Deliverables (subagent reports back)
1. Code changes committed in the isolated worktree
2. Passing verification
3. Single commit with correct prefix
4. PRD checkbox ticked (if US-N) — flip `- [ ] US-N` to `- [x] US-N` and stage with the commit
5. Final report: commit SHA, branch name, worktree path (returned by the `Agent` tool result)

Do not merge back to the parent feature branch — the orchestrator handles that. Do not ask clarifying questions. If blocked, flag in the final report with a specific file:line reference.
```

## Each subagent must

1. Implement the task. Ensure every acceptance criterion has a corresponding test.
2. Run `metadata.verification` — code must compile, all tests must pass.
3. **Commit with US-N prefix.** If `metadata.user_story` is set, format the commit message as:
   - `US-N: <subject>` when tag is `US-N`
   - `AC-N.M: <subject>` when tag is `AC-N.M`
   - `chore: <subject>` when tag starts with `chore:`
   - No prefix when tag is `none` or absent (ad-hoc task).
4. **Tick the PRD checkbox.** If `metadata.user_story` is `US-N`, resolve the PRD via `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh` and use `Edit` to flip `- [ ] US-N` to `- [x] US-N` on that exact line. Stage the PRD change with the agent's commit.

The subagent stops after step 4 and returns. It must NOT merge or remove its own worktree — it has no view of the parent's feature branch from inside the isolated worktree.

## Orchestrator (this skill) must

After each `Agent` call returns:
1. Read the returned worktree path and branch from the tool result.
2. From the parent feature branch, `git merge --no-ff <subagent-branch>` to bring the commit in.
3. Remove the worktree with `git worktree remove <path>` (the harness auto-cleans empty worktrees, but populated ones need explicit removal after merge).
4. Mark the task completed via `TaskUpdate` only after the merge lands.

If a subagent reports failure, leave the worktree in place for inspection — do not auto-discard work.

When done, run `Skill("simplify")`,
then `Skill("audit", "--fast")` (stages 1–2 only — fmt + clippy). A non-zero exit halts the chain; surface the `audit: report written to <path>` line from stderr in the chat so the developer can jump straight to the failing finding.

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Implement Done' --subtitle 'All tasks complete' || true")
```
