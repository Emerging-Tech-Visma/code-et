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

   If `package.json` is missing, stop with: *"`code-et` v5 targets TypeScript / Bun projects. Run `/code:start` to scaffold a fresh one, or add a `package.json` first if you intend to retrofit."*

2. **Detect existing workflow.**

   ```
   Bash('test -f .github/workflows/code-et-audit.yml && echo EXISTS || echo MISSING')
   ```

   If `EXISTS` and not `--force`, stop with: *"`.github/workflows/code-et-audit.yml` already present. Re-run with `--force` to overwrite."*

3. **Copy workflow.**

   ```
   Bash('mkdir -p .github/workflows && cp "${CLAUDE_PLUGIN_ROOT}/templates/shared/.github/workflows/code-et-audit.yml" .github/workflows/')
   ```

4. **Add `lint`, `lint:fix`, `typecheck`, and `audit` scripts** to `package.json` if any are missing. The four scripts are independent enough that users want to run them in isolation while debugging; `audit` chains all four for the merge gate.

   ```json
   "lint": "biome check .",
   "lint:fix": "biome check --write .",
   "typecheck": "tsc --noEmit",
   "audit": "biome check . && tsc --noEmit && bun audit --audit-level=high && bun test"
   ```

   If a project already defines any of these differently, leave that entry alone and print a note. Do not overwrite — the user may have wired their own tooling.

5. **Recommend doctrine adoption.** Print:

   ```
   The audit assumes deep-modules architecture (no fixed layers).
   See ${CLAUDE_PLUGIN_ROOT}/docs/architecture.md for the vocabulary.
   ```

6. **Recommend dev-dep installs** if missing. **Biome is the lint stack** — one binary covers lint + format + import-sort.

   ```
   bun add -d @biomejs/biome typescript
   ```

   If the project currently uses ESLint or Prettier, mention that Biome replaces both and ask before removing them.

## Output

`"Installed CI audit gate. Push the changes; the next PR will run the audit job."`
