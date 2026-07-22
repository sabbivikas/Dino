import { test } from "node:test";
import assert from "node:assert";
import {
  buildWeeklyPrompt,
  WEEKLY_MAX_QA,
  WEEKLY_MAX_PREV,
  WEEKLY_MAX_STR,
} from "./weeklyReport";

// Reference implementation of the ORIGINAL (pre-guard) prompt builder, used to
// prove a normal, well-formed report is rendered identically after the guards
// were added (guards/caps are no-ops on in-range input).
function originalBuildWeeklyPrompt(
  weekNumber: number,
  dateRange: string,
  questionsAndAnswers: Array<{ question: string; score: number }>,
  previousScores: Array<{ key: string; score: number }>
): string {
  const labels = ["not at all", "several days", "more than half the days", "nearly every day"];
  const lines: string[] = [];
  lines.push(
    `A user completed their weekly mental health check-in (Week ${weekNumber}, ${dateRange}). Here are their responses:`
  );
  lines.push("");
  questionsAndAnswers.forEach((qa, i) => {
    const score = Math.max(0, Math.min(3, Number(qa.score) || 0));
    lines.push(`Q${i + 1}: ${qa.question}`);
    lines.push(`A: ${labels[score]} (${score}/3)`);
  });
  lines.push("");
  if (previousScores && previousScores.length > 0) {
    const prevStr = previousScores.map((p) => `${p.key}=${p.score}`).join(", ");
    lines.push(`Previous week scores: ${prevStr}`);
  } else {
    lines.push("Previous week scores: none (first check-in)");
  }
  lines.push("");
  lines.push(
    [
      "Return JSON with this exact shape:",
      "{",
      '  "overallScore": number 0-100,',
      '  "overallLabel": string,',
      '  "overallEmoji": string,',
      '  "moodEnergyScore": number 0-100,',
      '  "moodEnergyInsight": string (2-3 warm sentences),',
      '  "anxietyStressScore": number 0-100,',
      '  "anxietyStressInsight": string (2-3 warm sentences),',
      '  "wellbeingScore": number 0-100,',
      '  "wellbeingInsight": string (2-3 warm sentences),',
      '  "weeklyReflection": string (3-4 sentences),',
      '  "trend": "improved" | "stable" | "needs attention",',
      '  "trendNote": string (one short line)',
      "}",
    ].join("\n")
  );
  return lines.join("\n");
}

// (c) A normal, well-formed report is rendered IDENTICALLY to the old builder.
test("normal report is unchanged by the guards", () => {
  const qa = [
    { question: "Little interest or pleasure in doing things?", score: 1 },
    { question: "Feeling nervous, anxious, or on edge?", score: 2 },
    { question: "Trouble relaxing?", score: 0 },
  ];
  const prev = [
    { key: "moodEnergy", score: 40 },
    { key: "anxietyStress", score: 55 },
  ];
  const got = buildWeeklyPrompt(3, "Jul 15-21", qa, prev);
  const want = originalBuildWeeklyPrompt(3, "Jul 15-21", qa, prev);
  assert.strictEqual(got, want);
});

// (a) Malformed elements do NOT throw and produce a bounded prompt.
test("malformed elements do not throw and are skipped/coerced", () => {
  const qa = [
    null,
    { question: "valid question", score: 2 },
    { score: 3 }, // missing question
    { question: "no score" }, // missing score
    "garbage",
  ] as unknown as Array<{ question: string; score: number }>;
  const prev = [null, { key: "mood" }, "junk"] as unknown as Array<{ key: string; score: number }>;

  let prompt = "";
  assert.doesNotThrow(() => {
    prompt = buildWeeklyPrompt(1, "range", qa, prev);
  });
  assert.ok(prompt.includes("valid question"), "the one valid question is rendered");
  assert.ok(prompt.includes("A: nearly every day (3/3)"), "missing-question element still coerces score");
  // prev has no numerically usable entries beyond coercion; it renders a bounded line.
  assert.ok(prompt.includes("Previous week scores:"), "prev line is present and bounded");
  assert.ok(prompt.length < 5000, "prompt stays bounded");
});

// Non-array inputs are tolerated (guarded), never throw.
test("non-array inputs do not throw", () => {
  assert.doesNotThrow(() => {
    buildWeeklyPrompt(
      0,
      "",
      null as unknown as Array<{ question: string; score: number }>,
      undefined as unknown as Array<{ key: string; score: number }>
    );
  });
});

// (b) Oversized arrays are capped and oversized strings are sliced.
test("oversized arrays and strings are capped", () => {
  const bigQa = Array.from({ length: 100 }, (_, i) => ({
    question: `question ${i}`,
    score: 1,
  }));
  const bigPrev = Array.from({ length: 100 }, (_, i) => ({ key: `k${i}`, score: 1 }));
  const prompt = buildWeeklyPrompt(1, "range", bigQa, bigPrev);

  // Only WEEKLY_MAX_QA questions rendered.
  assert.ok(prompt.includes(`Q${WEEKLY_MAX_QA}:`), "the cap-th question is rendered");
  assert.ok(!prompt.includes(`Q${WEEKLY_MAX_QA + 1}:`), "questions beyond the cap are dropped");

  // Only WEEKLY_MAX_PREV prev keys rendered.
  assert.ok(prompt.includes("k0=1"));
  assert.ok(prompt.includes(`k${WEEKLY_MAX_PREV - 1}=1`), "the cap-th prev key is rendered");
  assert.ok(!prompt.includes(`k${WEEKLY_MAX_PREV}=1`), "prev keys beyond the cap are dropped");

  // A single oversized question string is sliced to WEEKLY_MAX_STR chars.
  const longQ = "x".repeat(500);
  const p2 = buildWeeklyPrompt(1, "range", [{ question: longQ, score: 0 }], []);
  const line = p2.split("\n").find((l) => l.startsWith("Q1: "))!;
  const rendered = line.slice("Q1: ".length);
  assert.strictEqual(rendered.length, WEEKLY_MAX_STR, "question sliced to the string cap");
});
