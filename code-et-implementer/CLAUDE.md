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

Drop filler ("just", "simply", "really"), hedging ("perhaps", "maybe"), pleasantries ("Sure!", "Happy to help"). Fragments over sentences when meaning is clear. Pattern: `[thing] [action] [reason]. [next].`

Task subjects: `<verb> <object>` ≤50 chars. ✗ "I will implement the auth middleware". ✓ "add auth middleware in api/middleware.ts".

Never compress: code, file paths, URLs, error messages, security warnings.

## Context Hygiene

Token waste = worse plans + worse code.

1. **Trim attachments.** Quote back only the slice you act on. Ignore siblings the harness attached. Duplicate blocks count once.
2. **Read in slices.** Files >200 lines: Grep first, then `Read(offset, limit)` for a window. Re-reading the same file twice = first read should have been a slice.
3. **Delegate breadth.** 3+ independent areas, or fix in an unknown file → `Agent(subagent_type: "Explore")`. Parallel queries → one message, multiple Agent calls. Don't delegate AND search. Specify thoroughness: `quick` | `medium` | `very thorough`.
4. **Stop at sufficient.** `file:line` + rationale per task is enough. 5 sharp tasks > 15 vague ones.

## FILE-REFERENCE.md Lifecycle

`FILE-REFERENCE.md` is updated **only after a PR merges to main** that touched structural files (`*/page.tsx`, `*/route.ts`, `*/route.tsx`, `*/index.tsx`, `*/layout.tsx`, or new top-level apps/packages). Workflow:

1. All changes start on a branch (`feature/`, `fix/`, `chore/`) and ship via PR.
2. After merging the PR to main, if the diff touched structural files, run `/code:go update` to refresh `FILE-REFERENCE.md`. Commit the refresh on a follow-up branch + PR.
3. On a feature branch, do **not** edit `FILE-REFERENCE.md` — it tracks merged-to-main reality, not in-flight work.
