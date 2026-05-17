import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "./schema";

export type DB = ReturnType<typeof connect>;

export function connect(url: string) {
  const file = url.startsWith("file:") ? url.slice("file:".length) : url;
  const sqlite = new Database(file);
  sqlite.exec("PRAGMA journal_mode = WAL;");
  return drizzle(sqlite, { schema });
}
