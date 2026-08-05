import { test } from "node:test";
import assert from "node:assert";
import { FakeMonthlyStoryAudioProvider, FailingMonthlyStoryAudioProvider,
  MonthlyStoryAudioProviderError } from "./monthlyStoryAudioProvider";
import { generateMonthlyStoryAudio, InMemoryMonthlyStoryAudioObjectStore,
  MonthlyStoryAudioServiceError, monthlyStoryAudioStoragePath } from "./monthlyStoryAudioService";
import { InMemoryMonthlyStoryAudioRepository } from "./monthlyStoryAudioRepository";
import { MonthlyStoryControl } from "./monthlyStoryControl";
import { MonthlyStoryPersistedText } from "./monthlyStoryRepository";

const now = Date.parse("2026-08-04T12:00:00Z");
const uid = "synthetic-internal"; const monthKey = "2026-07"; const generationVersion = "deterministic-v1";
const control: MonthlyStoryControl = { visible: true, enrollmentEnabled: true, signalUploadEnabled: true,
  textGenerationEnabled: true, audioGenerationEnabled: true, rolloutBasisPoints: 10_000,
  minimumAppVersion: "2.1", dailyTextGenerationCap: 2, monthlyTextGenerationCap: 2,
  dailyAudioGenerationCap: 2, monthlyAudioGenerationCap: 2, monthlyBudgetMicros: 1_000_000,
  monthlyTextBudgetMicros: 0, monthlyAudioBudgetMicros: 1_000_000, maxTextAttempts: 2,
  maxAudioAttempts: 2, generationVersion, signalSchemaVersion: 1,
  scriptPromptVersion: "deterministic-v1", criticPromptVersion: "none-v1", ttsVersion: "hume-v1",
  humeConfigurationVersion: "hume-internal-v1", approvedVoiceKey: "synthetic-voice",
  maximumAudioScriptCharacters: 5_000, audioRequestTimeoutSeconds: 30,
  humeCostMicrosPerThousandCharacters: 150_000, updatedAtMillis: now };
const story: MonthlyStoryPersistedText = { monthKey, generationVersion, compositionVersion: "deterministic-v1",
  signalSchemaVersion: 1, status: "textReady", script: "synthetic words ".repeat(100).trim(),
  paragraphs: ["synthetic words ".repeat(100).trim()], wordCount: 200, profile: "standard",
  usedEvidenceIds: ["synthetic-evidence-01"], usedClaimKeys: ["workPressure"],
  usedSuggestionKeys: ["protectPersonalTime"], scriptHash: "a".repeat(64), createdAtMillis: now,
  finalizedAtMillis: now, expiresAtMillis: now + 1_000_000, audioStatus: "notRequested",
  deletionState: "active", validationVersion: "script-validator-v1", compositionMode: "deterministic",
  providerRequestCount: 0, providerCostMicros: 0,
  storageCleanup: { state: "notRequired", updatedAtMillis: now } };
const audio = Buffer.from("ID3synthetic-monthly-story-audio");

function setup() {
  const repository = new InMemoryMonthlyStoryAudioRepository(); repository.story = structuredClone(story);
  const objectStore = new InMemoryMonthlyStoryAudioObjectStore();
  const provider = new FakeMonthlyStoryAudioProvider({ audio, format: "mp3", durationMillis: 90_000,
    requestIdentifier: "synthetic", providerRequestCount: 1, estimatedCostMicros: 100_000 });
  return { repository, objectStore, provider };
}

test("successful audio is private-path ready and repeated request makes exactly one provider call", async () => {
  const fixture = setup(); const input = { uid, monthKey, generationVersion, nowMillis: now, control,
    audioSettingEnabled: true, ...fixture };
  const first = await generateMonthlyStoryAudio(input);
  const second = await generateMonthlyStoryAudio({ ...input, nowMillis: now + 1 });
  assert.equal(first.story.audioStatus, "ready"); assert.equal(second.reused, true);
  assert.equal(fixture.provider.calls, 1); assert.equal(first.story.audioStoragePath,
    monthlyStoryAudioStoragePath(uid, monthKey, generationVersion));
});

test("disabled setting, zero caps, budget, missing story, tombstone, and oversized scripts fail before provider", async () => {
  for (const variation of [
    { audioSettingEnabled: false },
    { control: { ...control, audioGenerationEnabled: false } },
    { control: { ...control, dailyAudioGenerationCap: 0 } },
    { control: { ...control, monthlyAudioBudgetMicros: 0 } },
    { control: { ...control, maximumAudioScriptCharacters: 10 } },
  ]) {
    const fixture = setup();
    await assert.rejects(generateMonthlyStoryAudio({ uid, monthKey, generationVersion, nowMillis: now,
      control, audioSettingEnabled: true, ...fixture, ...variation }), MonthlyStoryAudioServiceError);
    assert.equal(fixture.provider.calls, 0);
  }
  const missing = setup(); missing.repository.story = null;
  await assert.rejects(generateMonthlyStoryAudio({ uid, monthKey, generationVersion, nowMillis: now,
    control, audioSettingEnabled: true, ...missing }), /story-missing/);
  const deleted = setup(); deleted.repository.tombstoned = true;
  await assert.rejects(generateMonthlyStoryAudio({ uid, monthKey, generationVersion, nowMillis: now,
    control, audioSettingEnabled: true, ...deleted }), /story-deleted/);
});

test("concurrent lease is idempotent, expired lease can retry, and attempts are bounded", async () => {
  const fixture = setup(); fixture.repository.activeLeaseUntil = now + 1_000;
  await assert.rejects(generateMonthlyStoryAudio({ uid, monthKey, generationVersion, nowMillis: now,
    control, audioSettingEnabled: true, ...fixture }), /audio-active/);
  assert.equal(fixture.provider.calls, 0);
  fixture.repository.activeLeaseUntil = now - 1; fixture.repository.attempts = 1;
  await generateMonthlyStoryAudio({ uid, monthKey, generationVersion, nowMillis: now,
    control, audioSettingEnabled: true, ...fixture });
  assert.equal(fixture.provider.calls, 1);
});

test("storage and provider failure preserve the written story", async () => {
  const storage = setup(); storage.objectStore.failWrites = true;
  await assert.rejects(generateMonthlyStoryAudio({ uid, monthKey, generationVersion, nowMillis: now,
    control, audioSettingEnabled: true, ...storage }), /storage-failure/);
  assert.ok(storage.repository.story?.script); assert.equal(storage.repository.story?.audioStatus, "failed");
  const provider = setup(); const failure = new FailingMonthlyStoryAudioProvider(
    new MonthlyStoryAudioProviderError("timeout", true, false, false));
  await assert.rejects(generateMonthlyStoryAudio({ uid, monthKey, generationVersion, nowMillis: now,
    control, audioSettingEnabled: true, repository: provider.repository, objectStore: provider.objectStore,
    provider: failure }), /provider-failure/);
  assert.ok(provider.repository.story?.script); assert.equal(failure.calls, 1);
});

test("object existence reconciles uncertain metadata without another provider request", async () => {
  const fixture = setup(); const path = monthlyStoryAudioStoragePath(uid, monthKey, generationVersion);
  await fixture.objectStore.write(path, audio, { hash: "b".repeat(64), durationMillis: 90_000,
    generatedAtMillis: now, providerRequestCount: 1, estimatedCostMicros: 100_000,
    ttsVersion: "hume-v1", voiceKey: "synthetic-voice" });
  const result = await generateMonthlyStoryAudio({ uid, monthKey, generationVersion, nowMillis: now,
    control, audioSettingEnabled: true, ...fixture });
  assert.equal(result.reused, true); assert.equal(fixture.provider.calls, 0); assert.equal(result.story.audioStatus, "ready");
});
