import { test } from "node:test";
import assert from "node:assert";
import { estimatedHumeCostMicros, validateMonthlyStoryMp3 } from "./monthlyStoryAudioProvider";
import { HumeMonthlyStoryAudioProvider } from "./monthlyStoryHumeProvider";

const request = { script: "a synthetic monthly reflection", voiceKey: "synthetic-voice",
  ttsVersion: "hume-v1", configurationVersion: "hume-test-v1", timeoutMillis: 1_000 };

test("Hume provider fails closed without a key and never needs one in normal tests", () => {
  assert.throws(() => new HumeMonthlyStoryAudioProvider({ apiKey: "", microsPerThousandCharacters: 150_000 }),
    /authentication/);
});

test("Hume adapter sends only script and approved voice and normalizes MP3", async () => {
  let observed: { url: string; headers: Record<string, string>; body: string } | undefined;
  const audio = Buffer.from("ID3synthetic-audio");
  const provider = new HumeMonthlyStoryAudioProvider({ apiKey: "synthetic-test-key",
    microsPerThousandCharacters: 150_000, httpClient: async (url, init) => {
      observed = { url, headers: init.headers, body: init.body };
      return { ok: true, status: 200, json: async () => ({ request_id: "synthetic-request",
        generations: [{ audio: audio.toString("base64"), duration_ms: 42_000 }] }) };
    } });
  const result = await provider.synthesize(request);
  assert.equal(observed?.url, "https://api.hume.ai/v0/tts");
  assert.equal(observed?.headers["X-Hume-Api-Key"], "synthetic-test-key");
  const payload = JSON.parse(observed?.body ?? "{}") as Record<string, unknown>;
  assert.deepEqual(Object.keys(payload).sort(), ["format", "num_generations", "utterances", "version"]);
  assert.deepEqual(result.audio, audio); assert.equal(result.format, "mp3");
  assert.equal(result.durationMillis, 42_000); assert.equal(result.providerRequestCount, 1);
});

test("cost rounds upward and MP3 validation rejects malformed bytes", () => {
  assert.equal(estimatedHumeCostMicros(1, 150_000), 150);
  assert.equal(estimatedHumeCostMicros(1_001, 150_000), 150_150);
  assert.throws(() => validateMonthlyStoryMp3(Buffer.from("not audio")), /malformedResponse/);
});

test("provider errors are closed and never expose response bodies", async () => {
  const provider = new HumeMonthlyStoryAudioProvider({ apiKey: "synthetic-test-key",
    microsPerThousandCharacters: 150_000,
    httpClient: async () => ({ ok: false, status: 429, json: async () => ({ private: "not read" }) }) });
  await assert.rejects(provider.synthesize(request), (error: unknown) =>
    error instanceof Error && error.message === "rateLimited");
});

test("ambiguous transport failures preserve the uncertain and billable outcome", async () => {
  const provider = new HumeMonthlyStoryAudioProvider({ apiKey: "synthetic-test-key",
    microsPerThousandCharacters: 150_000,
    httpClient: async () => { throw new Error("synthetic transport failure"); } });
  await assert.rejects(provider.synthesize(request), (error: unknown) => {
    if (!(error instanceof Error) || error.message !== "transientProvider") return false;
    const failure = error as Error & { transient?: boolean; outcomeUncertain?: boolean; billable?: boolean };
    return failure.transient === true && failure.outcomeUncertain === true && failure.billable === true;
  });
});

test("timeouts preserve the uncertain and billable outcome", async () => {
  const provider = new HumeMonthlyStoryAudioProvider({ apiKey: "synthetic-test-key",
    microsPerThousandCharacters: 150_000, httpClient: async (_url, init) =>
      await new Promise<never>((_resolve, reject) => init.signal.addEventListener("abort", () =>
        reject(new Error("synthetic timeout")))) });
  await assert.rejects(provider.synthesize({ ...request, timeoutMillis: 1 }), (error: unknown) => {
    if (!(error instanceof Error) || error.message !== "timeout") return false;
    const failure = error as Error & { transient?: boolean; outcomeUncertain?: boolean; billable?: boolean };
    return failure.transient === true && failure.outcomeUncertain === true && failure.billable === true;
  });
});

test("HTTP 5xx preserves the uncertain and billable outcome", async () => {
  const provider = new HumeMonthlyStoryAudioProvider({ apiKey: "synthetic-test-key",
    microsPerThousandCharacters: 150_000,
    httpClient: async () => ({ ok: false, status: 503, json: async () => ({}) }) });
  await assert.rejects(provider.synthesize(request), (error: unknown) => {
    if (!(error instanceof Error) || error.message !== "transientProvider") return false;
    const failure = error as Error & { transient?: boolean; outcomeUncertain?: boolean; billable?: boolean };
    return failure.transient === true && failure.outcomeUncertain === true && failure.billable === true;
  });
});
