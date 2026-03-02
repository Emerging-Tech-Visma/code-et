---
context: fork
allowed-tools: Bash, Bash(gh:*), Bash(git:*), Read, Write, Edit, Grep, Glob, Task, Skill, TaskList, TaskGet, TaskUpdate
description: Start implementation from pending tasks
argument-hint: [--team | --no-team]
---

# Implement from Tasks

## Step 1: Verify Tasks Exist

```
TaskList() → find all pending tasks
```

If tasks exist → continue to Step 2.
If no tasks found → error: "No pending tasks found. Create tasks first using TaskCreate or Plan Mode."

## Step 2: Choose Execution Mode

Parse `$ARGUMENTS`:

- `--team` → force team mode (Step 3b)
- `--no-team` → force subagent mode (Step 3a)
- No flag → auto-detect (see below)

### Auto-detection

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json` env.

1. Count total pending tasks
2. Count independent tasks (no `blockedBy` or all blockers completed)
3. If total >= 4 AND independence ratio >= 0.6 → team mode (Step 3b)
4. Otherwise → subagent mode (Step 3a)

If `--team` is passed but `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set → error:
"Team mode requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in .claude/settings.json env."

## Step 3a: Subagent Mode (default)

```
Task(
  subagent_type: "coding-plugin:orchestrator",
  prompt: """
  Execute all pending tasks.
  Use TaskList to find all pending tasks.
  Update task status as you complete each task.
  Run /simplify when all tasks are done.
  """
)
```

The orchestrator spawns implementers in isolated worktrees, commits after each task, and reports completion. Press `ctrl+t` to view progress.

## Step 3b: Team Mode (Agent Swarm)

Become the **team lead**. Spawn N teammates where N = number of independent pending tasks (capped at 8).

Each teammate receives this prompt:

```
You are a teammate implementing tasks from the task list.

1. Read CLAUDE.md for project rules
2. Run TaskList to find a pending task with no blockers
3. Claim it: TaskUpdate(taskId, status: 'in_progress', owner: '<your-name>')
4. Implement the task using metadata.files as guidance
5. Run the verification command from metadata.verification
6. If pass → TaskUpdate(taskId, status: 'completed'), commit changes, pick next pending task
7. If fail → debug (max 3 attempts), then mark as blocked and move to next task
8. When no more pending tasks are available, report completion and exit
```

### Lead monitoring loop

After spawning teammates, monitor every 15 seconds:

1. `TaskList()` → check progress
2. Log: completed / in_progress / pending counts
3. **Deadlock detection:** if no tasks are `in_progress` AND pending tasks have unresolved blockers → alert user
4. **All complete:** when no pending or in_progress tasks remain:
   - Message teammates to exit
   - Run `/simplify`
   - Delete completed tasks

## Resuming Work

Run `/code:implement` again. The orchestrator (or lead) reconstructs state from TaskList.
