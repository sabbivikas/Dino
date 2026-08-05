import { test } from "node:test";
import assert from "node:assert";
import { composeMonthlyStoryDeterministically, MonthlyStoryDeterministicComposerError } from
  "./monthlyStoryDeterministicComposer";
import { runMonthlyStoryGenerationInternal, MonthlyStoryGenerationError,
  MONTHLY_STORY_INTERNAL_RETRY_DELAY_MILLIS } from "./monthlyStoryGenerationService";
import { acquireMonthlyStoryJobLease, createMonthlyStoryJobIfAbsent,
  deterministicMonthlyStoryJobId } from "./monthlyStoryJobs";
import { InMemoryMonthlyStoryRepository } from "./monthlyStoryRepository";
import { monthlyStoryOwnerKey } from "./monthlyStoryRollout";
import { approvedMonthlyStoryEvaluationFixture } from "./monthlyStorySyntheticEvaluationFixtures";

const uid = "synthetic-user-a";
const monthKey = "2026-07";
const generationVersion = "deterministic-v1";
const nowMillis = Date.parse("2026-08-04T12:00:00.000Z");

function control(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return { visible: true, enrollmentEnabled: true, signalUploadEnabled: true,
    textGenerationEnabled: true, audioGenerationEnabled: false, rolloutBasisPoints: 10_000,
    minimumAppVersion: "1.0.0", dailyTextGenerationCap: 10, monthlyTextGenerationCap: 100,
    dailyAudioGenerationCap: 0, monthlyAudioGenerationCap: 0,
    monthlyBudgetMicros: 1, monthlyTextBudgetMicros: 1, monthlyAudioBudgetMicros: 0,
    maxTextAttempts: 3, maxAudioAttempts: 0, generationVersion, signalSchemaVersion: 1,
    scriptPromptVersion: "deterministic-v1", criticPromptVersion: "none-v1", ttsVersion: "none-v1",
    humeConfigurationVersion: "none-v1", approvedVoiceKey: "disabled", maximumAudioScriptCharacters: 0,
    audioRequestTimeoutSeconds: 0, humeCostMicrosPerThousandCharacters: 0,
    updatedAt: nowMillis, ...overrides };
}

function settings(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return { enabled: true, useJournalThemes: true, useHealthPatterns: true, audioEnabled: false,
    timezone: "UTC", timezoneEffectiveMonth: monthKey, settingsVersion: 1,
    updatedAt: nowMillis, ...overrides };
}

function repository(fixture = "rich-work-home-projects"): InMemoryMonthlyStoryRepository {
  const result = new InMemoryMonthlyStoryRepository();
  result.controlDocument = control();
  result.settings.set(uid, settings());
  result.signals.set(`${uid}/${monthKey}`,
    approvedMonthlyStoryEvaluationFixture(fixture as "rich-work-home-projects"));
  return result;
}

function request(repo: InMemoryMonthlyStoryRepository, overrides: Record<string, unknown> = {}) {
  return runMonthlyStoryGenerationInternal({ uid, monthKey, generationVersion, nowMillis,
    workerId: "worker-a", repository: repo, ...overrides });
}

async function rejectsCode(promise: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(promise, (error: unknown) =>
    error instanceof MonthlyStoryGenerationError && error.code === code);
}

test("disabled, missing, malformed, stale, zero-rollout, and zero-cap controls fail before jobs", async () => {
  const variants: [unknown, string][] = [
    [null, "control-invalid"],
    [{ visible: true }, "control-invalid"],
    [control({ updatedAt: nowMillis - 24 * 60 * 60 * 1000 - 1 }), "control-invalid"],
    [control({ textGenerationEnabled: false }), "control-disabled"],
    [control({ rolloutBasisPoints: 0 }), "control-disabled"],
    [control({ monthlyTextGenerationCap: 0 }), "control-disabled"],
  ];
  for (const [value, code] of variants) {
    const repo = repository(); repo.controlDocument = value;
    await rejectsCode(request(repo), code);
    assert.equal(repo.jobs.size, 0);
  }
});

test("generation version and nonzero rollout exclusions fail before job creation", async () => {
  const version = repository();
  await rejectsCode(request(version, { generationVersion: "other-v1" }), "generation-version-mismatch");
  assert.equal(version.jobs.size, 0);
  const rollout = repository(); rollout.controlDocument = control({ rolloutBasisPoints: 1 });
  await rejectsCode(request(rollout), "rollout-ineligible");
  assert.equal(rollout.jobs.size, 0);
});

test("settings, signal, permission, safety, month-close, and eligibility gates fail closed", async () => {
  const missingSettings = repository(); missingSettings.settings.clear();
  await rejectsCode(request(missingSettings), "settings-disabled");
  const missingSignal = repository(); missingSignal.signals.clear();
  await rejectsCode(request(missingSignal), "signal-missing");
  const mismatch = repository(); mismatch.settings.set(uid, settings({ useJournalThemes: false }));
  await rejectsCode(request(mismatch), "settings-mismatch");
  const unsafe = repository();
  unsafe.signals.set(`${uid}/${monthKey}`, { ...approvedMonthlyStoryEvaluationFixture("rich-work-home-projects"),
    isStorySafetyEligible: false });
  await rejectsCode(request(unsafe), "safety-hold");
  const open = repository();
  const openTime = Date.parse("2026-08-03T03:59:59.000Z");
  open.controlDocument = control({ updatedAt: openTime });
  await rejectsCode(request(open, { nowMillis: openTime }), "month-not-closed");
  const sparse = repository();
  const raw = approvedMonthlyStoryEvaluationFixture("rich-work-home-projects");
  sparse.signals.set(`${uid}/${monthKey}`, { ...raw, usableEvidenceDays: ["2026-07-01"],
    moodEvidenceDays: ["2026-07-01"], corroboratingEvidenceDays: [] });
  await rejectsCode(request(sparse), "eligibility-failed");
  const wrongSchema = repository();
  wrongSchema.controlDocument = control({ signalSchemaVersion: 2 });
  await rejectsCode(request(wrongSchema), "signal-invalid");
});

test("successful deterministic persistence creates one valid story and completes its job", async () => {
  const repo = repository();
  const result = await request(repo);
  assert.equal(result.providerRequestCount, 0);
  assert.equal(result.providerCostMicros, 0);
  assert.equal(result.story.compositionMode, "deterministic");
  assert.equal(result.story.providerRequestCount, 0);
  assert.equal(result.story.audioStatus, "notRequested");
  assert.equal(result.story.storageCleanup.state, "notRequired");
  assert.equal(repo.stories.size, 1);
  assert.equal(repo.jobs.get(result.jobId)?.status, "textReady");
  assert.equal(repo.jobs.get(result.jobId)?.textArtifactHash, result.story.scriptHash);
  assert.equal(repo.generationSlots.size, 1);
});

test("deterministic persistence requires generation caps but no provider budget", async () => {
  const repo = repository();
  repo.controlDocument = control({ monthlyBudgetMicros: 0, monthlyTextBudgetMicros: 0,
    monthlyAudioBudgetMicros: 0 });
  const result = await request(repo);
  assert.equal(result.providerRequestCount, 0);
  assert.equal(result.providerCostMicros, 0);
  assert.equal(result.story.status, "textReady");
});

test("same owner and generation inputs produce byte-stable persisted content", async () => {
  const first = await request(repository());
  const second = await request(repository());
  assert.equal(JSON.stringify(first.story), JSON.stringify(second.story));
});

test("active tombstones and existing stories prevent regeneration", async () => {
  const tombstoned = repository();
  tombstoned.tombstones.set(`${uid}/${monthKey}`, { monthKey, generationVersion, reason: "userRequest",
    deletedAtMillis: nowMillis - 1, expiresAtMillis: Date.parse("2027-11-01T00:00:00Z"),
    storageCleanup: { state: "complete", updatedAtMillis: nowMillis - 1 } });
  await rejectsCode(request(tombstoned), "deleted-tombstone");
  const existing = repository(); await request(existing);
  await rejectsCode(request(existing), "story-already-exists");
  assert.equal(existing.stories.size, 1);
});

test("an expired tombstone does not regenerate its deleted marker and no longer blocks the new version run", async () => {
  const repo = repository();
  repo.tombstones.set(`${uid}/${monthKey}`, { monthKey, generationVersion, reason: "retention",
    deletedAtMillis: nowMillis - 1000, expiresAtMillis: nowMillis,
    storageCleanup: { state: "complete", updatedAtMillis: nowMillis - 1000 } });
  const result = await request(repo);
  assert.equal(result.story.status, "textReady");
  assert.equal(repo.tombstones.has(`${uid}/${monthKey}`), true);
});

test("a tombstone appearing after preflight still blocks atomic job creation", async () => {
  class RacingRepository extends InMemoryMonthlyStoryRepository {
    override async loadStory(owner: string, month: string) {
      const value = await super.loadStory(owner, month);
      this.tombstones.set(`${owner}/${month}`, { monthKey: month, generationVersion,
        reason: "accountDeletion", deletedAtMillis: nowMillis - 1,
        expiresAtMillis: Date.parse("2027-11-01T00:00:00Z"),
        storageCleanup: { state: "complete", updatedAtMillis: nowMillis - 1 } });
      return value;
    }
  }
  const base = repository(); const repo = new RacingRepository();
  repo.controlDocument = base.controlDocument;
  repo.settings.set(uid, base.settings.get(uid)!);
  repo.signals.set(`${uid}/${monthKey}`, base.signals.get(`${uid}/${monthKey}`)!);
  await rejectsCode(request(repo), "deleted-tombstone");
  assert.equal(repo.jobs.size, 0);
});

test("mutable gates are re-read immediately before job creation", async () => {
  class GateChangingRepository extends InMemoryMonthlyStoryRepository {
    override async loadStory(owner: string, month: string) {
      const value = await super.loadStory(owner, month);
      this.controlDocument = control({ textGenerationEnabled: false });
      return value;
    }
  }
  const base = repository(); const repo = new GateChangingRepository();
  repo.controlDocument = base.controlDocument;
  repo.settings.set(uid, base.settings.get(uid)!);
  repo.signals.set(`${uid}/${monthKey}`, base.signals.get(`${uid}/${monthKey}`)!);
  await rejectsCode(request(repo), "control-disabled");
  assert.equal(repo.jobs.size, 0);
});

test("a terminal completed job cannot restart even if its story is absent", async () => {
  const repo = repository();
  const ownerKey = monthlyStoryOwnerKey(uid, "monthly-story-owner-v1");
  const jobs = repo.jobRepository(uid, ownerKey);
  const created = await createMonthlyStoryJobIfAbsent(jobs, { uid, ownerKeyVersion: "monthly-story-owner-v1",
    monthKey, generationVersion, nowMillis: nowMillis - 100 });
  repo.jobs.set(created.job.jobId, { ...created.job, status: "ready", textArtifactHash: "a".repeat(64),
    audioTerminal: true });
  await rejectsCode(request(repo), "job-completed");
  assert.equal(repo.stories.size, 0);
});

test("one concurrent worker wins and no duplicate story or operational slot is created", async () => {
  const repo = repository();
  const results = await Promise.allSettled([request(repo, { workerId: "worker-a" }),
    request(repo, { workerId: "worker-b" })]);
  assert.equal(results.filter((item) => item.status === "fulfilled").length, 1);
  assert.equal(results.filter((item) => item.status === "rejected").length, 1);
  assert.equal(repo.stories.size, 1);
  assert.equal(repo.jobs.size, 1);
  assert.equal(repo.generationSlots.size, 1);
  assert.equal(repo.dailyCounts.get("2026-08-04"), 1);
});

test("active leases block a second worker and expired leases are recoverable", async () => {
  const repo = repository();
  const ownerKey = monthlyStoryOwnerKey(uid, "monthly-story-owner-v1");
  const jobs = repo.jobRepository(uid, ownerKey);
  const created = await createMonthlyStoryJobIfAbsent(jobs, { uid, ownerKeyVersion: "monthly-story-owner-v1",
    monthKey, generationVersion, nowMillis: nowMillis - 1000 });
  await acquireMonthlyStoryJobLease(jobs, { jobId: created.job.jobId, stage: "text", leaseOwner: "other",
    nowMillis: nowMillis - 1000, leaseDurationMillis: 10_000, maximumAttempts: 3 });
  await rejectsCode(request(repo), "lease-unavailable");
  const recovered = await request(repo, { nowMillis: nowMillis + 10_001 });
  assert.equal(recovered.jobId, created.job.jobId);
  assert.equal(repo.jobs.get(recovered.jobId)?.textAttempts, 2);
});

test("known persistence failure leaves no story and retry reuses job and reservation", async () => {
  const repo = repository(); repo.failPersistence = true;
  await rejectsCode(request(repo), "persistence-failed");
  assert.equal(repo.stories.size, 0);
  assert.equal(repo.jobs.size, 1);
  const [job] = [...repo.jobs.values()];
  assert.equal(job.status, "pending");
  assert.equal(job.failureCode, "persistenceFailure");
  repo.failPersistence = false;
  const retry = await request(repo, { nowMillis: nowMillis + MONTHLY_STORY_INTERNAL_RETRY_DELAY_MILLIS });
  assert.equal(retry.jobId, job.jobId);
  assert.equal(repo.stories.size, 1);
  assert.equal(repo.generationSlots.size, 1);
  assert.equal(repo.dailyCounts.get("2026-08-04"), 1);
});

test("composition and validation failures become terminal without fallback stories", async () => {
  const compositionFailure = repository();
  await rejectsCode(request(compositionFailure, { composer: () => {
    throw new MonthlyStoryDeterministicComposerError("insufficientDeterministicContent");
  } }), "composition-failed");
  assert.equal(compositionFailure.stories.size, 0);
  assert.equal([...compositionFailure.jobs.values()][0].status, "terminalFailure");

  const validationFailure = repository();
  await rejectsCode(request(validationFailure, { composer: (input: Parameters<
    typeof composeMonthlyStoryDeterministically>[0]) => ({ ...composeMonthlyStoryDeterministically(input),
      script: "too short", wordCount: 2 }) }), "validation-failed");
  assert.equal(validationFailure.stories.size, 0);
  assert.equal([...validationFailure.jobs.values()][0].status, "terminalFailure");
});

test("daily operational cap is fail-closed and UID is never stored in story or job body", async () => {
  const repo = repository(); repo.controlDocument = control({ dailyTextGenerationCap: 1 });
  repo.dailyCounts.set("2026-08-04", 1);
  await rejectsCode(request(repo), "operational-cap");
  assert.equal(repo.stories.size, 0);
  const successful = repository(); const result = await request(successful);
  assert.equal(JSON.stringify(result.story).includes(uid), false);
  assert.equal(JSON.stringify(successful.jobs.get(result.jobId)).includes(uid), false);
  assert.equal(result.jobId, deterministicMonthlyStoryJobId(uid, monthKey, generationVersion,
    "monthly-story-owner-v1"));
});
