---
tools: Read, Bash, Glob, AskUserQuestion
description: "Scaffold a Bun + Hono + Drizzle TypeScript project shaped around deep modules."
argument-hint: "<project-name> [--force]"
effort: high
---

# Start — Scaffold a new TypeScript project

Copies `${CLAUDE_PLUGIN_ROOT}/templates/typescript/` into a new directory, fills `{{name}}`, installs deps, generates an initial Drizzle migration, and runs `bun run audit` to verify a green start.

Stack: **Bun + Hono + Drizzle + Biome**. Database: **SQLite** for local + dev (Bun's built-in). Architecture: deep modules — see [`docs/architecture.md`](../docs/architecture.md). No fixed layer taxonomy; modules grow around interfaces.

**Postgres + a web frontend are manual add-ons,** not flags. The template ships the simplest viable stack; users layer on dependencies as needed:

- **Postgres in production** (sketch, untested in v5 template — exercise before relying on it):
  1. `bun add pg && bun add -d @types/pg`
  2. In `src/db/index.ts`, swap `drizzle-orm/bun-sqlite` for `drizzle-orm/node-postgres`; build a `Pool` from `DATABASE_URL` instead of opening a SQLite file.
  3. In `drizzle.config.ts`, change `dialect: "sqlite"` → `dialect: "postgresql"`.
  4. Regenerate migrations: `bun run db:generate`. The Drizzle schema in `src/db/schema.ts` ports unchanged for simple column types; review dialect-specific types (e.g. SQLite's `integer({ mode: "timestamp" })`) before assuming portability.
- **Web frontend.** Add Vite + React (or Solid, Svelte, etc.) as a subdirectory; wire its dev server proxy through Hono.

Both are common, and both are short. Putting them behind flags hides decisions the user should make explicitly.

## Inputs

Parse `$ARGUMENTS`:

- **project name** — positional, required. `^[a-z][a-z0-9-]{1,40}$`.
- `--force` — overlay onto a non-empty CWD.

If the project name is missing, one focused `AskUserQuestion` to collect it.

## Procedure

1. **Pre-flight.** Refuse if CWD already has `package.json` without `--force`. Refuse if `pwd` contains `code-et-implementer` — never scaffold inside the plugin repo.

   ```
   Bash('test -f package.json && echo CONFLICT || true')
   ```

2. **Copy template.**

   ```
   Bash('TPL="${CLAUDE_PLUGIN_ROOT}/templates/typescript" && SHARED="${CLAUDE_PLUGIN_ROOT}/templates/shared" && mkdir -p "<name>" && cp -R "$TPL"/. "<name>/" && cp -R "$SHARED/.github" "<name>/.github" && cp "$SHARED/CLAUDE.md.template" "<name>/CLAUDE.md"')
   ```

3. **Substitute placeholders** (`{{name}}` only) across `package.json`, `README.md`, `CLAUDE.md`, `.env.example`. Use `find -print0 | xargs -0 sed -i.bak …` and clean `.bak`.

4. **Install deps.**

   ```
   Bash('cd "<name>" && bun install 2>&1 | tail -10')
   ```

5. **Generate initial Drizzle migration.** The template ships a `greetings` example schema; this generates `src/db/migrations/0000_*.sql` so the bundled tests run.

   ```
   Bash('cd "<name>" && bun run db:generate 2>&1 | tail -5')
   ```

6. **Run the audit gate.**

   ```
   Bash('cd "<name>" && bun run audit 2>&1 | tail -20')
   ```

   Exit non-zero → template is broken; surface and stop.

7. **Init git** if the parent dir has no `.git`:

   ```
   Bash('cd "<name>" && [ -d ../.git ] || (git init -q && git add . && git commit -q -m "chore: scaffold <name> with code-et v5")')
   ```

8. **Print next steps.**

   ```
   ✓ Scaffolded <name> at $(pwd)/<name>

   Next:
     cd <name>
     cp .env.example .env
     bun run db:migrate
     bun run dev            # Hono server with hot-reload on :3000
     bun run audit          # local mirror of CI

   Add Postgres:
     bun add pg && bun add -d @types/pg
     # then swap drizzle-orm/bun-sqlite → drizzle-orm/node-postgres in src/db/index.ts

   Publish:
     gh repo create <name> --public --source=. --remote=origin --push
   ```

## Output

`"Scaffolded <name>. cd <name> && bun run audit to verify."`

## Notes

- The CI workflow lives at `.github/workflows/code-et-audit.yml` after step 2 — no separate install.
- Major version bumps to Bun/Hono/Drizzle ride on `package.json` caret ranges; `bun update` is a manual smoke step, not part of `/code:start`.
- Apply the rules in [`docs/architecture.md`](../docs/architecture.md), [`docs/anti-slop.md`](../docs/anti-slop.md), [`docs/testing.md`](../docs/testing.md).
