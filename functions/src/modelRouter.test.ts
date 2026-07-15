// node --test coverage for the router's hard rules — the rules live in
// code, so the tests are the contract.
import { test } from "node:test";
import assert from "node:assert";
import { route, assertRoute } from "./modelRouter";

test("watching routes to luna on openai", () => {
  const r = route("watching");
  assert.equal(r.provider, "openai");
  assert.equal(r.model, "gpt-5.6-luna");
});

test("mission routes to muse spark on meta", () => {
  const r = route("mission");
  assert.equal(r.provider, "meta");
  assert.equal(r.model, "muse-spark-1.1");
});

test("comfort recs stay gpt-4.1-mini", () => {
  assert.equal(route("comfortRecs").model, "gpt-4.1-mini");
});

test("hard rule: mission on luna throws", () => {
  assert.throws(() => assertRoute("mission",
    { provider: "openai", model: "gpt-5.6-luna", maxTokens: 1, temperature: 0 }));
});

test("hard rule: watching on meta throws", () => {
  assert.throws(() => assertRoute("watching",
    { provider: "meta", model: "muse-spark-1.1", maxTokens: 1, temperature: 0 }));
});

test("hard rule: comfort recs off 4.1 mini throws", () => {
  assert.throws(() => assertRoute("comfortRecs",
    { provider: "openai", model: "gpt-5.6-luna", maxTokens: 1, temperature: 0 }));
});
