---
name: testing
description: Testing doctrine for code-et v5 — interface-as-test-surface, deep-module test patterns, mirror-test ban, vertical-slice integration tests with Bun test.
applies_to: typescript
---

# Testing — through the interface (code-et v5)

**The interface is the test surface.** Callers and tests cross the same seam. If you want to test *past* the interface, the module is the wrong shape — fix the shape, not the test.

The pyramid is steep: many fast tests through deep-module interfaces, a thin layer of HTTP-seam integration tests, very few full-stack e2e tests. Mirror tests are banned.

For the general pyramid + what-to-cover guidance, see the engineering plugin's `testing-strategy` skill. This document is the *TypeScript-specific* delta.

## Test matrix

| Test type | Where | What to assert | What NOT to assert |
|---|---|---|---|
| **Module-interface** | `src/modules/<m>/<m>.test.ts` | Behaviour through the module's exported interface. Inputs at the interface → observable outputs at the interface. | Internal call shapes; private functions; how many times a dependency was called. |
| **HTTP-seam** | `src/http/routes/<r>.test.ts` | Round-trip: HTTP request → router → module → DB stand-in → response. Status codes, response shapes, auth gates. | Module internal logic (covered above); database SQL syntax. |
| **E2E (sparse)** | `tests/e2e/*.test.ts` | Critical happy paths end-to-end with the real server bound to an ephemeral port. | Edge cases the lower tiers already cover. |

Run all of it with `bun test`. The runner picks up `*.test.ts` everywhere; co-locate tests next to the module they test.

## Module-interface tests — the workhorse

A deep module exports an interface. Tests build the module with stand-in dependencies, then exercise it through the same interface a real caller uses.

```ts
// src/modules/orders/orders.test.ts
import { describe, it, expect } from "bun:test";
import { makeOrders } from "./impl";
import { inMemoryDb, fixedClock } from "../../test/stand-ins";

describe("orders", () => {
  it("places an order and returns its id", async () => {
    const orders = makeOrders({ db: inMemoryDb(), clock: fixedClock("2026-01-01") });

    const id = await orders.place({
      customerId: "c-1",
      lines: [{ sku: "A", qty: 2, unitPrice: 500 }],
    });

    const found = await orders.byId(id);
    expect(found?.total).toEqual({ currency: "USD", amount: 1000 });
    expect(found?.status).toBe("pending");
  });
});
```

Notes:

- **No mocking the implementation under test.** `makeOrders` is called with real stand-ins for its dependencies; the orders module itself is whole.
- **Stand-ins live in `src/test/stand-ins.ts`** (or per-module if specific). `inMemoryDb()` is a Drizzle SQLite `:memory:` instance running the real schema and migrations — same query layer as production.
- **Assert observable outputs.** `place` returns an id; `byId` returns the order. Don't assert that `db.insert` was called.

## HTTP-seam tests — via Hono's `app.fetch`

Hono's `app` is a `fetch`-compatible function. Build the app with stand-in modules, then call it directly — no server required.

```ts
// src/http/routes/orders.test.ts
import { describe, it, expect } from "bun:test";
import { buildHttp } from "../app";
import { stubOrders } from "../../test/stand-ins";

describe("POST /orders", () => {
  it("returns 201 with the new order id", async () => {
    const app = buildHttp({ orders: stubOrders({ placeReturns: "ord-1" }) });

    const res = await app.fetch(
      new Request("http://x/orders", {
        method: "POST",
        headers: { "content-type": "application/json", authorization: "Bearer test" },
        body: JSON.stringify({ customerId: "c-1", lines: [] }),
      }),
    );

    expect(res.status).toBe(201);
    expect(await res.json()).toEqual({ id: "ord-1" });
  });

  it("rejects an unauthenticated request with 401", async () => {
    const app = buildHttp({ orders: stubOrders() });
    const res = await app.fetch(new Request("http://x/orders", { method: "POST", body: "{}" }));
    expect(res.status).toBe(401);
  });
});
```

These tests cover the things only the seam knows: parsing, auth, error mapping. They don't re-cover what the module-interface tests already proved.

## E2E — keep it sparse

```ts
// tests/e2e/orders-flow.test.ts
import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { start } from "../../src/main";

let server: { url: string; stop: () => Promise<void> };
beforeAll(async () => { server = await start({ port: 0, database: ":memory:" }); });
afterAll(async () => { await server.stop(); });

it("a customer places and retrieves an order", async () => {
  const place = await fetch(`${server.url}/orders`, { method: "POST", /* ... */ });
  expect(place.status).toBe(201);
  const { id } = await place.json();
  const get = await fetch(`${server.url}/orders/${id}`);
  expect(get.status).toBe(200);
});
```

Two or three of these per major user flow. Not one per acceptance criterion — the lower tiers do that work.

## Contract tests at seams with multiple adapters

When a module declares a port and has more than one adapter (e.g. an in-memory adapter for tests and an HTTP adapter for production), write a **contract test** that runs against every adapter:

```ts
// src/modules/payments/contract.test.ts
import { describe } from "bun:test";
import { paymentsContract } from "./contract";
import { makeInMemoryPayments } from "./adapters/in-memory";
import { makeStripePayments } from "./adapters/stripe";

describe("in-memory payments adapter", () => paymentsContract(() => makeInMemoryPayments()));

if (process.env.STRIPE_TEST_KEY) {
  describe("stripe payments adapter", () => paymentsContract(() => makeStripePayments(env.STRIPE_TEST_KEY)));
}
```

The `paymentsContract` function (in `src/modules/payments/contract.ts`) is a `describe`-builder that takes a factory and asserts the port's behavioural contract — nothing implementation-specific. If both adapters pass, you can swap them in production.

## Mirror-test ban

A mirror test's pass condition mirrors the implementation rather than the caller's contract. They pass for any code that compiles and break only when the implementation is rewritten — making the test useless during refactors.

| ✗ Mirror | ✓ Behavioural |
|---|---|
| `expect(add(2, 3)).toBe(2 + 3);` | `expect(add(2, 3)).toBe(5);` |
| `expect(repo.save).toHaveBeenCalledWith(user);` | `expect(await useCase.execute(user)).toEqual(user);` |
| `expect(err.toString()).toBe("DomainError: NotFound");` | `expect(err).toBeInstanceOf(NotFoundError);` |
| `expect(JSON.stringify(result)).toMatchSnapshot();` *(on internal data)* | `expect(result.status).toBe("ok"); expect(result.total).toBe(42);` |

If a test is hard to write without referencing implementation detail, the implementation is wrong (too coupled, too leaky) — fix the code, not the test.

## Stand-ins, not mocks

A **stand-in** is a real implementation of a small interface; a **mock** is a recorded set of return values. Prefer stand-ins.

- `inMemoryDb()` — a Drizzle SQLite `:memory:` running the real schema. The same `db.query.orders.findFirst(...)` calls execute against it. Tests assert through the module's interface; the stand-in is invisible.
- `fixedClock(iso)` — `{ now: () => Date }` returning a fixed time.
- `stubOrders({ placeReturns: "ord-1" })` — a hand-written tiny impl of the `Orders` interface for HTTP-seam tests where the module under test is the route, not orders.

When you genuinely cannot stand in (true-external dependency: Stripe, Twilio), inject a mock. Restrict mocks to the **outermost** seam; never mock a module from inside its own tests.

## The runner: `bun test`

`bun test` is the default. It auto-discovers `*.test.ts`, runs in parallel processes, supports `describe`/`it`/`expect`, and is fast enough that watch-mode (`bun test --watch`) is the inner-loop tool.

In CI: `bun test --coverage` if a coverage gate matters; the audit workflow keeps it simple and runs `bun test`.

## Security test cases

Every HTTP seam gets at least these:

| Boundary | Test |
|---|---|
| Mutating routes | Unauth → 401; authed-wrong-actor → 403; malformed body → 400 with no leaked internal detail. |
| Read routes | Same auth checks. Sensitive fields (password hashes, secret tokens) never in response JSON. |
| Query parameters | Zod-parsed; oversized inputs rejected with 400, not OOM. |
| File uploads (if any) | A path-traversal filename (`../../etc/passwd`) is rejected. |

## See also

- [`architecture.md`](architecture.md) — the seam vocabulary; dependency categories drive test strategy.
- [`anti-slop.md`](anti-slop.md) — Rule of Three, mirror-test ban (cross-referenced here).
- Engineering plugin's `testing-strategy` skill — pyramid + what-to-cover for the bigger picture.
