import { Hono } from "hono";
import { z } from "zod";
import type { Greetings } from "../../modules/greetings";

const recordBody = z.object({ message: z.string().min(1).max(280) });

export function greetingsRoutes(greetings: Greetings) {
  const app = new Hono();

  app.post("/", async (c) => {
    const parsed = recordBody.safeParse(await c.req.json().catch(() => null));
    if (!parsed.success) {
      return c.json({ error: "invalid body", details: parsed.error.flatten() }, 400);
    }
    const recorded = await greetings.record(parsed.data.message);
    return c.json(recorded, 201);
  });

  app.get("/", async (c) => {
    const limit = Number(c.req.query("limit") ?? 10);
    return c.json(await greetings.recent(limit));
  });

  return app;
}
