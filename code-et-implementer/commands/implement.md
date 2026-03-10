---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: Implement pending tasks with parallel agents
argument-hint: [task-id]
---

Load pending tasks from `TaskList` or `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`. If on main, create a feature branch.

Every task runs as a subagent in its own worktree. Use the dependency graph to run independent tasks in parallel.

Each agent gets one task, implements it, and ensures every acceptance criterion has a corresponding test. Done = code compiles, all tests pass via `metadata.verification`. Agent commits, merges back to the feature branch, and removes the worktree — only then mark the task completed.

When done, run `Skill("simplify")` and report summary.

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Implement Done' --subtitle 'All tasks complete' || true")
```
