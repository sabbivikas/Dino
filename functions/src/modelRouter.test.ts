// node --test coverage for the router's hard rules — the rules live in
// code, so the tests are the contract.
import { test } from "node:test";
import assert from "node:assert";
import { route, routeChain, assertRoute } from "./modelRouter";

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

test("mission chain: muse spark primary, 4.1 mini fallback", () => {
  const c = routeChain("mission");
  assert.equal(c.length, 2);
  assert.deepEqual(c.map((r) => r.model), ["muse-spark-1.1", "gpt-4.1-mini"]);
  assert.deepEqual(c.map((r) => r.provider), ["meta", "openai"]);
});

test("watching chain has NO fallback — silence is correct", () => {
  assert.equal(routeChain("watching").length, 1);
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


test("preferences route to luna, never meta or spark (hard rule)", () => {
  const chain = routeChain("preferences");
  assert.equal(chain.length, 1);
  assert.equal(chain[0].model, "gpt-5.6-luna");
  assert.equal(chain[0].provider, "openai");
  assert.throws(() => assertRoute("preferences", { provider: "meta", model: "muse-spark-1.1", maxTokens: 300, temperature: 0 }));
  assert.throws(() => assertRoute("preferences", { provider: "openai", model: "muse-spark-1.1", maxTokens: 300, temperature: 0 }));
});
