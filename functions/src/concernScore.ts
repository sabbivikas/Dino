// concernScore.ts — luna recs T1+T2: the nightly concern score's DETERMINISTIC
// half, as PURE functions (no firebase, no network — node --test runs these
// directly). index.ts (nightlyExpeditionWatch) wires them to firestore.
//
// SPLIT OF LABOUR (cost rule 2 + rule 4):
//   • The 0-100 concern_score itself is MODEL work — produced by gpt-5.6-luna
//     (the cheap classification tier the watcher already calls once per
//     eligible user). It rides that existing call's JSON output; this module
//     never asks a model for anything. `sanitizeConcernScore` only VALIDATES
//     the number the model returned.
//   • Everything else here — confidence, the effective threshold, the 7-day
//     cooldown, the 4/30-day cap, the final shouldGenerate — is CODE, computed
//     INDEPENDENT of the model output. A scoring bug or model drift can move
//     the score but can NEVER move the caps: `decideRecGeneration` gates on
//     cooldown/cap regardless of score (see the pathological-cap test).
//
// CRISIS is NOT in this file and never will be. Crisis state is detected
// ON-DEVICE, is absolute, and routes to the existing crisis system before any
// server code runs. This module has no crisis input and returns only a recs
// decision, so it structurally cannot intercept, gate, throttle, or delay a
// crisis surface. The cooldown/cap here apply ONLY to comfort recs.

// ── Signal availability ─────────────────────────────────────────────────
// mood (moodTrend + heavyDays7) is ALWAYS present for a scored user (the
// eligibility gate requires a heavy signal). sleep, activity and journal are
// OPTIONAL: sleep/steps carry an explicit "unknown" when apple health is
// absent, and themes are present only when journalThemeLearningEnabled fed
// them. "ABSENCE OF DATA IS NOT A SIGNAL": a missing signal is never faked —
// its weight redistributes, and its absence LOWERS confidence (below).
export interface SignalAvailability {
  sleepKnown: boolean;    // sleepBucket !== "unknown"
  activityKnown: boolean; // stepsBucket !== "unknown"
  journalKnown: boolean;  // themes.length > 0
}

/** Which optional signals are present, from the already-validated buckets +
 *  themes the watcher holds. mood is always present, so it is not counted. */
export function signalAvailability(
  buckets: Record<string, string>, themes: string[]
): SignalAvailability {
  return {
    sleepKnown: buckets.sleepBucket !== undefined && buckets.sleepBucket !== "unknown",
    activityKnown: buckets.stepsBucket !== undefined && buckets.stepsBucket !== "unknown",
    journalKnown: Array.isArray(themes) && themes.length > 0,
  };
}

// ── Confidence (deterministic, code-level — NOT the model's job) ─────────
// mood alone is the floor; each of the three optional signals present adds an
// equal step. Full confidence (1.0) = both HK buckets known AND journal
// present. The model is TOLD which signals are present (prompt), but the
// number below is computed purely from availability so a model can never
// inflate its own confidence.
//   0 optional (mood only) → 0.40
//   1 optional             → 0.60
//   2 optional             → 0.80
//   3 optional (all)       → 1.00
export const CONFIDENCE_FLOOR = 0.4;
export const CONFIDENCE_STEP = 0.2;

export function computeConfidence(avail: SignalAvailability): number {
  const count = (avail.sleepKnown ? 1 : 0) + (avail.activityKnown ? 1 : 0) + (avail.journalKnown ? 1 : 0);
  return CONFIDENCE_FLOOR + CONFIDENCE_STEP * count;
}

// ── The model score, validated ──────────────────────────────────────────
/** The model returns concern_score as a 0-100 int. Anything not a finite
 *  number in range is null → the caller treats a null score as no-rec (a
 *  missing/garbage score must NEVER be read as "concerning"). */
export function sanitizeConcernScore(raw: unknown): number | null {
  const n = Number(raw);
  if (!Number.isFinite(n)) return null;
  const clamped = Math.max(0, Math.min(100, Math.round(n)));
  return clamped;
}

// ── Trigger math (all deterministic, independent of the model) ───────────
// Tuned (Task 2.4) against a simulated population so:
//   stable / low-signal  ≈ 0-1 rec / month
//   typical variance      ≈ 2-3 / month
//   sustained decline     → up to the 4/month ceiling
// See concernScore.test.ts (frequency-shape sim) and scratchpad frequency-sim.md.
export const BASE_THRESHOLD = 58;   // score a full-confidence user must clear
export const CONFIDENCE_K = 20;     // how much a total lack of confidence raises the bar
export const COOLDOWN_DAYS = 7;     // hard: ≥7 days since the last DELIVERED rec
export const MONTHLY_CAP = 4;       // hard: ≤4 delivered recs per rolling 30 days

/** Lower confidence demands a HIGHER score to fire. With BASE=58, K=20:
 *    confidence 1.0 → 58,  0.8 → 62,  0.6 → 66,  0.4 → 70 */
export function effectiveThreshold(confidence: number): number {
  const c = Math.max(0, Math.min(1, confidence));
  return BASE_THRESHOLD + (1 - c) * CONFIDENCE_K;
}

export interface RecDecisionInput {
  score: number | null;      // sanitized model concern_score (0-100), or null
  confidence: number;        // computeConfidence output (0.4..1.0)
  daysSinceLastRec: number;  // from the last DELIVERED (announced) rec; Infinity if none
  deliveriesLast30d: number; // count of delivered recs in the rolling 30 days
}

export type RecDecisionReason =
  | "no-score"       // model gave no usable score → quiet
  | "cooldown"       // <7 days since last delivered rec → quiet (independent of score)
  | "monthly-cap"    // already 4 delivered in 30 days → quiet (independent of score)
  | "below-threshold"// score under the confidence-adjusted bar → quiet
  | "generate";      // all gates pass → eligible to generate this night

export interface RecDecision {
  shouldGenerate: boolean;
  reason: RecDecisionReason;
  effectiveThreshold: number;
}

/**
 * The pure, unit-testable trigger. (score, confidence, daysSinceLastRec,
 * deliveriesLast30d) → shouldGenerate. The two caps are checked FIRST and are
 * fully independent of the score: no score, however high, can bypass the 7-day
 * cooldown or the 4/30-day cap. This is the runaway-generation firewall.
 */
export function decideRecGeneration(input: RecDecisionInput): RecDecision {
  const eff = effectiveThreshold(input.confidence);
  // Caps are independent of the model and are evaluated before the score, so a
  // pathological score can never slip past them.
  if (input.daysSinceLastRec < COOLDOWN_DAYS) {
    return { shouldGenerate: false, reason: "cooldown", effectiveThreshold: eff };
  }
  if (input.deliveriesLast30d >= MONTHLY_CAP) {
    return { shouldGenerate: false, reason: "monthly-cap", effectiveThreshold: eff };
  }
  if (input.score === null) {
    return { shouldGenerate: false, reason: "no-score", effectiveThreshold: eff };
  }
  if (input.score < eff) {
    return { shouldGenerate: false, reason: "below-threshold", effectiveThreshold: eff };
  }
  return { shouldGenerate: true, reason: "generate", effectiveThreshold: eff };
}
