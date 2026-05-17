import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import { loadConfig } from "../config";
import { connect } from "./index";

const config = loadConfig();
const db = connect(config.DATABASE_URL);
migrate(db, { migrationsFolder: "./src/db/migrations" });
console.info(`migrations applied against ${config.DATABASE_URL}`);
