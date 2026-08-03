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

const richScript = `this month held both hard and lighter moments. work seemed to take a lot out of you, and i think you were missing home too. those feelings could sit beside each other without needing a neat explanation. work and missing home were both present, without one explaining the other. they both deserved room without becoming the whole story. still, the month was not only about what felt difficult.

you seemed happiest when you had time for your own ideas. those personal pockets also seemed to give you a quiet place to pause when everything felt crowded. they did not have to fix the whole month to matter. they were simply places where there was a little more room to be yourself and let the pressure soften for a while.

i sent you something when things felt heavy. i hope it gave you a little break, but it is also okay if it was only a small moment in a complicated month.

next month, try to protect a little more time where work is actually over. save a small pocket of time for your own ideas before everything else fills the space. keep that time easy to return to, without turning it into another task. the goal is not to make every day lighter. it is to leave a few more openings for rest, home, and the parts of you that felt most alive.`;

const moodOnlyScript = `this month seemed heavy.

some days looked harder than others, and the difficult feeling stayed present across much of the month. i do not know exactly what was behind it. i will not guess at a reason or turn it into a lesson when the cause is not clear.

next month, choose a part of the weekend before other plans arrive, and keep that time open rather than filling it with another task. it does not have to become a routine or a goal. it can simply be time when nothing is expected from you.

if the week becomes crowded, decide what can wait until later instead of using the open time first. that gives the rest a fair chance to remain on the calendar without asking it to solve how the month felt.

i hope the coming weeks feel a little easier to move through than the last ones did.`;

const recommendationScript = `this month held a mix of strain and quieter moments. work seemed to take a lot out of you, and there were times when rest felt especially valuable. the difficult parts do not need to be exaggerated, but they also do not need to be brushed aside. work was weighing on you, and the need for a little room seemed real.

quiet time appeared to offer some relief. it may not have changed everything, and it did not need to. a pause can be worthwhile even when the rest of the day stays complicated. the gentler parts of the month seemed to come from having fewer demands for a while, rather than from pushing harder.

i sent you something when things felt heavy. i hope it gave you a little break. i cannot know what it meant to you, so it is enough that it was there if you wanted it.

next month, try to protect a little more room for real rest before the week becomes crowded. you could leave an evening open, make a familiar quiet activity easy to reach, or decide in advance when work is finished for the day. keep the plan modest. it should create breathing room, not become another standard to meet.

the next month does not have to be perfect to feel kinder. a few clearer boundaries and a little more unclaimed time may be enough to make it feel more livable.`;

const simpleScript = `this month held both hard and lighter moments.

breathing gave you a quiet place to pause. it was a brief practice you could return to without needing it to change the rest of the day. that pause stood on its own as something steady during a month that did not feel the same all the way through. a brief calm moment can matter without becoming proof that everything around it changed.

i sent you a few things, but you left them alone. that is okay. leaving them unopened does not mean you missed an opportunity or owe them another look. they can stay where they are unless you decide you want something from them later. nothing about that choice needs to be judged or corrected.

next month, keep the quiet practice easy to reach on stressful days. choose a simple moment when a brief pause already fits, rather than building a large routine around it. the aim is to keep something familiar nearby without turning it into another obligation. a small practice is enough when that is all the day has room for.

there were different kinds of days this month, and the next one can begin without extra pressure.`;

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
