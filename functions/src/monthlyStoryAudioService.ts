import { createHash, randomUUID } from "crypto";
import { MonthlyStoryAudioProvider, MonthlyStoryAudioProviderError, estimatedHumeCostMicros,
  validateMonthlyStoryMp3 } from "./monthlyStoryAudioProvider";
import { MonthlyStoryControl, monthlyStoryAudioGenerationIsFailClosed } from "./monthlyStoryControl";
import { MonthlyStoryPersistedText } from "./monthlyStoryRepository";
import { requireGenerationVersion, requireMonthKey } from "./monthlyStorySchema";

export const MONTHLY_STORY_AUDIO_LEASE_MILLIS = 2 * 60 * 1000;

export class MonthlyStoryAudioServiceError extends Error {
  constructor(readonly code: "audio-disabled" | "settings-disabled" | "story-missing" | "story-mismatch" |
    "story-deleted" | "audio-active" | "attempt-limit" | "daily-cap" | "monthly-cap" | "budget-denied" |
    "script-too-large" | "storage-failure" | "persistence-failure" | "provider-failure") {
    super(code); this.name = "MonthlyStoryAudioServiceError";
  }
}

export type MonthlyStoryAudioObject = { path: string; hash: string; bytes: number;
  durationMillis: number | null; generatedAtMillis: number; providerRequestCount: number;
  estimatedCostMicros: number; ttsVersion: string; voiceKey: string };

export interface MonthlyStoryAudioObjectStore {
  inspect(path: string): Promise<MonthlyStoryAudioObject | null>;
  write(path: string, audio: Buffer, metadata: Omit<MonthlyStoryAudioObject, "path" | "bytes">): Promise<void>;
  delete(path: string): Promise<void>;
}

export type AudioLeaseResult = { kind: "existing"; story: MonthlyStoryPersistedText } |
  { kind: "active" } | { kind: "acquired"; attempt: number; leaseOwner: string; reservedMicros: number };

export interface MonthlyStoryAudioRepository {
  loadStory(uid: string, monthKey: string): Promise<MonthlyStoryPersistedText | null>;
  hasActiveTombstone(uid: string, monthKey: string, generationVersion: string, nowMillis: number): Promise<boolean>;
  acquireAudioLease(input: { uid: string; monthKey: string; generationVersion: string; nowMillis: number;
    leaseOwner: string; leaseDurationMillis: number; maximumAttempts: number; reservationMicros: number;
    dailyCap: number; monthlyCap: number; monthlyBudgetMicros: number }): Promise<AudioLeaseResult>;
  markAudioReady(input: { uid: string; monthKey: string; generationVersion: string; leaseOwner: string;
    object: MonthlyStoryAudioObject; nowMillis: number }): Promise<MonthlyStoryPersistedText>;
  markAudioFailure(input: { uid: string; monthKey: string; generationVersion: string; leaseOwner: string;
    failureCode: string; transient: boolean; outcomeUncertain: boolean; billableMicros: number;
    nowMillis: number }): Promise<void>;
}

export function monthlyStoryAudioStoragePath(uid: string, monthKey: string, generationVersion: string): string {
  if (!/^[A-Za-z0-9._:-]{1,128}$/.test(uid)) throw new MonthlyStoryAudioServiceError("story-mismatch");
  return `monthlyStories/${uid}/${requireMonthKey(monthKey)}/${requireGenerationVersion(generationVersion)}/story.mp3`;
}

export async function generateMonthlyStoryAudio(input: { uid: string; monthKey: string;
  generationVersion: string; nowMillis: number; control: MonthlyStoryControl; audioSettingEnabled: boolean;
  repository: MonthlyStoryAudioRepository; objectStore: MonthlyStoryAudioObjectStore;
  provider: MonthlyStoryAudioProvider; workerId?: string }): Promise<{ story: MonthlyStoryPersistedText;
    reused: boolean; providerCalls: number }> {
  const monthKey = requireMonthKey(input.monthKey);
  const generationVersion = requireGenerationVersion(input.generationVersion);
  if (monthlyStoryAudioGenerationIsFailClosed(input.control)) throw new MonthlyStoryAudioServiceError("audio-disabled");
  if (!input.audioSettingEnabled) throw new MonthlyStoryAudioServiceError("settings-disabled");
  if (generationVersion !== input.control.generationVersion) throw new MonthlyStoryAudioServiceError("story-mismatch");
  if (await input.repository.hasActiveTombstone(input.uid, monthKey, generationVersion, input.nowMillis)) {
    throw new MonthlyStoryAudioServiceError("story-deleted");
  }
  const story = await input.repository.loadStory(input.uid, monthKey);
  if (!story) throw new MonthlyStoryAudioServiceError("story-missing");
  if (story.generationVersion !== generationVersion || story.deletionState !== "active") {
    throw new MonthlyStoryAudioServiceError("story-mismatch");
  }
  if (story.script.length > input.control.maximumAudioScriptCharacters) {
    throw new MonthlyStoryAudioServiceError("script-too-large");
  }
  const path = monthlyStoryAudioStoragePath(input.uid, monthKey, generationVersion);
  const existingObject = await input.objectStore.inspect(path);
  if (story.audioStatus === "ready") {
    if (!existingObject || existingObject.hash !== story.audioHash) {
      throw new MonthlyStoryAudioServiceError("storage-failure");
    }
    return { story, reused: true, providerCalls: 0 };
  }
  if (existingObject) {
    const reconciled = await input.repository.markAudioReady({ uid: input.uid, monthKey, generationVersion,
      leaseOwner: "object-reconciliation", object: existingObject, nowMillis: input.nowMillis });
    return { story: reconciled, reused: true, providerCalls: 0 };
  }
  const reservationMicros = estimatedHumeCostMicros(story.script.length,
    input.control.humeCostMicrosPerThousandCharacters);
  const leaseOwner = input.workerId ?? `audio-${randomUUID()}`;
  const lease = await input.repository.acquireAudioLease({ uid: input.uid, monthKey, generationVersion,
    nowMillis: input.nowMillis, leaseOwner, leaseDurationMillis: Math.max(MONTHLY_STORY_AUDIO_LEASE_MILLIS,
      input.control.audioRequestTimeoutSeconds * 1_000 + 30_000),
    maximumAttempts: Math.min(input.control.maxAudioAttempts, 2), reservationMicros,
    dailyCap: input.control.dailyAudioGenerationCap, monthlyCap: input.control.monthlyAudioGenerationCap,
    monthlyBudgetMicros: input.control.monthlyAudioBudgetMicros });
  if (lease.kind === "existing") return { story: lease.story, reused: true, providerCalls: 0 };
  if (lease.kind === "active") throw new MonthlyStoryAudioServiceError("audio-active");
  try {
    const generated = await input.provider.synthesize({ script: story.script,
      voiceKey: input.control.approvedVoiceKey, ttsVersion: input.control.ttsVersion,
      configurationVersion: input.control.humeConfigurationVersion,
      timeoutMillis: input.control.audioRequestTimeoutSeconds * 1_000 });
    validateMonthlyStoryMp3(generated.audio);
    const hash = createHash("sha256").update(generated.audio).digest("hex");
    const object: MonthlyStoryAudioObject = { path, hash, bytes: generated.audio.length,
      durationMillis: generated.durationMillis, generatedAtMillis: input.nowMillis,
      providerRequestCount: generated.providerRequestCount,
      estimatedCostMicros: generated.estimatedCostMicros,
      ttsVersion: input.control.ttsVersion, voiceKey: input.control.approvedVoiceKey };
    await input.objectStore.write(path, generated.audio, object);
    const stored = await input.objectStore.inspect(path);
    if (!stored || stored.hash !== hash) throw new MonthlyStoryAudioServiceError("storage-failure");
    const completed = await input.repository.markAudioReady({ uid: input.uid, monthKey, generationVersion,
      leaseOwner, object: stored, nowMillis: input.nowMillis });
    return { story: completed, reused: false, providerCalls: 1 };
  } catch (error) {
    const providerError = error instanceof MonthlyStoryAudioProviderError ? error : null;
    await input.repository.markAudioFailure({ uid: input.uid, monthKey, generationVersion, leaseOwner,
      failureCode: providerError?.code ?? (error instanceof MonthlyStoryAudioServiceError ? error.code : "persistenceFailure"),
      transient: providerError?.transient ?? false, outcomeUncertain: providerError?.outcomeUncertain ?? true,
      billableMicros: providerError?.billable ? reservationMicros : 0, nowMillis: input.nowMillis });
    if (error instanceof MonthlyStoryAudioServiceError) throw error;
    throw new MonthlyStoryAudioServiceError("provider-failure");
  }
}

export class InMemoryMonthlyStoryAudioObjectStore implements MonthlyStoryAudioObjectStore {
  readonly objects = new Map<string, { audio: Buffer; metadata: MonthlyStoryAudioObject }>();
  failWrites = false;
  async inspect(path: string): Promise<MonthlyStoryAudioObject | null> {
    return this.objects.get(path)?.metadata ?? null;
  }
  async write(path: string, audio: Buffer, metadata: Omit<MonthlyStoryAudioObject, "path" | "bytes">): Promise<void> {
    if (this.failWrites) throw new MonthlyStoryAudioServiceError("storage-failure");
    this.objects.set(path, { audio: Buffer.from(audio), metadata: { ...metadata, path, bytes: audio.length } });
  }
  async delete(path: string): Promise<void> { this.objects.delete(path); }
}
