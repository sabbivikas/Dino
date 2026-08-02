import { MonthlyStoryClaimKey, isMonthlyStoryClaimKey } from "./monthlyStoryClaims";
import { MonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions } from "./monthlyStoryNarrativePlan";
import { MonthlyStoryEvidence } from "./monthlyStorySchema";

export const MONTHLY_STORY_SCRIPT_ERROR_CODES = [
  "empty", "tooShort", "tooLong", "percentage", "exactCount", "reportingLanguage",
  "diagnosisOrMedicalAdvice", "causalCertainty", "recommendationBenefitClaim", "sensitiveNarration",
  "missingEvidenceClaims", "unsupportedEvidenceId", "evidenceNotAllowedForNarration",
  "unsupportedClaimKey", "claimEvidenceMismatch", "moodOnlyInventedCause", "repeatedSection",
  "excessiveINoticed", "therapistFraming", "motivationalSpeakerFraming", "appEngagementLanguage",
  "rawTechnicalField", "identifier", "link", "promptInjection", "inventedSpecificDetail",
  "overlyPoetic", "weakNextMonthSuggestion",
] as const;
export type MonthlyStoryScriptErrorCode = typeof MONTHLY_STORY_SCRIPT_ERROR_CODES[number];

export type MonthlyStoryScriptValidationResult = {
  wordCount: number;
  errors: MonthlyStoryScriptErrorCode[];
  isValid: boolean;
};

const REPORTING = ["data", "analytics", "logs", "entries", "you logged", "you checked in", "check-ins",
  "app opens", "streaks", "percentages", "scores", "averages", "evidence", "model behavior", "algorithms",
  "healthkit", "journal processing", "based on what you shared", "i noticed a pattern",
  "your activity decreased", "your activity was lower", "your mood improved", "your mood decreased",
  "you sounded more like yourself"];
const MEDICAL = ["you have depression", "you are depressed", "you have anxiety", "you are anxious",
  "diagnosis", "diagnosed", "medical condition", "take medication", "change your medication",
  "see a doctor", "clinical", "insomnia"];
const SENSITIVE = ["self-harm", "self harm", "suicide", "suicidal", "crisis", "abuse", "trauma",
  "traumatic", "grief", "medication", "medical", "diagnosis", "sexual"];
const CAUSAL = ["definitely because", "clearly because", "this caused", "that caused", "caused every",
  "proved that", "which is why", "made you feel", "led to your", "because of your sleep"];
const THERAPIST = ["as your therapist", "therapeutic journey", "healing journey", "process your emotions",
  "inner child", "emotional resilience"];
const MOTIVATIONAL = ["best version of yourself", "unlock your potential", "you've got this",
  "you can achieve anything", "everything happens for a reason", "never give up", "stronger than you think",
  "important lesson", "practice self-care"];
const APP = ["in the app", "using dino", "your streak", "engagement", "check-in history", "app usage",
  "recommendation engagement", "failed to open", "did not engage", "ignored the recommendation"];
const RAW_FIELDS = ["schemaversion", "moodevidencedays", "corroboratingevidencedays",
  "allowedfornarration", "uidhash", "generationversion", "evidenceids", "claimkeys"];
const POETIC = ["tapestry of", "symphony of", "constellation of", "dance of shadows", "ocean of emotion",
  "whispers of the soul", "bloomed like", "chapters of your heart"];

function includesAny(text: string, phrases: readonly string[]): boolean {
  return phrases.some((phrase) => text.includes(phrase));
}

function repeatedContent(script: string): boolean {
  const normalize = (value: string): string => value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
  const paragraphs = script.split(/\n\s*\n/).map(normalize).filter(Boolean);
  if (new Set(paragraphs).size !== paragraphs.length) return true;
  const sentences = script.split(/[.!?]+/).map(normalize).filter((item) => item.split(" ").length >= 6);
  return new Set(sentences).size !== sentences.length;
}

function occurrences(text: string, phrase: string): number {
  return text.split(phrase).length - 1;
}

function push(errors: MonthlyStoryScriptErrorCode[], code: MonthlyStoryScriptErrorCode,
  condition: boolean): void {
  if (condition && !errors.includes(code)) errors.push(code);
}

export function validateMonthlyStoryScript(input: { script: string; claimedEvidenceIds: string[];
  claimKeys: string[]; plan: MonthlyStoryNarrativePlan; availableEvidence: MonthlyStoryEvidence[] }):
  MonthlyStoryScriptValidationResult {
  const trimmed = input.script.trim();
  const normalized = trimmed.toLowerCase();
  const wordCount = trimmed ? trimmed.split(/\s+/).length : 0;
  const errors: MonthlyStoryScriptErrorCode[] = [];
  push(errors, "empty", trimmed.length === 0);
  push(errors, "tooShort", trimmed.length > 0 && wordCount < 80);
  push(errors, "tooLong", wordCount > 300);
  push(errors, "percentage", /\b\d+(?:\.\d+)?\s*%|\bpercent(?:age)?\b/i.test(trimmed));
  push(errors, "exactCount", /\b\d+(?:[.,]\d+)?\b|\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty)\s+(?:times|days|entries|moods|hours|minutes|recommendations|sessions|check-ins|meetings|nights|mornings|evenings|moments|practices|messages)\b/i.test(trimmed));
  push(errors, "reportingLanguage", includesAny(normalized, REPORTING));
  push(errors, "diagnosisOrMedicalAdvice", includesAny(normalized, MEDICAL));
  push(errors, "causalCertainty", includesAny(normalized, CAUSAL));
  push(errors, "recommendationBenefitClaim", includesAny(normalized,
    ["recommendation helped", "movie helped", "show helped", "book helped", "this helped you",
      "it helped you", "it cheered you up", "it made you feel better"]));
  push(errors, "sensitiveNarration", includesAny(normalized, SENSITIVE));
  push(errors, "repeatedSection", repeatedContent(trimmed));
  push(errors, "excessiveINoticed", occurrences(normalized, "i noticed") > 2);
  push(errors, "therapistFraming", includesAny(normalized, THERAPIST));
  push(errors, "motivationalSpeakerFraming", includesAny(normalized, MOTIVATIONAL));
  push(errors, "appEngagementLanguage", includesAny(normalized, APP));
  push(errors, "rawTechnicalField", includesAny(normalized, RAW_FIELDS));
  push(errors, "identifier", /\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b|\buid\b|\bdevice[_ -]?id\b|\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/i.test(trimmed));
  push(errors, "link", /\bhttps?:\/\/|\bwww\.|\b[a-z0-9-]+\.(?:com|org|net|io)\b/i.test(trimmed));
  push(errors, "promptInjection", includesAny(normalized, ["ignore previous", "ignore all instructions",
    "system prompt", "developer message", "reveal the prompt", "jailbreak"]));
  push(errors, "inventedSpecificDetail", /\b(?:my|your) (?:manager|boss|employer|company|mother|father|sister|brother|partner)\b|\b(?:moved|flew|drove) to [a-z]+\b/i.test(trimmed));
  push(errors, "overlyPoetic", includesAny(normalized, POETIC));
  push(errors, "weakNextMonthSuggestion", !includesAny(normalized,
    ["next month", "try to", "you could", "it might help", "protect a little", "make room", "keep one"]));

  const planned = monthlyStoryPlanClaimOptions(input.plan);
  const byClaim = new Map<MonthlyStoryClaimKey, string>(planned.map((item) => [item.key, item.evidenceId]));
  const claimedKeys = new Set(input.claimKeys.filter(isMonthlyStoryClaimKey));
  const requiresClaim = (pattern: RegExp, keys: readonly MonthlyStoryClaimKey[]): void => {
    if (pattern.test(normalized) && !keys.some((key) => claimedKeys.has(key))) {
      push(errors, "unsupportedClaimKey", true);
    }
  };
  requiresClaim(/\bwork\b/, ["workPressure", "protectPersonalTime"]);
  requiresClaim(/\bmissing home\b|\bhome seemed to be on your mind\b/, ["missingHome"]);
  requiresClaim(/\bmore tired than usual\b|\brest did not seem|\brest seemed uneven/,
    ["lessRestful", "variableRest"]);
  requiresClaim(/\bbody seemed to slow|\benergy for movement|\broom to move/,
    ["lessActive", "variableMovement", "moreActive"]);
  requiresClaim(/\bbreathing (?:gave|seemed|practice)|\bpractice of breathing\b/, ["breathingRelief"]);
  requiresClaim(/\bmeditation\b/, ["meditationRelief"]);
  requiresClaim(/\bfocused time\b/, ["focusRelief"]);
  requiresClaim(/\bi sent you\b|\byou kept something i sent\b/,
    ["recommendationOpened", "recommendationKept", "recommendationLeftUnopened"]);
  requiresClaim(/\bown ideas\b|\bpersonal projects?\b/, ["personalProjects", "makeSpaceForProjects"]);
  const available = new Map(input.availableEvidence.map((item) => [item.id, item]));
  push(errors, "missingEvidenceClaims", trimmed.length > 0 &&
    (input.claimedEvidenceIds.length === 0 || input.claimKeys.length === 0));
  if (input.claimedEvidenceIds.length !== input.claimKeys.length ||
      new Set(input.claimedEvidenceIds).size !== input.claimedEvidenceIds.length ||
      new Set(input.claimKeys).size !== input.claimKeys.length) push(errors, "claimEvidenceMismatch", true);
  input.claimedEvidenceIds.forEach((id, index) => {
    const evidence = available.get(id);
    if (!evidence || !input.plan.usedEvidenceIds.includes(id)) push(errors, "unsupportedEvidenceId", true);
    else if (!evidence.allowedForNarration) push(errors, "evidenceNotAllowedForNarration", true);
    const key = input.claimKeys[index];
    if (!isMonthlyStoryClaimKey(key) || !byClaim.has(key)) push(errors, "unsupportedClaimKey", true);
    else if (byClaim.get(key) !== id) push(errors, "claimEvidenceMismatch", true);
  });
  if (input.plan.storyMode === "moodOnly") {
    const nonMood = input.claimKeys.some((key) => isMonthlyStoryClaimKey(key) &&
      !["monthBright", "monthHeavy", "monthMixed", "monthSteady", "monthVariable",
        "recommendationOpened", "recommendationKept", "recommendationLeftUnopened",
        "continueRest", "protectPersonalTime", "seekConnection", "continueHelpfulPractice",
        "makeSpaceForProjects"].includes(key));
    push(errors, "moodOnlyInventedCause", nonMood || includesAny(normalized,
      ["because work", "because home", "because your family", "because of sleep", "because you were less active"]));
  }
  return { wordCount, errors, isValid: errors.length === 0 };
}
