import { test } from "node:test";
import assert from "node:assert";
import { createMonthlyStoryInternalApi, MonthlyStoryInternalApiError } from "./monthlyStoryInternalApi";
import { InMemoryMonthlyStoryRepository } from "./monthlyStoryRepository";
import { approvedMonthlyStoryEvaluationFixture } from "./monthlyStorySyntheticEvaluationFixtures";

const uid = "synthetic-internal"; const monthKey = "2026-07";
const nowMillis = Date.parse("2026-08-04T12:00:00Z");
const context = { auth: { uid }, appVersion: "2.1.0", nowMillis };
const control = (overrides: Record<string, unknown> = {}) => ({ visible: true,
  enrollmentEnabled: true, signalUploadEnabled: true, textGenerationEnabled: true,
  audioGenerationEnabled: false, rolloutBasisPoints: 10_000, minimumAppVersion: "2.1.0",
  dailyTextGenerationCap: 2, monthlyTextGenerationCap: 5, dailyAudioGenerationCap: 0,
  monthlyBudgetMicros: 1, monthlyTextBudgetMicros: 1, monthlyAudioBudgetMicros: 0,
  maxTextAttempts: 2, maxAudioAttempts: 0, generationVersion: "deterministic-v1",
  signalSchemaVersion: 1, scriptPromptVersion: "deterministic-v1", criticPromptVersion: "none-v1",
  ttsVersion: "none-v1", updatedAt: nowMillis, ...overrides });
const settings = (overrides: Record<string, unknown> = {}) => ({ enabled: true,
  useJournalThemes: true, useHealthPatterns: true, audioEnabled: false, timezone: "UTC",
  timezoneEffectiveMonth: monthKey, settingsVersion: 1, updatedAt: nowMillis, ...overrides });

function repository(): InMemoryMonthlyStoryRepository {
  const result = new InMemoryMonthlyStoryRepository(); result.controlDocument = control();
  result.internalTesters.set(uid, { enabled: true, updatedAt: nowMillis, expiresAt: nowMillis + 100_000 });
  result.settings.set(uid, settings()); return result;
}

async function rejectsCode(promise: Promise<unknown>, code: string) {
  await assert.rejects(promise, (error: unknown) =>
    error instanceof MonthlyStoryInternalApiError && error.code === code);
}

test("API rejects unauthenticated and normal users regardless of client state", async () => {
  const repo = repository(); const api = createMonthlyStoryInternalApi(repo);
  await rejectsCode(api.availability({ ...context, auth: null }), "unauthenticated");
  await rejectsCode(api.availability({ ...context, auth: { uid: "synthetic-normal" } }), "permission-denied");
});

test("availability and settings fail closed and reject spoof or unknown fields", async () => {
  const repo = repository(); const api = createMonthlyStoryInternalApi(repo);
  assert.equal((await api.availability(context)).visible, true);
  repo.controlDocument = control({ updatedAt: nowMillis - 86_400_001 });
  await rejectsCode(api.availability(context), "failed-precondition");
  repo.controlDocument = control();
  await rejectsCode(api.updateSettings(context, { ...settings(), uid: "synthetic-other" }), "invalid-argument");
  const saved = await api.updateSettings(context, { enabled: false, useJournalThemes: false,
    useHealthPatterns: false, audioEnabled: false, timezone: "UTC", timezoneEffectiveMonth: monthKey,
    settingsVersion: 1 });
  assert.equal(saved.enabled, false); assert.equal(saved.audioEnabled, false);
});

test("signal permission, safety, and upload controls are revalidated server-side", async () => {
  const repo = repository(); const api = createMonthlyStoryInternalApi(repo);
  const signal = approvedMonthlyStoryEvaluationFixture("rich-work-home-projects");
  repo.controlDocument = control({ signalUploadEnabled: false });
  await rejectsCode(api.generate(context, { monthKey, generationVersion: "deterministic-v1", signal }),
    "failed-precondition");
  repo.controlDocument = control();
  await rejectsCode(api.generate(context, { monthKey, generationVersion: "deterministic-v1",
    signal: { ...signal, isStorySafetyEligible: false } }), "failed-precondition");
  await rejectsCode(api.generate(context, { monthKey, generationVersion: "deterministic-v1",
    signal: { ...signal, unknown: true } }), "invalid-argument");
});

test("deterministic generation is idempotent and makes no provider or audio calls", async () => {
  const repo = repository(); const api = createMonthlyStoryInternalApi(repo);
  const signal = approvedMonthlyStoryEvaluationFixture("rich-work-home-projects");
  const first = await api.generate(context, { monthKey, generationVersion: "deterministic-v1", signal });
  const second = await api.generate(context, { monthKey, generationVersion: "deterministic-v1", signal });
  assert.equal(first.story.scriptHash, second.story.scriptHash);
  assert.equal(second.reused, true); assert.equal(repo.stories.size, 1); assert.equal(repo.jobs.size, 1);
  assert.equal(first.story.providerRequestCount, 0); assert.equal(first.story.audioStatus, "notRequested");
});

test("daily and explicit monthly generation caps are independently enforced", async () => {
  const signal = approvedMonthlyStoryEvaluationFixture("rich-work-home-projects");
  const daily = repository(); daily.dailyCounts.set("2026-08-04", 2);
  await rejectsCode(createMonthlyStoryInternalApi(daily).generate(context,
    { monthKey, generationVersion: "deterministic-v1", signal }), "resource-exhausted");
  const monthly = repository(); monthly.monthlyCounts.set(monthKey, 5);
  await rejectsCode(createMonthlyStoryInternalApi(monthly).generate(context,
    { monthKey, generationVersion: "deterministic-v1", signal }), "resource-exhausted");
  const zero = repository(); zero.controlDocument = control({ monthlyTextGenerationCap: 0 });
  await rejectsCode(createMonthlyStoryInternalApi(zero).generate(context,
    { monthKey, generationVersion: "deterministic-v1", signal }), "failed-precondition");
});

test("delete is owner-bound, idempotent, tombstones regeneration, and survives remote disable", async () => {
  const repo = repository(); const api = createMonthlyStoryInternalApi(repo);
  const signal = approvedMonthlyStoryEvaluationFixture("rich-work-home-projects");
  await api.generate(context, { monthKey, generationVersion: "deterministic-v1", signal });
  repo.controlDocument = control({ visible: false });
  assert.ok((await api.loadStory(context, { monthKey })).story);
  assert.equal((await api.deleteStory(context, { monthKey, generationVersion: "deterministic-v1" })).deleted, true);
  assert.equal((await api.deleteStory(context, { monthKey, generationVersion: "deterministic-v1" })).deleted, true);
  assert.equal((await api.loadStory(context, { monthKey })).story, null);
  repo.controlDocument = control();
  await rejectsCode(api.generate(context, { monthKey, generationVersion: "deterministic-v1", signal }),
    "already-exists");
});

test("delete failure never reports success and preserves the story", async () => {
  const repo = repository(); const api = createMonthlyStoryInternalApi(repo);
  const signal = approvedMonthlyStoryEvaluationFixture("rich-work-home-projects");
  await api.generate(context, { monthKey, generationVersion: "deterministic-v1", signal });
  repo.failDeletion = true;
  await rejectsCode(api.deleteStory(context, { monthKey, generationVersion: "deterministic-v1" }), "internal");
  assert.ok(repo.stories.get(`${uid}/${monthKey}`));
});
