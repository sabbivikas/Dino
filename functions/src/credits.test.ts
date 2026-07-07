import { test } from "node:test";
import * as assert from "node:assert";
import { capSources, shouldRun, monthKey, creditSummary, REC_MAX_SOURCES_PER_RUN } from "./credits";

test("per-run cap: over-cap lists scrape only the first 25", () => {
  const big = Array.from({ length: 31 }, (_, i) => i);
  const { kept, dropped } = capSources(big);
  assert.strictEqual(kept.length, REC_MAX_SOURCES_PER_RUN);
  assert.strictEqual(dropped, 6);
  assert.deepStrictEqual(kept, big.slice(0, 25));
});

test("per-run cap: at-or-under-cap lists pass through untouched", () => {
  const small = Array.from({ length: 22 }, (_, i) => i);
  assert.deepStrictEqual(capSources(small), { kept: small, dropped: 0 });
  const exact = Array.from({ length: 25 }, (_, i) => i);
  assert.strictEqual(capSources(exact).dropped, 0);
});

test("frequency guard: first run ever is allowed", () => {
  assert.strictEqual(shouldRun(null, Date.parse("2026-07-07T06:00:00Z")), true);
});

test("frequency guard: blocks runs under 5 days apart, manual included", () => {
  const lastRun = Date.parse("2026-07-07T06:00:00Z");
  const manualNextDay = Date.parse("2026-07-08T09:00:00Z");     // accidental manual trigger
  const fourPointNine = lastRun + 4.9 * 24 * 3600 * 1000;
  assert.strictEqual(shouldRun(lastRun, manualNextDay), false);
  assert.strictEqual(shouldRun(lastRun, fourPointNine), false);
  assert.strictEqual(shouldRun(lastRun, lastRun + 1000), false); // retry storm
});

test("frequency guard: allows at exactly 5 days and beyond", () => {
  const lastRun = Date.parse("2026-07-07T06:00:00Z");
  assert.strictEqual(shouldRun(lastRun, lastRun + 5 * 24 * 3600 * 1000), true);
  assert.strictEqual(shouldRun(lastRun, lastRun + 7 * 24 * 3600 * 1000), true);
});

test("month key + credit summary", () => {
  assert.strictEqual(monthKey(new Date(Date.parse("2026-07-07T23:59:00Z"))), "2026-07");
  assert.strictEqual(monthKey(new Date(Date.parse("2026-12-01T00:00:00Z"))), "2026-12");
  assert.strictEqual(creditSummary(20, 43),
    "rec pool: scraped 20 sources, ~20 credits, this month total ~43");
});
