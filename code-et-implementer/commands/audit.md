---
tools: Bash, Read
description: Run the v3.9.0 CI audit gate locally — fmt, clippy, layer-deps, machete, audit, deny, tests.
argument-hint: "[target-dir]"
effort: medium
---

Run the same seven-stage audit pipeline as the v3.9.0 CI gate against the working tree (or a specified target dir). The CI workflow yaml is the single source of truth — stages are parsed from it at runtime, not hardcoded, so local and CI cannot drift.

## Inputs

`$ARGUMENTS` (optional):
- **target-dir** — path to a Rust workspace. Defaults to the current working directory. If neither the target dir nor its enclosing git root has a `Cargo.toml`, the command exits 0 with `not a Rust workspace, skipping`.

## Procedure

```
Bash('bash "${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh" ${ARGUMENTS:-$PWD}')
```

The runner:

1. Locates the Rust workspace (target dir, falling back to `git rev-parse --show-toplevel`).
2. Parses `templates/shared/.github/workflows/code-et-audit.yml` for the seven gate stages and their commands. `uses:` actions map to local cargo subcommands (`bnjbvr/cargo-machete` → `cargo machete`, `rustsec/audit-check` → `cargo audit`, `EmbarkStudios/cargo-deny-action` → `cargo deny check`).
3. Runs each stage in order. If a stage's binary is not on PATH (e.g. `cargo-machete` not installed), prints a one-line skip notice on stderr and continues — T7 will refine this into a formal LOW-severity finding.
4. Writes `<workspace>/.claude/audit-<YYYYMMDD-HHMMSS>.md` (UTC) with findings grouped by severity (CRITICAL > HIGH > MEDIUM > LOW), each carrying a `path:line` citation.
5. Exits non-zero if any stage fails.

## Output

The runner streams stage progress and the final report path on stderr. On failure, the report file lists the offending stage and the closest `path:line` extracted from its log.

## Notes

- The runner is layer `chore` — code-et plugin tooling, not a Rust workspace.
- Flags `--fast`, `--stage <n>`, and `--review` are reserved for follow-up tasks (T3, T6) — not implemented in this slice.
- No org-specific tokens — the runner reads the target from CWD or the git root only.
