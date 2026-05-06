---
tools: Read, Bash, Glob
description: "Copy code-et's CI audit workflow + layer-deps validator into an existing Rust repo."
argument-hint: "[--force]"
effort: high
---

Install code-et's CI audit gate (`.github/workflows/code-et-audit.yml` + `scripts/layer-deps-validator.sh`) into the current Rust project. Idempotent — re-running overwrites only with `--force`.

## Procedure

1. **Pre-flight.**
   ```
   Bash('test -f Cargo.toml && echo OK || echo "Not a Rust project (no Cargo.toml)"')
   ```
   If not Rust, stop.

2. **Detect existing CI.**
   ```
   Bash('test -f .github/workflows/code-et-audit.yml && echo EXISTS || echo MISSING')
   ```
   If `EXISTS` and not `--force`, stop with: *"`.github/workflows/code-et-audit.yml` already present. Re-run with `--force` to overwrite."*

3. **Copy workflow + validator.**
   ```
   Bash('mkdir -p .github/workflows scripts && cp "${CLAUDE_PLUGIN_ROOT}/templates/shared/.github/workflows/code-et-audit.yml" .github/workflows/ && cp "${CLAUDE_PLUGIN_ROOT}/templates/shared/scripts/layer-deps-validator.sh" scripts/ && chmod +x scripts/layer-deps-validator.sh')
   ```

4. **Recommend doctrine adoption.** Print a one-line note pointing the user at `code-et-implementer/docs/architecture.md` if their project doesn't yet have a 4-crate workspace. The validator is a no-op on projects without `crates/<layer>/` dirs — exits 0 with `"layer-deps-validator: clean"`.

5. **Recommend tool installs.** Print:
   ```
   cargo install --locked cargo-machete cargo-audit cargo-deny cargo-nextest
   ```

## Output

`"Installed CI audit gate. Push the changes; the next PR will run the audit job."`
