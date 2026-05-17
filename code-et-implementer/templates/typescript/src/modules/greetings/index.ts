import { desc } from "drizzle-orm";
import type { DB } from "../../db";
import { greetings } from "../../db/schema";

export interface Greetings {
  record(message: string): Promise<{ id: number; message: string; createdAt: Date }>;
  recent(limit?: number): Promise<ReadonlyArray<{ id: number; message: string; createdAt: Date }>>;
}

export interface Clock {
  now(): Date;
}

export function makeGreetings(deps: { db: DB; clock: Clock }): Greetings {
  const { db, clock } = deps;
  return {
    async record(message) {
      const trimmed = message.trim();
      if (trimmed.length === 0) {
        throw new Error("greeting must not be empty");
      }
      const [row] = await db
        .insert(greetings)
        .values({ message: trimmed, createdAt: clock.now() })
        .returning();
      if (!row) throw new Error("insert did not return a row");
      return row;
    },
    async recent(limit = 10) {
      return db.query.greetings.findMany({
        orderBy: [desc(greetings.createdAt)],
        limit,
      });
    },
  };
}
