import { createHash } from "crypto";
import assert from "node:assert";
import { test } from "node:test";
import { composeMonthlyStoryDeterministically } from "./monthlyStoryDeterministicComposer";
import { buildMonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions,
  monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";
import { monthlyStoryPhraseSet } from "./monthlyStoryPhraseLibrary";
import { parseMonthlyStorySignal } from "./monthlyStorySchema";
import { validateMonthlyStoryScript } from "./monthlyStoryScriptValidator";
import { syntheticMonthlyStorySignal } from "./monthlyStoryWrittenFixtures";

// The sparse-month regression: a moodOnly plan whose only beats are the tone claim and a single
// next-month suggestion. The composer has to reach preferredMinimum out of the tone and suggestion
// phrase pools alone, so every seed-reachable core/cause/suggestion combination must be covered.
const GENERATION_VERSION = "gen-v1";
const MONTH_DISPLAY_NAME = "July";
const SEED_SEPARATOR = String.fromCharCode(31);

// Mirrors the private MOOD_UNKNOWN_CAUSES corpus in monthlyStoryDeterministicComposer.
const MOOD_UNKNOWN_CAUSES = ["i do not know what was behind that feeling, so i will not guess.",
  "i do not know why the month felt that way, and i will not make up a reason.",
  "the reason is not clear, and it would be wrong to invent one."] as const;

const signal = parseMonthlyStorySignal(syntheticMonthlyStorySignal({ mode: "moodOnly",
  journal: false, health: false, evidence: [
    { id: "sparse-variable-mood",
      value: { type: "emotionalShape", moodShape: "variable", moodDirection: "variable" },
      source: "mood" },
    { id: "sparse-connection-suggestion",
      value: { type: "nextMonthSuggestionBasis", suggestion: "seekConnection" },
      source: "deterministicCombination" },
  ] }));
const plan = buildMonthlyStoryNarrativePlan(signal);
const target = monthlyStoryWordTarget(plan);
const toneCores = monthlyStoryPhraseSet("monthVariable").core;
const suggestionCores = monthlyStoryPhraseSet("seekConnection").core;

// Works backwards from choose()/stableNumber: the selected variant for a key is
// sha256([stableUserHash, monthKey, generationVersion, key, offset].join(US)) >>> index % length.
function stableNumber(parts: readonly string[]): number {
  return createHash("sha256").update(parts.join(SEED_SEPARATOR), "utf8").digest().readUInt32BE(0);
}

function chosenIndex(stableUserHash: string, key: string, length: number): number {
  return stableNumber([stableUserHash, plan.monthKey, GENERATION_VERSION, key, "0"]) % length;
}

function combinationFor(stableUserHash: string): [number, number, number] {
  return [chosenIndex(stableUserHash, "monthVariable:core", toneCores.length),
    chosenIndex(stableUserHash, "mood-unknown-cause", MOOD_UNKNOWN_CAUSES.length),
    chosenIndex(stableUserHash, "seekConnection:core", suggestionCores.length)];
}

function inputFor(stableUserHash: string) {
  return { plan, profile: target.narrativeClass, closedClaims: monthlyStoryPlanClaimOptions(plan),
    approvedSuggestionKeys: plan.nextMonthSuggestionBases.map((claim) => claim.key),
    monthDisplayName: MONTH_DISPLAY_NAME, language: "en" as const,
    generationVersion: GENERATION_VERSION, stableUserHash };
}

function render(sentence: string): string {
  return sentence.split("{month}").join(MONTH_DISPLAY_NAME.toLowerCase());
}

// Bucket candidate seeds by the combination they select until the full cross product is covered.
function seedsCoveringEveryCombination(): Map<string, string> {
  const expected = toneCores.length * MOOD_UNKNOWN_CAUSES.length * suggestionCores.length;
  const seeds = new Map<string, string>();
  for (let attempt = 0; seeds.size < expected && attempt < 100000; attempt += 1) {
    const stableUserHash = createHash("sha256")
      .update(`sparse-mood-only-variable-connection-${attempt}`).digest("hex");
    const id = combinationFor(stableUserHash).join("-");
    if (!seeds.has(id)) seeds.set(id, stableUserHash);
  }
  return seeds;
}

test("the sparse mood-only month composes for every seed-reachable variant combination", () => {
  assert.equal(plan.storyMode, "moodOnly");
  assert.equal(plan.overallMonthTone.key, "monthVariable");
  assert.deepEqual(plan.nextMonthSuggestionBases.map((claim) => claim.key), ["seekConnection"]);
  assert.equal(target.preferredMinimum, 150);
  assert.equal(target.preferredMaximum, 210);
  assert.equal(toneCores.length, 3);
  assert.equal(MOOD_UNKNOWN_CAUSES.length, 3);
  assert.equal(suggestionCores.length, 3);

  const seeds = seedsCoveringEveryCombination();
  // The coverage itself is asserted: exactly the full 3 x 3 x 3 cross product, nothing missing.
  const fullCrossProduct: string[] = [];
  for (let tone = 0; tone < toneCores.length; tone += 1) {
    for (let cause = 0; cause < MOOD_UNKNOWN_CAUSES.length; cause += 1) {
      for (let suggestion = 0; suggestion < suggestionCores.length; suggestion += 1) {
        fullCrossProduct.push([tone, cause, suggestion].join("-"));
      }
    }
  }
  assert.equal(seeds.size, 27);
  assert.deepEqual([...seeds.keys()].sort(), [...fullCrossProduct].sort());

  // Every combination is exercised before asserting, so a regression reports all of them at once
  // rather than aborting on the first throw.
  const observed = new Set<string>();
  const wordCounts: number[] = [];
  const failures: string[] = [];
  for (const [id, stableUserHash] of seeds) {
    const [toneIndex, causeIndex, suggestionIndex] = combinationFor(stableUserHash);
    let result;
    try {
      result = composeMonthlyStoryDeterministically(inputFor(stableUserHash));
    } catch (error) {
      failures.push(`${id}: threw ${(error as Error).message}`);
      continue;
    }
    // The composed script must actually carry the predicted variants, so the coverage is real.
    assert.equal(result.paragraphs[0], render(toneCores[toneIndex]), `${id}: tone core`);
    assert.equal(result.paragraphs[2], MOOD_UNKNOWN_CAUSES[causeIndex], `${id}: mood-unknown cause`);
    assert.ok(result.paragraphs[3].startsWith(render(suggestionCores[suggestionIndex])),
      `${id}: suggestion core -> ${result.paragraphs[3]}`);
    if (result.wordCount < target.preferredMinimum || result.wordCount > target.preferredMaximum) {
      failures.push(`${id}: ${result.wordCount} outside ` +
        `${target.preferredMinimum}-${target.preferredMaximum}`);
      continue;
    }
    observed.add(id);
    wordCounts.push(result.wordCount);
  }
  assert.deepEqual(failures, [], `${failures.length} of ${seeds.size} combinations failed:\n` +
    failures.join("\n"));
  assert.deepEqual([...observed].sort(), [...fullCrossProduct].sort());
  assert.equal(wordCounts.length, 27);
});

test("every sparse mood-only variant still passes the script validator unchanged", () => {
  for (const [id, stableUserHash] of seedsCoveringEveryCombination()) {
    const result = composeMonthlyStoryDeterministically(inputFor(stableUserHash));
    const validation = validateMonthlyStoryScript({ script: result.script,
      claimedEvidenceIds: result.usedEvidenceIds, claimKeys: result.usedClaimKeys,
      plan, availableEvidence: signal.evidence });
    assert.deepEqual(validation.errors, [], `${id}: ${validation.errors.join(",")}`);
    assert.deepEqual(validation.warnings, [], `${id}: ${validation.warnings.join(",")}`);
    assert.equal(validation.isValid, true, id);
  }
});
