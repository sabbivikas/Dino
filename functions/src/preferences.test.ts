import { test } from "node:test";
import assert from "node:assert";
import { buildDistillerInput, validatePrefs, LedgerEntry,
         PREF_MIN_OUTCOMES, PREF_MAX_ENTRIES, PREF_MAX_AVOID_DOMAINS } from "./preferences";

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
