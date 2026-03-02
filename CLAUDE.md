# code-et

Team project — Bun + Next.js with Claude Code plugin workflow.

## Git Rules

- **Never push directly to main** — always create a feature branch and PR
- **Branch naming:** `feature/<name>`, `fix/<name>`, `chore/<name>`
- **Never force push** — rebase locally, push normally
- **Always PR** — use `/commit-push-pr` to commit, push, and create PR

## Plugin Usage

| Task            | Tool                                    |
| --------------- | --------------------------------------- |
| Plan & explore  | Plan Mode (Shift+Tab) + LSP             |
| Create tasks    | `TaskCreate` with metadata              |
| Implement tasks | `/code:implement`                       |
| Simplify code   | `/simplify` (auto-runs after implement) |
| Commit + PR     | `/commit-push-pr`                       |
| Review PR       | `/code-review`                          |

## Task Metadata Convention

Tasks created with `TaskCreate` should include metadata for `/code:implement` compatibility:

```
metadata: {
  verification: "bun test && bun run lint",
  files: ["src/path/to/file.ts"]
}
```

- **verification** — command that must pass for task to be considered done
- **files** — hint for which files the task touches (helps subagent focus)
- **blockedBy** — set via `TaskUpdate` for task dependencies

## Stack

- **Runtime:** Bun
- **Framework:** Next.js (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS

## Code Standards

- TypeScript strict mode
- Max 600 lines per file
- Use server components by default, client components only when needed
- Prefer server actions over API routes where possible
