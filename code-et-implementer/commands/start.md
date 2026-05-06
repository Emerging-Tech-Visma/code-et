---
tools: Read, Bash, Glob, AskUserQuestion
description: "Scaffold a new pure-Rust Clean Architecture project (axum + sqlx + Dioxus 0.7+ + tokio). Always-latest deps."
argument-hint: "<project-name> [--targets web,desktop,mobile,server] [--db sqlite|postgres] [--install-tools]"
effort: xhigh
---

Scaffold a fresh pure-Rust full-stack project from `${CLAUDE_PLUGIN_ROOT}/templates/rust/dioxus-fullstack/`.

**The whole stack is fixed:** `axum + sqlx + Dioxus 0.7+ + tokio`, four-crate Clean Architecture workspace (`domain`, `application`, `infrastructure`, `interface`), apps under `apps/` (`server`, `web`, `desktop`, `mobile`). The CI gate (`.github/workflows/code-et-audit.yml` + `scripts/layer-deps-validator.sh`) is copied in. Always-latest semver-compatible deps via post-scaffold `cargo update`.

**Refuses to run** if CWD has `Cargo.toml` or `package.json` unless `--force` is passed. **Never** scaffolds inside this plugin's repo.

## Inputs

Parse `$ARGUMENTS`:
- **project name** (positional, required) — `^[a-z][a-z0-9-]{1,40}$`
- `--targets <list>` — comma-separated subset of `web,desktop,mobile,server`. Default: all four. `server` always stays — it is the SSR + API root.
- `--db sqlite|postgres` — default `sqlite`.
- `--install-tools` — also `cargo install` the audit toolchain. Default: print checklist.
- `--force` — overlay onto a non-empty CWD.
- `--owner <gh-user>` — used to substitute `{{owner}}` in `Cargo.toml`'s `repository` field. Default: `git config user.name` slugified, else `your-org`.

If a required input is missing, ask via `AskUserQuestion` (one focused question per missing field, max two questions total).

## Procedure

1. **Pre-flight.**
   ```
   Bash('test -f Cargo.toml || test -f package.json && echo CONFLICT || true')
   ```
   On `CONFLICT` without `--force`, stop with: *"This directory already has a Rust or TS project. Re-run with `--force` to overlay."* Refuse if `pwd` contains `code-et-implementer` (don't scaffold inside the plugin repo).

2. **Copy template + shared assets.**
   ```
   Bash('TPL="${CLAUDE_PLUGIN_ROOT}/templates/rust/dioxus-fullstack" && SHARED="${CLAUDE_PLUGIN_ROOT}/templates/shared" && mkdir -p "<name>" && cp -R "$TPL"/. "<name>/" && cp -R "$SHARED/.github" "<name>/.github" && mkdir -p "<name>/scripts" && cp "$SHARED/scripts/layer-deps-validator.sh" "<name>/scripts/" && cp "$SHARED/CLAUDE.md.template" "<name>/CLAUDE.md"')
   ```

3. **Filter targets.** Remove unselected app dirs and their workspace member lines. Keep `apps/server` always.
   ```
   Bash('cd "<name>" && for t in web desktop mobile; do
     case ",<targets>," in *",$t,"*) ;; *) rm -rf "apps/$t"; sed -i.bak "/\\\"apps\\/$t\\\"/d" Cargo.toml && rm Cargo.toml.bak;; esac
   done')
   ```

4. **Substitute placeholders** (`{{name}}`, `{{owner}}`, `{{db}}`) across `Cargo.toml`, `apps/**/Cargo.toml`, `crates/**/Cargo.toml`, `Dioxus.toml`, `CLAUDE.md`, `README.md`, `justfile`, `.env.example`, `scripts/deploy.sh`, `scripts/upload.sh`. Use `find -print0 | xargs -0 sed -i.bak …` and clean `.bak`.

5. **Switch DB.** If `--db postgres`, edit `.env.example` to uncomment the postgres line, comment out the sqlite default. The template's `infrastructure` supports both at runtime.

6. **chmod the scripts.** `chmod +x "<name>/scripts/"*.sh` — covers `layer-deps-validator.sh`, `deploy.sh`, `upload.sh`.

7. **Latest deps.** Pull every workspace dep to its latest semver-compatible patch. Non-fatal — a transient yank or registry hiccup should not abort the bootstrap; `cargo check` (next step) is the actual gate:
   ```
   Bash('cd "<name>" && cargo update 2>&1 | tail -20 || echo "cargo update warned — see output above; bootstrap continues"')
   ```
   Caret pins (`dioxus = "0.7"`, `axum = "0.8"`, `sqlx = "0.8"`, `tokio = "1"`, etc.) deliver latest minor/patch automatically. **Major bumps** (e.g., dioxus 0.7→0.8) need a manual `cargo upgrade` (cargo-edit) and a smoke test — flag this on first `just audit` failure rather than gambling here.

8. **Compile-check.**
   ```
   Bash('cd "<name>" && cargo check --workspace 2>&1 | tail -40 || echo "cargo check failed — see output above"')
   ```
   Template's `infrastructure` uses runtime-checked queries, so check passes without a DB. If check fails, the template is broken — surface and stop.

9. **Install tools.** If `--install-tools`:
   ```
   Bash('cargo install --locked cargo-machete cargo-audit cargo-deny cargo-nextest sqlx-cli dioxus-cli')
   ```
   Otherwise print checklist:
   ```
   cargo install --locked cargo-machete cargo-audit cargo-deny cargo-nextest sqlx-cli dioxus-cli
   ```

10. **Print next steps.**
    ```
    ✓ Bootstrapped <name> at $(pwd)/<name>

    Next:
      cd <name>
      cp .env.example .env
      just db-migrate
      just run-server      # axum + dioxus-fullstack SSR on :3000
      just audit           # local mirror of CI

    Publish:
      gh repo create <name> --public --source=. --remote=origin --push
      # CI runs on first push; clean run = ready for /code:plan or /code:fix
    ```

## Output

`"Bootstrapped <name> with targets <list>, db <db>. cd <name> && just audit to verify."`

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Project ready' --subtitle '<name>' || true")
```

## Notes

- **Never** auto-run `git init` if the user's CWD is already a git repo (sub-project layouts are valid). Run `git init` only when the new project's parent dir has no `.git`.
- **Never** install tools without `--install-tools`. Print the checklist and wait.
- The CI workflow lives at `.github/workflows/code-et-audit.yml` after step 2 — no separate copy.
- Apply rules from `code-et-implementer/CLAUDE.md` and `code-et-implementer/docs/architecture.md`. Dioxus 0.7+ for one-codebase web/desktop/mobile. `sqlx::query!` macros for compile-time-checked SQL. Forward-only migrations.
