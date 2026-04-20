---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Edit, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: Implement pending tasks with parallel agents. Tags commits with US-N. Ticks PRD checklist.
argument-hint: [task-id]
effort: medium
---

Load pending tasks from `TaskList` or `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`. If on main, create a feature branch.

Every task runs as a subagent in its own worktree. Use the dependency graph to run independent tasks in parallel.

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
