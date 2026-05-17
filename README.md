# code-et

Lightweight TypeScript workflow for Claude Code, built on **deep modules**. **One stack, six commands, no slop.**

Stack: `Bun + Hono + Drizzle + Biome`. Database: SQLite out of the box (Bun's built-in). Postgres and a web frontend (Vite + React, Solid, etc.) are deliberately manual add-ons rather than flags — they're short additions, and putting them behind flags would hide decisions the user should make explicitly. Architecture vocabulary — *module / interface / seam / adapter / depth / leverage / locality* — is standard software-engineering terminology drawn from Ousterhout's *A Philosophy of Software Design* (deep modules) and Feathers' *Working Effectively with Legacy Code* (seams).

> **v5.0.0** is a deliberate rewrite. v4.x was Rust + Clean Architecture; v5 is TypeScript + deep modules. The command surface (`/code:start … /code:review`) is unchanged.

## The six commands

| Command | What it does |
|---|---|
| `/code:start <name>` | Scaffold a Bun + Hono + Drizzle project. Deep-modules shape: `src/modules/<name>/index.ts` is the interface. SQLite by default — Postgres and a web frontend are manual add-ons, deliberately not flags. |
| `/code:install-ci` | Drop the audit GitHub workflow into an existing TS repo. |
| `/code:fix "<bug>"` | Single-bug intake → Task Brief (with per-file `Module`). You implement directly. |
| `/code:plan "<idea>"` | One extended turn: refined brief → PRD on disk → vertical-slice tasks. Three checkpoints — interrupt at any. |
| `/code:ship` | Execute pending tasks in parallel worktree-isolated agents → audit → 1 auto-retry on CRITICAL/HIGH. |
| `/code:review` | Pre-merge gate: local audit + diff review. Delegates to engineering plugin's `code-review` skill if installed. |

That's it. `/commit-push-pr` (from the `commit-commands` plugin) ships the PR.

## Workflow

```
NEW PROJECT (one-time)
  /code:start myapp
     ↓
  cd myapp && cp .env.example .env && bun run db:migrate && bun run dev

DAILY

  Bug?       /code:fix "..."  →  user implements 1–3 files  →  /commit-push-pr
  Feature?   /code:plan "..."  →  /code:ship  →  /code:review  →  /commit-push-pr
                                       ↓
                                 audit auto-runs
                                       ↓
                              ✓ green → ready to push
                              ✗ red   → 1 retry → if still red, surface findings
```

Two lanes. No mid-points. `/code:fix` does **not** chain into `/code:plan` or `/code:ship` — bugs that span vertical slices are features in disguise; write a PRD.

## Architecture — deep modules

There is **no fixed layer taxonomy**. Modules grow around interfaces. The deletion test — *would removing this module make complexity vanish, or reappear across N callers?* — decides whether something earns its place.

```
src/
  modules/
    <module-name>/
      index.ts          The interface. Public exports + types only.
      <impl>.ts         The implementation.
      <name>.test.ts    Tests cross the same seam callers do.
  db/                   Drizzle schema + migrations.
  http/
    app.ts              Hono app — wires modules to routes.
    routes/<r>.ts       One file per resource.
  config.ts             Zod-validated env loading.
  main.ts               Composition root — the only place adapters are wired in.
```

Doctrine lives in [`code-et-implementer/docs/`](code-et-implementer/docs/):

- [`architecture.md`](code-et-implementer/docs/architecture.md) — deep modules, dependency categories, seam discipline.
- [`anti-slop.md`](code-et-implementer/docs/anti-slop.md) — 4 elements, 5 categories, 8 hard rules.
- [`testing.md`](code-et-implementer/docs/testing.md) — interface-as-test-surface, deep-module test patterns, mirror-test ban.

## Lint + audit gate

**Biome is the lint stack** — one binary covers lint + format + import-sort. No ESLint, no Prettier, no separate import sorter. The bundled `biome.json` enables Biome's `recommended` set plus targeted rules against shallow-extraction slop (`useConst`, `useTemplate`, `noImplicitAnyLet`, `noUnusedFunctionParameters`, `noUselessLoneBlockStatements`, `noUselessTypeConstraint`).

Local commands:

- `bun run lint` — `biome check .` (read-only; exits non-zero on findings)
- `bun run lint:fix` — `biome check --write .` (safe auto-fixes in place)
- `bun run typecheck` — `tsc --noEmit`
- `bun run audit` — runs all four stages below in series

`.github/workflows/code-et-audit.yml` runs on every PR + push to main:

1. **lint (biome)** — `biome check .`
2. **typecheck (tsc)** — `tsc --noEmit`
3. **dependency audit (bun audit)** — `bun audit --audit-level=high` (high + critical block; dev-only moderate advisories don't)
4. **test (bun test)** — `bun test`

`/code:ship` runs the same pipeline with a 1-pass auto-fix retry on CRITICAL/HIGH findings. **A green audit is the merge gate** — no manual override.

> **GitHub Actions:** uses `actions/checkout`, `oven-sh/setup-bun`, `actions/cache`. All public; GitHub fetches them automatically. `secrets.GITHUB_TOKEN` is auto-provided.

## Install

```
# Required — replace <owner> with the org/repo hosting your code-et fork
/plugin marketplace add <owner>/code-et
/plugin install code@code-et

# Recommended companions
/plugin install engineering@knowledge-work-plugins   # code-review, tech-debt, testing-strategy, system-design
/plugin install commit-commands@claude-plugins-official
/plugin install claude-md-management@claude-plugins-official
```

### Local development

```bash
claude --plugin-dir /path/to/code-et/code-et-implementer
```

Type `/code:` to confirm all six commands appear.

## Prerequisites

- **Claude Code** — `npm install -g @anthropic-ai/claude-code`
- **Bun** — `curl -fsSL https://bun.sh/install | bash` (Bun 1.1+)
- **GitHub CLI (`gh`)** — for PRs ([install](https://cli.github.com/))

The audit gate uses Bun's built-ins for everything (test, audit, package install). Biome and TypeScript ship as dev-dependencies in the scaffolded `package.json`.

## Always-latest dependencies

The template's `package.json` pins to caret (`^4.6.0`) so patches and compatible minors flow through `bun install`. Major bumps need a manual `bun update` plus a `bun run audit` smoke. The CI gate's `bun audit` step catches yanked or vulnerable pins on every PR.

## Settings

```json
{
  "env": {
    "CLAUDE_CODE_TASK_LIST_ID": "<your-project-tasks>"
  }
}
```

`CLAUDE_CODE_TASK_LIST_ID` lets `/code:ship` resume interrupted work across sessions via `.claude/<id>.json`.

## Companion plugin map

| Plugin | What it gives you |
|---|---|
| `engineering` (knowledge-work-plugins) | `code-review`, `tech-debt`, `testing-strategy`, `system-design` skills — delegated to from code-et's CLAUDE.md |
| `commit-commands` (official) | `/commit`, `/commit-push-pr`, `/clean_gone` |
| `code-review` (official) | Multi-agent PR review |
| `claude-md-management` (official) | `/revise-claude-md`, `/claude-md-improver` |

## How it stays simple

1. **One stack.** Bun + Hono + Drizzle. No flags for "TS or Rust", no legacy branches.
2. **Six commands.** Most days you use three (`/code:fix`, `/code:plan`, `/code:ship`).
3. **One philosophy.** Deep modules with shared vocabulary. The deletion test is the decision rule.
4. **Doctrine, not docs.** Three short markdown files (`architecture`, `anti-slop`, `testing`) loaded on demand.
5. **CI is the gate.** Local hooks give fast feedback; a green CI is the merge requirement.
6. **Vertical slices, not layers as tasks.** Each task touches every seam it needs to touch — `/code:plan` rejects horizontal tasks at decomposition time.

## Migrating from v4.x (Rust)

v5 is a different stack. The command surface is preserved, but projects scaffolded with v4 (`/code:start` → 4-crate Rust workspace) are not migrated automatically. Options:

- **Keep using v4 for existing Rust projects.** Pin to `5.0.0`-prior in your marketplace; v4's commands continue to work.
- **Start a fresh TS project with v5.** Run `/code:start <name>` in a new directory.

v4's final state is commit `c5bad00` on `main`. Pin or branch from there if you need to keep iterating on the Rust workflow.

## Influences

The architecture vocabulary (module, interface, seam, adapter, depth, leverage, locality) is standard software-engineering terminology — **deep modules** are from Ousterhout's *A Philosophy of Software Design*; **seams** are from Feathers' *Working Effectively with Legacy Code*; the **deletion test** is a common refactoring heuristic. The vertical-slice + TDD shape of `/code:plan` and `/code:ship` follows Kent Beck's "tracer bullet" / TDD practice.

## License

MIT. See [LICENSE](LICENSE).
