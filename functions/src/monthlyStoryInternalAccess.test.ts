import { test } from "node:test";
import assert from "node:assert";
import { monthlyStoryAppVersionIsCompatible, parseMonthlyStoryInternalTester,
  requireMonthlyStoryInternalAvailability } from "./monthlyStoryInternalAccess";
import { InMemoryMonthlyStoryRepository } from "./monthlyStoryRepository";

const now = Date.parse("2026-08-04T12:00:00Z");
const control = (overrides: Record<string, unknown> = {}) => ({ visible: true,
  enrollmentEnabled: true, signalUploadEnabled: true, textGenerationEnabled: true,
  audioGenerationEnabled: false, rolloutBasisPoints: 10_000, minimumAppVersion: "2.1.0",
  dailyTextGenerationCap: 2, monthlyTextGenerationCap: 5, dailyAudioGenerationCap: 0,
  monthlyBudgetMicros: 1, monthlyTextBudgetMicros: 1, monthlyAudioBudgetMicros: 0,
  maxTextAttempts: 2, maxAudioAttempts: 0, generationVersion: "deterministic-v1",
  signalSchemaVersion: 1, scriptPromptVersion: "deterministic-v1", criticPromptVersion: "none-v1",
  ttsVersion: "none-v1", updatedAt: now, ...overrides });

test("internal tester documents and app versions fail closed", () => {
  assert.equal(parseMonthlyStoryInternalTester(null, now), false);
  assert.equal(parseMonthlyStoryInternalTester({ enabled: true, updatedAt: now, expiresAt: now + 1 }, now), true);
  assert.equal(parseMonthlyStoryInternalTester({ enabled: true, updatedAt: now, expiresAt: now }, now), false);
  assert.equal(parseMonthlyStoryInternalTester({ enabled: true, updatedAt: now, expiresAt: now + 1,
    uid: "synthetic-user" }, now), false);
  assert.equal(monthlyStoryAppVersionIsCompatible("2.1", "2.1.0"), true);
  assert.equal(monthlyStoryAppVersionIsCompatible("2.0.9", "2.1.0"), false);
  assert.equal(monthlyStoryAppVersionIsCompatible("invalid", "2.1.0"), false);
});

test("availability requires auth, server allowlist, complete control, rollout, and app version", async () => {
  const repository = new InMemoryMonthlyStoryRepository(); repository.controlDocument = control();
  repository.internalTesters.set("synthetic-internal", { enabled: true, updatedAt: now, expiresAt: now + 1000 });
  await assert.rejects(requireMonthlyStoryInternalAvailability({ auth: null, repository,
    appVersion: "2.1.0", nowMillis: now }), /authentication-required/);
  await assert.rejects(requireMonthlyStoryInternalAvailability({ auth: { uid: "synthetic-normal" }, repository,
    appVersion: "2.1.0", nowMillis: now }), /internal-access-denied/);
  await assert.rejects(requireMonthlyStoryInternalAvailability({ auth: { uid: "synthetic-internal" }, repository,
    appVersion: "2.0.0", nowMillis: now }), /app-version-unsupported/);
  repository.controlDocument = control({ rolloutBasisPoints: 0 });
  await assert.rejects(requireMonthlyStoryInternalAvailability({ auth: { uid: "synthetic-internal" }, repository,
    appVersion: "2.1.0", nowMillis: now }), /feature-unavailable/);
  repository.controlDocument = control();
  const result = await requireMonthlyStoryInternalAvailability({ auth: { uid: "synthetic-internal" }, repository,
    appVersion: "2.1.0", nowMillis: now });
  assert.equal(result.uid, "synthetic-internal");
});
