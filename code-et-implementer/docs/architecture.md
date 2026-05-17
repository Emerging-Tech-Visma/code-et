---
name: architecture
description: Deep-modules TypeScript architecture for code-et. Loaded on demand by /code:start, /code:fix, /code:plan, /code:ship.
applies_to: typescript
---

# Architecture — Deep Modules (code-et v5)

code-et builds **deep modules** on a TypeScript stack: `Bun + Hono + Drizzle + Vite + React`. There is no fixed layer taxonomy. Modules grow organically around interfaces; the goal is **leverage at the interface** and **locality** for the maintainer.

> The vocabulary in this document — *module / interface / seam / adapter / depth / leverage / locality* — is established software-engineering terminology. **Deep modules** trace to Ousterhout's *A Philosophy of Software Design*; **seams** to Feathers' *Working Effectively with Legacy Code*. The terms are used here exactly as those sources define them so plan, ship, and review share a stable language.

## Stack — what every code-et project ships

| Concern | Choice | Why |
|---|---|---|
| Runtime | **Bun** | Single binary; built-in test runner, package manager, bundler. Fast cold-starts, native TypeScript. |
| HTTP server | **Hono** | Tiny, type-safe router. Runs on Bun, Node, Workers, Deno. |
| DB access | **Drizzle ORM** | Type-safe queries; SQL-first. SQLite for local + dev, Postgres for prod. |
| Migrations | **drizzle-kit** | Schema → migration. Forward-only. |
| Web UI (optional) | **Vite + React 19** | Dev-server speed; same TS types shared with the server module. |
| Validation | **Zod** | Single source of truth at the interface seam (HTTP, queue, file). |
| Tests | **Bun test** | In-runtime. Same `expect`/`describe`/`it` shape as Vitest/Jest. |
| Lint + format | **Biome** | One binary; replaces ESLint+Prettier. |

Desktop and mobile are **out of scope**. If you need them, fork the template; code-et does not maintain a multi-target frontend story.

## Vocabulary — use these terms exactly

- **Module** — anything with an interface and an implementation. Scale-agnostic: a function, a file, a folder, a workspace package.
- **Interface** — everything a caller must know to use the module correctly: types, invariants, error modes, ordering, config. *Not* just the type signature.
- **Implementation** — the body of code inside.
- **Depth** — leverage at the interface. A module is **deep** when a lot of behaviour sits behind a small interface. **Shallow** = interface nearly as complex as the implementation.
- **Seam** — where an interface lives; a place where behaviour can be altered without editing in place. (Term from Feathers, *Working Effectively with Legacy Code*.)
- **Adapter** — a concrete thing that satisfies an interface at a seam.
- **Leverage** — what callers get from depth. **Locality** — what maintainers get from depth.

Do **not** drift into "component", "service", "API", or "boundary". Consistent language is the whole point.

## Three load-bearing principles

1. **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, the module earned its keep. Use this when deciding whether to extract.
2. **The interface is the test surface.** Tests cross the same seam callers do. If you find yourself wanting to test *past* the interface, the module is the wrong shape — fix the shape, not the test.
3. **One adapter means a hypothetical seam. Two adapters means a real seam.** Don't introduce a port unless something actually varies across it (typically production + a test stand-in).

## Project shape — start flat, deepen as you go

A fresh code-et project starts as one workspace, one package:

```
src/
  modules/                     One folder per deep module. No fixed taxonomy.
    <module-name>/
      index.ts                 The interface. Public exports + types only.
      <impl>.ts                The implementation. Can be many files.
      <module-name>.test.ts    Tests cross the same seam callers do.
  db/                          Drizzle schema + migrations.
    schema.ts
    migrations/
  http/
    app.ts                     Hono app. Wires modules to routes.
    routes/<route>.ts          One file per resource. Calls module interfaces.
  config.ts                    Typed env loading (Zod). Read once at boot.
  main.ts                      Composition root. Imports concrete adapters,
                               wires them into modules + routes, starts server.
web/                           Optional Vite + React frontend (drop if API-only).
  src/...
docs/
  adr/                         Architecture Decision Records. Lazy-created.
CONTEXT.md                     Domain glossary. Lazy-created.
```

`src/main.ts` is the **composition root** — the only place that instantiates concrete adapters (DB pool, HTTP clients) and injects them into module factories. No module reaches into another module's implementation; all communication is via interfaces exported from `<module>/index.ts`.

## Dependency categories — how to deepen each kind of module

The category a module's dependencies fall into determines how it's tested across its seam.

| Category | Examples | How to deepen / test |
|---|---|---|
| **In-process** | Pure computation, in-memory state. | Always deepenable. Merge shallow helpers; test through the new interface directly. No adapter needed. |
| **Local-substitutable** | DB (SQLite/Postgres), filesystem. | Deepenable when a local stand-in exists. For DB: run the same Drizzle schema against in-process SQLite for tests. Seam is *internal*; no port at the module's external interface. |
| **Remote-but-owned** | Your other services across a network. | Define a **port** at the seam. Implement an HTTP/queue adapter for production, an in-memory adapter for tests. The logic sits in one deep module even though it's deployed across a network. |
| **True external** | Stripe, Twilio, third-party APIs. | Module takes the external dependency as an injected port. Tests provide a mock adapter. |

**One adapter = hypothetical seam. Two adapters = real seam.** Don't introduce a port for a single-adapter case — it's just indirection.

## Crossing seams — DTOs only

Data crossing a module's interface is a plain object (or a Zod-parsed type), never a Drizzle row, ORM entity, or framework type. The HTTP route parses the request with Zod, calls the module interface, serialises the result back out.

```ts
// src/modules/orders/index.ts — the interface
import type { OrderId, Money } from "./types";
export type { OrderId, Money };

export interface Orders {
  place(input: PlaceOrderInput): Promise<OrderId>;
  byId(id: OrderId): Promise<Order | null>;
}
export type PlaceOrderInput = { customerId: string; lines: OrderLine[] };
export type Order = { id: OrderId; total: Money; status: OrderStatus };

// src/modules/orders/impl.ts — the implementation (internal)
export function makeOrders(deps: { db: Database; clock: Clock }): Orders {
  // ... single deep module. Tests in orders.test.ts go through `Orders`.
}

// src/http/routes/orders.ts — adapter at the HTTP seam
const placeOrderBody = z.object({ customerId: z.string().uuid(), lines: z.array(orderLine) });
app.post("/orders", async c => {
  const body = placeOrderBody.parse(await c.req.json());
  const id = await orders.place(body);
  return c.json({ id }, 201);
});

// src/main.ts — composition root
const db = drizzle(new Database(env.DATABASE_URL));
const orders = makeOrders({ db, clock: systemClock });
const app = buildHttp({ orders });
```

## Database

### Local + small projects: SQLite

```ts
import { drizzle } from "drizzle-orm/bun-sqlite";
import { Database } from "bun:sqlite";
const db = drizzle(new Database(env.DATABASE_URL));     // file:./dev.db or :memory:
```

In-memory (`:memory:`) for tests. The same schema and queries run against Postgres in prod — Drizzle abstracts the dialect.

### Production: Postgres

```ts
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
const pool = new Pool({ connectionString: env.DATABASE_URL });
const db = drizzle(pool);
```

- **Migrations.** `drizzle-kit generate` from `db/schema.ts` → `db/migrations/`. Forward-only. Each rollback is its own forward migration. Apply at boot in `main.ts` via `migrate(db, { migrationsFolder })`.
- **Pool sizing.** Default `max` ≈ `min(num_cpus × 2, 25)` for managed Postgres tiers. Tune from `pg_stat_activity`.

### Repo placement

Only the module that owns persistence for a concept imports Drizzle. Other modules see the interface (a TypeScript type), not the schema. Tests use an in-memory SQLite Drizzle, exercising the real query layer.

## Secrets

- **Production.** Read from env at boot in `src/config.ts`. Validate with Zod; missing/invalid env crashes at start, not at first request.
- **Local.** `.env` loaded by Bun automatically (`bun --env-file=.env` or `Bun.env`). `.env` is gitignored. `.env.example` ships with placeholder names and no values.
- **CI.** GitHub Actions encrypted secrets. Tests run with `DATABASE_URL=":memory:"`; production secrets stay in deployment workflows.
- **Never.** Secrets in source, `package.json`, or logs. Wrap sensitive strings in a `Secret<T>` newtype with a `toString()` that redacts.

## Security checklist

Run through this list at PR time. CI catches the deterministic items; reviewers (or the engineering plugin's `code-review` skill) catch the rest.

| # | Check | How |
|---|---|---|
| 1 | All HTTP input parsed with Zod | Grep for `await c.req.json()` not paired with `.parse(`. |
| 2 | All DB writes go through Drizzle (no raw SQL string-concatenation) | Grep for `db.execute(` with template-literal interpolation. |
| 3 | Secrets validated at boot, not on the hot path | One Zod schema in `config.ts`. |
| 4 | No `eval`, no `new Function(...)` on untrusted input | Grep + review. |
| 5 | Dependency advisories clean | `bun audit` (CI). |
| 6 | Locked dependencies | `bun.lock` committed; CI does `bun install --frozen-lockfile`. |
| 7 | Auth at every mutating HTTP route | Hono middleware (`requireAuth`) asserted in route review. |
| 8 | Input validation lives at the HTTP seam | Modules trust their callers within the process boundary. |

## When to add layers

The flat `src/modules/<name>/` shape is the default. When a module's interface grows past ~5–7 exports, or when an obvious sub-bounded-context emerges, split the module — same shape, recursively. Resist the urge to introduce framework-style folders (`controllers/`, `services/`, `repositories/`); they pre-commit to seams that may not exist.

The **deletion test** is the decision rule: would removing this folder make complexity vanish (delete it) or reappear across callers (it earns its keep)?

## See also

- [`anti-slop.md`](anti-slop.md) — 4 elements, 5 categories, hard rules.
- [`testing.md`](testing.md) — testing through the interface; deep-module test patterns.
- Ousterhout, *A Philosophy of Software Design* — the source for **deep modules** and the leverage-vs-shallow framing.
- Feathers, *Working Effectively with Legacy Code* — the source for **seams** as a design primitive.
- Engineering plugin's `system-design` skill — for ADR / trade-off framing when a major decision is on the table.
