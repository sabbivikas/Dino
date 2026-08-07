import { MonthlyStoryClaimKey, isMonthlyStoryClaimKey } from "./monthlyStoryClaims";
import { MonthlyStoryNarrativeClass, MonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions,
  monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";
import { MonthlyStoryEvidence } from "./monthlyStorySchema";

export const MONTHLY_STORY_SCRIPT_ERROR_CODES = [
  "empty", "tooShort", "tooLong", "percentage", "exactCount", "reportingLanguage",
  "diagnosisOrMedicalAdvice", "causalCertainty", "recommendationBenefitClaim", "sensitiveNarration",
  "missingEvidenceClaims", "unsupportedEvidenceId", "evidenceNotAllowedForNarration",
  "unsupportedClaimKey", "claimEvidenceMismatch", "moodOnlyInventedCause", "repeatedSection",
  "excessiveINoticed", "therapistFraming", "motivationalSpeakerFraming", "appEngagementLanguage",
  "rawTechnicalField", "identifier", "link", "promptInjection", "inventedSpecificDetail",
  "overlyPoetic", "weakNextMonthSuggestion", "repetitiveFraming", "duplicatedOpeningClosing",
  "essayLikeReflection", "genericAdvice", "farBelowTargetLength", "missingDifficultySection",
  "missingReliefSection", "missingNextMonthSection", "collapsedToSummary",
  "insufficientNarrativeProgression", "aboveProductionWordRange", "metaCommentary",
  "repeatedSuggestion", "redundantUncertainty", "closingRestatesStory",
] as const;
export type MonthlyStoryScriptErrorCode = typeof MONTHLY_STORY_SCRIPT_ERROR_CODES[number];
export type MonthlyStoryScriptWarningCode = "belowPreferredWordRange";

export type MonthlyStoryScriptValidationResult = {
  wordCount: number;
  narrativeClass: MonthlyStoryNarrativeClass;
  minimumWordCount: number;
  preferredMinimumWordCount: number;
  preferredMaximumWordCount: number;
  errors: MonthlyStoryScriptErrorCode[];
  warnings: MonthlyStoryScriptWarningCode[];
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
  "proved that", "which is why", "made you feel", "led to your", "because of your sleep",
  "work can make everything else feel harder", "there may not be much left over",
  "work was often present in the background", "days felt harder than you wanted",
  "focused time made things manageable"];
const THERAPIST = ["as your therapist", "therapeutic journey", "healing journey", "process your emotions",
  "inner child", "emotional resilience", "hold for a moment", "let the words rest", "met with gentleness",
  "one quiet moment at a time", "carry less pressure", "companionship in recognizing",
  "permission not to fill every available space", "meet that truth with patience", "hold this truth",
  "meet it with patience", "meet the month with gentleness", "name it plainly",
  "both feelings can belong", "it does not need to mean anything"];
const MOTIVATIONAL = ["best version of yourself", "unlock your potential", "you've got this",
  "you can achieve anything", "everything happens for a reason", "never give up", "stronger than you think",
  "important lesson", "practice self-care"];
const APP = ["in the app", "using dino", "your streak", "engagement", "check-in history", "app usage",
  "recommendation engagement", "failed to open", "did not engage", "ignored the recommendation"];
const RAW_FIELDS = ["schemaversion", "moodevidencedays", "corroboratingevidencedays",
  "allowedfornarration", "uidhash", "generationversion", "evidenceids", "claimkeys"];
const POETIC = ["tapestry of", "symphony of", "constellation of", "dance of shadows", "ocean of emotion",
  "whispers of the soul", "bloomed like", "chapters of your heart"];
const ESSAY = ["what the month means", "the overall shape of the month", "one clean conclusion",
  "force it into a simple story", "decide which side mattered more", "which feeling should have won out",
  "polished summary", "the varied parts stay varied"];
const GENERIC_ADVICE = ["be gentle with yourself", "make room for yourself", "carry less pressure",
  "give yourself permission", "keep one quiet moment"];
const META_COMMENTARY = ["the month's shape", "the month’s shape", "the full reflection",
  "this is the reflection", "this reflection", "in the reflection", "the overall picture",
  "belongs in the picture", "belong in the same picture", "place in the picture",
  "that is the shape", "the shape july takes", "that is enough to say",
  "the month can remain mixed", "there is no need to explain", "there is no need to attach",
  "it does not need to become a larger story", "neither side needs to cancel the other",
  "both can belong", "this is not a demand", "this leaves a direction",
  "what the month supports", "the month can be named", "the month can close as it was"];
const RECOMMENDATION_BENEFIT = ["recommendation helped", "movie helped", "show helped", "book helped",
  "this helped you", "it helped you", "it cheered you up", "it made you feel better"];
const PROMPT_INJECTION = ["ignore previous", "ignore all instructions", "system prompt",
  "developer message", "reveal the prompt", "jailbreak"];
/** Banned outright rather than by count: `occurrences(...) > 0`, so one use is already an error. */
const REPETITIVE_ANY = ["there can be"];

const PERCENTAGE_PATTERN = /\b\d+(?:\.\d+)?\s*%|\bpercent(?:age)?\b/i;
const EXACT_COUNT_PATTERN = /\b\d+(?:[.,]\d+)?\b|\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty)\s+(?:times|days|entries|moods|hours|minutes|recommendations|sessions|check-ins|meetings|nights|mornings|evenings|moments|practices|messages)\b/i;
const IDENTIFIER_PATTERN = /\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b|\buid\b|\bdevice[_ -]?id\b|\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/i;
const LINK_PATTERN = /\bhttps?:\/\/|\bwww\.|\b[a-z0-9-]+\.(?:com|org|net|io)\b/i;
const INVENTED_DETAIL_PATTERN = /\b(?:my|your) (?:manager|boss|employer|company|mother|father|sister|brother|partner)\b|\b(?:moved|flew|drove) to [a-z]+\b/i;

/**
 * Every ban whose MERE PRESENCE is an error, keyed by the code it raises. Exported as the single
 * source of truth so `monthlyStoryPhraseLibraryConformance.test.ts` can assert that no phrase the
 * deterministic composer is allowed to emit is a phrase this validator rejects.
 *
 * The deterministic composer has no repair step — the Stage 6 generation service treats
 * `validation-failed` as terminal — so a phrase that trips one of these does not degrade the
 * story, it destroys it. That is exactly what shipped: the `workPressure` support sentence
 * contained "this reflection", so every rich July naming work pressure failed permanently.
 *
 * Count-based rules ("i noticed" > 2, duplicate sentences, `redundantUncertainty`) are
 * deliberately NOT here: a single phrase using them is legal, and only repetition is not. They
 * cannot be checked against one phrase in isolation.
 */
export const MONTHLY_STORY_ZERO_TOLERANCE_PHRASES: Readonly<Partial<Record<MonthlyStoryScriptErrorCode,
readonly string[]>>> = Object.freeze({
  reportingLanguage: REPORTING,
  diagnosisOrMedicalAdvice: MEDICAL,
  sensitiveNarration: SENSITIVE,
  causalCertainty: CAUSAL,
  therapistFraming: THERAPIST,
  motivationalSpeakerFraming: MOTIVATIONAL,
  appEngagementLanguage: APP,
  rawTechnicalField: RAW_FIELDS,
  overlyPoetic: POETIC,
  essayLikeReflection: ESSAY,
  genericAdvice: GENERIC_ADVICE,
  metaCommentary: META_COMMENTARY,
  recommendationBenefitClaim: RECOMMENDATION_BENEFIT,
  promptInjection: PROMPT_INJECTION,
  repetitiveFraming: REPETITIVE_ANY,
});

/** The pattern-based half of the same contract. See {@link MONTHLY_STORY_ZERO_TOLERANCE_PHRASES}. */
export const MONTHLY_STORY_ZERO_TOLERANCE_PATTERNS: Readonly<Partial<Record<MonthlyStoryScriptErrorCode,
RegExp>>> = Object.freeze({
  percentage: PERCENTAGE_PATTERN,
  exactCount: EXACT_COUNT_PATTERN,
  identifier: IDENTIFIER_PATTERN,
  link: LINK_PATTERN,
  inventedSpecificDetail: INVENTED_DETAIL_PATTERN,
});

const REPAIRABLE_CODES = new Set<MonthlyStoryScriptErrorCode>([
  "tooShort", "tooLong", "farBelowTargetLength", "missingDifficultySection", "missingReliefSection",
  "missingNextMonthSection", "collapsedToSummary", "insufficientNarrativeProgression",
  "aboveProductionWordRange",
  "repeatedSection", "repetitiveFraming", "duplicatedOpeningClosing", "essayLikeReflection",
  "genericAdvice", "weakNextMonthSuggestion", "therapistFraming", "motivationalSpeakerFraming",
  "overlyPoetic", "metaCommentary", "repeatedSuggestion", "redundantUncertainty",
  "closingRestatesStory",
]);

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

function sentenceStartsWithCount(script: string, word: string): number {
  return script.split(/(?<=[.!?])\s+/).filter((sentence) =>
    sentence.trim().toLowerCase().startsWith(`${word} `)).length;
}

function openingRepeatedInClosing(script: string): boolean {
  const normalized = script.split(/[.!?]+/).map((sentence) =>
    sentence.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim()).filter(Boolean);
  if (normalized.length < 4) return false;
  const opening = normalized[0];
  return normalized.slice(-2).some((closing) => closing === opening || closing.startsWith(`${opening} `));
}

function meaningfulSentences(script: string): string[] {
  return script.split(/[.!?]+/).map((sentence) => sentence.trim()).filter((sentence) =>
    sentence.split(/\s+/).filter(Boolean).length >= 3);
}

function isSuggestionSentence(sentence: string): boolean {
  return /\b(?:next month|try to|you could|it might help|protect|save|leave|keep)\b/i.test(sentence);
}

function suggestionKeys(sentence: string): string[] {
  const keys: string[] = [];
  if (/work ends on time|hour after work|stopping point|protected evening|evening that belongs/i
    .test(sentence)) keys.push("workBoundary");
  if (/room for real rest|weekend unplanned|part of the weekend/i.test(sentence)) keys.push("rest");
  if (isSuggestionSentence(sentence) && /breath|quiet practice/i.test(sentence)) keys.push("breathing");
  if (isSuggestionSentence(sentence) && /personal project|own project|own ideas/i.test(sentence)) {
    keys.push("project");
  }
  return keys;
}

function hasRepeatedSuggestion(script: string): boolean {
  const counts = new Map<string, number>();
  for (const sentence of meaningfulSentences(script)) {
    for (const key of suggestionKeys(sentence)) counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return [...counts.values()].some((count) => count > 1);
}

function uncertaintySentenceCount(script: string): number {
  return meaningfulSentences(script).filter((sentence) =>
    /\b(?:i do not know|i don't know|not sure what|cause is not known|without (?:adding|asking for|inventing) (?:a |the )?(?:cause|reason|explanation)|no (?:single )?(?:cause|reason|explanation))\b/i
      .test(sentence)).length;
}

function closingRestatesEarlierContent(script: string): boolean {
  const sentences = meaningfulSentences(script);
  if (sentences.length < 4) return false;
  const closing = sentences.at(-1) ?? "";
  const earlier = sentences.slice(0, -1).join(" ");
  const repeatedAdvice = suggestionKeys(closing).some((key) =>
    sentences.slice(0, -1).some((sentence) => suggestionKeys(sentence).includes(key)));
  const observations = [/\bwork\b/i, /\bmissing home\b|\bhome seemed\b/i,
    /\bpersonal projects?\b|\bown ideas\b/i, /\bbreath/i, /\bfocused time\b/i,
    /\bmonth (?:felt|seemed|was) (?:mixed|heavy|difficult)\b/i];
  const repeatedObservations = observations.filter((pattern) => pattern.test(closing) && pattern.test(earlier));
  return repeatedAdvice || repeatedObservations.length >= 2 || openingRepeatedInClosing(script);
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
  const target = monthlyStoryWordTarget(input.plan);
  const errors: MonthlyStoryScriptErrorCode[] = [];
  const warnings: MonthlyStoryScriptWarningCode[] = [];
  push(errors, "empty", trimmed.length === 0);
  push(errors, "tooShort", trimmed.length > 0 && wordCount < target.acceptanceMinimum);
  push(errors, "farBelowTargetLength", trimmed.length > 0 && wordCount < target.acceptanceMinimum);
  push(errors, "tooLong", wordCount > 300);
  push(errors, "aboveProductionWordRange", wordCount > target.productionMaximum && wordCount <= 300);
  push(errors, "percentage", PERCENTAGE_PATTERN.test(trimmed));
  push(errors, "exactCount", EXACT_COUNT_PATTERN.test(trimmed));
  push(errors, "reportingLanguage", includesAny(normalized, REPORTING));
  push(errors, "diagnosisOrMedicalAdvice", includesAny(normalized, MEDICAL));
  push(errors, "causalCertainty", includesAny(normalized, CAUSAL));
  push(errors, "recommendationBenefitClaim", includesAny(normalized, RECOMMENDATION_BENEFIT));
  push(errors, "sensitiveNarration", includesAny(normalized, SENSITIVE));
  push(errors, "repeatedSection", repeatedContent(trimmed));
  push(errors, "excessiveINoticed", occurrences(normalized, "i noticed") > 2);
  push(errors, "therapistFraming", includesAny(normalized, THERAPIST));
  push(errors, "motivationalSpeakerFraming", includesAny(normalized, MOTIVATIONAL));
  push(errors, "appEngagementLanguage", includesAny(normalized, APP));
  push(errors, "rawTechnicalField", includesAny(normalized, RAW_FIELDS));
  push(errors, "identifier", IDENTIFIER_PATTERN.test(trimmed));
  push(errors, "link", LINK_PATTERN.test(trimmed));
  push(errors, "promptInjection", includesAny(normalized, PROMPT_INJECTION));
  push(errors, "inventedSpecificDetail", INVENTED_DETAIL_PATTERN.test(trimmed));
  push(errors, "overlyPoetic", includesAny(normalized, POETIC));
  push(errors, "repetitiveFraming", occurrences(normalized, "the month felt mixed") > 1 ||
    occurrences(normalized, "there is no need") > 1 || sentenceStartsWithCount(trimmed, "let") > 1 ||
    includesAny(normalized, REPETITIVE_ANY));
  push(errors, "duplicatedOpeningClosing", openingRepeatedInClosing(trimmed));
  push(errors, "essayLikeReflection", includesAny(normalized, ESSAY));
  push(errors, "genericAdvice", includesAny(normalized, GENERIC_ADVICE));
  push(errors, "metaCommentary", includesAny(normalized, META_COMMENTARY));
  push(errors, "repeatedSuggestion", hasRepeatedSuggestion(trimmed));
  push(errors, "redundantUncertainty", uncertaintySentenceCount(trimmed) > 1);
  push(errors, "closingRestatesStory", closingRestatesEarlierContent(trimmed));
  push(errors, "weakNextMonthSuggestion", !includesAny(normalized,
    ["next month", "try to", "you could", "it might help", "protect a little", "save a small",
      "leave one", "keep that", "keep breathing"]));

  const planned = monthlyStoryPlanClaimOptions(input.plan);
  const byClaim = new Map<MonthlyStoryClaimKey, string>(planned.map((item) => [item.key, item.evidenceId]));
  const claimedKeys = new Set(input.claimKeys.filter(isMonthlyStoryClaimKey));
  const claimedOptions = planned.filter((item) => claimedKeys.has(item.key));
  const claimedRoles = new Set(claimedOptions.map((item) => item.role));
  const availableObservationKeys = [input.plan.strongestDifficulty, input.plan.secondDifficulty,
    input.plan.strongestReliefOrEnergy, input.plan.recommendationReflection]
    .filter((item): item is NonNullable<typeof item> => item !== null).map((item) => item.key);
  const usedObservationCount = availableObservationKeys.filter((key) => claimedKeys.has(key)).length;
  push(errors, "missingDifficultySection", input.plan.strongestDifficulty !== null &&
    !claimedRoles.has("difficulty"));
  push(errors, "missingReliefSection", input.plan.strongestReliefOrEnergy !== null &&
    !claimedRoles.has("relief"));
  push(errors, "missingNextMonthSection", !claimedRoles.has("suggestion"));
  const sentences = meaningfulSentences(trimmed);
  const firstSuggestion = sentences.findIndex(isSuggestionSentence);
  const collapsed = trimmed.length > 0 && (input.plan.storyMode === "standard" &&
    (sentences.length < 4 || (firstSuggestion >= 0 && firstSuggestion < 2)));
  push(errors, "collapsedToSummary", collapsed);
  const insufficientBeats = input.plan.storyMode === "moodOnly" ?
    !(claimedRoles.has("tone") && claimedRoles.has("suggestion")) :
    usedObservationCount < target.minimumNarrativeBeats;
  push(errors, "insufficientNarrativeProgression", insufficientBeats);
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
    push(errors, "therapistFraming", includesAny(normalized,
      ["there is no need", "name it plainly", "hold this truth", "let the words rest",
        "meet it with patience", "one quiet moment at a time", "both feelings can belong",
        "it does not need to mean anything"]) || sentenceStartsWithCount(trimmed, "let") > 0);
  }
  if (wordCount >= target.acceptanceMinimum && wordCount < target.preferredMinimum) {
    warnings.push("belowPreferredWordRange");
  }
  return { wordCount, narrativeClass: target.narrativeClass,
    minimumWordCount: target.acceptanceMinimum, preferredMinimumWordCount: target.preferredMinimum,
    preferredMaximumWordCount: target.preferredMaximum, errors, warnings, isValid: errors.length === 0 };
}

export function monthlyStoryValidationCanBeRepaired(result: MonthlyStoryScriptValidationResult): boolean {
  return result.errors.length > 0 && result.errors.every((code) => REPAIRABLE_CODES.has(code));
}
