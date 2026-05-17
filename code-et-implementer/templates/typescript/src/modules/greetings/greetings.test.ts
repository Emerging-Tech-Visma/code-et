import { Database } from "bun:sqlite";
import { afterEach, beforeEach, describe, expect, it } from "bun:test";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import * as schema from "../../db/schema";
import { type Clock, makeGreetings } from "./index";

function fixedClock(iso: string): Clock {
  return { now: () => new Date(iso) };
}

describe("greetings module", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle<typeof schema>>;

  beforeEach(() => {
    sqlite = new Database(":memory:");
    db = drizzle(sqlite, { schema });
    migrate(db, { migrationsFolder: "./src/db/migrations" });
  });

  afterEach(() => sqlite.close());

  it("records a greeting and returns it from recent()", async () => {
    const greetings = makeGreetings({ db, clock: fixedClock("2026-05-17T00:00:00Z") });

    const recorded = await greetings.record("hello, deep modules");
    expect(recorded.message).toBe("hello, deep modules");

    const recent = await greetings.recent();
    expect(recent).toHaveLength(1);
    expect(recent[0]?.id).toBe(recorded.id);
  });

  it("rejects an empty greeting", async () => {
    const greetings = makeGreetings({ db, clock: fixedClock("2026-05-17T00:00:00Z") });
    await expect(greetings.record("   ")).rejects.toThrow(/empty/);
  });
});
