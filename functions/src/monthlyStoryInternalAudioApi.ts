import { MonthlyStoryAudioObjectStore, MonthlyStoryAudioRepository,
  MonthlyStoryAudioServiceError, generateMonthlyStoryAudio } from "./monthlyStoryAudioService";
import { MonthlyStoryAudioProvider } from "./monthlyStoryAudioProvider";
import { MonthlyStoryControl, monthlyStoryAudioGenerationIsFailClosed } from "./monthlyStoryControl";
import { requireMonthlyStoryInternalAvailability } from "./monthlyStoryInternalAccess";
import { MonthlyStoryInternalApiContext, MonthlyStoryInternalApiError } from "./monthlyStoryInternalApi";
import { MonthlyStoryRepository } from "./monthlyStoryRepository";
import { parseMonthlyStorySettingsDocument, requireGenerationVersion, requireMonthKey } from "./monthlyStorySchema";

function payload(value: unknown): { monthKey: string; generationVersion: string } {
  if (typeof value !== "object" || value === null || Array.isArray(value)) throw new MonthlyStoryInternalApiError("invalid-argument");
  const data = value as Record<string, unknown>; const keys = Object.keys(data);
  if (keys.length !== 2 || !keys.includes("monthKey") || !keys.includes("generationVersion")) {
    throw new MonthlyStoryInternalApiError("invalid-argument");
  }
  return { monthKey: requireMonthKey(data.monthKey), generationVersion: requireGenerationVersion(data.generationVersion) };
}

function apiError(error: unknown): MonthlyStoryInternalApiError {
  if (error instanceof MonthlyStoryInternalApiError) return error;
  if (error instanceof MonthlyStoryAudioServiceError) {
    if (["audio-disabled", "settings-disabled", "story-deleted", "script-too-large"].includes(error.code)) {
      return new MonthlyStoryInternalApiError("failed-precondition");
    }
    if (error.code === "story-missing") return new MonthlyStoryInternalApiError("not-found");
    if (error.code === "audio-active") return new MonthlyStoryInternalApiError("already-exists");
    if (["attempt-limit", "daily-cap", "monthly-cap", "budget-denied"].includes(error.code)) {
      return new MonthlyStoryInternalApiError("resource-exhausted");
    }
  }
  const code = error instanceof Error && "code" in error ? String((error as { code: unknown }).code) : "";
  if (code === "authentication-required") return new MonthlyStoryInternalApiError("unauthenticated");
  if (code === "internal-access-denied") return new MonthlyStoryInternalApiError("permission-denied");
  return new MonthlyStoryInternalApiError("internal");
}

export function createMonthlyStoryInternalAudioApi(dependencies: { repository: MonthlyStoryRepository;
  audioRepository: MonthlyStoryAudioRepository; objectStore: MonthlyStoryAudioObjectStore;
  providerFactory(control: MonthlyStoryControl): MonthlyStoryAudioProvider }) {
  return async (context: MonthlyStoryInternalApiContext, request: unknown) => {
    try {
      const requested = payload(request);
      const access = await requireMonthlyStoryInternalAvailability({ ...context, repository: dependencies.repository });
      const settings = parseMonthlyStorySettingsDocument(await dependencies.repository.loadSettingsDocument(access.uid));
      if (monthlyStoryAudioGenerationIsFailClosed(access.control) || !settings.enabled || !settings.audioEnabled) {
        throw new MonthlyStoryInternalApiError("failed-precondition");
      }
      const result = await generateMonthlyStoryAudio({ uid: access.uid, monthKey: requested.monthKey,
        generationVersion: requested.generationVersion, nowMillis: context.nowMillis, control: access.control,
        audioSettingEnabled: settings.enabled && settings.audioEnabled,
        repository: dependencies.audioRepository, objectStore: dependencies.objectStore,
        provider: dependencies.providerFactory(access.control) });
      return { story: result.story, reused: result.reused };
    } catch (error) { throw apiError(error); }
  };
}
