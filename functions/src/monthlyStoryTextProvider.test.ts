import { test } from "node:test";
import assert from "node:assert";
import { buildMonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions } from "./monthlyStoryNarrativePlan";
import { buildMonthlyStoryWriterPrompt } from "./monthlyStoryPrompts";
import { parseMonthlyStorySignal } from "./monthlyStorySchema";
import { FailureMonthlyStoryTextProvider, FakeMonthlyStoryTextProvider,
  MalformedMonthlyStoryTextProvider, MonthlyStoryProviderError, TimeoutMonthlyStoryTextProvider,
  parseMonthlyStoryWriterOutput } from "./monthlyStoryTextProvider";
import { MONTHLY_STORY_GOLDENS, SYNTHETIC_RICH_SIGNAL } from "./monthlyStoryWrittenFixtures";

const signal = parseMonthlyStorySignal(SYNTHETIC_RICH_SIGNAL);
const plan = buildMonthlyStoryNarrativePlan(signal);
const prompt = buildMonthlyStoryWriterPrompt({ plan, allowedClaims: monthlyStoryPlanClaimOptions(plan),
  storyMode: plan.storyMode, wordTarget: { minimum: 220, preferredMaximum: 290, absoluteMaximum: 300 },
  language: "en", promptVersion: "writer-v1" });
const request = { operation: "writer" as const, prompt, modelSnapshot: "fake-snapshot-v1",
  promptVersion: "writer-v1", timeoutMillis: 1_000, maximumInputTokens: 2_000, maximumOutputTokens: 1_000 };
const golden = MONTHLY_STORY_GOLDENS[0];
const response = { script: golden.script, claimedEvidenceIds: golden.claimedEvidenceIds,
  claimKeys: golden.claimKeys, syntheticCostMicros: 50 };

test("deterministic fake provider returns structured synthetic responses without a key", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: response });
  const parsed = parseMonthlyStoryWriterOutput(await provider.generate(request));
  assert.equal(parsed.script, golden.script);
  assert.equal(provider.calls.length, 1);
  assert.deepEqual(Object.keys(provider.calls[0]).sort(), ["maximumInputTokens", "maximumOutputTokens",
    "modelSnapshot", "operation", "prompt", "promptVersion", "timeoutMillis"].sort());
});

test("provider output parser rejects unknown fields, duplicate IDs, and arbitrary structures", () => {
  assert.throws(() => parseMonthlyStoryWriterOutput({ ...response, rawPrompt: "no" }),
    MonthlyStoryProviderError);
  assert.throws(() => parseMonthlyStoryWriterOutput({ ...response,
    claimedEvidenceIds: [golden.claimedEvidenceIds[0], golden.claimedEvidenceIds[0]] }),
  /malformed-response/);
  assert.throws(() => parseMonthlyStoryWriterOutput("not-an-object"), /malformed-response/);
});

test("failure, malformed, and timeout providers are deterministic and make no network call", async () => {
  await assert.rejects(new FailureMonthlyStoryTextProvider().generate(request), /provider-failure/);
  assert.deepEqual(await new MalformedMonthlyStoryTextProvider().generate(request), { unstructured: true });
  await assert.rejects(new TimeoutMonthlyStoryTextProvider().generate(request), /provider-timeout/);
});
