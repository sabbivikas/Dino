import { test } from "node:test";
import assert from "node:assert";
import { MONTHLY_STORY_ACCOUNT_DELETION_INVENTORY, deleteMonthlyStoryAccountResources } from "./monthlyStoryDeletion";

test("deletion inventory explicitly covers every future monthly-story surface", () => {
  assert.deepEqual(MONTHLY_STORY_ACCOUNT_DELETION_INVENTORY.documentTrees, [
    "monthlyStoryInternalTesters/{uid}", "monthlyStorySettings/{uid}", "monthlyStorySignals/{uid}",
    "monthlyStories/{uid}", "monthlyStoryDeleted/{uid}",
  ]);
  assert.ok(MONTHLY_STORY_ACCOUNT_DELETION_INVENTORY.serverQueries.some((item) => item.includes("monthlyStoryJobs")));
  assert.ok(MONTHLY_STORY_ACCOUNT_DELETION_INVENTORY.serverQueries.some((item) => item.includes("reservations")));
  assert.ok(MONTHLY_STORY_ACCOUNT_DELETION_INVENTORY.serverQueries.some((item) =>
    item.includes("deterministicJobs")));
  assert.deepEqual(MONTHLY_STORY_ACCOUNT_DELETION_INVENTORY.storagePrefixes, ["monthlyStories/{uid}/"]);
  assert.ok(MONTHLY_STORY_ACCOUNT_DELETION_INVENTORY.localCaches.some((item) => item.includes("MonthlyStories")));
  assert.equal(MONTHLY_STORY_ACCOUNT_DELETION_INVENTORY.integrationStatus,
    "not-integrated-with-current-account-deletion");
});

test("future deletion hook enumerates jobs, reservations, trees, and storage", async () => {
  const calls: string[] = [];
  const jobs = [`ms_${"a".repeat(64)}`, `ms_${"b".repeat(64)}`];
  await deleteMonthlyStoryAccountResources("synthetic-user-a", "owner-v1", {
    deleteDocumentTree: async (path) => { calls.push(`tree:${path}`); },
    findJobIdsByOwnerKey: async (ownerKey) => {
      assert.match(ownerKey, /^[a-f0-9]{64}$/);
      assert.equal(ownerKey.includes("synthetic-user-a"), false);
      return jobs;
    },
    deleteSpendReservationsForJob: async (jobId) => { calls.push(`reservation:${jobId}`); },
    deleteDeterministicUsageForJob: async (jobId) => { calls.push(`usage:${jobId}`); },
    deleteJob: async (jobId) => { calls.push(`job:${jobId}`); },
    deleteStoragePrefix: async (prefix) => { calls.push(`storage:${prefix}`); },
  });
  for (const expected of ["tree:monthlyStoryInternalTesters/synthetic-user-a",
    "tree:monthlyStorySettings/synthetic-user-a",
    "tree:monthlyStorySignals/synthetic-user-a", "tree:monthlyStories/synthetic-user-a",
    "tree:monthlyStoryDeleted/synthetic-user-a", "storage:monthlyStories/synthetic-user-a/",
    ...jobs.flatMap((job) => [`reservation:${job}`, `usage:${job}`, `job:${job}`])]) {
    assert.ok(calls.includes(expected));
  }
});

test("future deletion hook stops before tombstone removal when earlier cleanup fails", async () => {
  const calls: string[] = [];
  await assert.rejects(deleteMonthlyStoryAccountResources("synthetic-user-a", "owner-v1", {
    deleteDocumentTree: async (path) => {
      calls.push(path);
      if (path.includes("monthlyStorySignals")) throw new Error("synthetic-failure");
    },
    findJobIdsByOwnerKey: async () => [],
    deleteSpendReservationsForJob: async () => undefined,
    deleteDeterministicUsageForJob: async () => undefined,
    deleteJob: async () => undefined,
    deleteStoragePrefix: async () => undefined,
  }), /synthetic-failure/);
  assert.equal(calls.includes("monthlyStoryDeleted/synthetic-user-a"), false);
});
