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
//     cooldown, the 3/30-day cap, the final shouldGenerate — is CODE, computed
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
//   sustained decline     → up to the 3/month ceiling
// See concernScore.test.ts (frequency-shape sim) and scratchpad frequency-sim.md.
export const BASE_THRESHOLD = 58;   // score a full-confidence user must clear
export const CONFIDENCE_K = 20;     // how much a total lack of confidence raises the bar
export const COOLDOWN_DAYS = 7;     // hard: ≥7 days since the last DELIVERED rec
export const MONTHLY_CAP = 3;       // hard: ≤3 delivered recs per rolling 30 days

// ── T4: personalized cadence — the ledger-learned threshold adjustment ──
// A user's own announcement (knock) engagement nudges their effective rec
// threshold: consistent opens LOWER it (slightly more recs), consistent
// ignoring RAISES it (fewer). The nudge is a BOUNDED integer computed purely
// from stored enum outcomes (see preferences.ts computeRecThresholdAdjustment)
// — no model call. These bounds are the single source of truth for both the
// producer (the distiller) and the consumer (this module); preferences.ts
// imports them from here so producer and consumer can never drift.
export const REC_ADJ_MIN = -6;      // most-engaged floor (lowers the bar most)
export const REC_ADJ_MAX = 6;       // most-ignoring ceiling (raises the bar most)
// Final effective-threshold clamp — a sanity envelope so no combination of
// confidence penalty + adjustment can push the bar out of a reasonable band.
// Normal operation stays well inside it (min 58-6=52, max 70+6=76); the clamp
// only ever catches a future retuning that overshoots.
export const THRESHOLD_MIN = 50;
export const THRESHOLD_MAX = 80;

/** Coerce a stored recThresholdAdjustment to a clamped int; non-finite → 0. A
 *  missing/garbage adjustment must read as "no nudge", never as a random shift. */
export function sanitizeRecThresholdAdjustment(raw: unknown): number {
  const n = Number(raw);
  if (!Number.isFinite(n)) return 0;
  return Math.max(REC_ADJ_MIN, Math.min(REC_ADJ_MAX, Math.round(n)));
}

/** Lower confidence demands a HIGHER score to fire; a per-user ledger
 *  adjustment then shifts the bar (opens lower it, ignores raise it). With
 *  BASE=58, K=20, adjustment 0:
 *    confidence 1.0 → 58,  0.8 → 62,  0.6 → 66,  0.4 → 70
 *  The adjustment is clamped to [REC_ADJ_MIN, REC_ADJ_MAX] and the final bar to
 *  [THRESHOLD_MIN, THRESHOLD_MAX]. It only eases/tightens eligibility WITHIN the
 *  hard cooldown/cap (checked separately in decideRecGeneration) — it can never
 *  breach them. */
export function effectiveThreshold(confidence: number, adjustment = 0): number {
  const c = Math.max(0, Math.min(1, confidence));
  const adj = sanitizeRecThresholdAdjustment(adjustment);
  const raw = BASE_THRESHOLD + (1 - c) * CONFIDENCE_K + adj;
  return Math.max(THRESHOLD_MIN, Math.min(THRESHOLD_MAX, raw));
}

export interface RecDecisionInput {
  score: number | null;      // sanitized model concern_score (0-100), or null
  confidence: number;        // computeConfidence output (0.4..1.0)
  daysSinceLastRec: number;  // from the last DELIVERED (announced) rec; Infinity if none
  deliveriesLast30d: number; // count of delivered recs in the rolling 30 days
  recThresholdAdjustment?: number; // T4: per-user ledger nudge (clamped); default 0
}

export type RecDecisionReason =
  | "no-score"       // model gave no usable score → quiet
  | "cooldown"       // <7 days since last delivered rec → quiet (independent of score)
  | "monthly-cap"    // already 3 delivered in 30 days → quiet (independent of score)
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
 * cooldown or the 3/30-day cap. This is the runaway-generation firewall.
 */
export function decideRecGeneration(input: RecDecisionInput): RecDecision {
  const eff = effectiveThreshold(input.confidence, input.recThresholdAdjustment ?? 0);
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

// ── T3 Part B — the SERVER-side generateComfortRecs input ────────────
// When the watcher decides a rec is due it must build the SAME input shape
// the onCall builds client-side (ComfortRecService.momentPayload), from the
// data the watcher actually holds server-side. This is the pure, testable
// half; runComfortRecGeneration (index.ts) consumes it. Every field's source
// or default is documented here and in scratchpad/luna-recs-QA/t3-verdict.md.
export const REC_THEMES = ["work", "sleep", "relationships", "health", "money", "self"];

/** The validated input generateComfortRecs generation runs on. Both callers
 *  (the onCall wrapper and the nightly watcher) produce this shape and hand it
 *  to the SAME runComfortRecGeneration — the generation/hold logic is never
 *  forked. `timeOfDay` is a free string here (not re-clamped) so the nightly
 *  path can pass "night"; the onCall clamps client input to midday/evening. */
export interface ComfortRecInput {
  mood: string;          // "" | "drained" | "overwhelmed"
  timeOfDay: string;     // onCall: midday|evening; watcher: night
  moodTrend: string;     // steady | wobbly | heavy
  recentThemes: string[];
  quietTypes: string[];
  userLocale: string;
  userCountry: string;   // ISO-2 region, or "" when unknown
  excludeTitles: string[];
}

/**
 * Build the generateComfortRecs input from the server-side nightly signals the
 * watcher already validated (buckets + themes + the signals doc's userLocale).
 *
 * FIELD SOURCES / DEFAULTS (rec-quality effect documented):
 *  - moodTrend   ← buckets.moodTrend (identical enum to the client path).
 *  - recentThemes← themes (EXPEDITION_THEME_ALLOW == REC_THEMES; identical).
 *  - userLocale  ← signals doc userLocale (AppLanguage.current); validated to
 *                  the 5 shipped languages, else "en". Drives the language of
 *                  the "why"/"length" text — full quality.
 *  - timeOfDay   = "night" (the watcher runs nightly). Honest context; recs are
 *                  still delivered out of quiet hours (21:30-08:30) next daypart.
 *  - mood        = "" — there is NO per-day logged mood server-side (signals
 *                  carry only the moodTrend/heavyDays buckets). The prompt's
 *                  "a quiet heaviness" fallback stands; moodTrend already
 *                  encodes the heaviness. Minor effect.
 *  - quietTypes  = [] — no server source for per-user disliked types. Effect:
 *                  no type is hard-excluded; the prefs-based typesLanding/
 *                  typesIgnored bias inside runComfortRecGeneration still
 *                  personalizes, and the 3-different-types rule still holds.
 *  - userCountry = "" — NO per-user country exists server-side (expeditionSignals
 *                  carries userLocale/language, not region; world docs are
 *                  privacy-folded aggregates, not per-uid profiles). Effect:
 *                  the model falls back to "globally beloved works" and the
 *                  TMDB watch-provider + poster lookup is skipped (film card is
 *                  paper-only in the reveal). FLAGGED: this is the one real
 *                  rec-quality degradation vs the client path (loses regional
 *                  resonance); the "why" still lands in the user's language.
 *  - excludeTitles = [] — no server-side history of prior rec titles (payloads
 *                  are deleted on open/expiry; the outcome ledger is enum-only,
 *                  no titles). Effect: a title could repeat. Mitigated by the
 *                  7-day cooldown + 3/month cap (recs are rare) and the prompt's
 *                  "reach widely across artists, eras, countries" variety rule.
 *                  FLAGGED as a possible-repeat, low-frequency.
 */
export function buildWatcherComfortRecInput(
  buckets: Record<string, string>, themes: string[], userLocale: string
): ComfortRecInput {
  const moodTrend = ["steady", "wobbly", "heavy"].includes(buckets.moodTrend)
    ? buckets.moodTrend : "steady";
  const recentThemes = (Array.isArray(themes) ? themes : [])
    .map((t) => String(t)).filter((t) => REC_THEMES.includes(t)).slice(0, 3);
  const locale = ["en", "es", "ja", "ko", "vi"].includes(userLocale) ? userLocale : "en";
  return {
    mood: "",
    timeOfDay: "night",
    moodTrend,
    recentThemes,
    quietTypes: [],
    userLocale: locale,
    userCountry: "",
    excludeTitles: [],
  };
}

// ── T3 Part A — the expedition-gift gates, as a pure predicate ─────────
// Decoupling the concern score from these gates (moving the shared luna call
// AHEAD of them) must NOT change which users get an expedition. This predicate
// is the exact, testable statement of the two gift-specific gates the watcher
// still applies AFTER the call: an expedition requires ≥14 days since the last
// gift AND not within ~3 days of a rec. `expeditionGiftGatesPass` is the exact
// complement of the old inline skip (`<14d` / `sinceLastRec==="0to2"` →
// continue), so relocating it leaves expedition delivery frequency unchanged.
export const EXPEDITION_MIN_DAYS = 14;

export interface ExpeditionGiftGateInput {
  daysSinceLastGift: number;  // (now - lastAt)/day; Infinity if no prior gift
  sinceLastRec: string;       // client-bucketed spacing since the last rec
}

export function expeditionGiftGatesPass(input: ExpeditionGiftGateInput): boolean {
  return input.daysSinceLastGift >= EXPEDITION_MIN_DAYS && input.sinceLastRec !== "0to2";
}
