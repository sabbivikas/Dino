import { MonthlyStoryClaimOption, claimOptionForEvidence } from "./monthlyStoryClaims";
import { MonthlyStoryEvidence, MonthlyStorySignal } from "./monthlyStorySchema";

export type MonthlyStoryMode = "standard" | "moodOnly";
export type MonthlyStoryClosingDirection = "gentleForwardLook" | "quietCompanionship";

export type MonthlyStoryNarrativePlan = {
  monthKey: string;
  storyMode: MonthlyStoryMode;
  overallMonthTone: MonthlyStoryClaimOption;
  strongestDifficulty: MonthlyStoryClaimOption | null;
  secondDifficulty: MonthlyStoryClaimOption | null;
  strongestReliefOrEnergy: MonthlyStoryClaimOption | null;
  recommendationReflection: MonthlyStoryClaimOption | null;
  nextMonthSuggestionBases: MonthlyStoryClaimOption[];
  closingDirection: MonthlyStoryClosingDirection;
  usedEvidenceIds: string[];
  excludedEvidenceIds: string[];
};

export class MonthlyStoryNarrativePlanError extends Error {
  constructor(readonly code: "ineligible-signal" | "missing-emotional-shape" |
    "insufficient-meaningful-material" | "mood-only-cause" | "conflicting-evidence") {
    super(code);
    this.name = "MonthlyStoryNarrativePlanError";
  }
}

const confidenceRank = { high: 3, medium: 2, low: 1 } as const;

function orderEvidence(left: MonthlyStoryEvidence, right: MonthlyStoryEvidence): number {
  const confidence = confidenceRank[right.confidence] - confidenceRank[left.confidence];
  if (confidence !== 0) return confidence;
  const duration = (item: MonthlyStoryEvidence): number =>
    Date.parse(`${item.endDay}T00:00:00.000Z`) - Date.parse(`${item.startDay}T00:00:00.000Z`);
  const span = duration(right) - duration(left);
  return span !== 0 ? span : left.id.localeCompare(right.id);
}

function uniqueStrongest(options: { evidence: MonthlyStoryEvidence; claim: MonthlyStoryClaimOption }[]):
  { evidence: MonthlyStoryEvidence; claim: MonthlyStoryClaimOption }[] {
  const seen = new Set<string>();
  return [...options].sort((a, b) => orderEvidence(a.evidence, b.evidence)).filter((item) => {
    if (seen.has(item.claim.key)) return false;
    seen.add(item.claim.key);
    return true;
  });
}

export function buildMonthlyStoryNarrativePlan(signal: MonthlyStorySignal): MonthlyStoryNarrativePlan {
  const eligibility = signal.eligibility?.code;
  if (eligibility !== "eligibleStandard" && eligibility !== "eligibleMoodOnly") {
    throw new MonthlyStoryNarrativePlanError("ineligible-signal");
  }
  const storyMode: MonthlyStoryMode = eligibility === "eligibleMoodOnly" ? "moodOnly" : "standard";
  const rawCandidates = signal.evidence.flatMap((evidence) => {
    if (evidence.confidence === "low") return [];
    const option = claimOptionForEvidence(evidence);
    return option ? [{ evidence, claim: option }] : [];
  });
  for (const category of ["emotionalShape", "sleepPattern", "movementPattern"] as const) {
    const keys = new Set(rawCandidates.filter((item) => item.evidence.category === category)
      .map((item) => item.claim.key));
    if (keys.size > 1) throw new MonthlyStoryNarrativePlanError("conflicting-evidence");
  }
  const candidates = uniqueStrongest(rawCandidates);
  const tone = candidates.find((item) => item.claim.role === "tone");
  if (!tone) throw new MonthlyStoryNarrativePlanError("missing-emotional-shape");

  const difficulties = candidates.filter((item) => item.claim.role === "difficulty");
  const relief = candidates.find((item) => item.claim.role === "relief");
  const recommendation = candidates.find((item) => item.claim.role === "recommendation");
  const suggestions = candidates.filter((item) => item.claim.role === "suggestion").slice(0, 3);

  if (suggestions.length === 0) {
    throw new MonthlyStoryNarrativePlanError("insufficient-meaningful-material");
  }

  if (storyMode === "moodOnly" && (difficulties.length > 0 || relief)) {
    throw new MonthlyStoryNarrativePlanError("mood-only-cause");
  }
  if (storyMode === "standard") {
    const observations = difficulties.length + (relief ? 1 : 0) + (recommendation ? 1 : 0);
    if (observations < 2 || (difficulties.length === 0 && !relief)) {
      throw new MonthlyStoryNarrativePlanError("insufficient-meaningful-material");
    }
  } else if (signal.moodEvidenceDays.length < 5) {
    throw new MonthlyStoryNarrativePlanError("insufficient-meaningful-material");
  }

  const selected = [tone, ...(storyMode === "standard" ? difficulties.slice(0, 2) : []),
    ...(storyMode === "standard" && relief ? [relief] : []), ...(recommendation ? [recommendation] : []),
    ...suggestions];
  const usedEvidenceIds = selected.map((item) => item.evidence.id);
  const used = new Set(usedEvidenceIds);
  return {
    monthKey: signal.monthKey,
    storyMode,
    overallMonthTone: tone.claim,
    strongestDifficulty: storyMode === "standard" ? difficulties[0]?.claim ?? null : null,
    secondDifficulty: storyMode === "standard" ? difficulties[1]?.claim ?? null : null,
    strongestReliefOrEnergy: storyMode === "standard" ? relief?.claim ?? null : null,
    recommendationReflection: recommendation?.claim ?? null,
    nextMonthSuggestionBases: suggestions.map((item) => item.claim),
    closingDirection: storyMode === "moodOnly" ? "quietCompanionship" : "gentleForwardLook",
    usedEvidenceIds,
    excludedEvidenceIds: signal.evidence.map((item) => item.id).filter((id) => !used.has(id)),
  };
}

export function monthlyStoryPlanClaimOptions(plan: MonthlyStoryNarrativePlan): MonthlyStoryClaimOption[] {
  return [plan.overallMonthTone, plan.strongestDifficulty, plan.secondDifficulty,
    plan.strongestReliefOrEnergy, plan.recommendationReflection, ...plan.nextMonthSuggestionBases]
    .filter((value): value is MonthlyStoryClaimOption => value !== null);
}
