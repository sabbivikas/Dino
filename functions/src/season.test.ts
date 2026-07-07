import { test } from "node:test";
import * as assert from "node:assert";
import { seasonForMonth, isSeasonEligible, isSlotActive } from "./season";

test("month to season mapping, all 12 months", () => {
  assert.strictEqual(seasonForMonth(12), "winter");
  assert.strictEqual(seasonForMonth(1), "winter");
  assert.strictEqual(seasonForMonth(2), "winter");
  assert.strictEqual(seasonForMonth(3), "spring");
  assert.strictEqual(seasonForMonth(4), "spring");
  assert.strictEqual(seasonForMonth(5), "spring");
  assert.strictEqual(seasonForMonth(6), "summer");
  assert.strictEqual(seasonForMonth(7), "summer");
  assert.strictEqual(seasonForMonth(8), "summer");
  assert.strictEqual(seasonForMonth(9), "autumn");
  assert.strictEqual(seasonForMonth(10), "autumn");
  assert.strictEqual(seasonForMonth(11), "autumn");
});

test("any is always eligible", () => {
  for (const s of ["spring", "summer", "autumn", "winter"] as const) {
    assert.ok(isSeasonEligible("any", s));
  }
});

test("out-of-season items are excluded, in-season kept", () => {
  // no christmas-cozy films in july
  assert.strictEqual(isSeasonEligible("winter", "summer"), false);
  assert.strictEqual(isSeasonEligible("summer", "winter"), false);
  assert.strictEqual(isSeasonEligible("winter", "winter"), true);
  assert.strictEqual(isSeasonEligible("autumn", "autumn"), true);
});

test("rotating seasonal slots activate by month", () => {
  const winterFilms = [11, 12, 1, 2];
  const summerPlaylists = [6, 7, 8];
  const autumnReads = [9, 10, 11];
  // november: winter films AND autumn reads both ride along
  assert.ok(isSlotActive(winterFilms, 11));
  assert.ok(isSlotActive(autumnReads, 11));
  assert.strictEqual(isSlotActive(summerPlaylists, 11), false);
  // july: only summer playlists
  assert.ok(isSlotActive(summerPlaylists, 7));
  assert.strictEqual(isSlotActive(winterFilms, 7), false);
  assert.strictEqual(isSlotActive(autumnReads, 7), false);
  // april: nothing seasonal (no spring slot by design)
  for (const months of [winterFilms, summerPlaylists, autumnReads]) {
    assert.strictEqual(isSlotActive(months, 4), false);
  }
});
