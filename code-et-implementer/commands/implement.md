---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: Implement pending tasks with parallel agents
argument-hint: [task-id]
---

Load pending tasks from `TaskList` or `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`. If on main, create a feature branch.

Choose the best execution approach — inline for trivial work, background agents in worktrees for independent tasks, agent swarm for large batches. You decide.

Each agent gets one task, implements it, runs verification from `metadata.verification`, and commits. Merge worktree branches back. Mark tasks completed.

When done, run `Skill("simplify")` and report summary.

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Implement Done' --subtitle 'All tasks complete' || true")
```
