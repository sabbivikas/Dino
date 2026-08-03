import { createHash } from "crypto";
import assert from "node:assert";
import { test } from "node:test";
import { MonthlyStoryClaimKey } from "./monthlyStoryClaims";
import { MonthlyStoryDeterministicComposerError, MonthlyStorySentenceSmoother,
  MONTHLY_STORY_DETERMINISTIC_PROVIDER_COST_MICROS, MONTHLY_STORY_SENTENCE_SMOOTHING_DEFAULT,
  composeMonthlyStoryDeterministically, monthlyStoryDeterministicCostModel,
  smoothMonthlyStorySentenceOrFallback } from
  "./monthlyStoryDeterministicComposer";
import { buildMonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions,
  monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";
import { validateMonthlyStoryScript } from "./monthlyStoryScriptValidator";
import { parseMonthlyStorySignal } from "./monthlyStorySchema";
import { approvedMonthlyStoryEvaluationFixture, MonthlyStoryEvaluationFixtureId } from
  "./monthlyStorySyntheticEvaluationFixtures";
import { MONTHLY_STORY_DEFAULT_WRITTEN_MODE, runMonthlyStoryCompositionPipeline } from
  "./monthlyStoryWrittenPipeline";

const sixFixtureIds: readonly MonthlyStoryEvaluationFixtureId[] = ["rich-work-home-projects",
  "mood-only-heavy", "mood-only-mixed", "rich-sleep-movement", "no-journal-or-health",
  "rest-and-breathing-relief"];

function inputFor(id: MonthlyStoryEvaluationFixtureId, stableUserHash = "a".repeat(64)) {
  const signal = parseMonthlyStorySignal(approvedMonthlyStoryEvaluationFixture(id));
  const plan = buildMonthlyStoryNarrativePlan(signal);
  const closedClaims = monthlyStoryPlanClaimOptions(plan);
  return { signal, input: { plan, profile: monthlyStoryWordTarget(plan).narrativeClass,
    closedClaims, approvedSuggestionKeys: plan.nextMonthSuggestionBases.map((claim) => claim.key),
    monthDisplayName: "July", language: "en" as const, generationVersion: "gen-v1", stableUserHash } };
}

test("rich, standard, and mood-only stories stay inside their deterministic profile ranges", () => {
  const classes = new Set<string>();
  for (const id of sixFixtureIds) {
    const { input } = inputFor(id);
    const result = composeMonthlyStoryDeterministically(input);
    classes.add(result.profile);
    const target = monthlyStoryWordTarget(input.plan);
    assert.ok(result.wordCount >= target.preferredMinimum, `${id}: ${result.wordCount}`);
    assert.ok(result.wordCount <= target.preferredMaximum, `${id}: ${result.wordCount}`);
    assert.equal(result.script.split(/\s+/).length, result.wordCount);
  }
  assert.deepEqual([...classes].sort(), ["moodOnly", "rich", "standard"]);
});

test("same seed is stable while a different opaque seed may select approved variants", () => {
  const first = composeMonthlyStoryDeterministically(inputFor("rich-work-home-projects").input);
  const again = composeMonthlyStoryDeterministically(inputFor("rich-work-home-projects").input);
  const different = composeMonthlyStoryDeterministically(
    inputFor("rich-work-home-projects", "b".repeat(64)).input);
  assert.deepEqual(first, again);
  assert.notEqual(first.script, different.script);
  assert.equal(first.compositionVersion, "deterministic-v1");
});

test("all factual paragraphs are traceable and claims and suggestions are each used once", () => {
  for (const id of sixFixtureIds) {
    const { input } = inputFor(id);
    const result = composeMonthlyStoryDeterministically(input);
    assert.equal(new Set(result.usedEvidenceIds).size, result.usedEvidenceIds.length);
    assert.equal(new Set(result.usedClaimKeys).size, result.usedClaimKeys.length);
    assert.equal(new Set(result.usedSuggestionKeys).size, result.usedSuggestionKeys.length);
    const sentences = result.script.split(/[.!?]+/).map((sentence) => sentence.trim()).filter(Boolean);
    assert.equal(new Set(sentences).size, sentences.length, `${id}: repeated sentence`);
    for (const trace of result.paragraphTrace.slice(0, -1)) {
      assert.ok(trace.claimKeys.length > 0, `${id} paragraph ${trace.paragraphIndex}`);
      assert.ok(trace.evidenceIds.length > 0, `${id} paragraph ${trace.paragraphIndex}`);
    }
    assert.deepEqual(result.paragraphTrace.at(-1)?.claimKeys, []);
  }
});

test("deterministic stories pass the existing validator without unsupported causes or repetition", () => {
  for (const id of sixFixtureIds) {
    const { signal, input } = inputFor(id);
    const result = composeMonthlyStoryDeterministically(input);
    const validation = validateMonthlyStoryScript({ script: result.script,
      claimedEvidenceIds: result.usedEvidenceIds, claimKeys: result.usedClaimKeys,
      plan: input.plan, availableEvidence: signal.evidence });
    assert.deepEqual(validation.errors, [], `${id}: ${validation.errors.join(",")}`);
    assert.equal(validation.isValid, true);
    const normalized = result.script.toLowerCase();
    for (const forbidden of ["therapist", "your data", "the app", "i noticed", "because work",
      "because home", "be gentle with yourself", "one quiet moment at a time"]) {
      assert.equal(normalized.includes(forbidden), false, `${id}: ${forbidden}`);
    }
  }
});

test("mood-only stories acknowledge uncertainty once and never invent life or health reasons", () => {
  for (const id of ["mood-only-heavy", "mood-only-mixed"] as const) {
    const result = composeMonthlyStoryDeterministically(inputFor(id).input);
    assert.match(result.script, /i do not know|reason is not clear/);
    for (const forbidden of ["because work", "because home", "because your relationship",
      "because of health", "because your family", "because of sleep", "because you moved less"]) {
      assert.equal(result.script.toLowerCase().includes(forbidden), false, `${id}: ${forbidden}`);
    }
  }
});

test("insufficient approved content and mismatched claims fail closed", () => {
  const { input } = inputFor("mood-only-heavy");
  assert.throws(() => composeMonthlyStoryDeterministically({ ...input, approvedSuggestionKeys: [] }),
    (error: unknown) => error instanceof MonthlyStoryDeterministicComposerError &&
      error.code === "unsupportedSuggestion");
  assert.throws(() => composeMonthlyStoryDeterministically({ ...input,
    closedClaims: input.closedClaims.slice(0, 1) }),
  (error: unknown) => error instanceof MonthlyStoryDeterministicComposerError &&
      error.code === "claimMismatch");
});

test("smoother failure or an attempted new claim preserves the deterministic sentence", async () => {
  const original = "work seemed to take a lot out of you this month.";
  const failure: MonthlyStorySentenceSmoother = { smooth: async () => { throw new Error("offline"); } };
  const invention: MonthlyStorySentenceSmoother = {
    smooth: async () => "work caused your sleep problems this month.",
  };
  const approved: MonthlyStorySentenceSmoother = {
    smooth: async () => "work was one of the heavier parts of the month.",
  };
  const base = { sentence: original, claimKey: "workPressure" as MonthlyStoryClaimKey,
    prohibitedFacts: ["sleep"], maximumCharacterCount: 80 };
  assert.equal(await smoothMonthlyStorySentenceOrFallback(base, failure), original);
  assert.equal(await smoothMonthlyStorySentenceOrFallback(base, invention), original);
  assert.equal(await smoothMonthlyStorySentenceOrFallback(base, approved),
    "work was one of the heavier parts of the month.");
  assert.equal(await smoothMonthlyStorySentenceOrFallback({ ...base,
    claimKey: "protectPersonalTime" }, approved), original);
});

test("production default is deterministic and makes zero provider calls or provider cost", async () => {
  assert.equal(MONTHLY_STORY_DEFAULT_WRITTEN_MODE, "deterministic");
  assert.equal(MONTHLY_STORY_DETERMINISTIC_PROVIDER_COST_MICROS, 0);
  assert.deepEqual(MONTHLY_STORY_SENTENCE_SMOOTHING_DEFAULT,
    { enabled: false, rolloutBasisPoints: 0, maximumCallsPerStory: 0 });
  assert.deepEqual(monthlyStoryDeterministicCostModel(), { deterministicTextProviderMicros: 0,
    optionalSentenceSmoothingProviderMicros: null, ttsProviderMicros: null });
  assert.deepEqual(monthlyStoryDeterministicCostModel(17), { deterministicTextProviderMicros: 0,
    optionalSentenceSmoothingProviderMicros: 17, ttsProviderMicros: null });
  const { input } = inputFor("rich-work-home-projects");
  const result = await runMonthlyStoryCompositionPipeline({ deterministicInput: input });
  assert.equal(result.mode, "deterministic");
  if (result.mode === "deterministic") {
    assert.equal(result.providerCallCount, 0);
    assert.equal(result.estimatedProviderCostMicros, 0);
  }
});

test("previous failed live writer outputs remain negative regression fixtures", () => {
  const tooShort = `This month held both hard and lighter moments. Home seemed to be on your mind.

Work seemed to take a lot out of you. That pressure was its own separate difficulty.

You seemed happiest when you had time for your own ideas.

For next month, try to keep one evening where work ends on time.`;
  const repetitive = `This month seemed heavy. Work seemed to take a lot out of you.

Your body seemed to slow down when the month felt heavier. Focused time seemed to settle things for a while.

Try to keep one evening where work ends on time. Try not to fill the hour after work with more tasks.

Leave one part of the weekend unplanned. Keep that time open for real rest.

Keep August gentle.`;
  const rich = inputFor("rich-work-home-projects");
  const health = inputFor("rich-sleep-movement");
  const validate = (script: string, value: ReturnType<typeof inputFor>) => validateMonthlyStoryScript({ script,
    claimedEvidenceIds: monthlyStoryPlanClaimOptions(value.input.plan).map((claim) => claim.evidenceId),
    claimKeys: monthlyStoryPlanClaimOptions(value.input.plan).map((claim) => claim.key),
    plan: value.input.plan, availableEvidence: value.signal.evidence });
  assert.equal(validate(tooShort, rich).isValid, false);
  assert.equal(validate(repetitive, health).isValid, false);
});

test("script hashes are stable without exposing the stable user hash", () => {
  const result = composeMonthlyStoryDeterministically(inputFor("no-journal-or-health").input);
  assert.equal(result.script.includes("a".repeat(64)), false);
  assert.equal(createHash("sha256").update(result.script).digest("hex").length, 64);
});
