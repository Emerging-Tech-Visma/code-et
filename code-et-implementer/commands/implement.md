---
context: fork
allowed-tools: Bash, Bash(gh:*), Bash(git:*), Read, Write, Edit, Grep, Glob, Task, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: Start implementation from pending tasks
argument-hint: [--team] [--worktree]
---

# Implement from Tasks

## Step 1: Load Tasks (Two-Source)

### 1a: Check native TaskList

```
TaskList() → find all pending tasks
```

If pending tasks exist → use them (same-session). Continue to Step 1d.

### 1b: Fall back to manifest file

If no pending tasks in TaskList, read the manifest:

```
manifest_path = ".claude/${CLAUDE_CODE_TASK_LIST_ID}.json"
Read(manifest_path) → parse JSON
```

Filter for tasks where `status != "completed"`. If pending tasks found → restore them:

```
id_mapping = {}
for task in manifest.tasks where status != "completed":
  result = TaskCreate(
    subject: task.subject,
    description: task.description,
    activeForm: task.activeForm,
    metadata: task.metadata
  )
  id_mapping[task.id] = result.new_id

# Restore dependencies using mapped IDs
for task in manifest.tasks where status != "completed":
  if task.blockedBy has entries:
    mapped_blockers = [id_mapping[b] for b in task.blockedBy if b in id_mapping]
    TaskUpdate(id_mapping[task.id], addBlockedBy: mapped_blockers)
```

### 1c: No tasks anywhere

If both TaskList and manifest are empty or missing → error: "No pending tasks found. Run /code:plan-issue first."

### 1d: Build task payload

Build a full JSON payload of all pending tasks for prompt serialization.

**Important:** `TaskList()` only returns summary fields (id, subject, status, owner, blockedBy). Use `TaskGet(taskId)` per task to retrieve full details (description, activeForm, metadata, blocks).

```
task_summaries = TaskList()
pending = [t for t in task_summaries where t.status == "pending"]

full_tasks = []
for t in pending:
  full = TaskGet(t.id)  # returns description, metadata, blocks, etc.
  full_tasks.append(full)

task_payload = JSON.stringify({
  "manifestPath": ".claude/${CLAUDE_CODE_TASK_LIST_ID}.json",
  "tasks": [
    {
      "id": t.id,
      "subject": t.subject,
      "description": t.description,
      "activeForm": t.activeForm,
      "status": t.status,
      "metadata": t.metadata,
      "blockedBy": t.blockedBy,
      "blocks": t.blocks
    }
    for t in full_tasks
  ]
})
```

## Step 2: Choose Execution Mode

Parse `$ARGUMENTS` for flags: `--team`, `--worktree`.

If `--team` is passed but `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set → error:
"Team mode requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in .claude/settings.json env."

Evaluate task count and complexity to pick the right mode:

```
pending = [t for t in full_tasks where t.status == "pending"]
total = len(pending)
has_deps = any(t.blockedBy is non-empty for t in pending)
is_complex = any(len(t.metadata.files) > 3 for t in pending)

if --team flag           → TEAM MODE (Step 3c)
elif total <= 2 AND NOT has_deps AND NOT is_complex → STANDALONE (Step 3a)
else                     → SUBAGENT MODE (Step 3b)
```

Report: `"N pending task(s). Mode: standalone|subagent|team"`

## Step 3a: Standalone Mode (inline)

Implement task(s) directly without spawning orchestrator or implementer agents. Use this for 1-2 simple tasks with no dependencies.

**Note:** `--worktree` is ignored in standalone mode (no benefit to isolating inline work).

For each pending task, in order:

1. `TaskUpdate(task.id, status: "in_progress")`
2. Read all files listed in `task.metadata.files`
3. Implement changes per task description (use file:line refs as guidance)
4. Run `task.metadata.verification` — if it fails, debug up to 3 attempts. If still failing → `TaskUpdate(task.id, status: "in_progress")`, report BLOCKED, and continue to next task
5. Self-review:
   - **Scope check:** did I only change what the task asked for?
   - **Quality check:** no leftover debug code, no regressions
6. `TaskUpdate(task.id, status: "completed")`
7. Update manifest JSON at `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json` — set the matching task's status to `"completed"`
8. `Skill("commit-commands:commit")`

After all tasks are processed:

1. `Skill("simplify")` — review changed code for quality
2. Delete completed tasks from TaskList
3. Report final status (completed / blocked counts)

## Step 3b: Subagent Mode (default)

```
Task(
  subagent_type: "code:orchestrator",
  prompt: """
  Execute all pending tasks.
  Worktree mode: <true if --worktree passed, false otherwise>
  Run /simplify when all tasks are done.

  ## Task Data
  <task_payload>
  """
)
```

The orchestrator receives the full task payload in its prompt so it works even with `context: fork`. It spawns implementers, commits after each task, and reports completion. When `--worktree` is passed, tasks with non-overlapping files run in isolated worktrees for safe parallelism. Press `ctrl+t` to view progress.

## Step 3c: Team Mode (Agent Swarm)

Become the **team lead**. Spawn N teammates where N = number of independent pending tasks (capped at 8).

Each teammate receives this prompt:

```
You are a teammate implementing tasks from the task list.

## Task Data
<task_payload>

1. Read CLAUDE.md for project rules
2. Run TaskList to find a pending task with no blockers (tasks are pre-loaded above)
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
