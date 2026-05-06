---
tools: Read, Bash, Glob, Skill, AskUserQuestion
description: "Scaffold a pure-Rust Clean Architecture project (axum + sqlx + dioxus + tokio)."
argument-hint: "[project-name] [--targets web,desktop,mobile] [--db sqlite|postgres] [--install-tools] [--force]"
effort: xhigh
---

Scaffold a new pure-Rust full-stack project from `${CLAUDE_PLUGIN_ROOT}/templates/rust/dioxus-fullstack/` with the CI gate, validator, and Clean Architecture skeleton.

**Refuses to run** if CWD has `Cargo.toml` or `package.json` (avoids overwriting existing projects), unless `--force` is passed.

## Inputs

Parse `$ARGUMENTS`:
- **project name** (positional, required) — kebab-case, must match `^[a-z][a-z0-9-]{1,40}$`. Becomes the workspace root dir name.
- `--targets web,desktop,mobile` — comma-separated subset; default = all three. Mobile is best-effort.
- `--db sqlite|postgres` — default `sqlite`. (Postgres only switches `.env.example`; the template supports both at runtime.)
- `--install-tools` — also run `cargo install` for the audit toolchain. Default: print checklist only.
- `--force` — proceed even if CWD has a `Cargo.toml`/`package.json`.
- `--owner GH_USER_OR_ORG` — GitHub owner used to substitute `{{owner}}` in `Cargo.toml`'s `repository` field. Defaults to `git config user.name` munged to kebab-case if available, else `your-org`.

If any required input is missing, ask via `AskUserQuestion` (one focused question per missing field, max two questions total).

## Procedure

1. **Pre-flight.**
   ```
   Bash("test -f Cargo.toml || test -f package.json && echo CONFLICT || true")
   ```
   If `CONFLICT` and not `--force`, stop with: *"This directory already has a Rust or TS project. Re-run with `--force` if you intend to overlay."*

2. **Resolve template root.**
   ```
   Bash('TPL="${CLAUDE_PLUGIN_ROOT}/templates/rust/dioxus-fullstack" && SHARED="${CLAUDE_PLUGIN_ROOT}/templates/shared" && echo "$TPL $SHARED"')
   ```

3. **Copy template + shared assets** into a new directory `<project-name>/`.
   ```
   Bash('mkdir -p "<name>" && cp -R "$TPL"/. "<name>/" && cp -R "$SHARED/.github" "<name>/.github" && mkdir -p "<name>/scripts" && cp "$SHARED/scripts/layer-deps-validator.sh" "<name>/scripts/" && cp "$SHARED/CLAUDE.md.template" "<name>/CLAUDE.md"')
   ```

4. **Filter apps by `--targets`.** If a target is not selected, remove its app dir + workspace member entry:
   ```
   Bash('for t in web desktop mobile; do
     case ",<targets>," in *",$t,"*) ;; *) rm -rf "<name>/apps/$t"; sed -i.bak "/\\\"apps\\/$t\\\"/d" "<name>/Cargo.toml" && rm "<name>/Cargo.toml.bak";; esac
   done')
   ```
   The `server` app always stays (it's the SSR + API root).

5. **Substitute placeholders** (`{{name}}`, `{{owner}}`, `{{db}}`) across the copied files. Use `find -print0 | xargs -0 sed -i.bak …` and clean `.bak` afterwards. Files to touch: `Cargo.toml`, `apps/**/Cargo.toml`, `crates/**/Cargo.toml`, `Dioxus.toml`, `CLAUDE.md`, `README.md`, `justfile`, `.env.example`.

6. **Switch DB.** If `--db postgres`, edit `.env.example` to uncomment the postgres line and comment out the sqlite default. (No code change required — the template's `infrastructure` already supports both.)

7. **chmod the validator.**
   ```
   Bash('chmod +x "<name>/scripts/layer-deps-validator.sh"')
   ```

8. **Compile-check.**
   ```
   Bash('cd "<name>" && cargo check --workspace 2>&1 | tail -40 || echo "cargo check failed — see output above"')
   ```
   The template's `infrastructure` uses runtime-checked `sqlx::query_as`, so check passes without a DB. If check fails, surface the error and stop — the template is broken, not the user.

9. **Install tools.** If `--install-tools`, run:
   ```
   Bash('cargo install --locked cargo-machete cargo-audit cargo-deny cargo-nextest sqlx-cli dioxus-cli')
   ```
   Otherwise print the checklist:
   ```
   cargo install --locked cargo-machete cargo-audit cargo-deny cargo-nextest sqlx-cli dioxus-cli
   # optional (requires nightly toolchain):
   rustup toolchain install nightly && cargo install --locked cargo-udeps
   ```

10. **Print next steps.**
    ```
    ✓ Bootstrapped <name> at $(pwd)/<name>
    
    Next:
      cd <name>
      cp .env.example .env
      just db-migrate
      just run-server      # or run-web / run-desktop
      just audit           # local mirror of CI
    
    Then:
      gh repo create <name> --public --source=. --remote=origin --push
      # CI runs on first push; clean run = ready for /code:grill or /code:go
    ```

## Output

Single line summary: `"Bootstrapped <name> with targets <list>, db <db>. Run cd <name> && just audit to verify."`

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Bootstrap complete' --subtitle '<name>' || true")
```

## Notes for the agent

- **Never** scaffold inside this plugin's own repo — refuse if `pwd` contains `code-et-implementer`.
- **Never** auto-run `git init` if the user's CWD is already a git repo (they may want a sub-project layout). Run `git init` only when the new project's parent dir has no `.git`.
- **Never** install tools without `--install-tools`. Surface the checklist and wait.
- The CI workflow already lives at `.github/workflows/code-et-audit.yml` after step 3 — no separate copy needed.
- Apply the rules from `code-et-implementer/CLAUDE.md` §"Clean Architecture (Rust)" — Dioxus 0.7+, sqlx with parameter binding (migrate to `query!` macros once schema stabilises), forward-only migrations.
