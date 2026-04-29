# code-et

Task-driven coding workflow with parallel agents in worktree isolation.

## Git Rules

- **Never push directly to main** — always create a feature branch and PR
- **Branch naming:** `feature/<name>`, `fix/<name>`, `chore/<name>`
- **Never force push** — rebase locally, push normally

## Commands

| Task | Command |
|------|---------|
| Single-bug intake | `/code:go` (scope → Task Brief) |
| Refine an idea | `/code:grill` (one-question-at-a-time interrogation) |
| Synthesize PRD | `/code:prd` (idea/conversation → `plans/YYYY-MM-DD-<slug>.md`) |
| Plan PRD | `/code:plan-issue` (PRD → vertical-slice tasks) |
| Implement tasks | `/code:implement` (parallel agents in worktrees) |

For commits and PRs use `commit-commands` plugin (`/commit`, `/commit-push-pr`).
For code review use `code-review` plugin (`/code-review`, `/simplify`).
For CLAUDE.md maintenance use `claude-md-management` plugin (`/revise-claude-md`, `/claude-md-improver`).

## Workflow — two lanes

**Bug lane** (single fix): `/code:go` → implement directly → `/commit-push-pr`

**Feature lane** (PRD-driven): `/code:grill` (optional) → `/code:prd` → `/code:plan-issue` → `/code:implement` → `/commit-push-pr`

`/code:go` does NOT chain into `/code:plan-issue` or `/code:implement` — it stops at the Task Brief. If a "bug" needs vertical decomposition (UI ↔ logic ↔ API ↔ DB), it's a feature in disguise — write a PRD.

`/code:plan-issue` is PRD-only. Each task is a **vertical slice** (UI ↔ logic ↔ API ↔ DB, end-to-end testable). When a slice supersedes existing code, deletion of the old code is part of the same commit — no parallel utilities, no `// TODO: remove old X`.

## Task Metadata Convention

Tasks created with `TaskCreate` should include metadata:

```
metadata: {
  verification: "bun test && bun run lint",
  files: ["src/path/to/file.ts:42"],
  expected_outcome: "what success looks like",
  rationale: "why this task exists — the constraint or decision driving it",
  user_story: "US-N" | "AC-N.M" | "chore:<reason>"  // feature lane only
}
```

`rationale` is mandatory. Subagents in `/code:implement` start cold — they need the *why*, not just the *what*, to make judgment calls.

## Code Standards

- TypeScript strict mode
- Max 600 lines per file
- Use server components by default, client components only when needed

## Brevity

Drop filler ("just", "simply", hedging), pleasantries, full sentences where fragments work. Pattern: `[thing] [action] [reason].` Never compress code blocks, file paths, error messages, or security warnings.

## Context Hygiene

See `.claude/rules/context-hygiene.md`. Three rules: trim attached payloads, Read in slices (offset/limit), delegate broad exploration to Explore subagents.
