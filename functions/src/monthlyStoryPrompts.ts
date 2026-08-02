import { MonthlyStoryClaimOption } from "./monthlyStoryClaims";
import { MonthlyStoryMode, MonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions } from "./monthlyStoryNarrativePlan";

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
  wordTarget: { minimum: number; preferredMaximum: number; absoluteMaximum: number };
  language: MonthlyStoryLanguage;
  promptVersion: string;
};

function validateInput(input: MonthlyStoryPromptInput): void {
  if (input.storyMode !== input.plan.storyMode || input.language !== "en" ||
      !/^[A-Za-z0-9._-]{1,32}$/.test(input.promptVersion) ||
      input.wordTarget.minimum !== 220 || input.wordTarget.preferredMaximum !== 290 ||
      input.wordTarget.absoluteMaximum !== 300) throw new Error("invalid-prompt-input");
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
      "Write a natural spoken monthly reflection in simple English.",
      "Sound warm and thoughtful, but restrained: never like a therapist, coach, report, or poem.",
      "Describe the person's month, not product use. Focus on the strongest two or three observations.",
      "Use only the supplied closed claim options. Do not infer causes, names, events, outcomes, or diagnoses.",
      "Mood-only mode may describe emotional shape but may not invent life reasons or causes.",
      "Never mention data, analytics, logs, entries, check-ins, app use, scores, counts, percentages, algorithms, or evidence.",
      "Do not claim that a recommendation helped. Do not repeat the conclusion.",
      "End with one to three realistic next-month suggestions grounded in supplied suggestion claims.",
      "Target 220 to 290 words and never exceed 300 words.",
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
      "Evaluate natural spoken language, evidence alignment, certainty, repetition, clinical tone, motivational tone, report tone, warmth, useful suggestions, and whether it feels like a month reflection.",
      "Do not rewrite it and do not add facts. Return only closed scores, decision, and reason codes.",
    ].join(" "),
    payload: { ...safePayload(input), script, claimedEvidenceIds, claimKeys },
  };
}

export function buildMonthlyStoryRepairPrompt(input: MonthlyStoryPromptInput, script: string,
  validationErrors: readonly string[], criticErrors: readonly string[]): MonthlyStoryPrompt {
  validateInput(input);
  return {
    kind: "repair", version: input.promptVersion,
    system: [
      "Repair the reflection once. Correct only the listed validation and critic problems.",
      "Use the original plan and closed claims. Do not add facts, evidence, explanations, or a generic fallback.",
      "Return only script, claimedEvidenceIds, and claimKeys.",
    ].join(" "),
    payload: { ...safePayload(input), originalScript: script,
      validationErrors: [...validationErrors], criticErrors: [...criticErrors] },
  };
}
