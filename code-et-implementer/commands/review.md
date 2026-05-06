---
tools: Bash, Read, Skill
description: "Pre-merge review — local audit + diff review against merge-base. Delegates to engineering plugin's code-review skill if installed."
argument-hint: "[--no-audit]"
effort: high
---

# Review — Pre-merge gate

Run before opening a PR (or after `/code:ship`). Two steps:

1. **Static gate** — full local audit pipeline (mirrors CI). Same as `/code:ship`'s tail step. Skipped with `--no-audit` if you just ran ship and the report is fresh.
2. **Diff review** — capture `git diff <merge-base>..HEAD` and route to the engineering plugin's `code-review` skill for a human-judgment pass over the change set.

This command does **not** push or open the PR — that's `/commit-push-pr`. It is a local gate that mirrors what the cloud reviewer would catch.

## Procedure

### Step 1 — Static gate (skip with `--no-audit`)

```
Bash('bash "${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh" "$PWD"')
```

This runs the same seven-stage pipeline as CI (`fmt`, `clippy -D warnings`, `layer-deps-validator.sh`, `cargo machete`, `cargo audit`, `cargo deny check`, `cargo nextest`). Report at `.claude/audit-<UTC>.md`. If it exits non-zero, surface the highest finding from the report and **stop** — fix the static gate before running Step 2 (a noisy diff review on top of broken static checks wastes everyone's time).

### Step 2 — Code-review

If the engineering plugin's `code-review` skill is installed, delegate to it:

```
Skill("code-review")
```

The skill reads `git diff <merge-base>..HEAD` (and the audit report from Step 1 if present) and returns findings ordered by confidence × severity. Feed the output back to the user.

If the engineering plugin is **not** installed, run a 5-area inline review:
1. **Layer compliance** — does any new file violate the inward dependency rule? (`code-et-implementer/docs/architecture.md` §"The Dependency Rule")
2. **Anti-slop** — Rule of Three duplicates, mirror tests, defensive validation, dead re-exports, complexity ≥ 15. (`code-et-implementer/docs/anti-slop.md` §"Hard rules")
3. **Test coverage** — every acceptance criterion has a corresponding test. (`code-et-implementer/docs/testing.md` §"Per-layer test matrix")
4. **Security** — `cargo audit` clean; secrets in `secrecy::Secret<T>`; auth at every interface entry point. (`code-et-implementer/docs/architecture.md` §"Rust security checklist")
5. **Slice integrity** — each commit (US-N / AC-N.M / chore) is a coherent vertical slice; superseded code deleted in same commit; no `// TODO: remove old X`.

Report findings with `severity | path:line | issue | suggested fix`. Group by severity (CRITICAL > HIGH > MEDIUM > LOW). Cite from the audit report and the diff.

## Output

```
Review complete.
- Audit: <PASS | FAIL — see .claude/audit-<UTC>.md>
- Code-review: <N findings | CLEAN>

Next: /commit-push-pr to ship, or fix and re-run /code:review.
```

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Review done' --subtitle 'See chat for findings' || true")
```

## Notes

- Use this in parallel with the cloud `/ultrareview` (built-in research preview). `/code:review` is the local gate; `/ultrareview` is the multi-agent cloud pass. Both are safe to run; they catch different things.
- If `--no-audit` is passed and no fresh `.claude/audit-*.md` exists, the diff review is still useful but lacks the static-gate context.
