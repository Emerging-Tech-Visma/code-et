---
tools: Read, Bash, Glob
description: "Copy code-et's CI audit workflow into an existing TypeScript / Bun repo."
argument-hint: "[--force]"
effort: medium
---

# Install CI — Drop the audit workflow into an existing repo

Adds `.github/workflows/code-et-audit.yml` and an `audit` script entry (if `package.json` is missing one). Idempotent — re-running overwrites only with `--force`.

The audit runs `biome check`, `tsc --noEmit`, `bun audit`, `bun test`. See [`docs/anti-slop.md`](../docs/anti-slop.md) §"4-stage verification loop".

## Procedure

1. **Pre-flight.**

   ```
   Bash('test -f package.json && echo OK || echo "Not a TS/Node project (no package.json)"')
   ```

   If not a TS project, stop with: *"This is for TypeScript / Bun projects. For a Rust project, install code-et v4.x."*

2. **Detect existing workflow.**

   ```
   Bash('test -f .github/workflows/code-et-audit.yml && echo EXISTS || echo MISSING')
   ```

   If `EXISTS` and not `--force`, stop with: *"`.github/workflows/code-et-audit.yml` already present. Re-run with `--force` to overwrite."*

3. **Copy workflow.**

   ```
   Bash('mkdir -p .github/workflows && cp "${CLAUDE_PLUGIN_ROOT}/templates/shared/.github/workflows/code-et-audit.yml" .github/workflows/')
   ```

4. **Add an `audit` npm script** if `package.json` doesn't have one. Read `package.json`, add to `scripts`:

   ```json
   "audit": "biome check . && tsc --noEmit && bun audit --audit-level=high && bun test"
   ```

   Skip if the project already defines `audit` differently — print a note instead.

5. **Recommend doctrine adoption.** Print:

   ```
   The audit assumes deep-modules architecture (no fixed layers).
   See ${CLAUDE_PLUGIN_ROOT}/docs/architecture.md for the vocabulary.
   ```

6. **Recommend dev-dep installs** if missing:

   ```
   bun add -d @biomejs/biome typescript
   ```

## Output

`"Installed CI audit gate. Push the changes; the next PR will run the audit job."`
