import { MonthlyStoryAudioProvider, MonthlyStoryAudioProviderError, MonthlyStoryAudioRequest,
  MonthlyStoryAudioResult, estimatedHumeCostMicros, validateMonthlyStoryMp3 } from "./monthlyStoryAudioProvider";

export interface HumeHttpResponse { ok: boolean; status: number; json(): Promise<unknown> }
export type HumeHttpClient = (url: string, init: { method: "POST"; headers: Record<string, string>;
  body: string; signal: AbortSignal }) => Promise<HumeHttpResponse>;

type HumeProviderOptions = { apiKey: string; microsPerThousandCharacters: number; httpClient?: HumeHttpClient };

function base64FromResponse(value: unknown): { audio: string; requestId: string | null; durationMillis: number | null } {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new MonthlyStoryAudioProviderError("malformedResponse", false, true, true);
  }
  const root = value as Record<string, unknown>;
  const generations = root.generations;
  if (!Array.isArray(generations) || generations.length !== 1 ||
      typeof generations[0] !== "object" || generations[0] === null) {
    throw new MonthlyStoryAudioProviderError("malformedResponse", false, true, true);
  }
  const generation = generations[0] as Record<string, unknown>;
  let audio = typeof generation.audio === "string" ? generation.audio : "";
  if (!audio && Array.isArray(generation.snippets)) {
    const parts = generation.snippets.map((snippet) =>
      typeof snippet === "object" && snippet !== null &&
      typeof (snippet as Record<string, unknown>).audio === "string" ?
        (snippet as Record<string, unknown>).audio as string : "");
    if (parts.every(Boolean)) audio = parts.join("");
  }
  if (!audio || !/^[A-Za-z0-9+/]+={0,2}$/.test(audio)) {
    throw new MonthlyStoryAudioProviderError("malformedResponse", false, true, true);
  }
  const duration = generation.duration_ms;
  return { audio,
    requestId: typeof root.request_id === "string" && root.request_id.length <= 128 ? root.request_id : null,
    durationMillis: typeof duration === "number" && Number.isSafeInteger(duration) && duration > 0 ? duration : null };
}

export class HumeMonthlyStoryAudioProvider implements MonthlyStoryAudioProvider {
  private readonly httpClient: HumeHttpClient;
  constructor(private readonly options: HumeProviderOptions) {
    if (!options.apiKey || options.apiKey.length > 512 || options.microsPerThousandCharacters <= 0) {
      throw new MonthlyStoryAudioProviderError("authentication", false, false, false);
    }
    this.httpClient = options.httpClient ?? (globalThis.fetch as unknown as HumeHttpClient);
  }

  async synthesize(request: MonthlyStoryAudioRequest): Promise<MonthlyStoryAudioResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), request.timeoutMillis);
    try {
      const response = await this.httpClient("https://api.hume.ai/v0/tts", { method: "POST",
        headers: { "Content-Type": "application/json", "X-Hume-Api-Key": this.options.apiKey },
        body: JSON.stringify({ version: "2", utterances: [{ text: request.script,
          voice: { id: request.voiceKey } }], format: { type: "mp3" }, num_generations: 1 }),
        signal: controller.signal });
      if (!response.ok) {
        if (response.status === 401 || response.status === 403) {
          throw new MonthlyStoryAudioProviderError("authentication", false, false, false);
        }
        if (response.status === 429) throw new MonthlyStoryAudioProviderError("rateLimited", true, false, false);
        const uncertain = response.status >= 500;
        throw new MonthlyStoryAudioProviderError(uncertain ? "transientProvider" : "providerRejected",
          uncertain, uncertain, uncertain);
      }
      const parsed = base64FromResponse(await response.json());
      const audio = Buffer.from(parsed.audio, "base64");
      validateMonthlyStoryMp3(audio);
      return { audio, format: "mp3", durationMillis: parsed.durationMillis,
        requestIdentifier: parsed.requestId, providerRequestCount: 1,
        estimatedCostMicros: estimatedHumeCostMicros(request.script.length,
          this.options.microsPerThousandCharacters) };
    } catch (error) {
      if (error instanceof MonthlyStoryAudioProviderError) throw error;
      if (controller.signal.aborted) throw new MonthlyStoryAudioProviderError("timeout", true, true, true);
      throw new MonthlyStoryAudioProviderError("transientProvider", true, true, true);
    } finally { clearTimeout(timeout); }
  }
}
