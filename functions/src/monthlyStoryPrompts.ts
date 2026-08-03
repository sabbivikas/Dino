import { MonthlyStoryClaimOption } from "./monthlyStoryClaims";
import { MonthlyStoryMode, MonthlyStoryNarrativePlan, MonthlyStoryWordTarget,
  monthlyStoryPlanClaimOptions, monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";

export type MonthlyStoryLanguage = "en";
export type MonthlyStoryPromptKind = "writer" | "critic" | "repair";

export type MonthlyStoryPrompt = {
  kind: MonthlyStoryPromptKind;
  version: string;
  system: string;
  payload: Readonly<Record<string, unknown>>;
};

export type MonthlyStoryPromptInput = {
  plan: MonthlyStoryNarrativePlan;
  allowedClaims: MonthlyStoryClaimOption[];
  storyMode: MonthlyStoryMode;
  wordTarget: MonthlyStoryWordTarget;
  language: MonthlyStoryLanguage;
  promptVersion: string;
};

const META_COMMENTARY_PHRASES = ["the month's shape", "the month’s shape", "the full reflection",
  "this is the reflection", "the overall picture", "belongs in the picture", "that is enough to say",
  "the month can remain mixed", "there is no need to explain", "there is no need to attach",
  "it does not need to become a larger story", "neither side needs to cancel the other",
  "both can belong", "this is not a demand", "this leaves a direction"] as const;

function repairSentencesToDelete(script: string, validationErrors: readonly string[]): string[] {
  const sentences = script.split(/(?<=[.!?])\s+/).map((item) => item.trim()).filter(Boolean);
  const meta = sentences.filter((sentence) => META_COMMENTARY_PHRASES.some((phrase) =>
    sentence.toLowerCase().includes(phrase)));
  if (validationErrors.includes("closingRestatesStory") ||
      validationErrors.includes("duplicatedOpeningClosing") ||
      validationErrors.includes("repeatedSuggestion")) {
    const closing = sentences.at(-1);
    if (closing) meta.push(closing);
  }
  return [...new Set(meta)];
}

function repeatedSuggestionKeys(script: string): string[] {
  const suggestionSentences = script.split(/(?<=[.!?])\s+/).filter((sentence) =>
    /\b(?:next month|try to|protect|leave|keep|save)\b/i.test(sentence));
  const groups = [
    ["protectPersonalTime", /work ends on time|hour after work|stopping point/i],
    ["continueRest", /room for real rest|weekend unplanned|part of the weekend/i],
    ["continueHelpfulPractice", /breath|quiet practice/i],
    ["makeSpaceForProjects", /personal project|own project|own ideas/i],
  ] as const;
  return groups.filter(([, pattern]) => suggestionSentences.filter((sentence) => pattern.test(sentence)).length > 1)
    .map(([key]) => key);
}

function validateInput(input: MonthlyStoryPromptInput): void {
  if (input.storyMode !== input.plan.storyMode || input.language !== "en" ||
      !/^[A-Za-z0-9._-]{1,32}$/.test(input.promptVersion) ||
      input.wordTarget.absoluteMaximum !== 300) throw new Error("invalid-prompt-input");
  const expectedTarget = monthlyStoryWordTarget(input.plan);
  if (Object.entries(expectedTarget).some(([key, value]) =>
    input.wordTarget[key as keyof MonthlyStoryWordTarget] !== value)) {
    throw new Error("invalid-prompt-input");
  }
  const planned = monthlyStoryPlanClaimOptions(input.plan);
  if (planned.length !== input.allowedClaims.length || planned.some((item, index) =>
    item.key !== input.allowedClaims[index]?.key || item.evidenceId !== input.allowedClaims[index]?.evidenceId)) {
    throw new Error("claim-plan-mismatch");
  }
}

function safePayload(input: MonthlyStoryPromptInput): Readonly<Record<string, unknown>> {
  return Object.freeze({
    broadMonth: input.plan.monthKey,
    storyMode: input.storyMode,
    overallTone: input.plan.overallMonthTone.key,
    claims: input.allowedClaims.map((claim) => ({ key: claim.key, evidenceId: claim.evidenceId,
      role: claim.role, allowedPhrases: [...claim.phrases] })),
    selectedStructure: {
      strongestDifficulty: input.plan.strongestDifficulty?.key ?? null,
      secondDifficulty: input.plan.secondDifficulty?.key ?? null,
      strongestReliefOrEnergy: input.plan.strongestReliefOrEnergy?.key ?? null,
      recommendationReflection: input.plan.recommendationReflection?.key ?? null,
      nextMonthSuggestions: input.plan.nextMonthSuggestionBases.map((item) => item.key),
      closingDirection: input.plan.closingDirection,
    },
    wordTarget: input.wordTarget,
    language: input.language,
  });
}

export function buildMonthlyStoryWriterPrompt(input: MonthlyStoryPromptInput): MonthlyStoryPrompt {
  validateInput(input);
  return {
    kind: "writer", version: input.promptVersion,
    system: [
      "Write a warm monthly reflection that sounds like a caring friend speaking plainly.",
      "Follow one concrete spoken progression: one short opening sentence; one paragraph for the strongest difficulty; one paragraph for another supported difficulty or source of relief; one recommendation sentence only when supported; one practical next-month paragraph; and one short closing sentence that adds no advice.",
      "Each paragraph must introduce one new supported point. Skip a section with no supporting claim. Never summarize earlier paragraphs at the end, repeat the opening in the closing, or state any suggestion twice.",
      "Use the supplied profile exactly. Reach its minimum, never exceed its preferred maximum, and never exceed 290 words. Stop when the supported points are covered. Leave unused word budget rather than pad, explain, or repeat a point in different words.",
      "Use only supplied closed claims. Never extend a claim into a cause, broader life conclusion, name, event, outcome, or diagnosis.",
      "In mood-only mode, be direct: describe the supported tone, acknowledge the unknown cause in at most one sentence, give one practical supported suggestion, and close briefly. Do not explain why emotions need no explanation or discuss what mixed feelings mean.",
      "Mood-only stories must not use there is no need, let, hold, meet this with, name it plainly, both feelings can belong, or other philosophical or therapy-style reassurance.",
      "In rich stories, mention each difficulty and relief once, never claim relief changed the month, and use at most two practical suggestions. Keep work, sleep, movement, mood, and relief as separate observations unless a supplied claim explicitly connects them.",
      "In standard stories, do not inflate limited evidence. Mention a recommendation once and describe breathing or focus as a brief pause only. Do not repeat that practice in the closing.",
      "Never mention data, analytics, logs, entries, check-ins, app use, scores, counts, percentages, algorithms, or evidence.",
      "Do not claim a recommendation helped. Vary recommendation wording using only its allowed meaning.",
      "Never talk about writing or interpreting the reflection. Prohibited ideas include the month's shape, the full reflection, the overall picture, what belongs in the picture, what is enough to say, why mixed feelings can coexist, or why the month does not need a larger explanation.",
      "Never use therapist or self-help language, generic resilience language, abstract emotional philosophy, or repeated uncertainty disclaimers.",
      "Keep suggestions concrete and supported. Do not add filler, invented inner thoughts, extra emotional explanation, or a second version of the same advice to reach the target.",
      "Return only the required structured response: script, claimedEvidenceIds, and claimKeys.",
    ].join(" "),
    payload: safePayload(input),
  };
}

export function buildMonthlyStoryCriticPrompt(input: MonthlyStoryPromptInput,
  script: string, claimedEvidenceIds: string[], claimKeys: string[]): MonthlyStoryPrompt {
  validateInput(input);
  return {
    kind: "critic", version: input.promptVersion,
    system: [
      "Judge the supplied reflection using only the plan and closed claims.",
      "Prioritize accuracy, natural spoken language, concision, usefulness, and freedom from repetition. Poetic warmth is not required.",
      "Check evidence alignment, unsupported causality, therapist tone, app or report language, meta-commentary about the reflection, padded explanation, repeated advice, redundant uncertainty, and a closing that restates the opening, story, or suggestions.",
      "Mark otherwise safe output repairable with metaCommentary, repeatedSuggestion, paddedExplanation, redundantUncertainty, closingRestatesStory, outsidePreferredWordRange, or the existing structural reason that applies.",
      "An overlong but otherwise safe script is repairable. Unnecessary explanations of mixed feelings are metaCommentary or paddedExplanation, not warmth.",
      "Mark repairable with tooCompressed, unusedSupportedEvidence, missingNarrativeSection, or insufficientProgression when valid claims can safely complete the story. Reject when expansion requires new facts, the plan is insufficient, or unsupported causes are central.",
      "A script outside its supplied profile range cannot pass. A pass does not require every available word when the story is complete.",
      "Do not rewrite or add facts. Return only closed scores, decision, and reason codes.",
    ].join(" "),
    payload: { ...safePayload(input), script, claimedEvidenceIds, claimKeys },
  };
}

export function buildMonthlyStoryRepairPrompt(input: MonthlyStoryPromptInput, script: string,
  validationErrors: readonly string[], criticErrors: readonly string[],
  claimedEvidenceIds: readonly string[] = [], claimKeys: readonly string[] = []): MonthlyStoryPrompt {
  validateInput(input);
  const originalWordCount = script.trim() ? script.trim().split(/\s+/).length : 0;
  const missingNarrativeSections = validationErrors.filter((error) =>
    ["missingDifficultySection", "missingReliefSection", "missingNextMonthSection",
      "collapsedToSummary", "insufficientNarrativeProgression"].includes(error));
  const usedKeys = new Set(claimKeys);
  const sentencesToDelete = repairSentencesToDelete(script, validationErrors);
  const repeatedKeys = repeatedSuggestionKeys(script);
  return {
    kind: "repair", version: input.promptVersion,
    system: [
      "Edit the original reflection once; do not rewrite it from scratch. Correct only the listed validation and critic problems.",
      "First delete meta-commentary, repeated emotional summaries, duplicated suggestions, and any closing that restates the story. Shorten overlong output before changing anything else.",
      "Preserve valid supported claims and one useful version of each concrete suggestion. Preserve the profile minimum while staying at or below its preferred maximum.",
      "Use the original plan and closed claims. Do not add facts, causes, evidence, imagined thoughts, unrelated advice, or a generic fallback.",
      "If the original is below its required minimum, expand it with unused supported claims, separate supported observations, concrete supported suggestions, and natural transitions. Do not collapse it into a summary.",
      "Never add emotional explanation, therapy language, generic philosophy, filler, or a second version of a suggestion. A closing must be one short sentence with no new or repeated advice.",
      "Use short spoken sentences. Each paragraph must add a new supported point; stop once those points are covered.",
      "Return only script, claimedEvidenceIds, and claimKeys.",
    ].join(" "),
    payload: { ...safePayload(input), originalScript: script,
      originalWordCount, minimumRequiredWordCount: input.wordTarget.acceptanceMinimum,
      preferredWordRange: { minimum: input.wordTarget.preferredMinimum,
        maximum: input.wordTarget.preferredMaximum },
      profileMaximumWordCount: input.wordTarget.preferredMaximum,
      sentencesToDelete, repeatedSuggestionKeys: repeatedKeys,
      openingOrClosingRepeated: validationErrors.includes("closingRestatesStory") ||
        validationErrors.includes("duplicatedOpeningClosing"),
      missingNarrativeSections, originalClaimedEvidenceIds: [...claimedEvidenceIds],
      originalClaimKeys: [...claimKeys], unusedSupportedClaimKeys: input.allowedClaims
        .filter((claim) => !usedKeys.has(claim.key)).map((claim) => claim.key),
      validationErrors: [...validationErrors], criticErrors: [...criticErrors] },
  };
}
