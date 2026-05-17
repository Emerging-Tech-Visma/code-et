---
tools: Bash, Read, Skill
description: "Pre-merge review — local audit + diff review against merge-base. Delegates to engineering plugin's code-review skill if installed."
argument-hint: "[--no-audit]"
effort: high
---

# Review — Pre-merge gate

Run before opening a PR (or after `/code:ship`). Two steps:

1. **Static gate** — `bun run audit` (mirror of CI). Skipped with `--no-audit` when ship just ran.
2. **Diff review** — `git diff <merge-base>..HEAD` routed to the engineering plugin's `code-review` skill (or an inline fallback).

This command does **not** push or open the PR — that's `/commit-push-pr`. It's a local gate that mirrors what the cloud reviewer would catch.

## Procedure

### Step 1 — Static gate (skip with `--no-audit`)

```
Bash('bun run audit')
```

The audit runs `biome check`, `tsc --noEmit`, `bun audit`, `bun test`. Report at `.claude/audit-<UTC>.md`. If it exits non-zero, surface the highest finding and **stop** — fix the static gate before running Step 2.

### Step 2 — Code-review

If the engineering plugin's `code-review` skill is installed, delegate:

```
Skill("code-review")
```

The skill reads `git diff <merge-base>..HEAD` (plus the audit report from Step 1) and returns findings ordered by confidence × severity. Feed the output back to the user.

If the engineering plugin is **not** installed, run a 5-area inline review:

1. **Deep-module shape.** Does any new module pass the deletion test? Anything extracted as a shallow pass-through? (See [`docs/architecture.md`](../docs/architecture.md).)
2. **Anti-slop.** Rule of Three, mirror tests, defensive validation between trusted modules, dead re-exports. (See [`docs/anti-slop.md`](../docs/anti-slop.md) §"Hard rules".)
3. **Test coverage.** Every acceptance criterion has a test; tests assert through the interface. (See [`docs/testing.md`](../docs/testing.md).)
4. **Security.** Zod parsing at every HTTP seam; secrets validated at boot; auth on mutating routes; no raw SQL string-concat.
5. **Slice integrity.** Each commit is a coherent vertical slice; superseded code deleted in the same commit; no `// TODO: remove old X`.

Report findings with `severity | path:line | issue | suggested fix`. Group by severity (CRITICAL > HIGH > MEDIUM > LOW). Cite from the audit report and the diff.

## Output

```
Review complete.
- Audit: <PASS | FAIL — see .claude/audit-<UTC>.md>
- Code-review: <N findings | CLEAN>

Next: /commit-push-pr to ship, or fix and re-run /code:review.
```

## Notes

- Use in parallel with the cloud `/ultrareview` if available. `/code:review` is the local gate; `/ultrareview` is the multi-agent cloud pass. Both catch different things.
- If `--no-audit` is passed and no fresh `.claude/audit-*.md` exists, the diff review is still useful but lacks static-gate context.
