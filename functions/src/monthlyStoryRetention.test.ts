import { test } from "node:test";
import assert from "node:assert";
import { completeMonthlyStoryStorageCleanup, createMonthlyStoryRetentionMetadata,
  createMonthlyStoryStorageCleanupMetadata, monthlyStoryDeletionIsEligible,
  monthlyStoryExpiresAtMillis, monthlyStoryTombstoneExpiresAtMillis,
  requestMonthlyStoryDeletion } from "./monthlyStoryRetention";

test("story retention expires twelve months after month end", () => {
  assert.equal(new Date(monthlyStoryExpiresAtMillis("2026-07")).toISOString(), "2027-08-01T00:00:00.000Z");
  assert.equal(new Date(monthlyStoryExpiresAtMillis("2028-02")).toISOString(), "2029-03-01T00:00:00.000Z");
});

test("retention is timezone independent after finalization", () => {
  const expected = monthlyStoryExpiresAtMillis("2026-11");
  for (const instant of ["2026-12-01T00:00:00Z", "2026-11-30T18:00:00-06:00",
    "2026-12-01T09:00:00+09:00"]) {
    assert.equal(Number.isFinite(Date.parse(instant)), true);
    assert.equal(monthlyStoryExpiresAtMillis("2026-11"), expected);
  }
});

test("deletion request makes a story eligible before retention expiry", () => {
  const finalized = Date.parse("2026-08-03T09:00:00Z");
  const requested = Date.parse("2026-09-01T00:00:00Z");
  const original = createMonthlyStoryRetentionMetadata("2026-07", finalized);
  assert.equal(monthlyStoryDeletionIsEligible(original, requested), false);
  const updated = requestMonthlyStoryDeletion(original, requested);
  assert.equal(monthlyStoryDeletionIsEligible(updated, requested), true);
});

test("deleted tombstones retain for fifteen months after month end", () => {
  assert.equal(new Date(monthlyStoryTombstoneExpiresAtMillis("2026-07")).toISOString(),
    "2027-11-01T00:00:00.000Z");
});

test("storage cleanup markers support pending and complete states", () => {
  const pending = createMonthlyStoryStorageCleanupMetadata(true, 200, 100);
  assert.equal(pending.state, "pending");
  assert.equal(completeMonthlyStoryStorageCleanup(pending, 150).state, "complete");
  assert.equal(createMonthlyStoryStorageCleanupMetadata(false, 200, 100).state, "notRequired");
});
