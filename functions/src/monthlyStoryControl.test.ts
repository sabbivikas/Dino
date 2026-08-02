import { test } from "node:test";
import assert from "node:assert";
import { MONTHLY_STORY_CONTROL_MAX_AGE_MS, parseMonthlyStoryControl,
  SAFE_DISABLED_MONTHLY_STORY_CONTROL, monthlyStoryGenerationIsFailClosed } from "./monthlyStoryControl";

const now = Date.parse("2026-08-02T12:00:00Z");
const validControl = (overrides: Record<string, unknown> = {}): Record<string, unknown> => ({
  visible: false, enrollmentEnabled: true, signalUploadEnabled: true,
  textGenerationEnabled: true, audioGenerationEnabled: true, rolloutBasisPoints: 500,
  minimumAppVersion: "1.2.3", dailyTextGenerationCap: 10, dailyAudioGenerationCap: 5,
  monthlyBudgetMicros: 1_000_000, monthlyTextBudgetMicros: 600_000,
  monthlyAudioBudgetMicros: 400_000, maxTextAttempts: 2, maxAudioAttempts: 2,
  generationVersion: "v1", signalSchemaVersion: 1, scriptPromptVersion: "script-v1",
  criticPromptVersion: "critic-v1", ttsVersion: "tts-v1", updatedAt: now,
  ...overrides,
});

test("monthly story control defaults are completely disabled", () => {
  assert.deepEqual(parseMonthlyStoryControl(null, now).control, SAFE_DISABLED_MONTHLY_STORY_CONTROL);
  assert.equal(monthlyStoryGenerationIsFailClosed({ ...SAFE_DISABLED_MONTHLY_STORY_CONTROL }), true);
});

test("missing, partial, unknown, malformed, and stale controls fail closed", () => {
  assert.equal(parseMonthlyStoryControl(undefined, now).reason, "missing");
  assert.equal(parseMonthlyStoryControl({ visible: true }, now).reason, "malformed");
  assert.equal(parseMonthlyStoryControl(validControl({ extra: true }), now).reason, "malformed");
  assert.equal(parseMonthlyStoryControl(validControl({ rolloutBasisPoints: 10_001 }), now).reason, "malformed");
  assert.equal(parseMonthlyStoryControl(validControl({ monthlyBudgetMicros: 1 }), now).reason, "malformed");
  assert.equal(parseMonthlyStoryControl(validControl({ updatedAt: now - MONTHLY_STORY_CONTROL_MAX_AGE_MS - 1 }), now).reason, "stale");
});

test("a complete fresh control parses but zero gates still fail closed", () => {
  const parsed = parseMonthlyStoryControl(validControl(), now);
  assert.equal(parsed.accepted, true);
  assert.equal(monthlyStoryGenerationIsFailClosed(parsed.control), false);

  for (const field of ["rolloutBasisPoints", "dailyTextGenerationCap", "monthlyBudgetMicros",
    "monthlyTextBudgetMicros", "maxTextAttempts"] as const) {
    const zero = parseMonthlyStoryControl(validControl({ [field]: 0,
      ...(field === "monthlyBudgetMicros" ? { monthlyTextBudgetMicros: 0, monthlyAudioBudgetMicros: 0 } : {}) }), now);
    assert.equal(zero.accepted, true);
    assert.equal(monthlyStoryGenerationIsFailClosed(zero.control), true);
  }
});
