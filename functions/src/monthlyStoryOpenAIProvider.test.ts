import { test } from "node:test";
import assert from "node:assert";
import { MONTHLY_STORY_EVALUATION_MODEL_CONFIG, monthlyStoryOperationConfig } from "./monthlyStoryModelConfig";
import { MonthlyStoryOpenAIProvider, MonthlyStoryOpenAIProviderError,
  MonthlyStoryOpenAIResponsesClient } from "./monthlyStoryOpenAIProvider";
import { MonthlyStoryPromptKind } from "./monthlyStoryPrompts";
import { MonthlyStoryTextProviderRequest } from "./monthlyStoryTextProvider";

function request(operation: MonthlyStoryPromptKind = "writer"): MonthlyStoryTextProviderRequest {
  const config = monthlyStoryOperationConfig(MONTHLY_STORY_EVALUATION_MODEL_CONFIG, operation);
  return { operation, prompt: { kind: operation, version: config.promptVersion,
    system: "Synthetic monthly story test. Return only the required structure.",
    payload: { claims: [{ key: "monthHeavy", evidenceId: "synthetic-evidence",
      role: "tone", allowedPhrases: ["this month seemed heavy"] }] } },
    modelSnapshot: config.model, promptVersion: config.promptVersion, timeoutMillis: config.timeoutMillis,
    maximumInputTokens: config.inputTokenCap, maximumOutputTokens: config.outputTokenCap };
}

function client(response: unknown): { value: MonthlyStoryOpenAIResponsesClient;
  calls: { parameters: Record<string, unknown>; options?: Record<string, unknown> }[] } {
  const calls: { parameters: Record<string, unknown>; options?: Record<string, unknown> }[] = [];
  return { calls, value: { responses: { create: async (parameters, options) => {
    calls.push({ parameters, options });
    if (response instanceof Error) throw response;
    return structuredClone(response) as never;
  } } } };
}

const writerResponse = { status: "completed", output_text: JSON.stringify({ script: "synthetic story",
  claimedEvidenceIds: ["synthetic-evidence"], claimKeys: ["monthHeavy"] }), output: [],
usage: { input_tokens: 1_000, output_tokens: 500 } };

test("provider uses Responses structured output, disables storage and retries, and normalizes usage", async () => {
  const mock = client(writerResponse);
  let time = 1_000;
  const provider = new MonthlyStoryOpenAIProvider(mock.value, MONTHLY_STORY_EVALUATION_MODEL_CONFIG,
    () => { time += 25; return time; });
  const output = await provider.generate(request()) as Record<string, unknown>;
  assert.equal(output.syntheticCostMicros, 10_000);
  assert.equal(mock.calls.length, 1);
  assert.equal(mock.calls[0].parameters.model, "gpt-5.6-terra");
  assert.equal(mock.calls[0].parameters.store, false);
  assert.equal(mock.calls[0].options?.maxRetries, 0);
  const text = mock.calls[0].parameters.text as Record<string, Record<string, unknown>>;
  assert.equal(text.format.type, "json_schema");
  assert.equal(text.format.name, "monthly_story_writer_v2");
  assert.equal(text.format.strict, true);
  assert.equal(provider.usageRecords()[0].latencyMillis, 25);
  assert.deepEqual(provider.usageRecords()[0], { requestStage: "writer", modelIdentifier: "gpt-5.6-terra",
    inputTokens: 1_000, cachedInputTokens: 0, outputTokens: 500, reasoningOutputTokens: 0,
    billingBasis: "reported-usage", latencyMillis: 25, estimatedCostMicros: 10_000 });
  assert.equal(JSON.stringify(mock.calls[0]).includes("OPENAI_API_KEY"), false);
});

test("provider discounts only explicit cached input and counts reasoning within billable output", async () => {
  const response = { ...writerResponse, usage: { input_tokens: 1_000, output_tokens: 500,
    input_tokens_details: { cached_tokens: 250 }, output_tokens_details: { reasoning_tokens: 100 } } };
  const provider = new MonthlyStoryOpenAIProvider(client(response).value,
    MONTHLY_STORY_EVALUATION_MODEL_CONFIG, () => 1_000);
  const output = await provider.generate(request()) as Record<string, unknown>;
  assert.equal(output.syntheticCostMicros, 9_438);
  assert.deepEqual(provider.usageRecords()[0], { requestStage: "writer", modelIdentifier: "gpt-5.6-terra",
    inputTokens: 1_000, cachedInputTokens: 250, outputTokens: 500, reasoningOutputTokens: 100,
    billingBasis: "reported-usage", latencyMillis: 0, estimatedCostMicros: 9_438 });

  const conservative = new MonthlyStoryOpenAIProvider(client(writerResponse).value,
    MONTHLY_STORY_EVALUATION_MODEL_CONFIG, () => 1_000);
  await conservative.generate(request());
  assert.equal(conservative.usageRecords()[0].cachedInputTokens, 0);
  assert.equal(conservative.usageRecords()[0].estimatedCostMicros, 10_000);
});

test("provider rejects mismatched config, malformed structures, refusals, and token overages", async () => {
  const cases: { response: unknown; code: string }[] = [
    { response: { ...writerResponse, output_text: "not json" }, code: "provider-malformed-response" },
    { response: { ...writerResponse, output_text: "{\"script\":", usage: {
      input_tokens: 634, output_tokens: 1_400 } }, code: "provider-output-truncated" },
    { response: { ...writerResponse, output: [{ type: "message", content: [{ type: "refusal" }] }] },
      code: "provider-refusal" },
    { response: { ...writerResponse, status: "incomplete",
      incomplete_details: { reason: "max_output_tokens" } }, code: "provider-output-truncated" },
    { response: { ...writerResponse, usage: { input_tokens: 4_001, output_tokens: 1 } },
      code: "provider-token-limit" },
    { response: { ...writerResponse, usage: { input_tokens: 1, output_tokens: 1_401 } },
      code: "provider-token-limit" },
    { response: { ...writerResponse, usage: null }, code: "provider-malformed-response" },
  ];
  for (const item of cases) {
    const provider = new MonthlyStoryOpenAIProvider(client(item.response).value,
      MONTHLY_STORY_EVALUATION_MODEL_CONFIG);
    await assert.rejects(provider.generate(request()), (error: unknown) =>
      error instanceof MonthlyStoryOpenAIProviderError && error.code === item.code);
    assert.equal(provider.usageRecords().length, 1);
    assert.equal(provider.usageRecords()[0].estimatedCostMicros > 0, true);
  }
  const provider = new MonthlyStoryOpenAIProvider(client(writerResponse).value,
    MONTHLY_STORY_EVALUATION_MODEL_CONFIG);
  await assert.rejects(provider.generate({ ...request(), modelSnapshot: "gpt-5.6-sol" }),
    (error: unknown) => error instanceof MonthlyStoryOpenAIProviderError && error.code === "provider-failure");
});

test("writer schema bounds script and trace arrays without adding response fields", async () => {
  const mock = client(writerResponse);
  const provider = new MonthlyStoryOpenAIProvider(mock.value, MONTHLY_STORY_EVALUATION_MODEL_CONFIG);
  await provider.generate(request());
  const text = mock.calls[0].parameters.text as Record<string, Record<string, unknown>>;
  const schema = text.format.schema as Record<string, Record<string, Record<string, unknown>>>;
  assert.deepEqual(Object.keys(schema.properties).sort(), ["claimKeys", "claimedEvidenceIds", "script"]);
  assert.equal(schema.properties.script.maxLength, 2_400);
  assert.equal(schema.properties.claimKeys.maxItems, 1);
  assert.equal(schema.properties.claimedEvidenceIds.maxItems, 1);
});

test("a 270-word structured story fits the 2,400-character schema and 1,400-token budget", async () => {
  const words = Array.from({ length: 270 }, (_, index) => index % 2 === 0 ? "spoken" : "story");
  const script = words.join(" ");
  const structured = { script, claimedEvidenceIds: ["synthetic-evidence"], claimKeys: ["monthHeavy"] };
  assert.equal(script.split(/\s+/).length, 270);
  assert.ok(script.length < 2_400);
  assert.ok(Math.ceil(Buffer.byteLength(JSON.stringify(structured), "utf8") / 3) < 1_400);
  const mock = client({ ...writerResponse, output_text: JSON.stringify(structured),
    usage: { input_tokens: 1_000, output_tokens: 900 } });
  const provider = new MonthlyStoryOpenAIProvider(mock.value, MONTHLY_STORY_EVALUATION_MODEL_CONFIG);
  const output = await provider.generate(request()) as Record<string, unknown>;
  assert.equal((output.script as string).split(/\s+/).length, 270);
  const text = mock.calls[0].parameters.text as Record<string, Record<string, unknown>>;
  const schema = text.format.schema as Record<string, Record<string, Record<string, unknown>>>;
  assert.equal(schema.properties.script.maxLength, 2_400);
  assert.equal(schema.properties.claimKeys.maxItems, 1);
  assert.equal(schema.properties.claimedEvidenceIds.maxItems, 1);
});

test("completed response without usable token details retains the conservative reservation", async () => {
  const provider = new MonthlyStoryOpenAIProvider(client({ ...writerResponse, usage: null }).value,
    MONTHLY_STORY_EVALUATION_MODEL_CONFIG, () => 1_000);
  await assert.rejects(provider.generate(request()), (error: unknown) =>
    error instanceof MonthlyStoryOpenAIProviderError && error.code === "provider-malformed-response");
  assert.deepEqual(provider.usageRecords()[0], { requestStage: "writer", modelIdentifier: "gpt-5.6-terra",
    inputTokens: 4_000, cachedInputTokens: 0, outputTokens: 1_400, reasoningOutputTokens: 0,
    billingBasis: "reserved-maximum", latencyMillis: 0, estimatedCostMicros: 31_000 });
});

test("provider maps timeout, refusal, rate limit, authentication, and generic failures to closed codes", async () => {
  const errors = [
    [Object.assign(new Error("timed out"), { name: "APIConnectionTimeoutError" }), "provider-timeout"],
    [Object.assign(new Error("limited"), { status: 429 }), "provider-rate-limit"],
    [Object.assign(new Error("unauthorized"), { status: 401 }), "provider-authentication"],
    [new Error("unknown"), "provider-failure"],
  ] as const;
  for (const [source, code] of errors) {
    const provider = new MonthlyStoryOpenAIProvider(client(source).value,
      MONTHLY_STORY_EVALUATION_MODEL_CONFIG);
    await assert.rejects(provider.generate(request()), (error: unknown) =>
      error instanceof MonthlyStoryOpenAIProviderError && error.code === code);
  }
});
