---
tools: Read, Grep, Glob, Bash, LSP, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet
description: "Research codebase with LSP, create implementation tasks"
argument-hint: "[feature-description] [@spec-file]"
effort: high
---

Research codebase, create tasks with `file:line` references.

1. If `$ARGUMENTS` has `@<path>`, read that spec. Also check `.claude/rules/*.md` for constraints.
2. Use LSP (`documentSymbol`, `findReferences`) to get exact line numbers. Grep/Glob to find files, LSP for precision. For 3+ independent areas, spawn parallel Explore agents.
3. Break into tasks. Reason about dependencies — use `blocked_by` to build a dependency graph. Tasks with no shared dependencies should be independent to allow parallel execution. Each task needs `file:line` refs from LSP, a verification command, and success criteria.
4. Create tasks via `TaskCreate` with metadata: `{ "verification": "<cmd>", "files": ["path:line"], "expected_outcome": "<what success looks like>" }`. Set dependencies with `TaskUpdate(addBlockedBy)`. Task subject: `<verb> <object>` ≤50 chars, imperative mood, no articles or filler (e.g. "add auth middleware in api/middleware.ts").
5. Save manifest to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`.

Output: `"Plan complete: N tasks created. Run /code:implement to start."`

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Plan Complete' --subtitle 'N tasks created' || true")
```
