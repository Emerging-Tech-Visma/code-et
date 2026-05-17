# {{name}}

TypeScript project scaffolded by **code-et v5**. Stack: **Bun + Hono + Drizzle**. Architecture: deep modules — see the plugin's `code-et-implementer/docs/architecture.md` (loaded via `Skill` when working in this repo).

## Quick start

```bash
cp .env.example .env
bun install
bun run db:migrate
bun run dev          # Hono server on :3000
bun test             # bun test runner
bun run audit        # local mirror of CI: biome + tsc + bun audit + bun test
```

## Project shape

```
src/
  modules/         One folder per deep module. Interface in index.ts.
  db/              Drizzle schema + migrations.
  http/
    app.ts         Hono app — wires modules to routes.
    routes/        One file per resource.
  config.ts        Zod-validated env loading.
  main.ts          Composition root.
```

Modules grow around interfaces, not framework-imposed folders. The deletion test (would removing this make complexity vanish, or reappear across callers?) decides whether something earns its place.

## Workflow

| Task | Command |
|---|---|
| Single bug fix | `/code:fix` → implement → `/commit-push-pr` |
| Feature | `/code:plan` → `/code:ship` → `/code:review` → `/commit-push-pr` |
