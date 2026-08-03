import { test } from "node:test";
import assert from "node:assert";
import { passingMonthlyStoryCriticResult } from "./monthlyStoryCritic";
import { MONTHLY_STORY_EVALUATION_MODEL_CONFIG } from "./monthlyStoryModelConfig";
import { buildMonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions } from "./monthlyStoryNarrativePlan";
import { parseMonthlyStorySignal } from "./monthlyStorySchema";
import { approvedMonthlyStoryEvaluationFixture } from "./monthlyStorySyntheticEvaluationFixtures";
import { evaluateMonthlyStorySyntheticFixture, MONTHLY_STORY_EVALUATION_MAX_REQUESTS,
  MONTHLY_STORY_EVALUATION_MAX_SPEND_MICROS, MonthlyStoryEvaluationLimits,
  MonthlyStoryEvaluationSafetyError, parseMonthlyStoryEvaluationArguments,
  requireMonthlyStoryEvaluationApiKey, runMonthlyStorySyntheticEvaluation } from
  "./monthlyStorySyntheticEvaluation";
import { FakeMonthlyStoryTextProvider } from "./monthlyStoryTextProvider";
import { MONTHLY_STORY_GOLDENS } from "./monthlyStoryWrittenFixtures";

const moodGolden = MONTHLY_STORY_GOLDENS.find((item) => item.id === "mood-only") ??
  (() => { throw new Error("missing-synthetic-golden"); })();

function writer(cost = 100): Record<string, unknown> {
  const signal = parseMonthlyStorySignal(approvedMonthlyStoryEvaluationFixture("mood-only-heavy"));
  const claims = monthlyStoryPlanClaimOptions(buildMonthlyStoryNarrativePlan(signal));
  return { script: moodGolden.script, claimedEvidenceIds: claims.map((claim) => claim.evidenceId),
    claimKeys: claims.map((claim) => claim.key), syntheticCostMicros: cost };
}

function limits(requests = MONTHLY_STORY_EVALUATION_MAX_REQUESTS,
  spend = MONTHLY_STORY_EVALUATION_MAX_SPEND_MICROS): MonthlyStoryEvaluationLimits {
  return new MonthlyStoryEvaluationLimits(requests, spend, MONTHLY_STORY_EVALUATION_MODEL_CONFIG);
}

test("CLI parser accepts only allowlisted fixture IDs and bounded operational flags", () => {
  const options = parseMonthlyStoryEvaluationArguments(["--live", "--confirm-synthetic-only",
    "--fixtures=mood-only-heavy,recommendation-opened", "--max-requests=12", "--max-spend-usd=1.25"]);
  assert.deepEqual(options.fixtureIds, ["mood-only-heavy", "recommendation-opened"]);
  assert.equal(options.maximumRequests, 12);
  assert.equal(options.maximumSpendMicros, 1_250_000);
  assert.equal(parseMonthlyStoryEvaluationArguments(["--fixtures=mood-only-heavy",
    "--max-spend-usd=0.000001"]).maximumSpendMicros, 1);
  for (const args of [["--live", "--fixtures=mood-only-heavy"], ["--fixtures=/tmp/story.txt"],
    ["--fixtures=user@example.com"], ["--fixtures=dino-app-wellness"],
    ["--fixtures=mood-only-heavy", "arbitrary text"], ["--fixtures=mood-only-heavy", "--max-requests=25"],
    ["--fixtures=mood-only-heavy", "--max-spend-usd=5.01"]]) {
    assert.throws(() => parseMonthlyStoryEvaluationArguments(args), MonthlyStoryEvaluationSafetyError);
  }
});

test("live mode requires a nonempty environment key while dry-run parsing requires none", () => {
  assert.equal(parseMonthlyStoryEvaluationArguments(["--fixtures=mood-only-heavy"]).live, false);
  assert.throws(() => requireMonthlyStoryEvaluationApiKey({}),
    (error: unknown) => error instanceof MonthlyStoryEvaluationSafetyError && error.code === "missing-api-key");
  assert.throws(() => requireMonthlyStoryEvaluationApiKey({ OPENAI_API_KEY: "short" }),
    MonthlyStoryEvaluationSafetyError);
  assert.equal(requireMonthlyStoryEvaluationApiKey({ OPENAI_API_KEY: "synthetic-test-key-not-live" }),
    "synthetic-test-key-not-live");
});

test("request caps and worst-case spend ceiling fail before another provider request", () => {
  const requestLimited = limits(1);
  requestLimited.beforeRequest("writer");
  assert.throws(() => requestLimited.beforeRequest("critic"),
    (error: unknown) => error instanceof MonthlyStoryEvaluationSafetyError && error.code === "request-cap");
  const spendLimited = limits(24, 100);
  assert.throws(() => spendLimited.beforeRequest("writer"),
    (error: unknown) => error instanceof MonthlyStoryEvaluationSafetyError && error.code === "spend-ceiling");
  assert.equal(spendLimited.requestCount, 0);
});

test("repairable output gets one repair and a required second critic pass", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(), critic: [
    { ...passingMonthlyStoryCriticResult(20), decision: "repairable", reasons: ["unnatural"] },
    passingMonthlyStoryCriticResult(20),
  ], repair: writer(50) });
  const result = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", provider, limits());
  assert.equal(result.passed, true);
  assert.equal(result.repaired, true);
  assert.equal(result.secondCriticPassed, true);
  assert.equal(result.requestCount, 4);
  assert.equal(result.totalCostMicros, 190);
  assert.deepEqual(provider.calls.map((call) => call.operation), ["writer", "critic", "repair", "critic"]);
});

test("a too-short synthetic draft expands once before its required post-repair critic", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: { script: "this month seemed heavy. " +
    "next month, try to protect a little more room for real rest.",
  claimedEvidenceIds: ["synthetic-heavy-mood", "synthetic-heavy-rest"],
  claimKeys: ["monthHeavy", "continueRest"], syntheticCostMicros: 10 },
  repair: writer(50), critic: passingMonthlyStoryCriticResult(20) });
  const result = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", provider, limits());
  assert.equal(result.passed, true);
  assert.equal(result.repaired, true);
  assert.equal(result.secondCriticPassed, true);
  assert.deepEqual(provider.calls.map((call) => call.operation), ["writer", "repair", "critic"]);
  assert.equal(result.totalCostMicros, 80);
});

test("a failed second critic rejects the repair and no second repair is attempted", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(), critic: [
    { ...passingMonthlyStoryCriticResult(20), decision: "repairable", reasons: ["unnatural"] },
    { ...passingMonthlyStoryCriticResult(20), decision: "repairable", reasons: ["weakSuggestions"] },
  ], repair: writer(50) });
  const result = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", provider, limits());
  assert.equal(result.passed, false);
  assert.equal(result.hardFailureCodes.includes("second-critic-not-pass"), true);
  assert.equal(provider.calls.length, 4);
});

test("critic reject is terminal and receives no repair or fallback story", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(), critic: {
    ...passingMonthlyStoryCriticResult(20), decision: "reject", reasons: ["evidenceMismatch"] } });
  const result = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", provider, limits());
  assert.equal(result.passed, false);
  assert.equal(result.failureCode, "critic-reject");
  assert.deepEqual(provider.calls.map((call) => call.operation), ["writer", "critic"]);
});

test("an unsafe deterministic writer failure gets no critic, repair, or generic fallback", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: {
    script: "your data shows a difficult month. next month, try to protect a little more room for rest.",
    claimedEvidenceIds: ["synthetic-heavy-mood", "synthetic-heavy-rest"],
    claimKeys: ["monthHeavy", "continueRest"], syntheticCostMicros: 10 } });
  const result = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", provider, limits());
  assert.equal(result.passed, false);
  assert.equal(result.hardFailureCodes.includes("reportingLanguage"), true);
  assert.equal(provider.calls.length, 1);
  assert.match(result.script ?? "", /your data shows/);
  assert.equal(result.totalCostMicros, 10);
});

test("an unusable malformed writer result receives exactly one bounded retry", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: [{ malformed: true }, writer()],
    critic: passingMonthlyStoryCriticResult(20) });
  const result = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", provider, limits());
  assert.equal(result.passed, true);
  assert.deepEqual(provider.calls.map((call) => call.operation), ["writer", "writer", "critic"]);
});

test("malformed writer metadata with a usable script is not retried", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: {
    script: moodGolden.script, claimedEvidenceIds: moodGolden.claimedEvidenceIds,
    claimKeys: moodGolden.claimKeys } });
  const result = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", provider, limits());
  assert.equal(result.passed, false);
  assert.equal(provider.calls.length, 1);
});

test("a malformed critic receives one retry and never more than one", async () => {
  const recovered = new FakeMonthlyStoryTextProvider({ writer: writer(),
    critic: [{ malformed: true }, passingMonthlyStoryCriticResult(20)] });
  const recoveredResult = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", recovered, limits());
  assert.equal(recoveredResult.passed, true);
  assert.deepEqual(recovered.calls.map((call) => call.operation), ["writer", "critic", "critic"]);

  const failed = new FakeMonthlyStoryTextProvider({ writer: writer(),
    critic: [{ malformed: true }, { stillMalformed: true }, passingMonthlyStoryCriticResult(20)] });
  const failedResult = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", failed, limits());
  assert.equal(failedResult.passed, false);
  assert.deepEqual(failed.calls.map((call) => call.operation), ["writer", "critic", "critic"]);
});

test("retry is denied when the request cap cannot reserve the second call", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: [{ malformed: true }, writer()] });
  const result = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", provider, limits(1));
  assert.equal(result.failureCode, "request-cap");
  assert.equal(provider.calls.length, 1);
});

test("aggregate report calculates actual costs and text-only projections from synthetic runs", async () => {
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(100),
    critic: passingMonthlyStoryCriticResult(20) });
  const report = await runMonthlyStorySyntheticEvaluation({ live: false, syntheticOnlyConfirmed: false,
    fixtureIds: ["mood-only-heavy"], maximumRequests: 24, maximumSpendMicros: 5_000_000 }, provider);
  assert.equal(report.label, "SYNTHETIC MONTHLY STORY EVALUATION");
  assert.equal(report.aggregate.passed, 1);
  assert.equal(report.aggregate.totalSpendMicros, 120);
  assert.equal(report.aggregate.projectedTextOnlyCostMicros.users2700, 324_000);
  assert.equal(JSON.stringify(report).includes("apiKey"), false);
});

test("rejected critic output and repair plus second critic remain billable", async () => {
  const rejected = new FakeMonthlyStoryTextProvider({ writer: writer(100), critic: {
    ...passingMonthlyStoryCriticResult(25), decision: "reject", reasons: ["evidenceMismatch"] } });
  const rejectedResult = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", rejected, limits());
  assert.equal(rejectedResult.totalCostMicros, 125);

  const repaired = new FakeMonthlyStoryTextProvider({ writer: writer(100), critic: [
    { ...passingMonthlyStoryCriticResult(25), decision: "repairable", reasons: ["unnatural"] },
    passingMonthlyStoryCriticResult(25),
  ], repair: writer(50) });
  const repairedResult = await evaluateMonthlyStorySyntheticFixture("mood-only-heavy", repaired, limits());
  assert.equal(repairedResult.totalCostMicros, 200);
  assert.equal(repairedResult.requestCount, 4);
});
