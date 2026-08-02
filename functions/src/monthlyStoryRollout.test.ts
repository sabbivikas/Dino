import { test } from "node:test";
import assert from "node:assert";
import { monthlyStoryOwnerKey, monthlyStoryRolloutBucket,
  monthlyStoryRolloutEligible } from "./monthlyStoryRollout";

test("rollout bucket is stable and in the 0 through 9999 range", () => {
  const first = monthlyStoryRolloutBucket("synthetic-user-a", "cohort-v1");
  assert.equal(monthlyStoryRolloutBucket("synthetic-user-a", "cohort-v1"), first);
  assert.ok(first >= 0 && first <= 9_999);
});

test("changing rollout percentage does not reshuffle the bucket", () => {
  const bucket = monthlyStoryRolloutBucket("synthetic-user-a", "cohort-v1");
  assert.equal(monthlyStoryRolloutEligible("synthetic-user-a", "cohort-v1", bucket), false);
  assert.equal(monthlyStoryRolloutEligible("synthetic-user-a", "cohort-v1", bucket + 1), true);
  assert.equal(monthlyStoryRolloutBucket("synthetic-user-a", "cohort-v1"), bucket);
});

test("zero rollout enrolls nobody and invalid rollout fails closed", () => {
  assert.equal(monthlyStoryRolloutEligible("synthetic-user-a", "cohort-v1", 0), false);
  assert.equal(monthlyStoryRolloutEligible("synthetic-user-a", "cohort-v1", -1), false);
  assert.equal(monthlyStoryRolloutEligible("synthetic-user-a", "cohort-v1", 10_001), false);
});

test("salt version intentionally changes cohorts and owner keys are opaque", () => {
  const buckets = new Set(Array.from({ length: 20 }, (_, index) =>
    monthlyStoryRolloutBucket(`synthetic-user-${index}`, "cohort-v1")));
  assert.ok(buckets.size > 1);
  const changed = Array.from({ length: 20 }, (_, index) =>
    monthlyStoryRolloutBucket(`synthetic-user-${index}`, "cohort-v1") !==
      monthlyStoryRolloutBucket(`synthetic-user-${index}`, "cohort-v2"));
  assert.ok(changed.some(Boolean));
  assert.match(monthlyStoryOwnerKey("synthetic-user-a", "owner-v1"), /^[a-f0-9]{64}$/);
});
