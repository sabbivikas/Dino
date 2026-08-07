import { test } from "node:test";
import assert from "node:assert";
import { readFileSync } from "fs";
import { join } from "path";
import { MonthlyStoryControl, SAFE_DISABLED_MONTHLY_STORY_CONTROL } from "./monthlyStoryControl";
import { MONTHLY_STORY_MAX_DAYS_PER_SET, MONTHLY_STORY_MAX_EVIDENCE_ITEMS,
  MONTHLY_STORY_PATHS, MonthlyStorySettings, MonthlyStoryValidationError,
  SAFE_MONTHLY_STORY_SETTINGS, parseMonthlyStoryDeletedTombstone, parseMonthlyStoryDocument,
  parseMonthlyStorySettingsDocument, parseMonthlyStorySignal, validateMonthlyStorySettingsContract,
  validateMonthlyStorySignalUploadContract } from "./monthlyStorySchema";

const enabledControl: MonthlyStoryControl = { ...SAFE_DISABLED_MONTHLY_STORY_CONTROL,
  enrollmentEnabled: true, signalUploadEnabled: true, signalSchemaVersion: 1,
  generationVersion: "v1", updatedAtMillis: 1 };
const settings: MonthlyStorySettings = { enabled: true, useJournalThemes: true,
  useHealthPatterns: true, audioEnabled: false, timezone: "America/Chicago",
  timezoneEffectiveMonth: "2026-07", settingsVersion: 1, updatedAtMillis: 1 };

const day = (number: number): string => `2026-07-${String(number).padStart(2, "0")}`;
const evidence = (id: string, value: Record<string, string>, source: string): Record<string, unknown> => ({
  id, value, confidence: "high", startDay: day(1), endDay: day(29), source,
  allowedForNarration: true,
});
const validSignal = (): Record<string, unknown> => ({
  schemaVersion: 1, monthKey: "2026-07", timeZone: "America/Chicago",
  evidenceStartDay: day(1), evidenceEndDay: day(29),
  usableEvidenceDays: [1, 5, 9, 14, 20, 29].map(day),
  moodEvidenceDays: [1, 9, 20, 29].map(day),
  corroboratingEvidenceDays: [5, 14].map(day),
  permissions: { featureEnabled: true, journalThemesEnabled: true,
    healthPatternsEnabled: true, audioEnabled: false },
  isStorySafetyEligible: true,
  evidence: [
    evidence("evidence-mood", { type: "emotionalShape", moodShape: "mixed", moodDirection: "brighter" }, "mood"),
    evidence("evidence-work", { type: "repeatedTheme", theme: "workPressure" }, "authorizedJournalTheme"),
    evidence("evidence-sleep", { type: "sleepPattern", sleep: "moreRestful" }, "authorizedHealthSummary"),
    evidence("evidence-practice", { type: "restorativePractice", practice: "breathing" }, "practicePresence"),
  ],
  eligibility: { code: "eligibleStandard", permitsCauseNarration: true },
});

test("settings defaults are false and affect monthly story fields only", () => {
  assert.equal(SAFE_MONTHLY_STORY_SETTINGS.enabled, false);
  assert.equal(SAFE_MONTHLY_STORY_SETTINGS.useJournalThemes, false);
  assert.equal(SAFE_MONTHLY_STORY_SETTINGS.useHealthPatterns, false);
  assert.equal(SAFE_MONTHLY_STORY_SETTINGS.audioEnabled, false);
  assert.deepEqual(Object.keys(SAFE_MONTHLY_STORY_SETTINGS).sort(),
    ["audioEnabled", "enabled", "settingsVersion", "timezone", "timezoneEffectiveMonth",
      "updatedAtMillis", "useHealthPatterns", "useJournalThemes"].sort());
  assert.deepEqual(parseMonthlyStorySettingsDocument(null), SAFE_MONTHLY_STORY_SETTINGS);
  assert.equal(parseMonthlyStorySettingsDocument({ enabled: false, useJournalThemes: false,
    useHealthPatterns: false, audioEnabled: false, timezone: "UTC", timezoneEffectiveMonth: "2026-08",
    settingsVersion: 1, updatedAt: 100 }).updatedAtMillis, 100);
  assert.throws(() => parseMonthlyStorySettingsDocument({ enabled: false, useJournalThemes: false,
    useHealthPatterns: false, audioEnabled: false, timezone: "UTC", timezoneEffectiveMonth: "2026-08",
    settingsVersion: 1, updatedAt: 100, journalEnabled: true }), /unknown-field/);
});

test("settings contract takes UID only from auth and rejects spoofing or unknown fields", () => {
  const payload = { enabled: false, useJournalThemes: false, useHealthPatterns: false,
    audioEnabled: false, timezone: "UTC", timezoneEffectiveMonth: "2026-08", settingsVersion: 1 };
  assert.equal(validateMonthlyStorySettingsContract({ uid: "synthetic-user-a" }, payload,
    enabledControl, 100).uid, "synthetic-user-a");
  assert.throws(() => validateMonthlyStorySettingsContract({ uid: "synthetic-user-a" },
    { ...payload, uid: "synthetic-user-b" }, enabledControl, 100), MonthlyStoryValidationError);
  assert.throws(() => validateMonthlyStorySettingsContract(null, payload, enabledControl, 100),
    /authentication-required/);
  assert.throws(() => validateMonthlyStorySettingsContract({ uid: "synthetic-user-a" },
    { ...payload, timezone: "Not/AZone" }, enabledControl, 100), /invalid-timezone/);
});

test("disabled control rejects the unexported settings contract", () => {
  assert.throws(() => validateMonthlyStorySettingsContract({ uid: "synthetic-user-a" },
    { enabled: false, useJournalThemes: false, useHealthPatterns: false, audioEnabled: false,
      timezone: "UTC", timezoneEffectiveMonth: "2026-08", settingsVersion: 1 },
    { ...SAFE_DISABLED_MONTHLY_STORY_CONTROL }, 100), /feature-disabled/);
});

test("signal schema matches Swift limits and accepts only structured buckets", () => {
  assert.equal(MONTHLY_STORY_MAX_EVIDENCE_ITEMS, 64);
  assert.equal(MONTHLY_STORY_MAX_DAYS_PER_SET, 31);
  const parsed = parseMonthlyStorySignal(validSignal());
  assert.equal(parsed.evidence.length, 4);
  assert.equal(parsed.monthKey, "2026-07");
  const json = JSON.stringify(parsed).toLowerCase();
  for (const prohibited of ["rawjournal", "gratitude", "recommendationtitle", "url", "stepcount",
    "sleepduration", "crisisreason", "deviceid", "email", "uid"]) assert.equal(json.includes(prohibited), false);
});

test("backend signal limits and enum vocabulary stay in parity with the Stage 2 Swift foundation", () => {
  const root = join(__dirname, "..", "..");
  const swiftSignal = readFileSync(join(root, "Dino", "Models", "MonthlyStorySignal.swift"), "utf8");
  const swiftEvidence = readFileSync(join(root, "Dino", "Models", "MonthlyStoryEvidence.swift"), "utf8");
  assert.match(swiftSignal, /maximumEvidenceItems = 64/);
  assert.match(swiftSignal, /maximumDaysPerSet = 31/);
  for (const token of ["emotionalShape", "repeatedTheme", "sleepPattern", "movementPattern",
    "restorativePractice", "recommendationAction", "nextMonthSuggestionBasis", "authorizedJournalTheme",
    "authorizedHealthSummary"]) assert.match(swiftEvidence, new RegExp(`case ${token}`));
});

test("signal rejects unknown fields, arbitrary strings, duplicates, and outside-month evidence", () => {
  assert.throws(() => parseMonthlyStorySignal({ ...validSignal(), rawJournalText: "synthetic private text" }),
    /unknown-field/);
  const duplicate = validSignal();
  duplicate.evidence = [
    evidence("evidence-same", { type: "restorativePractice", practice: "focus" }, "practicePresence"),
    evidence("evidence-same", { type: "restorativePractice", practice: "focus" }, "practicePresence"),
  ];
  assert.throws(() => parseMonthlyStorySignal(duplicate), /duplicate-evidence-id/);
  const invalidEvidenceId = validSignal();
  invalidEvidenceId.evidence = [
    evidence("evidence..id", { type: "restorativePractice", practice: "focus" }, "practicePresence"),
  ];
  assert.throws(() => parseMonthlyStorySignal(invalidEvidenceId), /invalid-evidence-id/);
  const outside = validSignal();
  outside.evidence = [{ ...evidence("evidence-away", { type: "restorativePractice", practice: "focus" },
    "practicePresence"), endDay: "2026-08-01" }];
  assert.throws(() => parseMonthlyStorySignal(outside), /evidence-outside-month/);
});

test("signal enforces the exact 31-day and 64-evidence boundaries", () => {
  const atLimit = validSignal();
  atLimit.evidence = Array.from({ length: 64 }, (_, index) =>
    evidence(`evidence-${String(index).padStart(2, "0")}`,
      { type: "restorativePractice", practice: "focus" }, "practicePresence"));
  assert.equal(parseMonthlyStorySignal(atLimit).evidence.length, 64);
  const aboveEvidenceLimit = { ...atLimit,
    evidence: [...atLimit.evidence as Record<string, unknown>[],
      evidence("evidence-over", { type: "restorativePractice", practice: "focus" }, "practicePresence")] };
  assert.throws(() => parseMonthlyStorySignal(aboveEvidenceLimit), /evidence-limit/);
  assert.throws(() => parseMonthlyStorySignal({ ...validSignal(),
    usableEvidenceDays: [...Array.from({ length: 31 }, (_, index) => day(index + 1)), day(1)] }), /array-limit/);
});

test("signal rejects permission mismatch and safety-ineligible status", () => {
  const journalDenied = validSignal();
  journalDenied.permissions = { featureEnabled: true, journalThemesEnabled: false,
    healthPatternsEnabled: true, audioEnabled: false };
  assert.throws(() => parseMonthlyStorySignal(journalDenied), /journal-permission-required/);
  const healthDenied = validSignal();
  healthDenied.permissions = { featureEnabled: true, journalThemesEnabled: true,
    healthPatternsEnabled: false, audioEnabled: false };
  assert.throws(() => parseMonthlyStorySignal(healthDenied), /health-permission-required/);
  assert.throws(() => parseMonthlyStorySignal({ ...validSignal(), isStorySafetyEligible: false }),
    /safety-ineligible/);
});

test("signal upload contract fails closed and uses authenticated UID", () => {
  assert.throws(() => validateMonthlyStorySignalUploadContract({ uid: "synthetic-user-a" }, validSignal(),
    { ...SAFE_DISABLED_MONTHLY_STORY_CONTROL }, settings), /signal-upload-disabled/);
  const accepted = validateMonthlyStorySignalUploadContract({ uid: "synthetic-user-a" }, validSignal(),
    enabledControl, settings);
  assert.equal(accepted.uid, "synthetic-user-a");
  assert.equal(Object.prototype.hasOwnProperty.call(accepted.signal, "uid"), false);
  assert.throws(() => validateMonthlyStorySignalUploadContract({ uid: "synthetic-user-a" },
    { ...validSignal(), uid: "synthetic-user-b" }, enabledControl, settings), /unknown-field/);
});

// Mirrors the client declaration built by
// Dino/Services/MonthlyStorySignalCoordinator.swift (`permissions(for:)`), which must equal the
// stored settings field for field. Same comparison as monthlyStoryGenerationService.ts:215-219.
test("client permissions mirroring stored settings are accepted, audio on and themes on with no theme evidence",
  () => {
    const stored: MonthlyStorySettings = { ...settings, audioEnabled: true, useJournalThemes: true,
      useHealthPatterns: true };
    const signal = validSignal();
    signal.permissions = { featureEnabled: true, journalThemesEnabled: true,
      healthPatternsEnabled: true, audioEnabled: true };
    // Theme learning off locally: the permission is granted, but no repeatedTheme evidence exists.
    signal.evidence = (signal.evidence as Record<string, unknown>[])
      .filter((item) => (item.value as Record<string, string>).type !== "repeatedTheme");
    assert.equal((signal.evidence as Record<string, unknown>[]).some((item) =>
      (item.value as Record<string, string>).type === "repeatedTheme"), false);

    const accepted = validateMonthlyStorySignalUploadContract({ uid: "synthetic-user-a" }, signal,
      enabledControl, stored);
    assert.equal(accepted.signal.permissions.audioEnabled, true);
    assert.equal(accepted.signal.permissions.journalThemesEnabled, true);

    // The shape the client used to send against these settings: hardcoded audio off and journal
    // themes narrowed by the local learning preference.
    const drifted = { ...signal, permissions: { featureEnabled: true, journalThemesEnabled: false,
      healthPatternsEnabled: true, audioEnabled: false } };
    assert.throws(() => validateMonthlyStorySignalUploadContract({ uid: "synthetic-user-a" }, drifted,
      enabledControl, stored), /settings-mismatch/);
  });

test("story and tombstone schemas are metadata-only and strict", () => {
  const storageCleanup = { state: "notRequired", updatedAtMillis: 10 };
  const story = parseMonthlyStoryDocument({ monthKey: "2026-07", generationVersion: "v1",
    status: "pending", signalSchemaVersion: 1, createdAtMillis: 10, updatedAtMillis: 10,
    expiresAtMillis: 20, storageCleanup });
  assert.equal(story.status, "pending");
  assert.throws(() => parseMonthlyStoryDocument({ ...story, script: "not accepted" }), /unknown-field/);
  const tombstone = parseMonthlyStoryDeletedTombstone({ monthKey: "2026-07", generationVersion: "v1",
    reason: "accountDeletion", deletedAtMillis: 10, expiresAtMillis: 20,
    storageCleanup: { state: "pending", updatedAtMillis: 10 } });
  assert.equal(tombstone.reason, "accountDeletion");
  assert.equal(MONTHLY_STORY_PATHS.story("synthetic-user-a", "2026-07"),
    "monthlyStories/synthetic-user-a/months/2026-07");
  assert.equal(MONTHLY_STORY_PATHS.audio("synthetic-user-a", "2026-07", "v1"),
    "monthlyStories/synthetic-user-a/2026-07/v1/story.mp3");
});
