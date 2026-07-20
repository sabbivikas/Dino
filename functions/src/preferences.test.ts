import { test } from "node:test";
import assert from "node:assert";
import { buildDistillerInput, validatePrefs, LedgerEntry,
         computeRecThresholdAdjustment, REC_ADJ_WINDOW, REC_ADJ_MIN_RESOLVED,
         PREF_MIN_OUTCOMES, PREF_MAX_ENTRIES, PREF_MAX_AVOID_DOMAINS } from "./preferences";
import { REC_ADJ_MIN, REC_ADJ_MAX } from "./concernScore";

// T4 helper — an announcement (knock) outcome entry
const ann = (action: string): LedgerEntry => ({
  kind: "announcement", itemType: "parcel", moodContext: "none",
  daypart: "evening", action,
});
const rep = (n: number, action: string): LedgerEntry[] =>
  Array.from({ length: n }, () => ann(action));

const entry = (over: Partial<LedgerEntry> = {}): LedgerEntry => ({
  kind: "rec", itemType: "music", moodContext: "drained",
  daypart: "evening", action: "kept", ...over,
});

test("distiller input is compact enum lines, nothing else", () => {
  const input = buildDistillerInput([
    entry(),
    entry({ kind: "gift", itemType: "wonder", sourceDomain: "nasa.gov", action: "ignored", followupTrend: "steady" }),
  ]);
  assert.equal(input, "rec|music|drained|evening|kept|unknown\ngift|wonder|drained|evening|ignored|steady|nasa.gov");
});

test("valid output passes and is clamped to sets", () => {
  const entries = [entry(), entry({ kind: "gift", itemType: "wonder", sourceDomain: "nasa.gov" })];
  const p = validatePrefs({
    recTypesLanding: ["music", "music"], recTypesIgnored: [],
    needKindsLanding: ["wonder"], needKindsIgnored: [],
    avoidDomains: ["nasa.gov"], bestDaypart: "evening", giftFatigue: "mild",
  }, entries);
  assert.ok(p);
  assert.deepEqual(p!.recTypesLanding, ["music"]);   // deduped
  assert.deepEqual(p!.avoidDomains, ["nasa.gov"]);
  assert.equal(p!.bestDaypart, "evening");
  assert.equal(p!.basedOnCount, 2);
});

test("off-enum values are dropped or defaulted, never passed through", () => {
  const p = validatePrefs({
    recTypesLanding: ["music", "podcast", 7],
    needKindsLanding: ["wonder", "chaos"],
    avoidDomains: [], bestDaypart: "brunch", giftFatigue: "terminal",
  }, [entry()]);
  assert.ok(p);
  assert.deepEqual(p!.recTypesLanding, ["music"]);
  assert.deepEqual(p!.needKindsLanding, ["wonder"]);
  assert.equal(p!.bestDaypart, "unknown");
  assert.equal(p!.giftFatigue, "none");
});

test("avoidDomains may only name domains in the user's own ledger, capped", () => {
  const entries = [1, 2, 3, 4, 5, 6].map((i) =>
    entry({ kind: "gift", itemType: "rest", sourceDomain: `s${i}.org` }));
  const p = validatePrefs({
    avoidDomains: ["s1.org", "evil.example", "s2.org", "s3.org", "s4.org", "s5.org"],
  }, entries);
  assert.ok(p);
  assert.ok(!p!.avoidDomains.includes("evil.example"));
  assert.ok(p!.avoidDomains.length <= PREF_MAX_AVOID_DOMAINS);
});

test("wrong shapes are rejected outright — no partial doc", () => {
  assert.equal(validatePrefs(null, []), null);
  assert.equal(validatePrefs("music", []), null);
  assert.equal(validatePrefs({ recTypesLanding: "music" }, []), null);
  assert.equal(validatePrefs({ avoidDomains: "nasa.gov" }, []), null);
});

test("constants hold the approved plan", () => {
  assert.equal(PREF_MIN_OUTCOMES, 8);
  assert.equal(PREF_MAX_ENTRIES, 200);
});

// ── T4: ledger-based cadence — open-rate → threshold adjustment ───────────

test("T4: open-heavy knock history LOWERS the threshold (negative adjustment)", () => {
  // 9 opened / 1 ignored → open-rate 0.9 ≥ 0.80 → floor -6
  assert.equal(computeRecThresholdAdjustment([...rep(9, "opened"), ann("ignored")]), -6);
  // 7 opened / 3 ignored → 0.70 → -3
  assert.equal(computeRecThresholdAdjustment([...rep(7, "opened"), ...rep(3, "ignored")]), -3);
});

test("T4: ignore-heavy knock history RAISES the threshold (positive adjustment)", () => {
  // 1 opened / 9 ignored → open-rate 0.1 < 0.20 → ceiling +6
  assert.equal(computeRecThresholdAdjustment([ann("opened"), ...rep(9, "ignored")]), 6);
  // 3 opened / 7 ignored → 0.30 → +3
  assert.equal(computeRecThresholdAdjustment([...rep(3, "opened"), ...rep(7, "ignored")]), 3);
});

test("T4: neutral open-rate → ZERO nudge", () => {
  // 5 opened / 5 ignored → 0.50, inside the 0.40–0.60 neutral band → 0
  assert.equal(computeRecThresholdAdjustment([...rep(5, "opened"), ...rep(5, "ignored")]), 0);
});

test("T4: insufficient/absent signal → EXACTLY zero", () => {
  assert.equal(REC_ADJ_MIN_RESOLVED, 4);
  // 3 resolved (< 4) even all-opened → 0
  assert.equal(computeRecThresholdAdjustment(rep(3, "opened")), 0);
  // no entries → 0
  assert.equal(computeRecThresholdAdjustment([]), 0);
  // 'shown' does not count as resolved: 10 shown + 3 opened = 3 resolved → 0
  assert.equal(computeRecThresholdAdjustment([...rep(10, "shown"), ...rep(3, "opened")]), 0);
});

test("T4: only announcement/parcel entries count; rec + gift outcomes ignored", () => {
  const recAndGift: LedgerEntry[] = [
    { kind: "rec", itemType: "music", moodContext: "drained", daypart: "evening", action: "ignored" },
    { kind: "gift", itemType: "rest", moodContext: "none", daypart: "night", action: "ignored", sourceDomain: "x.org" },
  ];
  assert.equal(computeRecThresholdAdjustment(recAndGift), 0);   // no announcements → 0
  // rec/gift ignores must NOT pull the announcement open-rate down
  assert.equal(computeRecThresholdAdjustment([...recAndGift, ...rep(8, "opened")]), -6);
});

test("T4: adjustment always within [REC_ADJ_MIN, REC_ADJ_MAX]", () => {
  for (const c of [rep(30, "opened"), rep(30, "ignored"),
                   [...rep(15, "opened"), ...rep(15, "ignored")]]) {
    const a = computeRecThresholdAdjustment(c);
    assert.ok(a >= REC_ADJ_MIN && a <= REC_ADJ_MAX, `adj ${a} out of bounds`);
  }
});

test("T4: only the most-recent REC_ADJ_WINDOW knocks are weighed", () => {
  // newest window all opened (entries are newest-first) → -6, despite a long
  // older tail of ignores beyond the window.
  assert.equal(computeRecThresholdAdjustment([...rep(REC_ADJ_WINDOW, "opened"), ...rep(50, "ignored")]), -6);
});

test("T4: validatePrefs stamps recThresholdAdjustment onto the doc", () => {
  // 8 opened / 1 ignored ≈ 0.89 ≥ 0.80 → -6; the rec entry is ignored by the math
  const entries = [...rep(8, "opened"), ann("ignored"), entry()];
  const p = validatePrefs({ recTypesLanding: [], needKindsLanding: [] }, entries);
  assert.ok(p);
  assert.equal(p!.recThresholdAdjustment, -6);
});
