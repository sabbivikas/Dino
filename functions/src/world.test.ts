import { test } from "node:test";
import * as assert from "node:assert";
import {
  normalizeCountry, foldPulseCountry, WORLD_PRIVACY_FLOOR,
  utcDayKey, sanitizeAggregateDayKeys, retainNewestDays, groupWorldMoodDocs,
} from "./world";

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

// ── UTC-Gregorian day semantics (the calendar-corruption fix) ──

const ts = (iso: string) => ({ toDate: () => new Date(iso) });

test("corrupted client dayKey is ignored — server createdAt decides the bucket", () => {
  const grouped = groupWorldMoodDocs([
    // Thai-device shape: Buddhist-year dayKey, real 2026 createdAt
    { mood: "clear", countryCode: "TH", dayKey: "2569-07-21", createdAt: ts("2026-07-21T10:00:00Z") },
    { mood: "drained", countryCode: "US", dayKey: "2569-07-21", createdAt: ts("2026-07-21T15:00:00Z") },
    // docs without a usable createdAt are skipped
    { mood: "clear", countryCode: "US", dayKey: "2026-07-21", createdAt: null },
    { mood: "clear", countryCode: "US", dayKey: "2026-07-21" },
    { mood: "clear", countryCode: "US", dayKey: "2026-07-21", createdAt: "not-a-timestamp" },
    // invalid mood skipped, invalid country folds to elsewhere
    { mood: "ecstatic", countryCode: "US", createdAt: ts("2026-07-21T10:00:00Z") },
    { mood: "clear", countryCode: "USA", createdAt: ts("2026-07-21T10:00:00Z") },
  ]);
  assert.deepStrictEqual(Object.keys(grouped), ["2026-07-21"]);
  assert.strictEqual(grouped["2026-07-21"]["TH"]["clear"], 1);
  assert.strictEqual(grouped["2026-07-21"]["US"]["drained"], 1);
  assert.strictEqual(grouped["2026-07-21"]["elsewhere"]["clear"], 1);
});

test("day boundary: 23:59 and 00:01 UTC land in different buckets", () => {
  assert.strictEqual(utcDayKey(new Date("2026-07-21T23:59:59Z")), "2026-07-21");
  assert.strictEqual(utcDayKey(new Date("2026-07-22T00:01:00Z")), "2026-07-22");
  const grouped = groupWorldMoodDocs([
    { mood: "clear", countryCode: "US", createdAt: ts("2026-07-21T23:59:00Z") },
    { mood: "clear", countryCode: "US", createdAt: ts("2026-07-22T00:01:00Z") },
  ]);
  assert.deepStrictEqual(Object.keys(grouped).sort(), ["2026-07-21", "2026-07-22"]);
  assert.strictEqual(grouped["2026-07-21"]["US"]["clear"], 1);
  assert.strictEqual(grouped["2026-07-22"]["US"]["clear"], 1);
});

test("sanitize drops out-of-range years from an existing days map, keeps [y-1, y+1]", () => {
  const now = Date.UTC(2026, 6, 22);   // 2026-07-22
  const days = {
    "2569-07-20": 1, "2569-07-21": 2,     // the stuck production corruption
    "2026-07-22": 3, "2025-12-31": 4, "2027-01-01": 5,   // in-range, kept
    "2024-12-31": 6, "2028-01-01": 7,     // out of range
    "garbage": 8, "07-22": 9,             // malformed
  };
  assert.deepStrictEqual(sanitizeAggregateDayKeys(days, now), {
    "2026-07-22": 3, "2025-12-31": 4, "2027-01-01": 5,
  });
});

test("retention keeps the newest-7 VALID keys after the year-sanity filter", () => {
  const now = Date.UTC(2026, 6, 22);
  const days: Record<string, number> = { "2569-07-20": -1, "2569-07-21": -1 };
  for (let d = 13; d <= 22; d++) days[`2026-07-${d}`] = d;   // 10 valid days
  const trimmed = retainNewestDays(sanitizeAggregateDayKeys(days, now), 7);
  assert.deepStrictEqual(Object.keys(trimmed).sort(), [
    "2026-07-16", "2026-07-17", "2026-07-18", "2026-07-19",
    "2026-07-20", "2026-07-21", "2026-07-22",
  ]);
  // without the filter, the "2569" keys would have evicted real days forever
  assert.ok(!("2569-07-21" in trimmed));
});
