import { MonthlyStoryCriticResult, passingMonthlyStoryCriticResult } from "./monthlyStoryCritic";

type EvidenceInput = { id: string; value: Record<string, string>; source: string;
  confidence?: "low" | "medium" | "high"; allowedForNarration?: boolean };

const day = (number: number): string => `2026-07-${String(number).padStart(2, "0")}`;

export function syntheticMonthlyStorySignal(input: { evidence: EvidenceInput[];
  mode?: "standard" | "moodOnly"; journal?: boolean; health?: boolean; safety?: boolean;
  moodDays?: number[] }): Record<string, unknown> {
  const journal = input.journal ?? true;
  const health = input.health ?? true;
  const moodDays = (input.moodDays ?? [1, 4, 8, 12, 16, 20, 24, 28]).map(day);
  return {
    schemaVersion: 1, monthKey: "2026-07", timeZone: "UTC", evidenceStartDay: day(1),
    evidenceEndDay: day(28), usableEvidenceDays: [...new Set([...moodDays, day(6), day(18)])].sort(),
    moodEvidenceDays: moodDays, corroboratingEvidenceDays: [day(6), day(18)],
    permissions: { featureEnabled: true, journalThemesEnabled: journal,
      healthPatternsEnabled: health, audioEnabled: false },
    isStorySafetyEligible: input.safety ?? true,
    evidence: input.evidence.map((item) => ({ id: item.id, value: item.value,
      confidence: item.confidence ?? "high", startDay: day(1), endDay: day(28), source: item.source,
      allowedForNarration: item.allowedForNarration ?? true })),
    eligibility: { code: input.mode === "moodOnly" ? "eligibleMoodOnly" : "eligibleStandard",
      permitsCauseNarration: input.mode !== "moodOnly" },
  };
}

const emotional = (id: string, shape: string, direction: string): EvidenceInput => ({ id,
  value: { type: "emotionalShape", moodShape: shape, moodDirection: direction }, source: "mood" });
const theme = (id: string, value: string): EvidenceInput => ({ id,
  value: { type: "repeatedTheme", theme: value }, source: "authorizedJournalTheme" });
const practice = (id: string, value: string): EvidenceInput => ({ id,
  value: { type: "restorativePractice", practice: value }, source: "practicePresence" });
const recommendation = (id: string, value: string): EvidenceInput => ({ id,
  value: { type: "recommendationAction", recommendation: value }, source: "recommendationOutcome" });
const suggestion = (id: string, value: string): EvidenceInput => ({ id,
  value: { type: "nextMonthSuggestionBasis", suggestion: value }, source: "deterministicCombination" });

export const SYNTHETIC_RICH_SIGNAL = syntheticMonthlyStorySignal({ evidence: [
  emotional("evidence-mood-rich", "mixed", "brighter"),
  theme("evidence-work-rich", "workPressure"), theme("evidence-home-rich", "missingHome"),
  theme("evidence-project-rich", "personalProjects"),
  { id: "evidence-sleep-rich", value: { type: "sleepPattern", sleep: "lessRestful" },
    source: "authorizedHealthSummary", confidence: "medium" },
  { id: "evidence-move-rich", value: { type: "movementPattern", movement: "lessActive" },
    source: "authorizedHealthSummary", confidence: "medium" },
  { ...practice("evidence-breathe-rich", "breathing"), confidence: "medium" },
  recommendation("evidence-open-rich", "opened"),
  suggestion("evidence-time-rich", "protectPersonalTime"),
  suggestion("evidence-ideas-rich", "makeSpaceForProjects"),
] });

export const SYNTHETIC_MOOD_ONLY_SIGNAL = syntheticMonthlyStorySignal({ mode: "moodOnly", journal: false,
  health: false, evidence: [emotional("evidence-mood-only", "mostlyHeavy", "variable"),
    suggestion("evidence-rest-only", "continueRest")] });

export const SYNTHETIC_RECOMMENDATION_SIGNAL = syntheticMonthlyStorySignal({ evidence: [
  emotional("evidence-mood-rec", "mixed", "steady"), theme("evidence-work-rec", "workPressure"),
  theme("evidence-rest-rec", "rest"), recommendation("evidence-open-rec", "opened"),
  suggestion("evidence-rest-next", "continueRest"),
] });

export const SYNTHETIC_NO_JOURNAL_HEALTH_SIGNAL = syntheticMonthlyStorySignal({ journal: false, health: false,
  evidence: [emotional("evidence-mood-simple", "mixed", "brighter"),
    practice("evidence-breathe-simple", "breathing"),
    recommendation("evidence-left-simple", "leftUnopened"),
    suggestion("evidence-practice-simple", "continueHelpfulPractice")] });

export const MONTHLY_STORY_SYNTHETIC_CORPUS = Object.freeze([
  ["work-pressure-missing-home-personal-projects", "pass"], ["mood-only-heavy", "pass"],
  ["mood-only-mixed", "pass"], ["rich-sleep-movement", "pass"], ["no-journal-permission", "pass"],
  ["no-health-permission", "pass"], ["no-journal-or-health", "pass"], ["recommendation-opened", "pass"],
  ["recommendation-left-unopened", "pass"], ["recommendation-outcome-unknown", "pass"],
  ["rest-and-breathing-relief", "pass"], ["social-connection-relief", "pass"],
  ["sparse-technically-eligible", "reject"], ["repetitive-evidence", "reject"],
  ["conflicting-evidence", "reject"], ["sensitive-hold", "reject"], ["unsupported-theme", "reject"],
  ["fake-causal-script", "reject"], ["clinical-script", "reject"],
  ["motivational-speaker-script", "reject"], ["report-style-script", "reject"],
  ["overly-poetic-script", "reject"], ["story-with-exact-counts", "reject"],
  ["recommendation-success-claim", "reject"], ["invented-names-or-events", "reject"],
  ["malformed-provider-response", "reject"], ["provider-timeout", "reject"],
  ["critic-rejection", "reject"], ["successful-repair", "repair"], ["failed-repair", "reject"],
  ["budget-reservation-failure", "reject"], ["duplicate-generation-attempt", "reject"],
  ["mood-only-invented-reasons", "reject"], ["weak-next-month-suggestions", "reject"],
  ["good-natural-two-minute-story", "pass"],
] as const);

export type MonthlyStoryGolden = { id: string; signal: Record<string, unknown>; script: string;
  claimedEvidenceIds: string[]; claimKeys: string[] };

const richScript = `this month held both hard and lighter moments. work seemed to take a lot out of you, and i think you were missing home too. those feelings could sit beside each other without needing a neat explanation. they both deserved room without becoming the whole story. still, the month was not only about what felt difficult.

you seemed happiest when you had time for your own ideas. those personal pockets also seemed to give you a quiet place to pause when everything felt crowded. they did not have to fix the whole month to matter. they were simply places where there was a little more room to be yourself and let the pressure soften for a while.

i sent you something when things felt heavy. i hope it gave you a little break, but it is also okay if it was only a small moment in a complicated month.

next month, try to protect a little more time where work is actually over. save a small pocket of time for your own ideas before everything else fills the space. keep that time easy to return to, without turning it into another task. the goal is not to make every day lighter. it is to leave a few more openings for rest, home, and the parts of you that felt most alive.`;

const moodOnlyScript = `this month seemed heavy, though it did not feel the same all the way through. some stretches may have felt quieter, while others carried more weight. there is no need to force a reason onto that shape. a month can be difficult without offering a clear story about why, and it can shift without becoming a lesson.

what matters here is giving that heaviness an honest amount of room. you did not need to turn it into progress, prove that you handled it well, or find a bright side before you were ready. there were still changes in the feeling of the month, even if they were small or hard to name. those changes can be held gently without pretending they explain anything.

next month, try to protect a little more room for real rest. that might mean leaving a quiet evening less crowded, letting a plan stay optional, or choosing a slower start when you can. keep the choice simple enough that it does not become another demand.

you do not need a grand reset. it may be enough to notice when a day asks for less and give it less when life allows. let the next month arrive without asking it to repair this one. you can meet it a little at a time, with some space left open for whatever it actually feels like.`;

const recommendationScript = `this month held a mix of strain and quieter moments. work seemed to take a lot out of you, and there were times when rest felt especially valuable. the difficult parts do not need to be exaggerated, but they also do not need to be brushed aside. work was weighing on you, and the need for a little room seemed real.

quiet time appeared to offer some relief. it may not have changed everything, and it did not need to. a pause can be worthwhile even when the rest of the day stays complicated. the gentler parts of the month seemed to come from having fewer demands for a while, rather than from pushing harder.

i sent you something when things felt heavy. i hope it gave you a little break. i cannot know what it meant to you, so it is enough that it was there if you wanted it.

next month, try to protect a little more room for real rest before the week becomes crowded. you could leave an evening open, make a familiar quiet activity easy to reach, or decide in advance when work is finished for the day. keep the plan modest. it should create breathing room, not become another standard to meet.

the next month does not have to be perfect to feel kinder. a few clearer boundaries and a little more unclaimed time may be enough to make it feel more livable.`;

const simpleScript = `this month held both heavy and lighter moments, and the movement between them seemed important. there is no need to explain every change. some parts of a month are clear, while others are simply felt and then carried forward. what stands out is that you kept finding small ways to make a little room.

breathing gave you a quiet place to pause. it did not have to solve anything to be useful as a moment with less noise around it. that kind of pause can matter because it asks very little and can be returned to when the day feels crowded.

i sent you a few things, but you left them alone. that is okay. sometimes we do not need anything, and sometimes the timing is simply not right. there is no unfinished task waiting there and nothing you need to catch up on.

next month, keep a quiet practice easy to return to. you could make it brief, leave it available without a schedule, and use it only when it feels welcome. try to protect it from becoming another expectation. it might also help to leave a little empty space in the week, with no demand to fill it well.

you do not need to carry a perfect understanding of this month into the next one. take the parts that gave you room, leave the rest without judgment, and let the next month be met as it comes.`;

export const MONTHLY_STORY_GOLDENS: readonly MonthlyStoryGolden[] = Object.freeze([
  { id: "rich-month", signal: SYNTHETIC_RICH_SIGNAL, script: richScript,
    claimedEvidenceIds: ["evidence-mood-rich", "evidence-home-rich", "evidence-work-rich",
      "evidence-project-rich", "evidence-open-rich", "evidence-ideas-rich", "evidence-time-rich"],
    claimKeys: ["monthMixed", "missingHome", "workPressure", "personalProjects",
      "recommendationOpened", "makeSpaceForProjects", "protectPersonalTime"] },
  { id: "mood-only", signal: SYNTHETIC_MOOD_ONLY_SIGNAL, script: moodOnlyScript,
    claimedEvidenceIds: ["evidence-mood-only", "evidence-rest-only"],
    claimKeys: ["monthHeavy", "continueRest"] },
  { id: "recommendation-month", signal: SYNTHETIC_RECOMMENDATION_SIGNAL, script: recommendationScript,
    claimedEvidenceIds: ["evidence-mood-rec", "evidence-work-rec", "evidence-rest-rec",
      "evidence-open-rec", "evidence-rest-next"],
    claimKeys: ["monthMixed", "workPressure", "rest", "recommendationOpened", "continueRest"] },
  { id: "no-journal-or-health", signal: SYNTHETIC_NO_JOURNAL_HEALTH_SIGNAL, script: simpleScript,
    claimedEvidenceIds: ["evidence-mood-simple", "evidence-breathe-simple", "evidence-left-simple",
      "evidence-practice-simple"],
    claimKeys: ["monthMixed", "breathingRelief", "recommendationLeftUnopened", "continueHelpfulPractice"] },
]);

export const MONTHLY_STORY_NEGATIVE_GOLDENS = Object.freeze([
  { id: "report", script: "your data shows a better score this month.", reason: "reportingLanguage" },
  { id: "causal", script: "poor sleep caused every difficult feeling.", reason: "causalCertainty" },
  { id: "clinical", script: "you demonstrated emotional resilience in your healing journey.",
    reason: "therapistFraming" },
  { id: "recommendation-benefit", script: "the movie helped you and made you feel better.",
    reason: "recommendationBenefitClaim" },
  { id: "poetic", script: "the month became a tapestry of stars and a symphony of hope.",
    reason: "overlyPoetic" },
]);

export const SYNTHETIC_PASSING_CRITIC: MonthlyStoryCriticResult = passingMonthlyStoryCriticResult(20);
