import { runMonthlyStoryGenerationInternal } from "./monthlyStoryGenerationService";
import { requireMonthlyStoryInternalAccount, requireMonthlyStoryInternalAvailability } from "./monthlyStoryInternalAccess";
import { MonthlyStoryRepository } from "./monthlyStoryRepository";
import { monthlyStoryTombstoneExpiresAtMillis } from "./monthlyStoryRetention";
import { MonthlyStoryValidationError, parseMonthlyStorySettingsDocument,
  requireGenerationVersion, requireMonthKey, validateMonthlyStorySettingsContract,
  validateMonthlyStorySignalUploadContract } from "./monthlyStorySchema";

export class MonthlyStoryInternalApiError extends Error {
  constructor(readonly code: "unauthenticated" | "permission-denied" | "failed-precondition" |
    "invalid-argument" | "not-found" | "already-exists" | "resource-exhausted" | "internal") {
    super(code);
    this.name = "MonthlyStoryInternalApiError";
  }
}

export type MonthlyStoryInternalApiContext = { auth: { uid?: unknown } | null | undefined;
  appVersion: string; nowMillis: number };

function exactPayload(value: unknown, fields: readonly string[]): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new MonthlyStoryInternalApiError("invalid-argument");
  }
  const data = value as Record<string, unknown>;
  if (Object.keys(data).length !== fields.length || Object.keys(data).some((key) => !fields.includes(key))) {
    throw new MonthlyStoryInternalApiError("invalid-argument");
  }
  return data;
}

function mapError(error: unknown): MonthlyStoryInternalApiError {
  if (error instanceof MonthlyStoryInternalApiError) return error;
  const code = error instanceof Error && "code" in error ? String((error as { code: unknown }).code) : "";
  if (code === "authentication-required") return new MonthlyStoryInternalApiError("unauthenticated");
  if (code === "internal-access-denied") return new MonthlyStoryInternalApiError("permission-denied");
  if (["feature-unavailable", "app-version-unsupported", "control-disabled", "control-invalid",
    "settings-disabled", "signal-upload-disabled", "settings-mismatch", "safety-hold", "safety-ineligible",
    "month-not-closed", "eligibility-failed"].includes(code)) return new MonthlyStoryInternalApiError("failed-precondition");
  if (["invalid-input", "invalid-object", "unknown-field", "missing-field", "invalid-token",
    "invalid-month", "invalid-timezone", "unsupported-settings-version", "signal-invalid",
    "generation-version-mismatch"]
    .includes(code)) return new MonthlyStoryInternalApiError("invalid-argument");
  if (code === "signal-missing") return new MonthlyStoryInternalApiError("not-found");
  if (["deleted-tombstone", "story-already-exists", "job-completed", "lease-unavailable"]
    .includes(code)) return new MonthlyStoryInternalApiError("already-exists");
  if (code === "operational-cap") return new MonthlyStoryInternalApiError("resource-exhausted");
  return new MonthlyStoryInternalApiError("internal");
}

export function createMonthlyStoryInternalApi(repository: MonthlyStoryRepository) {
  return {
    availability: async (context: MonthlyStoryInternalApiContext) => {
      try {
        const { control } = await requireMonthlyStoryInternalAvailability({ ...context, repository });
        return { visible: true, enrollmentEnabled: true, signalUploadEnabled: control.signalUploadEnabled,
          textGenerationEnabled: control.textGenerationEnabled, generationVersion: control.generationVersion,
          signalSchemaVersion: control.signalSchemaVersion };
      } catch (error) { throw mapError(error); }
    },
    loadSettings: async (context: MonthlyStoryInternalApiContext) => {
      try {
        const { uid } = await requireMonthlyStoryInternalAvailability({ ...context, repository });
        return parseMonthlyStorySettingsDocument(await repository.loadSettingsDocument(uid));
      } catch (error) { throw mapError(error); }
    },
    updateSettings: async (context: MonthlyStoryInternalApiContext, payload: unknown) => {
      try {
        const access = await requireMonthlyStoryInternalAvailability({ ...context, repository });
        const validated = validateMonthlyStorySettingsContract({ uid: access.uid }, payload,
          access.control, context.nowMillis);
        const settings: Record<string, unknown> = { enabled: validated.settings.enabled,
          useJournalThemes: validated.settings.useJournalThemes,
          useHealthPatterns: validated.settings.useHealthPatterns, audioEnabled: false,
          timezone: validated.settings.timezone,
          timezoneEffectiveMonth: validated.settings.timezoneEffectiveMonth,
          settingsVersion: validated.settings.settingsVersion, updatedAt: context.nowMillis };
        await repository.saveSettingsDocument(access.uid, settings);
        return parseMonthlyStorySettingsDocument(settings);
      } catch (error) { throw mapError(error); }
    },
    loadStory: async (context: MonthlyStoryInternalApiContext, payload: unknown) => {
      try {
        const data = exactPayload(payload, ["monthKey"]);
        const uid = await requireMonthlyStoryInternalAccount({ ...context, repository });
        const story = await repository.loadStory(uid, requireMonthKey(data.monthKey));
        return { story };
      } catch (error) { throw mapError(error); }
    },
    generate: async (context: MonthlyStoryInternalApiContext, payload: unknown) => {
      try {
        const data = exactPayload(payload, ["monthKey", "generationVersion", "signal"]);
        const access = await requireMonthlyStoryInternalAvailability({ ...context, repository });
        const monthKey = requireMonthKey(data.monthKey);
        const generationVersion = requireGenerationVersion(data.generationVersion);
        if (generationVersion !== access.control.generationVersion) {
          throw new MonthlyStoryValidationError("generation-version-mismatch");
        }
        const settings = parseMonthlyStorySettingsDocument(await repository.loadSettingsDocument(access.uid));
        const validated = validateMonthlyStorySignalUploadContract({ uid: access.uid }, data.signal,
          access.control, settings);
        if (validated.signal.monthKey !== monthKey) throw new MonthlyStoryValidationError("invalid-month");
        const storedSignal = { schemaVersion: validated.signal.schemaVersion,
          monthKey: validated.signal.monthKey, timeZone: validated.signal.timeZone,
          evidenceStartDay: validated.signal.evidenceStartDay, evidenceEndDay: validated.signal.evidenceEndDay,
          usableEvidenceDays: validated.signal.usableEvidenceDays,
          moodEvidenceDays: validated.signal.moodEvidenceDays,
          corroboratingEvidenceDays: validated.signal.corroboratingEvidenceDays,
          permissions: validated.signal.permissions, isStorySafetyEligible: true,
          evidence: validated.signal.evidence.map((item) => ({ id: item.id, value: item.value,
            confidence: item.confidence, startDay: item.startDay, endDay: item.endDay,
            source: item.source, allowedForNarration: item.allowedForNarration })),
          ...(validated.signal.eligibility ? { eligibility: validated.signal.eligibility } : {}) };
        await repository.saveSignalDocument(access.uid, monthKey, storedSignal);
        const existing = await repository.loadStory(access.uid, monthKey);
        if (existing) return { story: existing, reused: true };
        const result = await runMonthlyStoryGenerationInternal({ uid: access.uid, monthKey, generationVersion,
          nowMillis: context.nowMillis, workerId: `internal-${context.nowMillis}`, repository });
        return { story: result.story, reused: result.duplicate };
      } catch (error) { throw mapError(error); }
    },
    deleteStory: async (context: MonthlyStoryInternalApiContext, payload: unknown) => {
      try {
        const data = exactPayload(payload, ["monthKey", "generationVersion"]);
        const uid = await requireMonthlyStoryInternalAccount({ ...context, repository });
        const monthKey = requireMonthKey(data.monthKey);
        await repository.deleteStoryAndCreateTombstone({ uid, monthKey,
          generationVersion: requireGenerationVersion(data.generationVersion), nowMillis: context.nowMillis,
          expiresAtMillis: monthlyStoryTombstoneExpiresAtMillis(monthKey) });
        return { deleted: true };
      } catch (error) { throw mapError(error); }
    },
  };
}
