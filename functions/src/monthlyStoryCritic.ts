import { MonthlyStoryProviderError } from "./monthlyStoryTextProvider";

export const MONTHLY_STORY_CRITIC_REASON_CODES = [
  "unnatural", "evidenceMismatch", "unsupportedCertainty", "repetitive", "clinicalTone",
  "motivationalTone", "reportTone", "insufficientWarmth", "weakSuggestions",
  "notMonthReflection", "notSpokenLanguage", "overlyPoetic", "outsidePreferredWordRange",
  "therapistTone", "abstractFiller", "duplicatedOpeningClosing", "genericAdvice",
  "tooCompressed", "unusedSupportedEvidence", "missingNarrativeSection",
  "insufficientProgression", "metaCommentary", "repeatedSuggestion", "paddedExplanation",
  "redundantUncertainty", "closingRestatesStory",
] as const;
export type MonthlyStoryCriticReasonCode = typeof MONTHLY_STORY_CRITIC_REASON_CODES[number];
export type MonthlyStoryCriticDecision = "pass" | "repairable" | "reject";

export type MonthlyStoryCriticScores = {
  naturalness: number;
  evidenceAlignment: number;
  unsupportedCertainty: number;
  repetition: number;
  clinicalTone: number;
  motivationalTone: number;
  reportTone: number;
  warmth: number;
  suggestionUsefulness: number;
  monthReflection: number;
  spokenLanguage: number;
};

export type MonthlyStoryCriticResult = {
  decision: MonthlyStoryCriticDecision;
  reasons: MonthlyStoryCriticReasonCode[];
  scores: MonthlyStoryCriticScores;
  syntheticCostMicros: number;
};

const SCORE_FIELDS: readonly (keyof MonthlyStoryCriticScores)[] = ["naturalness", "evidenceAlignment",
  "unsupportedCertainty", "repetition", "clinicalTone", "motivationalTone", "reportTone", "warmth",
  "suggestionUsefulness", "monthReflection", "spokenLanguage"];

function exactRecord(value: unknown, fields: readonly string[]): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new MonthlyStoryProviderError("malformed-response");
  }
  const record = value as Record<string, unknown>;
  if (Object.keys(record).length !== fields.length || Object.keys(record).some((key) => !fields.includes(key))) {
    throw new MonthlyStoryProviderError("malformed-response");
  }
  return record;
}

export function parseMonthlyStoryCriticResult(value: unknown): MonthlyStoryCriticResult {
  const data = exactRecord(value, ["decision", "reasons", "scores", "syntheticCostMicros"]);
  if (data.decision !== "pass" && data.decision !== "repairable" && data.decision !== "reject") {
    throw new MonthlyStoryProviderError("malformed-response");
  }
  if (!Array.isArray(data.reasons) || data.reasons.length > MONTHLY_STORY_CRITIC_REASON_CODES.length ||
      data.reasons.some((reason) => typeof reason !== "string" ||
        !(MONTHLY_STORY_CRITIC_REASON_CODES as readonly string[]).includes(reason)) ||
      new Set(data.reasons).size !== data.reasons.length) {
    throw new MonthlyStoryProviderError("malformed-response");
  }
  if ((data.decision === "pass" && data.reasons.length !== 0) ||
      (data.decision !== "pass" && data.reasons.length === 0)) {
    throw new MonthlyStoryProviderError("malformed-response");
  }
  const scoreData = exactRecord(data.scores, SCORE_FIELDS);
  if (SCORE_FIELDS.some((field) => typeof scoreData[field] !== "number" ||
      !Number.isSafeInteger(scoreData[field]) || (scoreData[field] as number) < 1 ||
      (scoreData[field] as number) > 5) || typeof data.syntheticCostMicros !== "number" ||
      !Number.isSafeInteger(data.syntheticCostMicros) || data.syntheticCostMicros < 0) {
    throw new MonthlyStoryProviderError("malformed-response");
  }
  return { decision: data.decision, reasons: data.reasons as MonthlyStoryCriticReasonCode[],
    scores: scoreData as MonthlyStoryCriticScores, syntheticCostMicros: data.syntheticCostMicros };
}

export function passingMonthlyStoryCriticResult(syntheticCostMicros = 0): MonthlyStoryCriticResult {
  return { decision: "pass", reasons: [], syntheticCostMicros,
    scores: { naturalness: 5, evidenceAlignment: 5, unsupportedCertainty: 5, repetition: 5,
      clinicalTone: 5, motivationalTone: 5, reportTone: 5, warmth: 5, suggestionUsefulness: 5,
      monthReflection: 5, spokenLanguage: 5 } };
}
