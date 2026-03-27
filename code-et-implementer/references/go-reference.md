# Go Command — Reference

## Important Files

| File | Purpose |
|------|---------|
| `commands/go.md` | The go intake command definition |
| `FILE-REFERENCE.md` (project root) | Auto-generated map of all apps, screens, and files |
| `commands/plan-issue.md` | Next step after intake — research + create tasks |
| `commands/implement.md` | Execute tasks after planning |

## Workflow Position

```
/code:go → /code:plan-issue → /code:implement → /commit-push-pr
  ^              ^                   ^
  intake         planning            execution
  (this cmd)
```

`/code:go` is the entry point. It scopes the work, then the user proceeds to `/code:plan-issue` with a clear brief.

## FILE-REFERENCE.md Lifecycle

- **First run:** `/code:go` auto-generates `FILE-REFERENCE.md` by scanning the project (Glob for routes/pages, Grep for exports/endpoints)
- **Update:** Run `/code:go update` to rescan and refresh the file after structural changes
- **Manual edits:** Users can edit the file directly — the go command reads whatever is there

The file structure:
- **Apps Overview** — table of all apps with root paths
- **Per-app sections** — screens with routes and key files
- **Shared** — components and utilities used across apps
- **API Routes** — backend endpoints

Keep it flat and scannable.
