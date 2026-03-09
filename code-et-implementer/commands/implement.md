---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: Implement pending tasks with parallel agents
argument-hint: [task-id]
---

# Implement from Tasks

**NEVER enter plan mode.** Proceed directly to loading tasks and executing.

## Step 1: Load Tasks

### 1a: Check native TaskList

```
TaskList() → find all pending tasks
```

If pending tasks exist → use them. Skip to Step 1c.

### 1b: Fall back to manifest file

If no pending tasks, read `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`:

```
Read(manifest_path) → parse JSON → filter status != "completed"
```

Restore tasks:

```
id_mapping = {}
for task in manifest.tasks where status != "completed":
  result = TaskCreate(subject, description, metadata)
  id_mapping[old_id] = new_id

for task with blockedBy:
  TaskUpdate(id_mapping[task.id], addBlockedBy: [id_mapping[b] for b in blockedBy])
```

If both sources empty → error: "No pending tasks. Run /code:plan-issue first."

### 1c: Build task payload

`TaskList()` returns summaries only. Use `TaskGet(taskId)` per task for full details.

## Step 2: Ensure Feature Branch

1. `git branch --show-current`
2. If on non-main branch → continue
3. If on `main` → `git checkout -b feature/<slug-from-first-task>`

## Step 3: Choose Execution Mode

Count pending tasks and apply these rules **exactly** — do NOT override:

- **1 task** (or 2 with no deps and ≤2 files each) → **Inline mode**
- **2-5 independent tasks** → **Background agent mode** (one agent PER task)
- **5+ tasks** or `--team` flag → **Agent swarm mode**

**CRITICAL: Background agent mode means spawning MULTIPLE agents — one per task. Do NOT put all tasks into a single agent. Each agent gets exactly ONE task.**

## Step 4: Execute

### Inline mode

Implement task(s) directly. For each task:
1. Read target files, implement changes following task description
2. Run verification command from `metadata.verification`
3. Commit: `git add <files> && git commit -m "<task subject>"`
4. `TaskUpdate(taskId, status: "completed")`

### Background agent mode

Spawn ALL agents in a **single message** — one Agent call per task, all in parallel:

```
// 3 tasks = 3 Agent calls in ONE message. NEVER combine tasks into 1 agent.
Agent(subagent_type: "code:implementer", run_in_background: true,
  prompt: "Implement: <task 1 subject>\n<task 1 description>\nFiles: <files>\nVerify: <verify>\nCommit and return COMPLETE or BLOCKED.")

Agent(subagent_type: "code:implementer", run_in_background: true,
  prompt: "Implement: <task 2 subject>\n<task 2 description>\nFiles: <files>\nVerify: <verify>\nCommit and return COMPLETE or BLOCKED.")

Agent(subagent_type: "code:implementer", run_in_background: true,
  prompt: "Implement: <task 3 subject>\n<task 3 description>\nFiles: <files>\nVerify: <verify>\nCommit and return COMPLETE or BLOCKED.")
```

When each agent completes (automatic notification — NO polling):
1. Merge worktree branch: `git merge <branch> --no-edit`
2. Close task: `TaskUpdate(taskId, status: "completed")`

If merge fails → `TaskUpdate(taskId, status: "blocked")`, report conflict.

### Agent swarm mode

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Act as team lead, spawn teammates (max 14). Each teammate:
1. Claims a pending task via `TaskUpdate(status: "in_progress")`
2. Implements, verifies, commits
3. Marks `TaskUpdate(status: "completed")`, picks next task

Monitor via `TaskList()` every 15s. Deadlock if nothing in_progress but pending tasks have unresolved blockers.

## Step 5: Wrap Up

After all tasks complete:
1. Run `Skill("simplify")` to review and clean up changed code
2. Report summary: tasks completed, branch name
3. `"Run /code:pr to create a pull request."`

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Implement Done' --subtitle 'All tasks complete' || true")
```
