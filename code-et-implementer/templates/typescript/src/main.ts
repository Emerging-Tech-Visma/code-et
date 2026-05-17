import { loadConfig } from "./config";
import { connect } from "./db";
import { buildHttp } from "./http/app";
import { makeGreetings } from "./modules/greetings";

export async function start(overrides?: { port?: number; database?: string }) {
  const config = loadConfig({
    ...process.env,
    ...(overrides?.port ? { PORT: String(overrides.port) } : {}),
    ...(overrides?.database ? { DATABASE_URL: overrides.database } : {}),
  });
  const db = connect(config.DATABASE_URL);
  const app = buildHttp({
    greetings: makeGreetings({ db, clock: { now: () => new Date() } }),
  });
  const server = Bun.serve({ port: config.PORT, fetch: app.fetch });
  return {
    url: `http://${server.hostname}:${server.port}`,
    async stop() {
      server.stop();
    },
  };
}

if (import.meta.main) {
  const { url } = await start();
  console.info(`server listening at ${url}`);
}
