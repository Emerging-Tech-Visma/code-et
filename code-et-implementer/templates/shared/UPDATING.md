# Template Updating Checklist

How to keep `templates/typescript/` and `templates/shared/` aligned with the upstream TS ecosystem.

## When to update

- A pinned dependency has a new minor (Hono 4.6 → 4.7, Drizzle 0.36 → 0.37).
- Bun has a new minor with a behaviour change relevant to the template.
- Biome has a new major (config schema changes).
- A pinned GitHub Action has a new major (`actions/checkout@v4` → `@v5`).
- A security advisory affects a templated dependency.

Cadence: review every quarter even if nothing has shipped.

## Update procedure

1. **Branch.** `feature/templates-refresh-YYYY-MM`.
2. **Bump versions** in `templates/typescript/package.json`:
   - `hono`, `drizzle-orm`, `zod` (runtime)
   - `@biomejs/biome`, `drizzle-kit`, `typescript`, `@types/bun` (dev)
3. **Bump GitHub Actions** in `templates/shared/.github/workflows/code-et-audit.yml`. Pin to majors (`@v4`); avoid floating `@latest`.
4. **Smoke-test.** Scaffold a fresh project from the updated template into `/tmp/upgrade-smoke`:
   ```
   bun install
   bun run db:generate
   bun run audit
   ```
   All four audit stages (biome, tsc, bun audit, bun test) must pass.
5. **CI smoke.** Push to a temp repo or run `act` against the workflow.
6. **Bump plugin patch version** (e.g. `5.0.x → 5.0.x+1`), update `CHANGELOG.md`.

## Pinning policy

- **Dependencies:** pin to minor with caret (`^4.6.0`). Patches flow through `bun update`.
- **Actions:** pin to major (`@v4`). Major bumps require manual smoke + a CHANGELOG note.
- **Bun:** `oven-sh/setup-bun@v2` with `bun-version: latest` — Bun's API is stable enough at minor cadence.

## Risk register

| Risk | Mitigation |
|---|---|
| Drizzle ORM breaking changes between minors | The smoke project's `greetings` schema is the canary; if migration generation fails, hold the bump. |
| Hono API drift | Two HTTP routes (`POST /greetings`, `GET /greetings`) exercise routing + Zod parsing + DI; if `app.fetch` test breaks, fix before merging. |
| Biome rule churn | Pin to a specific minor; review the changelog before bumping. |
| GHA action removal | Pin majors; check the action's repo for archived/deprecated status before bumping. |
