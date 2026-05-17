import { Hono } from "hono";
import { logger } from "hono/logger";
import type { Greetings } from "../modules/greetings";
import { greetingsRoutes } from "./routes/greetings";

export interface AppDeps {
  greetings: Greetings;
}

export function buildHttp(deps: AppDeps) {
  const app = new Hono();
  app.use("*", logger());
  app.get("/health", (c) => c.json({ status: "ok" }));
  app.route("/greetings", greetingsRoutes(deps.greetings));
  return app;
}
