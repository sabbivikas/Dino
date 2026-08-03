import { monthlyStoryScriptHash } from "./monthlyStoryArtifact";
import { MonthlyStoryControl, monthlyStoryGenerationIsFailClosed,
  parseMonthlyStoryControl } from "./monthlyStoryControl";
import { MonthlyStoryDeterministicComposerError, MonthlyStoryDeterministicComposerInput,
  MonthlyStoryDeterministicComposition,
  composeMonthlyStoryDeterministically } from "./monthlyStoryDeterministicComposer";
import { acquireMonthlyStoryJobLease, createMonthlyStoryJobIfAbsent,
  recordMonthlyStoryJobFailure } from "./monthlyStoryJobs";
import { buildMonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions,
  monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";
import { MonthlyStoryPersistedText, MonthlyStoryRepository,
  MONTHLY_STORY_PERSISTENCE_VALIDATION_VERSION,
  MONTHLY_STORY_REPOSITORY_OWNER_KEY_VERSION } from "./monthlyStoryRepository";
import { createMonthlyStoryRetentionMetadata } from "./monthlyStoryRetention";
import { monthlyStoryOwnerKey, monthlyStoryRolloutEligible } from "./monthlyStoryRollout";
import { validateMonthlyStoryScript } from "./monthlyStoryScriptValidator";
import { MonthlyStorySignal, authenticatedMonthlyStoryUid, monthlyStoryTombstoneBlocks,
  parseMonthlyStorySettingsDocument, parseMonthlyStorySignal, requireGenerationVersion,
  requireMonthKey } from "./monthlyStorySchema";

export const MONTHLY_STORY_INTERNAL_OWNER_KEY_VERSION = MONTHLY_STORY_REPOSITORY_OWNER_KEY_VERSION;
export const MONTHLY_STORY_INTERNAL_LEASE_MILLIS = 5 * 60 * 1000;
export const MONTHLY_STORY_INTERNAL_RETRY_DELAY_MILLIS = 60 * 1000;

export type MonthlyStoryEligibilityResult = {
  eligible: boolean;
  code: "eligibleStandard" | "eligibleMoodOnly" | "featureDisabled" | "insufficientSpan" |
    "insufficientEvidenceDays" | "insufficientMoodDays" | "insufficientCorroboration" |
    "insufficientObservations" | "monthNotClosed" | "invalidTimezone";
  permitsCauseNarration: boolean;
};

export type MonthlyStoryGenerationServiceInput = {
  uid: string;
  monthKey: string;
  generationVersion: string;
  nowMillis: number;
  workerId: string;
  repository: MonthlyStoryRepository;
  composer?: (input: MonthlyStoryDeterministicComposerInput) => MonthlyStoryDeterministicComposition;
};

export type MonthlyStoryGenerationServiceResult = {
  story: MonthlyStoryPersistedText;
  jobId: string;
  compositionMode: "deterministic";
  providerRequestCount: 0;
  providerCostMicros: 0;
  duplicate: boolean;
};

export type MonthlyStoryGenerationErrorCode = "invalid-input" | "control-disabled" | "control-invalid" |
  "generation-version-mismatch" | "settings-disabled" | "rollout-ineligible" | "signal-missing" |
  "signal-invalid" | "settings-mismatch" | "month-not-closed" | "eligibility-failed" |
  "safety-hold" | "deleted-tombstone" | "story-already-exists" | "job-completed" |
  "lease-unavailable" | "operational-cap" | "composition-failed" | "validation-failed" |
  "persistence-failed";

export class MonthlyStoryGenerationError extends Error {
  constructor(readonly code: MonthlyStoryGenerationErrorCode) {
    super(code);
    this.name = "MonthlyStoryGenerationError";
  }
}

function validNow(value: number): number {
  if (!Number.isSafeInteger(value) || value < 0) throw new MonthlyStoryGenerationError("invalid-input");
  return value;
}

function localParts(instant: number, timeZone: string): number[] {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone, hour12: false, year: "numeric", month: "2-digit",
    day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" }).formatToParts(instant);
  const value = (type: string): number => Number(parts.find((part) => part.type === type)?.value);
  return [value("year"), value("month"), value("day"), value("hour") % 24, value("minute"), value("second")];
}

function zonedInstant(year: number, month: number, day: number, hour: number, timeZone: string): number {
  const target = Date.UTC(year, month - 1, day, hour);
  let candidate = target;
  for (let index = 0; index < 3; index += 1) {
    const parts = localParts(candidate, timeZone);
    const observed = Date.UTC(parts[0], parts[1] - 1, parts[2], parts[3], parts[4], parts[5]);
    candidate += target - observed;
  }
  return candidate;
}

export function monthlyStoryEvidenceFreezeMillis(monthKey: string, timeZone: string): number {
  const month = requireMonthKey(monthKey);
  try {
    new Intl.DateTimeFormat("en-US", { timeZone }).format(0);
  } catch {
    throw new MonthlyStoryGenerationError("invalid-input");
  }
  const year = Number(month.slice(0, 4));
  const monthNumber = Number(month.slice(5, 7));
  const next = new Date(Date.UTC(year, monthNumber, 1));
  return zonedInstant(next.getUTCFullYear(), next.getUTCMonth() + 1, 3, 4, timeZone);
}

export function recalculateMonthlyStoryEligibility(signal: MonthlyStorySignal, nowMillis: number,
  settingsTimeZone: string): MonthlyStoryEligibilityResult {
  if (!signal.permissions.featureEnabled) return { eligible: false, code: "featureDisabled",
    permitsCauseNarration: false };
  if (signal.timeZone !== settingsTimeZone) return { eligible: false, code: "invalidTimezone",
    permitsCauseNarration: false };
  if (nowMillis < monthlyStoryEvidenceFreezeMillis(signal.monthKey, settingsTimeZone)) {
    return { eligible: false, code: "monthNotClosed", permitsCauseNarration: false };
  }
  const span = (Date.parse(`${signal.evidenceEndDay}T12:00:00.000Z`) -
    Date.parse(`${signal.evidenceStartDay}T12:00:00.000Z`)) / 86_400_000;
  if (!Number.isInteger(span) || span < 14) return { eligible: false, code: "insufficientSpan",
    permitsCauseNarration: false };
  const observations = signal.evidence.filter((item) => item.allowedForNarration && item.confidence === "high").length;
  if (signal.usableEvidenceDays.length >= 6 && signal.moodEvidenceDays.length >= 4 &&
      signal.corroboratingEvidenceDays.length >= 2) {
    if (observations < 2) return { eligible: false, code: "insufficientObservations",
      permitsCauseNarration: false };
    return { eligible: true, code: "eligibleStandard", permitsCauseNarration: true };
  }
  if (signal.moodEvidenceDays.length >= 8) {
    if (observations < 2) return { eligible: false, code: "insufficientObservations",
      permitsCauseNarration: false };
    return { eligible: true, code: "eligibleMoodOnly", permitsCauseNarration: false };
  }
  if (signal.usableEvidenceDays.length < 6) return { eligible: false, code: "insufficientEvidenceDays",
    permitsCauseNarration: false };
  if (signal.moodEvidenceDays.length < 4) return { eligible: false, code: "insufficientMoodDays",
    permitsCauseNarration: false };
  return { eligible: false, code: "insufficientCorroboration", permitsCauseNarration: false };
}

function controlAllowsGeneration(control: MonthlyStoryControl): boolean {
  return control.visible && control.enrollmentEnabled && control.signalUploadEnabled &&
    control.textGenerationEnabled && !monthlyStoryGenerationIsFailClosed(control) &&
    control.generationVersion.length > 0 && control.signalSchemaVersion > 0;
}

function monthDisplayName(monthKey: string): string {
  const [year, month] = monthKey.split("-").map(Number);
  return new Intl.DateTimeFormat("en-US", { month: "long", timeZone: "UTC" })
    .format(new Date(Date.UTC(year, month - 1, 1)));
}

function dayKey(nowMillis: number): string {
  return new Date(nowMillis).toISOString().slice(0, 10);
}

function monthlyOperationalCap(control: MonthlyStoryControl): number {
  return Math.min(1_000_000, control.dailyTextGenerationCap * 31);
}

function persistedStory(input: { composition: MonthlyStoryDeterministicComposition; signal: MonthlyStorySignal;
  control: MonthlyStoryControl; nowMillis: number }): MonthlyStoryPersistedText {
  const retention = createMonthlyStoryRetentionMetadata(input.signal.monthKey, input.nowMillis);
  return { monthKey: input.signal.monthKey, generationVersion: input.control.generationVersion,
    compositionVersion: input.composition.compositionVersion,
    signalSchemaVersion: input.signal.schemaVersion, status: "textReady", script: input.composition.script,
    paragraphs: [...input.composition.paragraphs], wordCount: input.composition.wordCount,
    profile: input.composition.profile, usedEvidenceIds: [...input.composition.usedEvidenceIds],
    usedClaimKeys: [...input.composition.usedClaimKeys],
    usedSuggestionKeys: [...input.composition.usedSuggestionKeys],
    scriptHash: monthlyStoryScriptHash(input.composition.script), createdAtMillis: input.nowMillis,
    finalizedAtMillis: retention.finalizedAtMillis, expiresAtMillis: retention.expiresAtMillis,
    audioStatus: "notRequested", deletionState: "active",
    validationVersion: MONTHLY_STORY_PERSISTENCE_VALIDATION_VERSION,
    compositionMode: "deterministic", providerRequestCount: 0, providerCostMicros: 0,
    storageCleanup: { state: "notRequired", updatedAtMillis: input.nowMillis } };
}

function mapPreLeaseError(error: unknown): MonthlyStoryGenerationError {
  if (error instanceof MonthlyStoryGenerationError) return error;
  if (error instanceof MonthlyStoryDeterministicComposerError) {
    return new MonthlyStoryGenerationError("composition-failed");
  }
  const message = error instanceof Error ? error.message : "";
  if (message === "tombstoned") return new MonthlyStoryGenerationError("deleted-tombstone");
  if (message === "lease-active" || message === "retry-not-due") {
    return new MonthlyStoryGenerationError("lease-unavailable");
  }
  if (message === "terminal-state") return new MonthlyStoryGenerationError("job-completed");
  if (message.includes("generation-cap")) return new MonthlyStoryGenerationError("operational-cap");
  return new MonthlyStoryGenerationError("persistence-failed");
}

async function loadValidatedGenerationContext(repository: MonthlyStoryRepository, uid: string,
  monthKey: string, generationVersion: string, nowMillis: number) {
  const controlResult = parseMonthlyStoryControl(await repository.loadControlDocument(), nowMillis);
  if (!controlResult.accepted) throw new MonthlyStoryGenerationError("control-invalid");
  const control = controlResult.control;
  if (!controlAllowsGeneration(control)) throw new MonthlyStoryGenerationError("control-disabled");
  if (control.generationVersion !== generationVersion) {
    throw new MonthlyStoryGenerationError("generation-version-mismatch");
  }
  let settings;
  try {
    settings = parseMonthlyStorySettingsDocument(await repository.loadSettingsDocument(uid));
  } catch {
    throw new MonthlyStoryGenerationError("settings-disabled");
  }
  if (!settings.enabled) throw new MonthlyStoryGenerationError("settings-disabled");
  if (!monthlyStoryRolloutEligible(uid, generationVersion, control.rolloutBasisPoints)) {
    throw new MonthlyStoryGenerationError("rollout-ineligible");
  }
  const rawSignal = await repository.loadSignalDocument(uid, monthKey);
  if (rawSignal === null) throw new MonthlyStoryGenerationError("signal-missing");
  let signal: MonthlyStorySignal;
  try { signal = parseMonthlyStorySignal(rawSignal); } catch (error) {
    if (error instanceof Error && error.message === "safety-ineligible") {
      throw new MonthlyStoryGenerationError("safety-hold");
    }
    throw new MonthlyStoryGenerationError("signal-invalid");
  }
  if (signal.monthKey !== monthKey || signal.schemaVersion !== control.signalSchemaVersion) {
    throw new MonthlyStoryGenerationError("signal-invalid");
  }
  if (signal.permissions.featureEnabled !== settings.enabled ||
      signal.permissions.journalThemesEnabled !== settings.useJournalThemes ||
      signal.permissions.healthPatternsEnabled !== settings.useHealthPatterns ||
      signal.permissions.audioEnabled !== settings.audioEnabled || signal.timeZone !== settings.timezone) {
    throw new MonthlyStoryGenerationError("settings-mismatch");
  }
  const eligibility = recalculateMonthlyStoryEligibility(signal, nowMillis, settings.timezone);
  if (!eligibility.eligible) throw new MonthlyStoryGenerationError(
    eligibility.code === "monthNotClosed" ? "month-not-closed" : "eligibility-failed");
  signal = { ...signal, eligibility: { code: eligibility.code,
    permitsCauseNarration: eligibility.permitsCauseNarration } };
  return { control, signal };
}

export async function runMonthlyStoryGenerationInternal(input: MonthlyStoryGenerationServiceInput):
Promise<MonthlyStoryGenerationServiceResult> {
  let uid: string;
  let monthKey: string;
  let generationVersion: string;
  let nowMillis: number;
  try {
    uid = authenticatedMonthlyStoryUid({ uid: input.uid });
    monthKey = requireMonthKey(input.monthKey);
    generationVersion = requireGenerationVersion(input.generationVersion);
    nowMillis = validNow(input.nowMillis);
  } catch {
    throw new MonthlyStoryGenerationError("invalid-input");
  }
  if (!/^[A-Za-z0-9._-]{1,64}$/.test(input.workerId)) throw new MonthlyStoryGenerationError("invalid-input");

  let { control, signal } = await loadValidatedGenerationContext(input.repository, uid, monthKey,
    generationVersion, nowMillis);
  const tombstone = await input.repository.loadDeletedTombstone(uid, monthKey);
  if (monthlyStoryTombstoneBlocks(tombstone, monthKey, generationVersion, nowMillis)) {
    throw new MonthlyStoryGenerationError("deleted-tombstone");
  }
  if (await input.repository.loadStory(uid, monthKey)) {
    throw new MonthlyStoryGenerationError("story-already-exists");
  }

  // Re-read every mutable gate directly before creating or leasing a job.
  ({ control, signal } = await loadValidatedGenerationContext(input.repository, uid, monthKey,
    generationVersion, nowMillis));

  const ownerKey = monthlyStoryOwnerKey(uid, MONTHLY_STORY_INTERNAL_OWNER_KEY_VERSION);
  const jobs = input.repository.jobRepository(uid, ownerKey);
  let jobId = "";
  let leaseAcquired = false;
  try {
    const created = await createMonthlyStoryJobIfAbsent(jobs, { uid,
      ownerKeyVersion: MONTHLY_STORY_INTERNAL_OWNER_KEY_VERSION, monthKey, generationVersion, nowMillis });
    jobId = created.job.jobId;
    await acquireMonthlyStoryJobLease(jobs, { jobId, stage: "text", leaseOwner: input.workerId,
      nowMillis, leaseDurationMillis: MONTHLY_STORY_INTERNAL_LEASE_MILLIS,
      maximumAttempts: control.maxTextAttempts });
    leaseAcquired = true;
    await input.repository.reserveDeterministicGenerationSlot({ jobId, monthKey, dayKey: dayKey(nowMillis),
      dailyCap: control.dailyTextGenerationCap, monthlyCap: monthlyOperationalCap(control), nowMillis });
    const plan = buildMonthlyStoryNarrativePlan(signal);
    const compose = input.composer ?? composeMonthlyStoryDeterministically;
    const composition = compose({ plan, profile: monthlyStoryWordTarget(plan).narrativeClass,
      closedClaims: monthlyStoryPlanClaimOptions(plan),
      approvedSuggestionKeys: plan.nextMonthSuggestionBases.map((claim) => claim.key),
      monthDisplayName: monthDisplayName(monthKey), language: "en", generationVersion,
      stableUserHash: ownerKey });
    const validation = validateMonthlyStoryScript({ script: composition.script,
      claimedEvidenceIds: composition.usedEvidenceIds, claimKeys: composition.usedClaimKeys,
      plan, availableEvidence: signal.evidence });
    if (!validation.isValid) throw new MonthlyStoryGenerationError("validation-failed");
    const story = persistedStory({ composition, signal, control, nowMillis });
    const saved = await input.repository.persistStoryAndCompleteJob({ uid, story, jobId,
      leaseOwner: input.workerId, nowMillis });
    return { story: saved.story, jobId, compositionMode: "deterministic", providerRequestCount: 0,
      providerCostMicros: 0, duplicate: saved.duplicate };
  } catch (error) {
    const mapped = mapPreLeaseError(error);
    if (leaseAcquired && jobId) {
      const terminal = mapped.code === "composition-failed" || mapped.code === "validation-failed";
      try {
        await recordMonthlyStoryJobFailure(jobs, { jobId, stage: "text", leaseOwner: input.workerId,
          nowMillis, failureCode: terminal ? "schemaInvalid" : "persistenceFailure",
          ...(terminal ? {} : { nextAttemptAtMillis: nowMillis + MONTHLY_STORY_INTERNAL_RETRY_DELAY_MILLIS }) });
      } catch {
        throw new MonthlyStoryGenerationError("persistence-failed");
      }
    }
    throw mapped;
  }
}
