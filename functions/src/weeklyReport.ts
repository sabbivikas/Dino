// ---------------------------------------------------------------------------
// Weekly report prompt builder — extracted from index.ts so the input-guarding
// and caps are a pure, testable path. Malformed elements are skipped/coerced
// (never thrown on); oversized arrays and strings are capped for cost/quota
// discipline. The caps are generous — a legit ~7-9 question report is never
// truncated.
// ---------------------------------------------------------------------------

/** Max check-in questions rendered into the prompt. */
export const WEEKLY_MAX_QA = 30;
/** Max previous-week score entries rendered into the prompt. */
export const WEEKLY_MAX_PREV = 30;
/** Max characters kept for any single question / key string. */
export const WEEKLY_MAX_STR = 300;

/** Coerce any value to a bounded string (null/undefined → ""). */
function capStr(value: unknown): string {
  return String(value ?? "").slice(0, WEEKLY_MAX_STR);
}

/** Clamp a check-in answer score to the valid 0-3 Likert range. */
function clampAnswerScore(value: unknown): number {
  return Math.max(0, Math.min(3, Number(value) || 0));
}

export function buildWeeklyPrompt(
  weekNumber: number,
  dateRange: string,
  questionsAndAnswers: Array<{ question: string; score: number }>,
  previousScores: Array<{ key: string; score: number }>
): string {
  const labels = [
    "not at all",
    "several days",
    "more than half the days",
    "nearly every day",
  ];
  const lines: string[] = [];
  lines.push(
    `A user completed their weekly mental health check-in (Week ${
      Number(weekNumber) || 0
    }, ${capStr(dateRange)}). Here are their responses:`
  );
  lines.push("");

  const qaList = Array.isArray(questionsAndAnswers)
    ? questionsAndAnswers.slice(0, WEEKLY_MAX_QA)
    : [];
  qaList.forEach((qa, i) => {
    if (qa === null || typeof qa !== "object") return; // skip malformed element
    const score = clampAnswerScore((qa as { score?: unknown }).score);
    const question = capStr((qa as { question?: unknown }).question);
    lines.push(`Q${i + 1}: ${question}`);
    lines.push(`A: ${labels[score]} (${score}/3)`);
  });
  lines.push("");

  const prevList = Array.isArray(previousScores)
    ? previousScores.slice(0, WEEKLY_MAX_PREV)
    : [];
  const validPrev = prevList.filter(
    (p) => p !== null && typeof p === "object"
  );
  if (validPrev.length > 0) {
    const prevStr = validPrev
      .map((p) => {
        const key = capStr((p as { key?: unknown }).key);
        const raw = Number((p as { score?: unknown }).score);
        const score = Number.isFinite(raw) ? raw : 0;
        return `${key}=${score}`;
      })
      .join(", ");
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
