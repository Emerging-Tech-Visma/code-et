---
context: fork
allowed-tools: Read, Write, Grep, Glob, Bash, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__typescript-lsp__*, mcp__pyright-lsp__*, mcp__rust-analyzer-lsp__*
description: Research codebase with LSP precision, plan feature, create native tasks
argument-hint: [feature-description] [@spec-file]
---

# Plan Issue — LSP Research → Native Tasks

Research codebase with LSP precision, design implementation approach, create native tasks with `file:line` references.

## Phase 0.5: Load Existing Plan

Check for a spec or plan document in this order:

1. `@file` argument (if `$ARGUMENTS` contains `@<path>`) → Read that file
2. `SPEC.md` in project root
3. `plans/*.md` files

If found → use as requirements context alongside the feature description from `$ARGUMENTS`.
If not found → use only the feature description from `$ARGUMENTS`.

## Phase 0.6: Load Code Quality Rules

Check `.claude/rules/` for project-specific rules:

```
Glob(".claude/rules/*.md") → Read each rule file
```

Incorporate rules as constraints for the implementation plan (anti-patterns to avoid, conventions to follow).

## Phase 0.7: Explore Approaches

Research the codebase to identify 2-3 viable implementation approaches:

```
Glob + Grep → find relevant modules, patterns, existing similar features
Read → understand current architecture
```

Evaluate approaches internally, pick the best one based on:
- Alignment with existing codebase patterns
- Minimal blast radius (fewest files/lines changed)
- Least risk of regressions

Log the decision: `"Approach: <name> — <1-line reason>"`

## Phase 0.8: Detect Stack → Select LSP

Detect the project stack by checking for marker files:

| Check                                  | Stack      | LSP tools                   |
| -------------------------------------- | ---------- | --------------------------- |
| `tsconfig.json` or `package.json`      | TypeScript | `mcp__typescript-lsp__*`    |
| `pyproject.toml` or `requirements.txt` | Python     | `mcp__pyright-lsp__*`       |
| `Cargo.toml`                           | Rust       | `mcp__rust-analyzer-lsp__*` |

```
Glob("tsconfig.json") → TypeScript
Glob("pyproject.toml") OR Glob("requirements.txt") → Python
Glob("Cargo.toml") → Rust
```

For mixed projects (e.g. TS frontend + Python backend), use all detected LSPs.
If no LSP marker found, skip LSP phases and use Grep/Read only.

## Phase 1: LSP Deep Research

Using the detected LSP, trace the code paths relevant to the chosen approach:

1. **Find entry points** — `go_to_definition` on key symbols from Phase 0.7
2. **Trace references** — `find_references` to understand usage patterns and blast radius
3. **Inspect types** — `hover` on interfaces, types, and function signatures
4. **Map data flow** — follow the chain: entry → processing → storage/output

Build a mental model of exactly which files, functions, and lines need changes.

## Phase 1.5: Create Precise Task Specs

Read every file that will be modified. For each change:

- Note the exact `file:line` range
- Describe what changes at that location
- Identify dependencies between changes

## Phase 2: Break into Tasks

Split the implementation into ordered tasks:

- **Max 3 files per task** — keeps each task focused and reviewable
- **Order by dependency** — foundational changes first, dependent changes later
- Each task must be independently verifiable

## Phase 2.5: Quality Gate

Before presenting the plan, verify each task has:

- [ ] Specific `file:line` references (not just file names)
- [ ] A verification command (test, lint, type-check, or build)
- [ ] Clear success criteria (what "done" looks like)
- [ ] Anti-patterns noted (from Phase 0.6 rules, if any)

If any task is missing these → go back and research more with LSP.

## Phase 3: Create Tasks

For each task, create with full metadata:

```
TaskCreate(
  subject: "<imperative title>",
  description: "<detailed steps with file:line refs>\n\nVerification: <command>\nExpected outcome: <what success looks like>",
  metadata: {
    "verification": "<specific test/build command>",
    "expected_outcome": "<what success looks like>",
    "files": ["src/path/file.ts:15-30", "src/other.ts:42"]
  }
)
```

After all tasks are created, set dependencies:

```
TaskUpdate(taskId: "<later-task>", addBlockedBy: ["<earlier-task>"])
```

## Phase 3.5: Persist Tasks to Manifest

After all tasks and dependencies are set, serialize them to a JSON manifest file for cross-session persistence.

The manifest path is derived from the `CLAUDE_CODE_TASK_LIST_ID` env var: `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`

**Important:** `TaskList()` only returns summary fields (id, subject, status, owner, blockedBy). Use `TaskGet(taskId)` for each task to retrieve full details (description, metadata, blocks).

```
task_summaries = TaskList()
full_tasks = []
for summary in task_summaries:
  full = TaskGet(summary.id)
  full_tasks.append(full)

manifest = {
  "version": 1,
  "createdAt": "<current ISO timestamp>",
  "tasks": [
    {
      "id": task.id,
      "subject": task.subject,
      "description": task.description,
      "status": task.status,
      "metadata": task.metadata,
      "blockedBy": task.blockedBy,
      "blocks": task.blocks
    }
    for task in full_tasks
  ]
}

Write(".claude/${CLAUDE_CODE_TASK_LIST_ID}.json", JSON.stringify(manifest, null, 2))
```

Each `/code:plan-issue` run **replaces** the manifest (fresh plan).

## Output

After all tasks and dependencies are created:

```
"Plan complete: N tasks created and saved to .claude/<task-list-id>.json. Run /code:implement to start."
```

Send cmux notification:

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Plan Complete' --subtitle 'N tasks created' || true")
```
