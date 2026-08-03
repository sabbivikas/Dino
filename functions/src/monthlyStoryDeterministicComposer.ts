import { createHash } from "crypto";
import { MonthlyStoryClaimKey, MonthlyStoryClaimOption,
  isMonthlyStoryClaimKey } from "./monthlyStoryClaims";
import { MonthlyStoryNarrativeClass, MonthlyStoryNarrativePlan,
  monthlyStoryPlanClaimOptions, monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";
import { isApprovedMonthlyStoryPhrase, monthlyStoryPhraseSet } from "./monthlyStoryPhraseLibrary";

export const MONTHLY_STORY_DETERMINISTIC_COMPOSITION_VERSION = "deterministic-v1";
export const MONTHLY_STORY_SENTENCE_SMOOTHING_DEFAULT = Object.freeze({ enabled: false,
  rolloutBasisPoints: 0, maximumCallsPerStory: 0 });
export const MONTHLY_STORY_DETERMINISTIC_PROVIDER_COST_MICROS = 0;

export type MonthlyStoryDeterministicCostModel = {
  deterministicTextProviderMicros: 0;
  optionalSentenceSmoothingProviderMicros: number | null;
  ttsProviderMicros: null;
};

export function monthlyStoryDeterministicCostModel(optionalSmoothingProviderMicros: number | null = null):
MonthlyStoryDeterministicCostModel {
  if (optionalSmoothingProviderMicros !== null &&
      (!Number.isSafeInteger(optionalSmoothingProviderMicros) || optionalSmoothingProviderMicros < 0)) {
    throw new MonthlyStoryDeterministicComposerError("invalidDeterministicInput");
  }
  return { deterministicTextProviderMicros: 0,
    optionalSentenceSmoothingProviderMicros: optionalSmoothingProviderMicros, ttsProviderMicros: null };
}

export type MonthlyStoryDeterministicComposerInput = {
  plan: MonthlyStoryNarrativePlan;
  profile: MonthlyStoryNarrativeClass;
  closedClaims: readonly MonthlyStoryClaimOption[];
  approvedSuggestionKeys: readonly MonthlyStoryClaimKey[];
  monthDisplayName: string;
  language: "en";
  generationVersion: string;
  stableUserHash: string;
};

export type MonthlyStoryParagraphTrace = {
  paragraphIndex: number;
  claimKeys: MonthlyStoryClaimKey[];
  evidenceIds: string[];
};

export type MonthlyStoryDeterministicComposition = {
  script: string;
  paragraphs: string[];
  paragraphTrace: MonthlyStoryParagraphTrace[];
  usedEvidenceIds: string[];
  usedClaimKeys: MonthlyStoryClaimKey[];
  usedSuggestionKeys: MonthlyStoryClaimKey[];
  wordCount: number;
  profile: MonthlyStoryNarrativeClass;
  compositionVersion: typeof MONTHLY_STORY_DETERMINISTIC_COMPOSITION_VERSION;
};

export type MonthlyStoryDeterministicComposerErrorCode = "invalidDeterministicInput" |
  "profileMismatch" | "claimMismatch" | "duplicateClaim" | "unsupportedSuggestion" |
  "insufficientDeterministicContent";

export class MonthlyStoryDeterministicComposerError extends Error {
  constructor(readonly code: MonthlyStoryDeterministicComposerErrorCode) {
    super(code);
    this.name = "MonthlyStoryDeterministicComposerError";
  }
}

export interface MonthlyStorySentenceSmoother {
  smooth(input: { sentence: string; claimKey: MonthlyStoryClaimKey;
    prohibitedFacts: readonly string[]; maximumCharacterCount: number }): Promise<string>;
}

type Section = { sentences: string[]; optional: string[]; claimKeys: MonthlyStoryClaimKey[];
  evidenceIds: string[] };

const CLOSINGS = ["that is enough to carry into next month.",
  "those are the parts of the month worth keeping close.",
  "next month can begin with those small changes.",
  "for now, start with the parts that felt most useful."] as const;

const MOOD_UNKNOWN_CAUSES = ["i do not know what was behind that feeling, so i will not guess.",
  "i do not know why the month felt that way, and i will not make up a reason.",
  "the reason is not clear, and it would be wrong to invent one."] as const;

function stableNumber(parts: readonly string[]): number {
  const digest = createHash("sha256").update(parts.join("\u001f"), "utf8").digest();
  return digest.readUInt32BE(0);
}

function choose<T>(values: readonly T[], input: MonthlyStoryDeterministicComposerInput,
  key: string, offset = 0): T {
  if (values.length === 0) throw new MonthlyStoryDeterministicComposerError("insufficientDeterministicContent");
  return values[stableNumber([input.stableUserHash, input.plan.monthKey, input.generationVersion,
    key, String(offset)]) % values.length];
}

function render(sentence: string, input: MonthlyStoryDeterministicComposerInput): string {
  return sentence.split("{month}").join(input.monthDisplayName.toLowerCase());
}

function wordCount(value: string): number {
  return value.trim() ? value.trim().split(/\s+/).length : 0;
}

function claimSection(claim: MonthlyStoryClaimOption, input: MonthlyStoryDeterministicComposerInput): Section {
  const set = monthlyStoryPhraseSet(claim.key);
  const core = render(choose(set.core, input, `${claim.key}:core`), input);
  const optional = [...set.support, ...set.transition]
    .map((value, index) => ({ value: render(value, input), rank: stableNumber([input.stableUserHash,
      input.plan.monthKey, input.generationVersion, claim.key, "optional", String(index)]) }))
    .sort((left, right) => left.rank - right.rank).map((item) => item.value);
  return { sentences: [core], optional, claimKeys: [claim.key], evidenceIds: [claim.evidenceId] };
}

function validateInput(input: MonthlyStoryDeterministicComposerInput): Map<MonthlyStoryClaimKey,
MonthlyStoryClaimOption> {
  if (input.language !== "en" || !/^[A-Za-z]{3,12}$/.test(input.monthDisplayName) ||
      !/^[A-Za-z0-9._-]{1,32}$/.test(input.generationVersion) ||
      !/^[a-f0-9]{32,128}$/.test(input.stableUserHash)) {
    throw new MonthlyStoryDeterministicComposerError("invalidDeterministicInput");
  }
  const target = monthlyStoryWordTarget(input.plan);
  if (target.narrativeClass !== input.profile) {
    throw new MonthlyStoryDeterministicComposerError("profileMismatch");
  }
  const planned = new Map(monthlyStoryPlanClaimOptions(input.plan).map((claim) => [claim.key, claim]));
  const claims = new Map<MonthlyStoryClaimKey, MonthlyStoryClaimOption>();
  for (const claim of input.closedClaims) {
    if (!isMonthlyStoryClaimKey(claim.key) || claims.has(claim.key)) {
      throw new MonthlyStoryDeterministicComposerError("duplicateClaim");
    }
    const expected = planned.get(claim.key);
    if (!expected || expected.evidenceId !== claim.evidenceId || expected.role !== claim.role) {
      throw new MonthlyStoryDeterministicComposerError("claimMismatch");
    }
    claims.set(claim.key, claim);
  }
  for (const required of planned.values()) {
    if (!claims.has(required.key)) throw new MonthlyStoryDeterministicComposerError("claimMismatch");
  }
  if (new Set(input.approvedSuggestionKeys).size !== input.approvedSuggestionKeys.length ||
      input.approvedSuggestionKeys.some((key) => claims.get(key)?.role !== "suggestion")) {
    throw new MonthlyStoryDeterministicComposerError("unsupportedSuggestion");
  }
  return claims;
}

function selectedObservationClaims(input: MonthlyStoryDeterministicComposerInput,
  claims: ReadonlyMap<MonthlyStoryClaimKey, MonthlyStoryClaimOption>): MonthlyStoryClaimOption[] {
  const ordered = input.plan.storyMode === "moodOnly" ? [] : [input.plan.strongestDifficulty,
    input.plan.secondDifficulty, input.plan.strongestReliefOrEnergy, input.plan.recommendationReflection];
  return ordered.filter((claim): claim is MonthlyStoryClaimOption => claim !== null)
    .map((claim) => claims.get(claim.key))
    .filter((claim): claim is MonthlyStoryClaimOption => claim !== undefined);
}

function addOptionalContent(sections: Section[], minimum: number, maximum: number): void {
  let cursor = 0;
  while (wordCount(sections.map((section) => section.sentences.join(" ")).join(" ")) < minimum) {
    const candidates = sections.filter((section) => section.optional.length > 0);
    if (candidates.length === 0) {
      throw new MonthlyStoryDeterministicComposerError("insufficientDeterministicContent");
    }
    const section = candidates[cursor % candidates.length];
    cursor += 1;
    const sentence = section.optional.shift();
    if (!sentence) continue;
    const current = wordCount(sections.map((item) => item.sentences.join(" ")).join(" "));
    if (current + wordCount(sentence) <= maximum) section.sentences.push(sentence);
  }
}

export function composeMonthlyStoryDeterministically(input: MonthlyStoryDeterministicComposerInput):
MonthlyStoryDeterministicComposition {
  const claims = validateInput(input);
  const tone = claims.get(input.plan.overallMonthTone.key);
  if (!tone) throw new MonthlyStoryDeterministicComposerError("claimMismatch");
  const toneSection = claimSection(tone, input);
  const sections: Section[] = [toneSection];

  if (input.plan.storyMode === "moodOnly") {
    const toneSet = monthlyStoryPhraseSet(tone.key);
    toneSection.optional = [];
    const shapeSentences = [...toneSet.support, ...toneSet.transition]
      .map((sentence) => render(sentence, input));
    sections.push({ sentences: [shapeSentences.shift() ?? ""].filter(Boolean), optional: shapeSentences,
      claimKeys: [tone.key], evidenceIds: [tone.evidenceId] });
    sections.push({ sentences: [choose(MOOD_UNKNOWN_CAUSES, input, "mood-unknown-cause")], optional: [],
      claimKeys: [tone.key], evidenceIds: [tone.evidenceId] });
  } else {
    for (const observation of selectedObservationClaims(input, claims)) {
      sections.push(claimSection(observation, input));
    }
  }

  const maximumSuggestions = input.profile === "moodOnly" ? 1 : 2;
  const suggestions = input.approvedSuggestionKeys.slice(0, maximumSuggestions).map((key) => claims.get(key));
  if (suggestions.some((claim) => !claim) || suggestions.length === 0) {
    throw new MonthlyStoryDeterministicComposerError("unsupportedSuggestion");
  }
  for (const suggestion of suggestions) sections.push(claimSection(suggestion!, input));

  const closing = choose(CLOSINGS, input, "closing");
  sections.push({ sentences: [closing], optional: [], claimKeys: [], evidenceIds: [] });
  const target = monthlyStoryWordTarget(input.plan);
  addOptionalContent(sections.slice(0, -1), target.preferredMinimum, target.preferredMaximum);
  const paragraphs = sections.map((section) => section.sentences.join(" "));
  const script = paragraphs.join("\n\n");
  const totalWords = wordCount(script);
  if (totalWords < target.preferredMinimum || totalWords > target.preferredMaximum) {
    throw new MonthlyStoryDeterministicComposerError("insufficientDeterministicContent");
  }
  const usedClaimKeys = sections.flatMap((section) => section.claimKeys)
    .filter((key, index, all) => all.indexOf(key) === index);
  const usedEvidenceIds = sections.flatMap((section) => section.evidenceIds)
    .filter((id, index, all) => all.indexOf(id) === index);
  return { script, paragraphs,
    paragraphTrace: sections.map((section, paragraphIndex) => ({ paragraphIndex,
      claimKeys: [...section.claimKeys], evidenceIds: [...section.evidenceIds] })),
    usedEvidenceIds, usedClaimKeys,
    usedSuggestionKeys: suggestions.map((claim) => claim!.key), wordCount: totalWords,
    profile: input.profile, compositionVersion: MONTHLY_STORY_DETERMINISTIC_COMPOSITION_VERSION };
}

function isSingleSentence(value: string): boolean {
  const trimmed = value.trim();
  return trimmed.length > 0 && trimmed.split(/[.!?]+/).filter((part) => part.trim()).length === 1;
}

export async function smoothMonthlyStorySentenceOrFallback(input: { sentence: string;
  claimKey: MonthlyStoryClaimKey; prohibitedFacts: readonly string[]; maximumCharacterCount: number },
smoother: MonthlyStorySentenceSmoother): Promise<string> {
  const suggestionKeys = new Set<MonthlyStoryClaimKey>(["continueRest", "protectPersonalTime",
    "seekConnection", "continueHelpfulPractice", "makeSpaceForProjects"]);
  if (suggestionKeys.has(input.claimKey)) return input.sentence;
  try {
    const smoothed = (await smoother.smooth(input)).trim();
    if (smoothed.length > input.maximumCharacterCount || !isSingleSentence(smoothed) ||
        input.prohibitedFacts.some((fact) => fact.length > 0 && smoothed.toLowerCase().includes(fact.toLowerCase())) ||
        !isApprovedMonthlyStoryPhrase(input.claimKey, smoothed)) return input.sentence;
    return smoothed;
  } catch {
    return input.sentence;
  }
}
