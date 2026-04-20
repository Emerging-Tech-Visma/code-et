---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Edit, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: Implement pending tasks with parallel agents. Tags commits with US-N. Ticks PRD checklist.
argument-hint: [task-id]
effort: xhigh
---

Load pending tasks from `TaskList` or `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`. If on main, create a feature branch.

Every task runs as a subagent in its own worktree. Use the dependency graph to run independent tasks in parallel — independent tasks MUST be dispatched concurrently in a single batch, not serialized.

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
- Follow rules in .claude/rules/*.md (brevity, TypeScript strict, ≤600 lines/file)
- Every acceptance criterion must have a corresponding test
- No scope expansion — implement exactly what the task specifies; flag adjacent issues instead of fixing inline
- Commit format: `<prefix>: <subject>` where prefix is US-N | AC-N.M | chore (or no prefix if tag is `none`)

## Deliverables
1. Code changes in worktree
2. Passing verification
3. Single commit with correct prefix
4. PRD checkbox ticked (if US-N) — flip `- [ ] US-N` to `- [x] US-N` and stage with the commit
5. Merge to feature branch, remove worktree

Do not ask clarifying questions. If blocked, flag in the final report with a specific file:line reference.
```

## Each agent must

1. Implement the task. Ensure every acceptance criterion has a corresponding test.
2. Run `metadata.verification` — code must compile, all tests must pass.
3. **Commit with US-N prefix.** If `metadata.user_story` is set, format the commit message as:
   - `US-N: <subject>` when tag is `US-N`
   - `AC-N.M: <subject>` when tag is `AC-N.M`
   - `chore: <subject>` when tag starts with `chore:`
   - No prefix when tag is `none` or absent (bug lane).
4. **Tick the PRD checkbox.** If `metadata.user_story` is `US-N`, resolve the PRD via `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh` and use `Edit` to flip `- [ ] US-N` to `- [x] US-N` on that exact line. Stage the PRD change with the agent's commit.
5. Merge back to the feature branch and remove the worktree.

Only mark the task completed after the commit lands and the PRD checkbox is ticked (if applicable).

When done, run `Skill("simplify")` and report summary.

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Implement Done' --subtitle 'All tasks complete' || true")
```
