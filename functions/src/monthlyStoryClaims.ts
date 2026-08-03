import { MonthlyStoryEvidence } from "./monthlyStorySchema";

export const MONTHLY_STORY_CLAIM_KEYS = [
  "monthBright", "monthHeavy", "monthMixed", "monthSteady", "monthVariable",
  "workPressure", "missingHome", "familyConnection", "relationshipWeight",
  "uncertainty", "personalProjects", "rest", "change", "socialConnection",
  "lessRestful", "moreRestful", "variableRest", "lessActive", "moreActive",
  "variableMovement", "meditationRelief", "breathingRelief", "focusRelief",
  "recommendationOpened", "recommendationKept", "recommendationLeftUnopened",
  "continueRest", "protectPersonalTime", "seekConnection", "continueHelpfulPractice",
  "makeSpaceForProjects",
] as const;

export type MonthlyStoryClaimKey = typeof MONTHLY_STORY_CLAIM_KEYS[number];
export type MonthlyStoryClaimRole = "tone" | "difficulty" | "relief" | "recommendation" | "suggestion";

export type MonthlyStoryClaimOption = {
  key: MonthlyStoryClaimKey;
  evidenceId: string;
  role: MonthlyStoryClaimRole;
  phrases: readonly string[];
};

type ClaimDefinition = Omit<MonthlyStoryClaimOption, "evidenceId">;

const claim = (key: MonthlyStoryClaimKey, role: MonthlyStoryClaimRole,
  phrases: readonly string[]): ClaimDefinition => ({ key, role, phrases });

const DEFINITIONS: Readonly<Record<MonthlyStoryClaimKey, ClaimDefinition>> = Object.freeze({
  monthBright: claim("monthBright", "tone", ["this month seemed lighter", "there was more ease in the month"]),
  monthHeavy: claim("monthHeavy", "tone", ["this month seemed heavy", "a lot of the month felt difficult"]),
  monthMixed: claim("monthMixed", "tone", ["this month held both hard and lighter moments", "the month felt mixed"]),
  monthSteady: claim("monthSteady", "tone", ["the month felt fairly steady"]),
  monthVariable: claim("monthVariable", "tone", ["the month seemed to shift from one kind of day to another"]),
  workPressure: claim("workPressure", "difficulty", ["work seemed to take a lot out of you", "work was weighing on you"]),
  missingHome: claim("missingHome", "difficulty", ["i think you were missing home", "home seemed to be on your mind"]),
  familyConnection: claim("familyConnection", "relief", ["time connected with family seemed meaningful"]),
  relationshipWeight: claim("relationshipWeight", "difficulty", ["some relationships seemed to feel complicated"]),
  uncertainty: claim("uncertainty", "difficulty", ["not knowing what came next seemed hard"]),
  personalProjects: claim("personalProjects", "relief", ["you seemed happiest when you had time for your own ideas"]),
  rest: claim("rest", "relief", ["quiet time seemed to give you a little room"]),
  change: claim("change", "difficulty", ["there was a lot of change to carry"]),
  socialConnection: claim("socialConnection", "relief", ["being around people you care about seemed to bring some ease"]),
  lessRestful: claim("lessRestful", "difficulty", ["you seemed more tired than usual", "rest did not seem to come easily"]),
  moreRestful: claim("moreRestful", "relief", ["rest seemed to come a little more easily"]),
  variableRest: claim("variableRest", "difficulty", ["rest seemed uneven through the month"]),
  lessActive: claim("lessActive", "difficulty", ["your body seemed to slow down when the month felt heavier"]),
  moreActive: claim("moreActive", "relief", ["having room to move seemed to bring some energy"]),
  variableMovement: claim("variableMovement", "difficulty", ["your energy for movement seemed to come and go"]),
  meditationRelief: claim("meditationRelief", "relief", ["meditation seemed to give you a little room"]),
  breathingRelief: claim("breathingRelief", "relief", ["breathing gave you a quiet place to pause"]),
  focusRelief: claim("focusRelief", "relief", ["focused time seemed to settle things for a while"]),
  recommendationOpened: claim("recommendationOpened", "recommendation",
    ["i sent you something to watch when things felt heavy. i hope it gave you a small break",
      "i shared something with you during one of the harder stretches. i hope it was useful, even for a little while"]),
  recommendationKept: claim("recommendationKept", "recommendation",
    ["you kept something i sent your way. i hope it was worth having nearby"]),
  recommendationLeftUnopened: claim("recommendationLeftUnopened", "recommendation",
    ["i sent you a few things, but you left them alone. that is okay",
      "i shared a few things, but you did not feel like opening them. that is completely fine"]),
  continueRest: claim("continueRest", "suggestion", ["protect a little more room for real rest",
    "leave one part of the weekend unplanned"]),
  protectPersonalTime: claim("protectPersonalTime", "suggestion",
    ["try to keep one evening where work ends on time",
      "try not to fill the hour after work with more tasks"]),
  seekConnection: claim("seekConnection", "suggestion", ["make room for an easy moment with someone you trust"]),
  continueHelpfulPractice: claim("continueHelpfulPractice", "suggestion",
    ["keep that quiet practice easy to return to on stressful days"]),
  makeSpaceForProjects: claim("makeSpaceForProjects", "suggestion",
    ["protect a small block of time for your own project"]),
});

function definitionForEvidence(evidence: MonthlyStoryEvidence): ClaimDefinition | null {
  const value = evidence.value;
  switch (evidence.category) {
  case "emotionalShape":
    return DEFINITIONS[({ mostlyBright: "monthBright", mostlyHeavy: "monthHeavy", mixed: "monthMixed",
      steady: "monthSteady", variable: "monthVariable" } as const)[value.moodShape as
        "mostlyBright" | "mostlyHeavy" | "mixed" | "steady" | "variable"]];
  case "repeatedTheme":
    return DEFINITIONS[({ workPressure: "workPressure", missingHome: "missingHome", family: "familyConnection",
      relationships: "relationshipWeight", uncertainty: "uncertainty", personalProjects: "personalProjects",
      rest: "rest", change: "change", socialConnection: "socialConnection" } as const)[value.theme as
        "workPressure" | "missingHome" | "family" | "relationships" | "uncertainty" |
        "personalProjects" | "rest" | "change" | "socialConnection"]];
  case "sleepPattern":
    return value.sleep === "steady" ? null : DEFINITIONS[({ lessRestful: "lessRestful",
      moreRestful: "moreRestful", variable: "variableRest" } as const)[value.sleep as
        "lessRestful" | "moreRestful" | "variable"]];
  case "movementPattern":
    return value.movement === "steady" ? null : DEFINITIONS[({ lessActive: "lessActive",
      moreActive: "moreActive", variable: "variableMovement" } as const)[value.movement as
        "lessActive" | "moreActive" | "variable"]];
  case "restorativePractice":
    return DEFINITIONS[({ meditation: "meditationRelief", breathing: "breathingRelief",
      focus: "focusRelief" } as const)[value.practice as "meditation" | "breathing" | "focus"]];
  case "recommendationAction":
    if (value.recommendation === "delivered") return null;
    return DEFINITIONS[({ opened: "recommendationOpened", kept: "recommendationKept",
      leftUnopened: "recommendationLeftUnopened" } as const)[value.recommendation as
        "opened" | "kept" | "leftUnopened"]];
  case "nextMonthSuggestionBasis":
    return DEFINITIONS[value.suggestion as "continueRest" | "protectPersonalTime" | "seekConnection" |
      "continueHelpfulPractice" | "makeSpaceForProjects"];
  }
}

export function claimOptionForEvidence(evidence: MonthlyStoryEvidence): MonthlyStoryClaimOption | null {
  if (!evidence.allowedForNarration) return null;
  const definition = definitionForEvidence(evidence);
  return definition ? { ...definition, evidenceId: evidence.id } : null;
}

export function isMonthlyStoryClaimKey(value: unknown): value is MonthlyStoryClaimKey {
  return typeof value === "string" && (MONTHLY_STORY_CLAIM_KEYS as readonly string[]).includes(value);
}

export function allowedClaimPhrases(key: MonthlyStoryClaimKey): readonly string[] {
  return DEFINITIONS[key].phrases;
}

export const MONTHLY_STORY_FORBIDDEN_CLAIM_EXAMPLES = Object.freeze({
  workPressure: ["your manager criticized you", "work caused your sleep problems", "your performance declined"],
  missingHome: ["you missed Chicago", "you missed your mother", "a family event made you homesick"],
  lessRestful: ["you slept five hours", "you have insomnia", "poor sleep caused your mood"],
  lessActive: ["you should exercise", "you were lazy", "you failed to stay active"],
  recommendationOpened: ["it helped you", "it cheered you up", "you loved the film"],
  recommendationLeftUnopened: ["you ignored it", "you failed to open it", "you did not engage"],
});
