import { test } from "node:test";
import assert from "node:assert";
import { readFileSync } from "fs";
import { join } from "path";
import { MONTHLY_STORY_FORBIDDEN_CLAIM_EXAMPLES, allowedClaimPhrases,
  claimOptionForEvidence } from "./monthlyStoryClaims";
import { MonthlyStoryNarrativePlanError, buildMonthlyStoryNarrativePlan,
  monthlyStoryPlanClaimOptions, monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";
import { buildMonthlyStoryCriticPrompt, buildMonthlyStoryRepairPrompt,
  buildMonthlyStoryWriterPrompt } from "./monthlyStoryPrompts";
import { validateMonthlyStoryScript } from "./monthlyStoryScriptValidator";
import { parseMonthlyStorySignal } from "./monthlyStorySchema";
import { MONTHLY_STORY_GOLDENS, MONTHLY_STORY_NEGATIVE_GOLDENS,
  MONTHLY_STORY_SYNTHETIC_CORPUS, SYNTHETIC_MOOD_ONLY_SIGNAL,
  SYNTHETIC_NO_JOURNAL_HEALTH_SIGNAL, SYNTHETIC_RICH_SIGNAL, syntheticMonthlyStorySignal } from
  "./monthlyStoryWrittenFixtures";

test("narrative plan selects a small evidence-backed emotional story", () => {
  const signal = parseMonthlyStorySignal(SYNTHETIC_RICH_SIGNAL);
  const plan = buildMonthlyStoryNarrativePlan(signal);
  assert.equal(plan.storyMode, "standard");
  assert.equal(plan.overallMonthTone.key, "monthMixed");
  assert.deepEqual([plan.strongestDifficulty?.key, plan.secondDifficulty?.key],
    ["missingHome", "workPressure"]);
  assert.equal(plan.strongestReliefOrEnergy?.key, "personalProjects");
  assert.equal(plan.recommendationReflection?.key, "recommendationOpened");
  assert.deepEqual(plan.nextMonthSuggestionBases.map((item) => item.key),
    ["makeSpaceForProjects", "protectPersonalTime"]);
  assert.ok(plan.excludedEvidenceIds.includes("evidence-sleep-rich"));
  assert.ok(plan.excludedEvidenceIds.includes("evidence-move-rich"));
  assert.ok(plan.excludedEvidenceIds.includes("evidence-breathe-rich"));
});

test("mood-only plans contain no cause, difficulty, or relief claim", () => {
  const plan = buildMonthlyStoryNarrativePlan(parseMonthlyStorySignal(SYNTHETIC_MOOD_ONLY_SIGNAL));
  assert.equal(plan.storyMode, "moodOnly");
  assert.equal(plan.strongestDifficulty, null);
  assert.equal(plan.secondDifficulty, null);
  assert.equal(plan.strongestReliefOrEnergy, null);
  assert.deepEqual(monthlyStoryPlanClaimOptions(plan).map((item) => item.key),
    ["monthHeavy", "continueRest"]);
});

test("narrative plans select deterministic rich, standard, and mood-only word targets", () => {
  const rich = monthlyStoryWordTarget(buildMonthlyStoryNarrativePlan(
    parseMonthlyStorySignal(SYNTHETIC_RICH_SIGNAL)));
  const standard = monthlyStoryWordTarget(buildMonthlyStoryNarrativePlan(
    parseMonthlyStorySignal(SYNTHETIC_NO_JOURNAL_HEALTH_SIGNAL)));
  const mood = monthlyStoryWordTarget(buildMonthlyStoryNarrativePlan(
    parseMonthlyStorySignal(SYNTHETIC_MOOD_ONLY_SIGNAL)));
  assert.deepEqual([rich.narrativeClass, rich.acceptanceMinimum, rich.preferredMinimum,
    rich.preferredMaximum], ["rich", 220, 220, 275]);
  assert.deepEqual([standard.narrativeClass, standard.acceptanceMinimum, standard.preferredMinimum,
    standard.preferredMaximum], ["standard", 190, 190, 260]);
  assert.deepEqual([mood.narrativeClass, mood.acceptanceMinimum, mood.preferredMinimum,
    mood.preferredMaximum], ["moodOnly", 150, 150, 210]);
});

test("technically shaped but narratively sparse material fails before generation", () => {
  const sparse = syntheticMonthlyStorySignal({ evidence: [
    { id: "evidence-mood-sparse", value: { type: "emotionalShape", moodShape: "steady",
      moodDirection: "steady" }, source: "mood" },
    { id: "evidence-rest-sparse", value: { type: "nextMonthSuggestionBasis", suggestion: "continueRest" },
      source: "deterministicCombination" },
  ] });
  assert.throws(() => buildMonthlyStoryNarrativePlan(parseMonthlyStorySignal(sparse)),
    MonthlyStoryNarrativePlanError);

  const weak = syntheticMonthlyStorySignal({ evidence: [
    { id: "evidence-mood-weak", value: { type: "emotionalShape", moodShape: "mixed",
      moodDirection: "steady" }, source: "mood" },
    { id: "evidence-work-weak", value: { type: "repeatedTheme", theme: "workPressure" },
      source: "authorizedJournalTheme", confidence: "low" },
    { id: "evidence-rest-weak", value: { type: "repeatedTheme", theme: "rest" },
      source: "authorizedJournalTheme", confidence: "low" },
    { id: "evidence-next-weak", value: { type: "nextMonthSuggestionBasis", suggestion: "continueRest" },
      source: "deterministicCombination" },
  ] });
  assert.throws(() => buildMonthlyStoryNarrativePlan(parseMonthlyStorySignal(weak)),
    /insufficient-meaningful-material/);
});

test("journal and Health permissions isolate their evidence categories", () => {
  const noJournal = syntheticMonthlyStorySignal({ journal: false, evidence: [
    { id: "evidence-mood-nojournal", value: { type: "emotionalShape", moodShape: "mixed",
      moodDirection: "steady" }, source: "mood" },
    { id: "evidence-sleep-nojournal", value: { type: "sleepPattern", sleep: "lessRestful" },
      source: "authorizedHealthSummary" },
    { id: "evidence-breathe-nojournal", value: { type: "restorativePractice", practice: "breathing" },
      source: "practicePresence" },
    { id: "evidence-next-nojournal", value: { type: "nextMonthSuggestionBasis",
      suggestion: "continueHelpfulPractice" }, source: "deterministicCombination" },
  ] });
  const noJournalPlan = buildMonthlyStoryNarrativePlan(parseMonthlyStorySignal(noJournal));
  assert.equal(monthlyStoryPlanClaimOptions(noJournalPlan).some((item) => item.key === "lessRestful"), true);
  assert.equal(monthlyStoryPlanClaimOptions(noJournalPlan).some((item) => item.key === "workPressure"), false);

  const noHealth = syntheticMonthlyStorySignal({ health: false, evidence: [
    { id: "evidence-mood-nohealth", value: { type: "emotionalShape", moodShape: "mixed",
      moodDirection: "steady" }, source: "mood" },
    { id: "evidence-work-nohealth", value: { type: "repeatedTheme", theme: "workPressure" },
      source: "authorizedJournalTheme" },
    { id: "evidence-rest-nohealth", value: { type: "repeatedTheme", theme: "rest" },
      source: "authorizedJournalTheme" },
    { id: "evidence-next-nohealth", value: { type: "nextMonthSuggestionBasis", suggestion: "continueRest" },
      source: "deterministicCombination" },
  ] });
  const noHealthPlan = buildMonthlyStoryNarrativePlan(parseMonthlyStorySignal(noHealth));
  assert.equal(monthlyStoryPlanClaimOptions(noHealthPlan).some((item) => item.key === "workPressure"), true);
  assert.equal(monthlyStoryPlanClaimOptions(noHealthPlan).some((item) => item.key === "lessRestful"), false);
});

test("conflicting summaries and safety-ineligible signals fail closed", () => {
  const conflicting = syntheticMonthlyStorySignal({ evidence: [
    { id: "evidence-mood-conflict-a", value: { type: "emotionalShape", moodShape: "mostlyHeavy",
      moodDirection: "heavier" }, source: "mood" },
    { id: "evidence-mood-conflict-b", value: { type: "emotionalShape", moodShape: "mostlyBright",
      moodDirection: "brighter" }, source: "mood" },
    { id: "evidence-work-conflict", value: { type: "repeatedTheme", theme: "workPressure" },
      source: "authorizedJournalTheme" },
    { id: "evidence-rest-conflict", value: { type: "repeatedTheme", theme: "rest" },
      source: "authorizedJournalTheme" },
    { id: "evidence-next-conflict", value: { type: "nextMonthSuggestionBasis", suggestion: "continueRest" },
      source: "deterministicCombination" },
  ] });
  assert.throws(() => buildMonthlyStoryNarrativePlan(parseMonthlyStorySignal(conflicting)),
    /conflicting-evidence/);
  assert.throws(() => parseMonthlyStorySignal({ ...SYNTHETIC_RICH_SIGNAL,
    isStorySafetyEligible: false }), /safety-ineligible/);
  const unsupported = structuredClone(SYNTHETIC_RICH_SIGNAL);
  (unsupported.evidence as Record<string, unknown>[])[1] = {
    ...(unsupported.evidence as Record<string, unknown>[])[1],
    value: { type: "repeatedTheme", theme: "unsupportedSyntheticTheme" },
  };
  assert.throws(() => parseMonthlyStorySignal(unsupported), /invalid-enum/);
});

test("delivered-only recommendation outcomes do not imply opening or benefit", () => {
  const raw = syntheticMonthlyStorySignal({ evidence: [
    { id: "evidence-mood-delivered", value: { type: "emotionalShape", moodShape: "mixed",
      moodDirection: "steady" }, source: "mood" },
    { id: "evidence-work-delivered", value: { type: "repeatedTheme", theme: "workPressure" },
      source: "authorizedJournalTheme" },
    { id: "evidence-rest-delivered", value: { type: "repeatedTheme", theme: "rest" },
      source: "authorizedJournalTheme" },
    { id: "evidence-rec-delivered", value: { type: "recommendationAction", recommendation: "delivered" },
      source: "recommendationOutcome" },
    { id: "evidence-next-delivered", value: { type: "nextMonthSuggestionBasis", suggestion: "continueRest" },
      source: "deterministicCombination" },
  ] });
  const plan = buildMonthlyStoryNarrativePlan(parseMonthlyStorySignal(raw));
  assert.equal(plan.recommendationReflection, null);
  assert.ok(plan.excludedEvidenceIds.includes("evidence-rec-delivered"));
});

test("closed claims expose only allowed phrases and keep forbidden implications out", () => {
  const signal = parseMonthlyStorySignal(SYNTHETIC_RICH_SIGNAL);
  for (const evidence of signal.evidence) {
    const option = claimOptionForEvidence(evidence);
    if (!option) continue;
    assert.ok(option.phrases.length >= 1);
    assert.ok(option.phrases.every((phrase) => phrase === phrase.toLowerCase()));
  }
  for (const [key, forbidden] of Object.entries(MONTHLY_STORY_FORBIDDEN_CLAIM_EXAMPLES)) {
    const allowed = allowedClaimPhrases(key as Parameters<typeof allowedClaimPhrases>[0]).join(" ");
    for (const phrase of forbidden) assert.equal(allowed.includes(phrase), false);
  }
  assert.match(allowedClaimPhrases("recommendationLeftUnopened").join(" "), /left them alone/);
  assert.match(allowedClaimPhrases("recommendationLeftUnopened").join(" "), /did not feel like opening/);
  assert.match(allowedClaimPhrases("recommendationOpened").join(" "), /shared something with you/);
  assert.match(allowedClaimPhrases("protectPersonalTime").join(" "), /work ends on time/);
  assert.match(allowedClaimPhrases("continueRest").join(" "), /weekend unplanned/);
  assert.match(allowedClaimPhrases("makeSpaceForProjects").join(" "), /own project/);
  assert.doesNotMatch(allowedClaimPhrases("recommendationLeftUnopened").join(" "), /ignored|failed|engage/);
});

test("writer, critic, and repair prompts carry only closed structured inputs", () => {
  const signal = parseMonthlyStorySignal(SYNTHETIC_RICH_SIGNAL);
  const plan = buildMonthlyStoryNarrativePlan(signal);
  const input = { plan, allowedClaims: monthlyStoryPlanClaimOptions(plan), storyMode: plan.storyMode,
    wordTarget: monthlyStoryWordTarget(plan),
    language: "en" as const, promptVersion: "writer-v1" };
  const prompts = [buildMonthlyStoryWriterPrompt(input),
    buildMonthlyStoryCriticPrompt(input, "synthetic script", plan.usedEvidenceIds,
      input.allowedClaims.map((item) => item.key)),
    buildMonthlyStoryRepairPrompt(input, "synthetic script",
      ["tooShort", "missingReliefSection"], ["tooCompressed"])];
  for (const prompt of prompts) {
    const payload = JSON.stringify(prompt.payload).toLowerCase();
    for (const prohibited of ["rawjournal", "gratitude", "healthsample", "recommendationtitle",
      "email", "deviceid", "uid", "private source", "transcript"]) assert.equal(payload.includes(prohibited), false);
  }
  assert.notEqual(prompts[0].system, prompts[1].system);
  assert.notEqual(prompts[1].system, prompts[2].system);
  assert.match(prompts[0].system, /repeat the opening in the closing/);
  assert.match(prompts[0].system, /Do not explain why emotions need no explanation/);
  assert.match(prompts[0].system, /one concrete spoken progression/);
  assert.match(prompts[0].system, /never exceed its preferred maximum/);
  assert.match(prompts[1].system, /meta-commentary about the reflection/);
  assert.match(prompts[1].system, /Reject when expansion requires new facts/);
  assert.match(prompts[2].system, /do not rewrite it from scratch/);
  const repairPayload = prompts[2].payload;
  assert.equal(repairPayload.originalWordCount, 2);
  assert.equal(repairPayload.minimumRequiredWordCount, 220);
  assert.deepEqual(repairPayload.preferredWordRange, { minimum: 220, maximum: 275 });
  assert.equal(repairPayload.profileMaximumWordCount, 275);
  assert.deepEqual(repairPayload.missingNarrativeSections, ["missingReliefSection"]);
});

test("synthetic corpus covers every approved quality and failure scenario", () => {
  assert.equal(MONTHLY_STORY_SYNTHETIC_CORPUS.length, 35);
  assert.equal(new Set(MONTHLY_STORY_SYNTHETIC_CORPUS.map(([id]) => id)).size, 35);
  assert.equal(MONTHLY_STORY_SYNTHETIC_CORPUS.every(([id]) => !/user|email|uid/i.test(id)), true);
});

test("all positive golden scripts are natural-length, traceable, and deterministic-validator clean", () => {
  for (const golden of MONTHLY_STORY_GOLDENS) {
    const signal = parseMonthlyStorySignal(golden.signal);
    const plan = buildMonthlyStoryNarrativePlan(signal);
    const result = validateMonthlyStoryScript({ script: golden.script,
      claimedEvidenceIds: golden.claimedEvidenceIds, claimKeys: golden.claimKeys,
      plan, availableEvidence: signal.evidence });
    const target = monthlyStoryWordTarget(plan);
    assert.equal(result.isValid, true, `${golden.id}: ${result.errors.join(",")}`);
    assert.ok(result.wordCount >= target.preferredMinimum, `${golden.id} is ${result.wordCount} words`);
    assert.ok(result.wordCount <= target.preferredMaximum, `${golden.id} is ${result.wordCount} words`);
  }
});

test("positive live-run regressions cover natural work, mood, recommendations, breathing, and suggestions", () => {
  const expected = new Map([
    ["rich-month", ["workPressure", "personalProjects", "makeSpaceForProjects"]],
    ["mood-only", ["monthHeavy", "continueRest"]],
    ["recommendation-month", ["recommendationOpened", "workPressure", "continueRest"]],
    ["no-journal-or-health", ["recommendationLeftUnopened", "breathingRelief",
      "continueHelpfulPractice"]],
  ]);
  for (const golden of MONTHLY_STORY_GOLDENS) {
    const signal = parseMonthlyStorySignal(golden.signal);
    const result = validateMonthlyStoryScript({ script: golden.script,
      claimedEvidenceIds: golden.claimedEvidenceIds, claimKeys: golden.claimKeys,
      plan: buildMonthlyStoryNarrativePlan(signal), availableEvidence: signal.evidence });
    assert.equal(result.isValid, true, golden.id);
    for (const key of expected.get(golden.id) ?? []) assert.ok(golden.claimKeys.includes(key as never));
  }
});

test("sleep and movement wording remains natural without adding causality", () => {
  const raw = syntheticMonthlyStorySignal({ evidence: [
    { id: "evidence-mood-body", value: { type: "emotionalShape", moodShape: "mostlyHeavy",
      moodDirection: "variable" }, source: "mood" },
    { id: "evidence-sleep-body", value: { type: "sleepPattern", sleep: "lessRestful" },
      source: "authorizedHealthSummary" },
    { id: "evidence-move-body", value: { type: "movementPattern", movement: "lessActive" },
      source: "authorizedHealthSummary" },
    { id: "evidence-breathe-body", value: { type: "restorativePractice", practice: "breathing" },
      source: "practicePresence" },
    { id: "evidence-rest-body", value: { type: "nextMonthSuggestionBasis", suggestion: "continueRest" },
      source: "deterministicCombination" },
  ] });
  const signal = parseMonthlyStorySignal(raw);
  const plan = buildMonthlyStoryNarrativePlan(signal);
  const claims = monthlyStoryPlanClaimOptions(plan);
  const script = `this month seemed heavy. you seemed more tired than usual. your body seemed to slow down when the month felt heavier. breathing gave you a quiet place to pause. some days felt demanding, while that simple pause offered a different pace. next month, leave one part of the weekend unplanned. keep the plan practical and easy to follow. a small amount of open time can stay open without becoming another task. the aim is simply to keep rest available when the week feels full. try to choose the time before other plans take it.`;
  const result = validateMonthlyStoryScript({ script,
    claimedEvidenceIds: claims.map((item) => item.evidenceId), claimKeys: claims.map((item) => item.key),
    plan, availableEvidence: signal.evidence });
  assert.equal(result.errors.every((error) => ["tooShort", "farBelowTargetLength"].includes(error)),
    true, result.errors.join(","));
  assert.equal(result.errors.includes("causalCertainty"), false);
});

test("negative goldens fail for their documented closed reason", () => {
  const signal = parseMonthlyStorySignal(SYNTHETIC_MOOD_ONLY_SIGNAL);
  const plan = buildMonthlyStoryNarrativePlan(signal);
  for (const golden of MONTHLY_STORY_NEGATIVE_GOLDENS) {
    const result = validateMonthlyStoryScript({ script: golden.script,
      claimedEvidenceIds: plan.usedEvidenceIds, claimKeys: monthlyStoryPlanClaimOptions(plan).map((item) => item.key),
      plan, availableEvidence: signal.evidence });
    assert.ok(result.errors.includes(golden.reason as typeof result.errors[number]), golden.id);
  }
});

test("TypeScript validator retains practical Stage 2 Swift parity", () => {
  const swift = readFileSync(join(__dirname, "..", "..", "Dino", "Services",
    "MonthlyStoryScriptValidator.swift"), "utf8");
  assert.match(swift, /minimumWords = 80/);
  assert.match(swift, /maximumWords = 300/);
  for (const phrase of ["your data shows", "you logged", "self-harm", "as your therapist",
    "best version of yourself", "using dino", "schemaVersion"]) assert.ok(swift.toLowerCase().includes(phrase.toLowerCase()));
});
