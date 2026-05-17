import { describe, expect, it } from "bun:test";
import type { Greetings } from "../../modules/greetings";
import { buildHttp } from "../app";

function stubGreetings(overrides: Partial<Greetings> = {}): Greetings {
  return {
    record: async (message) => ({ id: 1, message, createdAt: new Date("2026-05-17T00:00:00Z") }),
    recent: async () => [],
    ...overrides,
  };
}

describe("POST /greetings", () => {
  it("returns 201 with the recorded greeting", async () => {
    const app = buildHttp({ greetings: stubGreetings() });
    const res = await app.fetch(
      new Request("http://test/greetings", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ message: "hi" }),
      }),
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as { message: string };
    expect(body.message).toBe("hi");
  });

  it("rejects an empty message with 400", async () => {
    const app = buildHttp({ greetings: stubGreetings() });
    const res = await app.fetch(
      new Request("http://test/greetings", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ message: "" }),
      }),
    );
    expect(res.status).toBe(400);
  });
});
