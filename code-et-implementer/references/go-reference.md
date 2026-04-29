# Go Command — Reference

## Important Files

| File | Purpose |
|------|---------|
| `commands/go.md` | The go intake command definition |
| `FILE-REFERENCE.md` (project root) | Non-derivable knowledge: apps overview, hot paths, landmines, invariants |
| `commands/plan-issue.md` | Next step after intake — research + create tasks |
| `commands/implement.md` | Execute tasks after planning |

## Workflow Position

Two distinct lanes — `/code:go` does NOT chain into `/code:plan-issue` or `/code:implement`.

```
Bug lane (single fix):
  /code:go → (user implements directly) → /commit-push-pr

Feature lane (PRD-driven):
  /code:grill → /code:prd → /code:plan-issue → /code:implement → /commit-push-pr
   (optional)    PRD doc    vertical slices     parallel agents
```

`/code:go` produces a Task Brief and stops. The user reads it and either:
- Implements the fix directly (most bugs are 1-3 file edits — no swarm needed), or
- Realises the work is multi-slice and routes to `/code:prd` instead.

If the bug genuinely needs vertical decomposition (UI ↔ logic ↔ API ↔ DB), it's a feature in disguise — write a PRD.

## FILE-REFERENCE.md Lifecycle

- **First run:** `/code:go` auto-generates `FILE-REFERENCE.md` by scanning for non-derivable knowledge — CLAUDE.md "never" rules, deprecated markers, hot-path entry points, schema purposes, top-of-file invariants
- **Update:** Run `/code:go update` to rescan after structural changes (new app, new landmine, schema change)
- **Manual edits:** Users can edit the file directly — the go command reads whatever is there. Hand-curated landmines are especially valuable

The file structure:
- **Apps Overview** — ≤5 lines: app name, one-line purpose, root path
- **Hot Paths** — per-request vs startup-only files (blast radius)
- **Landmines** — never-do rules with reasons
- **Module Invariants** — per-module non-obvious constraints
- **Database Schema** (optional) — table purposes + key relations
- **Domain Rules / DSL** (optional) — ≤10-line summary, link to source

What's **not** in here: routes, components, screens, API endpoints, file paths in general. Glob the filesystem on demand — duplicating it bloats tokens and goes stale.

Keep it flat and scannable.
