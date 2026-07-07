import { test } from "node:test";
import * as assert from "node:assert";
import { normalizeCountry, foldPulseCountry, WORLD_PRIVACY_FLOOR } from "./world";

test("country normalization", () => {
  assert.strictEqual(normalizeCountry("us"), "US");
  assert.strictEqual(normalizeCountry("JP"), "JP");
  assert.strictEqual(normalizeCountry("USA"), "elsewhere");
  assert.strictEqual(normalizeCountry(""), "elsewhere");
  assert.strictEqual(normalizeCountry(undefined), "elsewhere");
  assert.strictEqual(normalizeCountry("1A"), "elsewhere");
});

test("pulse folding respects the aggregate's privacy floor", () => {
  // visible in the aggregate → the pulse may name it
  assert.strictEqual(foldPulseCountry("US", true), "US");
  // below the floor (not in the aggregate) → folded, never singled out
  assert.strictEqual(foldPulseCountry("JP", false), "elsewhere");
  // elsewhere stays elsewhere regardless
  assert.strictEqual(foldPulseCountry("elsewhere", true), "elsewhere");
  assert.strictEqual(foldPulseCountry("elsewhere", false), "elsewhere");
});

test("floor is 3 per the approved tuning", () => {
  assert.strictEqual(WORLD_PRIVACY_FLOOR, 3);
});
