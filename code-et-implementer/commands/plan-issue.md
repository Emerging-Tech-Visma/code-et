---
tools: Read, Grep, Glob, Bash, LSP, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet
description: Research codebase with LSP, create implementation tasks
argument-hint: [feature-description] [@spec-file]
---

# Plan Issue — LSP Research → Native Tasks

Research codebase with LSP precision, design implementation approach, create native tasks with `file:line` references.

## Phase 1: Load Context

1. **Spec file** — if `$ARGUMENTS` contains `@<path>`, Read that file. Else check `SPEC.md`, then `plans/*.md`
2. **Code rules** — `Glob(".claude/rules/*.md")` → Read each. These are constraints for the plan
3. **Codebase research** — Grep/Glob to find relevant modules, patterns, similar features. Pick the approach with minimal blast radius that follows existing patterns

Log: `"Approach: <name> — <1-line reason>"`

## Phase 2: LSP Deep Research

HARD RULE: Every `file:line` in a task MUST come from an LSP call. Grep/Glob find files, LSP provides lines.

For EACH target file:
1. `LSP(operation: "documentSymbol")` — get symbols with exact line numbers
2. `LSP(operation: "findReferences")` on key symbols — understand blast radius

### Parallel mode (3+ independent areas)

Spawn up to 3 Explore agents for independent subsystems:

```
Agent(subagent_type: "Explore", prompt: "Research <area>. Use LSP on: [files]. Report symbols, lines, deps.", run_in_background: true)
```

WAIT for completion notifications — do NOT poll or sleep.

## Phase 3: Break into Tasks

- **Max 3 files per task** — keeps each focused and reviewable
- **Order by dependency** — foundational changes first
- Each task independently verifiable

### Quality gate — verify each task has:

- Specific `file:line` references from LSP (NOT from Read/Grep)
- A verification command (test, lint, type-check, or build)
- Clear success criteria

If any line number wasn't from LSP, call `LSP(operation: "documentSymbol")` NOW.

## Phase 4: Create Tasks

```
TaskCreate(
  subject: "<imperative title>",
  description: "<steps with file:line refs>\n\nVerification: <command>\nExpected: <success criteria>",
  metadata: {
    "verification": "<test/build command>",
    "expected_outcome": "<what success looks like>",
    "files": ["src/path/file.ts:15-30", "src/other.ts:42"]
  }
)
```

Set dependencies: `TaskUpdate(taskId: "<later>", addBlockedBy: ["<earlier>"])`

## Phase 5: Persist Manifest

Serialize tasks to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json` for cross-session persistence:

```
task_summaries = TaskList()
full_tasks = [TaskGet(t.id) for t in task_summaries]

manifest = {
  "version": 1,
  "createdAt": "<ISO timestamp>",
  "tasks": [{ id, subject, description, status, metadata, blockedBy, blocks } for each]
}

Write(".claude/${CLAUDE_CODE_TASK_LIST_ID}.json", JSON.stringify(manifest, null, 2))
```

## Output

```
"Plan complete: N tasks created and saved to .claude/<id>.json. Run /code:implement to start."
```

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Plan Complete' --subtitle 'N tasks created' || true")
```
