# code-et

Team project — Bun + Next.js with Claude Code plugin workflow.

## Git Rules

- **Never push directly to main** — always create a feature branch and PR
- **Branch naming:** `feature/<name>`, `fix/<name>`, `chore/<name>`
- **Never force push** — rebase locally, push normally
- **Always PR** — use `/commit-push-pr` to commit, push, and create PR

## Plugin Usage

| Task            | Tool                                      |
| --------------- | ----------------------------------------- |
| Clean up        | `/clean_gone` (stale branches+worktrees)  |
| Plan feature    | `/code:plan-issue` (LSP research → tasks) |
| Plan & explore  | Plan Mode (Shift+Tab) + LSP               |
| Create tasks    | `TaskCreate` with metadata                |
| Implement tasks | `/code:implement`                         |
| Simplify code   | `/simplify` (auto-runs after implement)   |
| Commit + PR     | `/commit-push-pr`                         |
| Review PR       | `/code-review`                            |

## Workflow

- Use `/code:plan-issue` to research codebase with LSP and create implementation tasks
- Use `/code:implement` to execute tasks (spawns parallel agents in worktrees, auto-commits per task)
- After planning, confirm with the user before implementing large changes

## Task Metadata Convention

Tasks created with `TaskCreate` should include metadata for `/code:implement` compatibility:

```
metadata: {
  verification: "bun test && bun run lint",
  files: ["src/path/to/file.ts"]
}
```

- **verification** — command to verify the task (optional — if omitted, implementer auto-detects project tests)
- **files** — hint for which files the task touches (helps subagent focus)
- **blockedBy** — set via `TaskUpdate` for task dependencies

## Stack

- **Runtime:** Bun
- **Framework:** Next.js (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS

## cmux Integration

code-et hooks are cmux-aware. When running inside cmux:
- `run-tests.sh` sends notifications on test pass/fail/timeout
- `teammate-idle.sh` alerts on stalled implementers
- `/code:workspace` sets up a workspace per feature branch

All cmux calls are guarded with `command -v cmux` checks — hooks work fine without cmux installed.

## Code Standards

- TypeScript strict mode
- Max 600 lines per file
- Use server components by default, client components only when needed
- Prefer server actions over API routes where possible
