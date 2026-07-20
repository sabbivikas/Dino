import { test } from "node:test";
import assert from "node:assert";
import {
  signalAvailability, computeConfidence, sanitizeConcernScore,
  effectiveThreshold, decideRecGeneration,
  buildWatcherComfortRecInput, expeditionGiftGatesPass, EXPEDITION_MIN_DAYS,
  CONFIDENCE_FLOOR, CONFIDENCE_STEP,
  BASE_THRESHOLD, CONFIDENCE_K, COOLDOWN_DAYS, MONTHLY_CAP,
  REC_ADJ_MIN, REC_ADJ_MAX, THRESHOLD_MIN, THRESHOLD_MAX,
  sanitizeRecThresholdAdjustment,
} from "./concernScore";

// ── confidence: from signal availability, deterministic ──────────────────

test("computeConfidence: floor is mood-only, full is all three optionals", () => {
  const none = { sleepKnown: false, activityKnown: false, journalKnown: false };
  const all = { sleepKnown: true, activityKnown: true, journalKnown: true };
  assert.equal(computeConfidence(none), CONFIDENCE_FLOOR);                 // 0.40
  assert.equal(computeConfidence({ ...none, sleepKnown: true }), CONFIDENCE_FLOOR + CONFIDENCE_STEP); // 0.60
  assert.equal(computeConfidence({ sleepKnown: true, activityKnown: true, journalKnown: false }),
    CONFIDENCE_FLOOR + 2 * CONFIDENCE_STEP);                              // 0.80
  assert.equal(computeConfidence(all), 1.0);                             // 1.00
});

test("signalAvailability: unknown HK buckets and empty themes are absent", () => {
  const a = signalAvailability(
    { sleepBucket: "unknown", stepsBucket: "mid" }, ["work"]);
  assert.deepEqual(a, { sleepKnown: false, activityKnown: true, journalKnown: true });
  const b = signalAvailability({ sleepBucket: "short", stepsBucket: "unknown" }, []);
  assert.deepEqual(b, { sleepKnown: true, activityKnown: false, journalKnown: false });
});

// ── score sanitation ─────────────────────────────────────────────────────

test("sanitizeConcernScore: clamps, rounds, rejects garbage as null", () => {
  assert.equal(sanitizeConcernScore(72), 72);
  assert.equal(sanitizeConcernScore(72.6), 73);
  assert.equal(sanitizeConcernScore(-5), 0);
  assert.equal(sanitizeConcernScore(150), 100);
  assert.equal(sanitizeConcernScore("80"), 80);
  assert.equal(sanitizeConcernScore("nonsense"), null);
  assert.equal(sanitizeConcernScore(undefined), null);
  assert.equal(sanitizeConcernScore(NaN), null);
});

// ── confidence gating: same score, lower confidence stays quiet ──────────

test("effectiveThreshold rises as confidence falls", () => {
  assert.equal(effectiveThreshold(1.0), BASE_THRESHOLD);
  assert.ok(effectiveThreshold(0.6) > effectiveThreshold(1.0));
  assert.ok(effectiveThreshold(0.4) > effectiveThreshold(0.6));
  assert.equal(effectiveThreshold(0.8), BASE_THRESHOLD + 0.2 * CONFIDENCE_K);
});

// ── T4: the ledger-learned threshold adjustment ─────────────────────────

test("T4: effectiveThreshold shifts by the clamped adjustment (default none)", () => {
  assert.equal(effectiveThreshold(1.0), BASE_THRESHOLD);            // default 0 → unchanged
  assert.equal(effectiveThreshold(1.0, -6), BASE_THRESHOLD - 6);    // engaged → lower bar
  assert.equal(effectiveThreshold(1.0, 6), BASE_THRESHOLD + 6);     // ignoring → higher bar
  // out-of-range adjustments clamp to [REC_ADJ_MIN, REC_ADJ_MAX]
  assert.equal(effectiveThreshold(1.0, -100), BASE_THRESHOLD + REC_ADJ_MIN);
  assert.equal(effectiveThreshold(1.0, 100), BASE_THRESHOLD + REC_ADJ_MAX);
  // final bar stays inside the sane envelope
  assert.ok(effectiveThreshold(0.4, REC_ADJ_MAX) <= THRESHOLD_MAX);
  assert.ok(effectiveThreshold(1.0, REC_ADJ_MIN) >= THRESHOLD_MIN);
});

test("T4: sanitizeRecThresholdAdjustment clamps + rejects garbage as 0", () => {
  assert.equal(sanitizeRecThresholdAdjustment(-3), -3);
  assert.equal(sanitizeRecThresholdAdjustment(3.4), 3);
  assert.equal(sanitizeRecThresholdAdjustment(-99), REC_ADJ_MIN);
  assert.equal(sanitizeRecThresholdAdjustment(99), REC_ADJ_MAX);
  assert.equal(sanitizeRecThresholdAdjustment("nonsense"), 0);
  assert.equal(sanitizeRecThresholdAdjustment(undefined), 0);
  assert.equal(sanitizeRecThresholdAdjustment(null), 0);
});

test("T4: a downward adjustment makes a borderline score eligible (within caps)", () => {
  const score = BASE_THRESHOLD - 3;   // 55: below the full-confidence bar (58)
  const base = { score, confidence: 1.0, daysSinceLastRec: 999, deliveriesLast30d: 0 };
  assert.equal(decideRecGeneration(base).shouldGenerate, false);                        // no nudge → quiet
  assert.equal(decideRecGeneration({ ...base, recThresholdAdjustment: -6 }).shouldGenerate, true);  // engaged → bar 52 → eligible
  assert.equal(decideRecGeneration({ ...base, recThresholdAdjustment: 6 }).shouldGenerate, false);  // ignoring → bar 64 → quiet
});

test("CONFIDENCE GATING: one raw score crosses at full confidence, not at low", () => {
  // a score sitting between the full-confidence bar and the low-confidence bar
  const score = Math.ceil(effectiveThreshold(1.0)) + 1; // clears full-confidence bar
  assert.ok(score < effectiveThreshold(CONFIDENCE_FLOOR)); // but below the mood-only bar
  const base = { score, daysSinceLastRec: 999, deliveriesLast30d: 0 };
  assert.equal(decideRecGeneration({ ...base, confidence: 1.0 }).shouldGenerate, true);
  assert.equal(decideRecGeneration({ ...base, confidence: CONFIDENCE_FLOOR }).shouldGenerate, false);
  assert.equal(decideRecGeneration({ ...base, confidence: CONFIDENCE_FLOOR }).reason, "below-threshold");
});

// ── caps are independent of the score ────────────────────────────────────

test("cooldown and cap gate BEFORE score, independent of it", () => {
  const hot = { score: 100, confidence: 1.0 };
  // cooldown: 6 days < 7 → quiet even at score 100
  assert.equal(decideRecGeneration({ ...hot, daysSinceLastRec: 6, deliveriesLast30d: 0 }).reason, "cooldown");
  // cap: 4 already delivered → quiet even at score 100
  assert.equal(decideRecGeneration({ ...hot, daysSinceLastRec: 999, deliveriesLast30d: 4 }).reason, "monthly-cap");
  // both clear → generate
  assert.equal(decideRecGeneration({ ...hot, daysSinceLastRec: 7, deliveriesLast30d: 3 }).shouldGenerate, true);
});

test("null score never generates, but still respects nothing above caps", () => {
  assert.equal(decideRecGeneration({ score: null, confidence: 1.0, daysSinceLastRec: 999, deliveriesLast30d: 0 }).reason, "no-score");
});

// ── T3 Part B — the server-side input builder ────────────────────────────

test("buildWatcherComfortRecInput: maps signals + applies documented defaults", () => {
  const input = buildWatcherComfortRecInput(
    { moodTrend: "heavy", heavyDays7: "4plus", sleepBucket: "short", stepsBucket: "low", sinceLastRec: "14plus" },
    ["work", "sleep"], "ja");
  // clean server mappings
  assert.equal(input.moodTrend, "heavy");
  assert.deepEqual(input.recentThemes, ["work", "sleep"]);
  assert.equal(input.userLocale, "ja");
  // nightly context
  assert.equal(input.timeOfDay, "night");
  // documented defaults for fields with no clean server source
  assert.equal(input.mood, "");
  assert.deepEqual(input.quietTypes, []);
  assert.equal(input.userCountry, "");
  assert.deepEqual(input.excludeTitles, []);
});

test("buildWatcherComfortRecInput: sanitizes off-shape trend/themes/locale", () => {
  const input = buildWatcherComfortRecInput(
    { moodTrend: "garbage" }, ["work", "notATheme", "health", "money", "self"], "xx");
  assert.equal(input.moodTrend, "steady");                 // bad trend → safe default
  assert.deepEqual(input.recentThemes, ["work", "health", "money"]); // filtered to allow-list, capped 3
  assert.equal(input.userLocale, "en");                    // unknown locale → en
});

test("WIRING: a shouldGenerate=true decision yields a valid generation input", () => {
  // The watcher's live path: decide → (if generate) build input → runComfortRecGeneration.
  // runComfortRecGeneration is impure (firestore/openai) so it is not node-tested;
  // this asserts the pure boundary the watcher crosses before invoking it.
  const decision = decideRecGeneration({
    score: 90, confidence: 1.0, daysSinceLastRec: 999, deliveriesLast30d: 0,
  });
  assert.equal(decision.shouldGenerate, true);
  const input = buildWatcherComfortRecInput({ moodTrend: "heavy" }, ["work"], "en");
  // the input the onCall's validators would accept unchanged
  assert.ok(["", "drained", "overwhelmed"].includes(input.mood));
  assert.ok(["steady", "wobbly", "heavy"].includes(input.moodTrend));
  assert.equal(typeof input.userLocale, "string");
});

// ── T3 Part A — expedition-gift gates unchanged by the decouple ──────────

test("expeditionGiftGatesPass: 14d-since-gift + 3d-since-rec gates preserved", () => {
  // gift-gated: within 14 days of the last gift → NO expedition, whatever else
  assert.equal(expeditionGiftGatesPass({ daysSinceLastGift: 5, sinceLastRec: "14plus" }), false);
  assert.equal(expeditionGiftGatesPass({ daysSinceLastGift: EXPEDITION_MIN_DAYS - 0.001, sinceLastRec: "8to13" }), false);
  // rec-gated: within ~3 days of a rec (0to2 bucket) → NO expedition
  assert.equal(expeditionGiftGatesPass({ daysSinceLastGift: 999, sinceLastRec: "0to2" }), false);
  // non-gated: ≥14d since gift AND not within 3d of a rec → expedition allowed
  assert.equal(expeditionGiftGatesPass({ daysSinceLastGift: 14, sinceLastRec: "3to7" }), true);
  assert.equal(expeditionGiftGatesPass({ daysSinceLastGift: Infinity, sinceLastRec: "14plus" }), true);
});

test("expeditionGiftGatesPass: is the exact complement of the old inline skip", () => {
  // The pre-T3 watcher did: skip if (now-lastAt < 14d) OR (sinceLastRec==="0to2").
  // The predicate must return the negation of that skip for every case, so the
  // SET of users who get an expedition is identical after moving the call earlier.
  for (const days of [0, 6.9, 13.999, 14, 14.001, 30, Infinity]) {
    for (const rec of ["0to2", "3to7", "8to13", "14plus"]) {
      const oldSkip = days < EXPEDITION_MIN_DAYS || rec === "0to2";
      assert.equal(expeditionGiftGatesPass({ daysSinceLastGift: days, sinceLastRec: rec }), !oldSkip,
        `mismatch at days=${days} rec=${rec}`);
    }
  }
});

// ── simulation harness (deterministic) ───────────────────────────────────

function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

interface NightPlan { eligible: boolean; score: number | null; confidence: number }
interface Profile {
  pEligible: number; scoreLo: number; scoreHi: number;
  pSleep: number; pSteps: number; pJournal: number;
}

const PROFILES: Record<string, Profile> = {
  // calm weeks: rarely even eligible; when it is, low severity, thin signals
  stable:    { pEligible: 0.20, scoreLo: 25, scoreHi: 50, pSleep: 0.6, pSteps: 0.6, pJournal: 0.10 },
  // ordinary ups and downs
  typical:   { pEligible: 0.50, scoreLo: 45, scoreHi: 72, pSleep: 0.7, pSteps: 0.7, pJournal: 0.40 },
  // a sustained heavy stretch: eligible most nights, high severity, rich signals
  declining: { pEligible: 0.85, scoreLo: 68, scoreHi: 96, pSleep: 0.8, pSteps: 0.8, pJournal: 0.60 },
}

function nightFor(p: Profile, rnd: () => number): NightPlan {
  if (rnd() > p.pEligible) return { eligible: false, score: null, confidence: 0 };
  const rawScore = p.scoreLo + rnd() * (p.scoreHi - p.scoreLo);
  const avail = {
    sleepKnown: rnd() < p.pSleep,
    activityKnown: rnd() < p.pSteps,
    journalKnown: rnd() < p.pJournal,
  };
  return {
    eligible: true,
    score: sanitizeConcernScore(rawScore),
    confidence: computeConfidence(avail),
  };
}

/** Run one simulated month, enforcing cooldown+cap through the SAME decision
 *  function production uses. Returns the number of delivered recs. A generation
 *  is modeled as one same-day delivery (one generateComfortRecs call → one
 *  announcement/knock; the ±1 day the 45-90 min hold adds is immaterial to a
 *  30-day count). */
function simulateMonth(plan: (day: number) => NightPlan, days = 30): number {
  const deliveryDays: number[] = [];
  for (let day = 0; day < days; day++) {
    const n = plan(day);
    if (!n.eligible) continue;
    const last = deliveryDays.length ? deliveryDays[deliveryDays.length - 1] : -Infinity;
    const daysSinceLastRec = day - last;                       // Infinity if none yet
    const deliveriesLast30d = deliveryDays.filter((d) => day - d < 30).length;
    const decision = decideRecGeneration({
      score: n.score, confidence: n.confidence, daysSinceLastRec, deliveriesLast30d,
    });
    if (decision.shouldGenerate) deliveryDays.push(day);
  }
  return deliveryDays.length;
}

function avgMonthly(name: string, seeds: number): { avg: number; max: number; min: number } {
  const p = PROFILES[name];
  let sum = 0, max = 0, min = Infinity;
  for (let s = 0; s < seeds; s++) {
    const rnd = mulberry32(0x1000 * (name.length + 1) + s);
    const count = simulateMonth(() => nightFor(p, rnd));
    sum += count; max = Math.max(max, count); min = Math.min(min, count);
  }
  return { avg: sum / seeds, max, min };
}

// ── REQUIRED TEST 2 — frequency-shape simulation ─────────────────────────

test("FREQUENCY SHAPE: monthly deliveries land in the target bands", () => {
  const SEEDS = 400;
  const stable = avgMonthly("stable", SEEDS);
  const typical = avgMonthly("typical", SEEDS);
  const declining = avgMonthly("declining", SEEDS);
  if (process.env.SIM_PRINT) console.error(`SIM stable=${stable.avg.toFixed(3)} typical=${typical.avg.toFixed(3)} declining=${declining.avg.toFixed(3)} (declining max=${declining.max})`);

  // stable/low-signal ≈ 0-1/month
  assert.ok(stable.avg <= 1.0, `stable avg ${stable.avg} should be ≤ 1`);
  // typical ≈ 2-3/month
  assert.ok(typical.avg >= 2.0 && typical.avg <= 3.0, `typical avg ${typical.avg} should be 2-3`);
  // sustained decline → up to the 4/month ceiling (and NEVER over it)
  assert.ok(declining.avg >= 3.0 && declining.avg <= 4.0, `declining avg ${declining.avg} should be 3-4`);
  assert.ok(declining.max <= MONTHLY_CAP, `declining max ${declining.max} must never exceed the ${MONTHLY_CAP} cap`);
  assert.ok(stable.avg < typical.avg && typical.avg < declining.avg, "bands must be ordered");
});

// ── REQUIRED TEST 1 — pathological score cap ─────────────────────────────

test("PATHOLOGICAL CAP: concern_score=100 every night for 60 days stays ≤1/7d and ≤4/30d", () => {
  // Force the worst case: eligible every night, top score, full confidence.
  const deliveryDays: number[] = [];
  for (let day = 0; day < 60; day++) {
    const daysSinceLastRec = deliveryDays.length ? day - deliveryDays[deliveryDays.length - 1] : Infinity;
    const deliveriesLast30d = deliveryDays.filter((d) => day - d < 30).length;
    const decision = decideRecGeneration({
      score: 100, confidence: 1.0, daysSinceLastRec, deliveriesLast30d,
    });
    if (decision.shouldGenerate) deliveryDays.push(day);
  }
  // ≤1 per any rolling 7-day window
  for (let i = 1; i < deliveryDays.length; i++) {
    assert.ok(deliveryDays[i] - deliveryDays[i - 1] >= COOLDOWN_DAYS,
      `deliveries ${deliveryDays[i - 1]} and ${deliveryDays[i]} are <7 days apart`);
  }
  // ≤4 per any rolling 30-day window
  for (let day = 0; day < 60; day++) {
    const inWindow = deliveryDays.filter((d) => d <= day && day - d < 30).length;
    assert.ok(inWindow <= MONTHLY_CAP, `${inWindow} deliveries in the 30d window ending day ${day} exceeds ${MONTHLY_CAP}`);
  }
  // over 60 days at ~4/30d the ceiling yields at most 9 (two rolling months + boundary)
  assert.ok(deliveryDays.length <= 9, `runaway: ${deliveryDays.length} deliveries in 60 days`);
});

// ── REQUIRED TEST 2 (T4) — pathological cap UNDER max downward adjustment ──

test("PATHOLOGICAL CAP + MAX DOWNWARD ADJUSTMENT: most-engaged user, score=100 every night for 60 days STILL ≤1/7d and ≤4/30d", () => {
  // The cadence learner's strongest possible nudge (REC_ADJ_MIN = the most-
  // engaged user) stacked on the pathological score. The caps are hard and
  // independent of BOTH score and adjustment — lowering the bar can never
  // breach them. This is the cost-rule-4 firewall proof for T4.
  const deliveryDays: number[] = [];
  for (let day = 0; day < 60; day++) {
    const daysSinceLastRec = deliveryDays.length ? day - deliveryDays[deliveryDays.length - 1] : Infinity;
    const deliveriesLast30d = deliveryDays.filter((d) => day - d < 30).length;
    const decision = decideRecGeneration({
      score: 100, confidence: 1.0, daysSinceLastRec, deliveriesLast30d,
      recThresholdAdjustment: REC_ADJ_MIN,   // max downward — easiest possible eligibility
    });
    if (decision.shouldGenerate) deliveryDays.push(day);
  }
  for (let i = 1; i < deliveryDays.length; i++) {
    assert.ok(deliveryDays[i] - deliveryDays[i - 1] >= COOLDOWN_DAYS,
      `deliveries ${deliveryDays[i - 1]} and ${deliveryDays[i]} <7d apart under max downward adjustment`);
  }
  for (let day = 0; day < 60; day++) {
    const inWindow = deliveryDays.filter((d) => d <= day && day - d < 30).length;
    assert.ok(inWindow <= MONTHLY_CAP,
      `${inWindow} deliveries in the 30d window ending day ${day} exceeds ${MONTHLY_CAP} under max downward adjustment`);
  }
  assert.ok(deliveryDays.length <= 9,
    `runaway under max downward adjustment: ${deliveryDays.length} deliveries in 60 days`);
});
