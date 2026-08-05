export const MONTHLY_STORY_AUDIO_FORMAT = "mp3" as const;

export type MonthlyStoryAudioRequest = {
  script: string;
  voiceKey: string;
  ttsVersion: string;
  configurationVersion: string;
  timeoutMillis: number;
};

export type MonthlyStoryAudioResult = {
  audio: Buffer;
  format: typeof MONTHLY_STORY_AUDIO_FORMAT;
  durationMillis: number | null;
  requestIdentifier: string | null;
  providerRequestCount: 1;
  estimatedCostMicros: number;
};

export type MonthlyStoryAudioFailureCode = "authentication" | "rateLimited" | "timeout" |
  "providerRejected" | "malformedResponse" | "transientProvider";

export class MonthlyStoryAudioProviderError extends Error {
  constructor(readonly code: MonthlyStoryAudioFailureCode, readonly transient: boolean,
    readonly outcomeUncertain: boolean, readonly billable: boolean) {
    super(code);
    this.name = "MonthlyStoryAudioProviderError";
  }
}

export interface MonthlyStoryAudioProvider {
  synthesize(request: MonthlyStoryAudioRequest): Promise<MonthlyStoryAudioResult>;
}

export class FakeMonthlyStoryAudioProvider implements MonthlyStoryAudioProvider {
  calls = 0;
  constructor(private readonly result: MonthlyStoryAudioResult) {}
  async synthesize(): Promise<MonthlyStoryAudioResult> {
    this.calls += 1;
    return { ...this.result, audio: Buffer.from(this.result.audio) };
  }
}

export class FailingMonthlyStoryAudioProvider implements MonthlyStoryAudioProvider {
  calls = 0;
  constructor(private readonly error = new MonthlyStoryAudioProviderError(
    "providerRejected", false, false, false)) {}
  async synthesize(): Promise<never> { this.calls += 1; throw this.error; }
}

export class TimeoutMonthlyStoryAudioProvider extends FailingMonthlyStoryAudioProvider {
  constructor() { super(new MonthlyStoryAudioProviderError("timeout", true, false, false)); }
}

export class MalformedMonthlyStoryAudioProvider extends FailingMonthlyStoryAudioProvider {
  constructor() { super(new MonthlyStoryAudioProviderError("malformedResponse", false, true, true)); }
}

export function estimatedHumeCostMicros(characterCount: number, microsPerThousandCharacters: number): number {
  if (!Number.isSafeInteger(characterCount) || characterCount < 0 ||
      !Number.isSafeInteger(microsPerThousandCharacters) || microsPerThousandCharacters < 0) {
    throw new MonthlyStoryAudioProviderError("providerRejected", false, false, false);
  }
  return Math.ceil(characterCount * microsPerThousandCharacters / 1_000);
}

export function validateMonthlyStoryMp3(audio: Buffer): void {
  if (audio.length < 4 || audio.length > 25 * 1024 * 1024) {
    throw new MonthlyStoryAudioProviderError("malformedResponse", false, true, true);
  }
  const id3 = audio.subarray(0, 3).toString("ascii") === "ID3";
  const frame = audio[0] === 0xff && (audio[1] & 0xe0) === 0xe0;
  if (!id3 && !frame) throw new MonthlyStoryAudioProviderError("malformedResponse", false, true, true);
}
