# code-et

Task-driven coding workflow with parallel agents in worktree isolation.

## Git Rules

- **Never push directly to main** — always create a feature branch and PR
- **Branch naming:** `feature/<name>`, `fix/<name>`, `chore/<name>`
- **Never force push** — rebase locally, push normally

## Commands

| Task | Command |
|------|---------|
| Plan feature | `/code:plan-issue` (LSP research → tasks) |
| Implement tasks | `/code:implement` (parallel agents in worktrees) |

For commits and PRs use `commit-commands` plugin (`/commit`, `/commit-push-pr`).
For code review use `code-review` plugin (`/code-review`, `/simplify`).
For CLAUDE.md maintenance use `claude-md-management` plugin (`/revise-claude-md`, `/claude-md-improver`).

## Workflow

1. `/code:plan-issue` — research codebase with LSP, create tasks with `file:line` refs
2. `/code:implement` — execute tasks (inline, background agents, or agent swarm)
3. `/commit-push-pr` — commit, push, and create GitHub PR

## Task Metadata Convention

Tasks created with `TaskCreate` should include metadata:

```
metadata: {
  verification: "bun test && bun run lint",
  files: ["src/path/to/file.ts"],
  expected_outcome: "what success looks like"
}
```

## Code Standards

- TypeScript strict mode
- Max 600 lines per file
- Use server components by default, client components only when needed
