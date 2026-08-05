import { test } from "node:test";
import assert from "node:assert";
import { FakeMonthlyStoryAudioProvider } from "./monthlyStoryAudioProvider";
import { InMemoryMonthlyStoryAudioRepository } from "./monthlyStoryAudioRepository";
import { InMemoryMonthlyStoryAudioObjectStore } from "./monthlyStoryAudioService";
import { createMonthlyStoryInternalAudioApi } from "./monthlyStoryInternalAudioApi";
import { MonthlyStoryInternalApiError } from "./monthlyStoryInternalApi";
import { InMemoryMonthlyStoryRepository, MonthlyStoryPersistedText } from "./monthlyStoryRepository";

const uid = "synthetic-audio-tester";
const monthKey = "2026-07";
const generationVersion = "deterministic-v1";
const nowMillis = Date.parse("2026-08-04T12:00:00Z");
const context = { auth: { uid }, appVersion: "2.1.0", nowMillis };

function setup() {
  const repository = new InMemoryMonthlyStoryRepository();
  repository.controlDocument = { visible: true, enrollmentEnabled: true, signalUploadEnabled: true,
    textGenerationEnabled: true, audioGenerationEnabled: true, rolloutBasisPoints: 10_000,
    minimumAppVersion: "2.1.0", dailyTextGenerationCap: 2, monthlyTextGenerationCap: 2,
    dailyAudioGenerationCap: 2, monthlyAudioGenerationCap: 2, monthlyBudgetMicros: 1_000_000,
    monthlyTextBudgetMicros: 0, monthlyAudioBudgetMicros: 1_000_000, maxTextAttempts: 2,
    maxAudioAttempts: 2, generationVersion, signalSchemaVersion: 1,
    scriptPromptVersion: "deterministic-v1", criticPromptVersion: "none-v1", ttsVersion: "hume-v1",
    humeConfigurationVersion: "hume-internal-v1", approvedVoiceKey: "synthetic-voice",
    maximumAudioScriptCharacters: 5_000, audioRequestTimeoutSeconds: 30,
    humeCostMicrosPerThousandCharacters: 150_000, updatedAt: nowMillis };
  repository.internalTesters.set(uid, { enabled: true, updatedAt: nowMillis, expiresAt: nowMillis + 100_000 });
  repository.settings.set(uid, { enabled: true, useJournalThemes: false, useHealthPatterns: false,
    audioEnabled: true, timezone: "UTC", timezoneEffectiveMonth: monthKey, settingsVersion: 1,
    updatedAt: nowMillis });
  const audioRepository = new InMemoryMonthlyStoryAudioRepository();
  audioRepository.story = { monthKey, generationVersion, compositionVersion: generationVersion,
    signalSchemaVersion: 1, status: "textReady", script: "synthetic words ".repeat(100).trim(),
    paragraphs: ["synthetic words ".repeat(100).trim()], wordCount: 200, profile: "standard",
    usedEvidenceIds: ["synthetic-evidence-01"], usedClaimKeys: ["workPressure"],
    usedSuggestionKeys: ["protectPersonalTime"], scriptHash: "a".repeat(64), createdAtMillis: nowMillis,
    finalizedAtMillis: nowMillis, expiresAtMillis: nowMillis + 1_000_000, audioStatus: "notRequested",
    deletionState: "active", validationVersion: "script-validator-v1", compositionMode: "deterministic",
    providerRequestCount: 0, providerCostMicros: 0,
    storageCleanup: { state: "notRequired", updatedAtMillis: nowMillis } } satisfies MonthlyStoryPersistedText;
  const objectStore = new InMemoryMonthlyStoryAudioObjectStore();
  const provider = new FakeMonthlyStoryAudioProvider({ audio: Buffer.from("ID3synthetic-audio"), format: "mp3",
    durationMillis: 90_000, requestIdentifier: "synthetic-request", providerRequestCount: 1,
    estimatedCostMicros: 100_000 });
  let providerConstructions = 0;
  const api = createMonthlyStoryInternalAudioApi({ repository, audioRepository, objectStore,
    providerFactory: () => { providerConstructions += 1; return provider; } });
  return { repository, audioRepository, objectStore, provider, api, providerConstructions: () => providerConstructions };
}

async function rejectsCode(promise: Promise<unknown>, code: string) {
  await assert.rejects(promise, (error: unknown) =>
    error instanceof MonthlyStoryInternalApiError && error.code === code);
}

test("audio API rejects unauthenticated and normal users before provider construction", async () => {
  const fixture = setup();
  const payload = { monthKey, generationVersion };
  await rejectsCode(fixture.api({ ...context, auth: null }, payload), "unauthenticated");
  await rejectsCode(fixture.api({ ...context, auth: { uid: "synthetic-normal" } }, payload), "permission-denied");
  assert.equal(fixture.providerConstructions(), 0);
  assert.equal(fixture.provider.calls, 0);
});

test("audio API is owner-bound, strict, and idempotently reuses ready audio", async () => {
  const fixture = setup();
  await rejectsCode(fixture.api(context, { monthKey, generationVersion, uid: "synthetic-other" }), "invalid-argument");
  const first = await fixture.api(context, { monthKey, generationVersion });
  const second = await fixture.api(context, { monthKey, generationVersion });
  assert.equal(first.story.audioStatus, "ready");
  assert.equal(second.reused, true);
  assert.equal(fixture.provider.calls, 1);
});

test("audio API fails closed when remote audio or feature-specific opt-in is disabled", async () => {
  const disabled = setup();
  disabled.repository.controlDocument = { ...disabled.repository.controlDocument as object,
    audioGenerationEnabled: false };
  await rejectsCode(disabled.api(context, { monthKey, generationVersion }), "failed-precondition");
  assert.equal(disabled.providerConstructions(), 0);

  const optedOut = setup();
  optedOut.repository.settings.set(uid, { ...optedOut.repository.settings.get(uid)!, audioEnabled: false });
  await rejectsCode(optedOut.api(context, { monthKey, generationVersion }), "failed-precondition");
  assert.equal(optedOut.provider.calls, 0);
});
