---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Write, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: Start implementation from pending tasks
argument-hint: [--team]
---

# Implement from Tasks

## CRITICAL: No Plan Mode

**NEVER enter plan mode.** Do NOT call EnterPlanMode or ExitPlanMode. Do NOT write or update a plan. Proceed directly to loading tasks and launching the orchestrator.

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

**Important:** `TaskList()` only returns summary fields (id, subject, status, owner, blockedBy). Use `TaskGet(taskId)` per task to retrieve full details (description, metadata, blocks).

```
task_summaries = TaskList()
pending = [t for t in task_summaries where t.status == "pending"]

full_tasks = []
for t in pending:
  full = TaskGet(t.id)  # returns description, metadata, blocks, etc.
  full_tasks.append(full)

task_payload = JSON.stringify({
  "tasks": [
    {
      "id": t.id,
      "subject": t.subject,
      "description": t.description,
      "status": t.status,
      "metadata": t.metadata,
      "blockedBy": t.blockedBy,
      "blocks": t.blocks
    }
    for t in full_tasks
  ]
})
```

## Step 1.5: Ensure Feature Branch

Before spawning the orchestrator, ensure work happens on a feature branch — not main.

1. Get current branch: `git branch --show-current`
2. If already on a non-main branch (e.g. `feature/*`, `fix/*`, `chore/*`) → continue as-is
3. If on `main` → create and checkout a feature branch:
   - Derive name from first task subject: slugify it (lowercase, replace spaces/special chars with hyphens, trim), prefix with `feature/`
   - Example: task "Add user authentication" → `feature/add-user-authentication`
   - `git checkout -b feature/<slug>`
4. Report: "Working on branch: `<branch-name>`"

## Step 2: Choose Execution Mode

Parse `$ARGUMENTS` for flags: `--team`.

If `--team` is passed but `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set → error:
"Team mode requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in .claude/settings.json env."

Pick execution mode:

```
pending = [t for t in full_tasks where t.status == "pending"]
total = len(pending)

if --team flag → TEAM MODE (Step 3b)
else           → SUBAGENT MODE (Step 3a)
```

Report: `"N pending task(s). Mode: subagent|team"`

## Step 3a: Subagent Mode (default)

```
Agent(
  subagent_type: "code:orchestrator",
  prompt: """
  Execute all pending tasks.
  Run /simplify when all tasks are done.

  ## Task Data
  <task_payload>
  """
)
```

The orchestrator receives the full task payload in its prompt. It spawns implementers in worktrees, merges branches back after each task, and reports completion. Press `ctrl+t` to view progress.

Send cmux notification:

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Implement Started' --subtitle 'N tasks → orchestrator' || true")
```

## Step 3b: Team Mode (Agent Swarm)

Become the **team lead**. Spawn N teammates where N = number of independent pending tasks (capped at 14).

Each teammate receives this prompt:

```
You are a teammate implementing tasks from the task list.

## Task Data
<task_payload>

1. Read CLAUDE.md for project rules
2. Find a pending task with no blockers from the task data above
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
