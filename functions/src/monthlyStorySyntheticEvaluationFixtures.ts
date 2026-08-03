import { syntheticMonthlyStorySignal } from "./monthlyStoryWrittenFixtures";

export const MONTHLY_STORY_APPROVED_EVALUATION_FIXTURE_IDS = [
  "rich-work-home-projects",
  "mood-only-heavy",
  "mood-only-mixed",
  "rich-sleep-movement",
  "no-journal-or-health",
  "recommendation-opened",
  "recommendation-left-unopened",
  "rest-and-breathing-relief",
] as const;
export type MonthlyStoryEvaluationFixtureId =
  typeof MONTHLY_STORY_APPROVED_EVALUATION_FIXTURE_IDS[number];

type Evidence = { id: string; value: Record<string, string>; source: string;
  confidence?: "low" | "medium" | "high" };
const mood = (id: string, moodShape: string, moodDirection: string): Evidence => ({ id,
  value: { type: "emotionalShape", moodShape, moodDirection }, source: "mood" });
const theme = (id: string, value: string): Evidence => ({ id,
  value: { type: "repeatedTheme", theme: value }, source: "authorizedJournalTheme" });
const practice = (id: string, value: string): Evidence => ({ id,
  value: { type: "restorativePractice", practice: value }, source: "practicePresence" });
const recommendation = (id: string, value: string): Evidence => ({ id,
  value: { type: "recommendationAction", recommendation: value }, source: "recommendationOutcome" });
const suggestion = (id: string, value: string): Evidence => ({ id,
  value: { type: "nextMonthSuggestionBasis", suggestion: value }, source: "deterministicCombination" });
const health = (id: string, type: "sleepPattern" | "movementPattern", key: string,
  value: string): Evidence => ({ id, value: { type, [key]: value }, source: "authorizedHealthSummary",
  confidence: "medium" });

const fixtures: Record<MonthlyStoryEvaluationFixtureId, Record<string, unknown>> = {
  "rich-work-home-projects": syntheticMonthlyStorySignal({ evidence: [
    mood("synthetic-rich-mood", "mixed", "brighter"),
    theme("synthetic-rich-work", "workPressure"),
    theme("synthetic-rich-home", "missingHome"),
    theme("synthetic-rich-projects", "personalProjects"),
    suggestion("synthetic-rich-boundary", "protectPersonalTime"),
    suggestion("synthetic-rich-space", "makeSpaceForProjects"),
  ] }),
  "mood-only-heavy": syntheticMonthlyStorySignal({ mode: "moodOnly", journal: false, health: false,
    evidence: [mood("synthetic-heavy-mood", "mostlyHeavy", "variable"),
      suggestion("synthetic-heavy-rest", "continueRest")] }),
  "mood-only-mixed": syntheticMonthlyStorySignal({ mode: "moodOnly", journal: false, health: false,
    evidence: [mood("synthetic-mixed-mood", "mixed", "steady"),
      suggestion("synthetic-mixed-time", "protectPersonalTime")] }),
  "rich-sleep-movement": syntheticMonthlyStorySignal({ evidence: [
    mood("synthetic-health-mood", "mostlyHeavy", "brighter"),
    theme("synthetic-health-work", "workPressure"),
    health("synthetic-health-sleep", "sleepPattern", "sleep", "lessRestful"),
    health("synthetic-health-movement", "movementPattern", "movement", "lessActive"),
    practice("synthetic-health-focus", "focus"),
    suggestion("synthetic-health-rest", "continueRest"),
    suggestion("synthetic-health-boundary", "protectPersonalTime"),
  ] }),
  "no-journal-or-health": syntheticMonthlyStorySignal({ journal: false, health: false, evidence: [
    mood("synthetic-private-mood", "mixed", "brighter"),
    practice("synthetic-private-breathing", "breathing"),
    recommendation("synthetic-private-left", "leftUnopened"),
    suggestion("synthetic-private-practice", "continueHelpfulPractice"),
  ] }),
  "recommendation-opened": syntheticMonthlyStorySignal({ evidence: [
    mood("synthetic-open-mood", "mixed", "steady"),
    theme("synthetic-open-work", "workPressure"),
    practice("synthetic-open-focus", "focus"),
    recommendation("synthetic-open-recommendation", "opened"),
    suggestion("synthetic-open-next", "continueRest"),
  ] }),
  "recommendation-left-unopened": syntheticMonthlyStorySignal({ evidence: [
    mood("synthetic-left-mood", "mixed", "steady"),
    theme("synthetic-left-work", "workPressure"),
    practice("synthetic-left-focus", "focus"),
    recommendation("synthetic-left-recommendation", "leftUnopened"),
    suggestion("synthetic-left-next", "continueRest"),
  ] }),
  "rest-and-breathing-relief": syntheticMonthlyStorySignal({ evidence: [
    mood("synthetic-relief-mood", "mostlyHeavy", "brighter"),
    theme("synthetic-relief-work", "workPressure"),
    theme("synthetic-relief-rest", "rest"),
    practice("synthetic-relief-breathing", "breathing"),
    suggestion("synthetic-relief-next", "continueHelpfulPractice"),
    suggestion("synthetic-relief-boundary", "protectPersonalTime"),
  ] }),
};

export function isApprovedMonthlyStoryEvaluationFixtureId(value: string):
value is MonthlyStoryEvaluationFixtureId {
  return (MONTHLY_STORY_APPROVED_EVALUATION_FIXTURE_IDS as readonly string[]).includes(value);
}

export function approvedMonthlyStoryEvaluationFixture(id: MonthlyStoryEvaluationFixtureId):
Record<string, unknown> {
  return structuredClone(fixtures[id]);
}
