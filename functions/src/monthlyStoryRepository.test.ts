import { test } from "node:test";
import assert from "node:assert";
import { runMonthlyStoryGenerationInternal } from "./monthlyStoryGenerationService";
import { InMemoryMonthlyStoryRepository, MonthlyStoryRepositoryError,
  parseMonthlyStoryPersistedText } from "./monthlyStoryRepository";
import { approvedMonthlyStoryEvaluationFixture } from "./monthlyStorySyntheticEvaluationFixtures";

const uid = "synthetic-repository-user";
const monthKey = "2026-07";
const generationVersion = "deterministic-v1";
const nowMillis = Date.parse("2026-08-04T12:00:00Z");

function readyRepository(): InMemoryMonthlyStoryRepository {
  const repo = new InMemoryMonthlyStoryRepository();
  repo.controlDocument = { visible: true, enrollmentEnabled: true, signalUploadEnabled: true,
    textGenerationEnabled: true, audioGenerationEnabled: false, rolloutBasisPoints: 10_000,
    minimumAppVersion: "1.0.0", dailyTextGenerationCap: 10, monthlyTextGenerationCap: 100,
    dailyAudioGenerationCap: 0,
    monthlyBudgetMicros: 1, monthlyTextBudgetMicros: 1, monthlyAudioBudgetMicros: 0,
    maxTextAttempts: 3, maxAudioAttempts: 0, generationVersion, signalSchemaVersion: 1,
    scriptPromptVersion: "deterministic-v1", criticPromptVersion: "none-v1", ttsVersion: "none-v1",
    updatedAt: nowMillis };
  repo.settings.set(uid, { enabled: true, useJournalThemes: true, useHealthPatterns: true,
    audioEnabled: false, timezone: "UTC", timezoneEffectiveMonth: monthKey, settingsVersion: 1,
    updatedAt: nowMillis });
  repo.signals.set(`${uid}/${monthKey}`,
    approvedMonthlyStoryEvaluationFixture("rich-work-home-projects"));
  return repo;
}

async function generate(repo: InMemoryMonthlyStoryRepository) {
  return runMonthlyStoryGenerationInternal({ uid, monthKey, generationVersion, nowMillis,
    workerId: "repository-worker", repository: repo });
}

test("persisted story parser rejects unknown fields, provider cost, and private owner fields", async () => {
  const result = await generate(readyRepository());
  assert.deepEqual(parseMonthlyStoryPersistedText(result.story), result.story);
  assert.throws(() => parseMonthlyStoryPersistedText({ ...result.story, uid }), /persistence-failure/);
  assert.throws(() => parseMonthlyStoryPersistedText({ ...result.story, providerCostMicros: 1 }),
    /persistence-failure/);
  assert.throws(() => parseMonthlyStoryPersistedText({ ...result.story, rawPrompt: "synthetic" }),
    /persistence-failure/);
});

test("deletion inventory is owner-scoped and includes every persistence surface", async () => {
  const repo = readyRepository();
  const own = await generate(repo);
  const otherUid = "synthetic-other-user";
  const otherJob = { ...repo.jobs.get(own.jobId)!, jobId: `ms_${"b".repeat(64)}`,
    ownerKey: "c".repeat(64) };
  repo.jobs.set(otherJob.jobId, otherJob);
  const inventory = await repo.enumerateAccountDeletion(uid, "monthly-story-owner-v1");
  assert.deepEqual(inventory.documentTrees, [`monthlyStorySettings/${uid}`, `monthlyStorySignals/${uid}`,
    `monthlyStories/${uid}`, `monthlyStoryDeleted/${uid}`]);
  assert.deepEqual(inventory.jobIds, [own.jobId]);
  assert.deepEqual(inventory.reservationJobIds, [own.jobId]);
  assert.deepEqual(inventory.deterministicUsageJobIds, [own.jobId]);
  assert.deepEqual(inventory.storagePrefixes, [`monthlyStories/${uid}/`]);
  assert.equal(JSON.stringify(inventory).includes(otherUid), false);
});

test("metadata deletion is idempotent and a deletion failure preserves the story", async () => {
  const repo = readyRepository(); await generate(repo);
  repo.failDeletion = true;
  await assert.rejects(repo.deleteStoryMetadata(uid, monthKey), (error: unknown) =>
    error instanceof MonthlyStoryRepositoryError && error.code === "persistence-failure");
  assert.equal(repo.stories.size, 1);
  repo.failDeletion = false;
  await repo.deleteStoryMetadata(uid, monthKey);
  await repo.deleteStoryMetadata(uid, monthKey);
  assert.equal(repo.stories.size, 0);
});

test("deterministic slot reservation is idempotent and never increments past caps", async () => {
  const repo = readyRepository();
  const slot = { jobId: `ms_${"a".repeat(64)}`, monthKey, dayKey: "2026-08-04",
    dailyCap: 1, monthlyCap: 1, nowMillis };
  assert.deepEqual(await repo.reserveDeterministicGenerationSlot(slot), { duplicate: false });
  assert.deepEqual(await repo.reserveDeterministicGenerationSlot(slot), { duplicate: true });
  await assert.rejects(repo.reserveDeterministicGenerationSlot({ ...slot, jobId: `ms_${"b".repeat(64)}` }),
    /daily-generation-cap/);
  assert.equal(repo.dailyCounts.get(slot.dayKey), 1);
  assert.equal(repo.monthlyCounts.get(monthKey), 1);
});

test("job repository rejects an owner hash that does not belong to the path UID", () => {
  const repo = readyRepository();
  assert.throws(() => repo.jobRepository(uid, "a".repeat(64)), /invalid-repository-input/);
});
