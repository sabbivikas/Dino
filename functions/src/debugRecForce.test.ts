import test from "node:test";
import assert from "node:assert/strict";
import { debugRecForceGate, clampDelayMinutes, DEBUG_REC_FIXTURE_RECS } from "./debugRecForce";

const GOOD_KEY = "k".repeat(48);

test("gate fails closed: empty/missing allowlist or key denies everything", () => {
  assert.equal(debugRecForceGate(undefined, undefined, "").allowed, false);
  assert.equal(debugRecForceGate("", GOOD_KEY, GOOD_KEY).allowed, false);
  assert.equal(debugRecForceGate("uid1", undefined, "anything").allowed, false);
  assert.equal(debugRecForceGate("uid1", "short", "short").allowed, false); // key too short
  assert.equal(debugRecForceGate("uid1", GOOD_KEY, "").allowed, false);
  assert.equal(debugRecForceGate("uid1", GOOD_KEY, "wrong").allowed, false);
});

test("gate allows only with allowlist + exact key; uid is the FIRST allowlisted (never from the request)", () => {
  const g = debugRecForceGate(" uidA , uidB ", GOOD_KEY, GOOD_KEY);
  assert.equal(g.allowed, true);
  assert.equal(g.uid, "uidA");
});

test("delay clamp: garbage→1, 0→1, 200→90, '5'→5", () => {
  assert.equal(clampDelayMinutes("garbage"), 1);
  assert.equal(clampDelayMinutes(0), 1);
  assert.equal(clampDelayMinutes(200), 90);
  assert.equal(clampDelayMinutes("5"), 5);
  assert.equal(clampDelayMinutes(undefined), 1);
});

test("fixture recs match the sanitized shape the client expects", () => {
  const TYPES = ["music", "book", "film"];
  const FLAGS = ["not graphic", "no distressing themes", "a soft one", "gentle pacing", "some bittersweet moments"];
  const FEELS = ["cozy", "hopeful", "quiet"];
  assert.equal(DEBUG_REC_FIXTURE_RECS.length, 3);
  const nowYear = new Date().getUTCFullYear();
  for (const r of DEBUG_REC_FIXTURE_RECS) {
    assert.ok(TYPES.includes(r.type));
    assert.ok(r.title.length > 0 && r.title.length <= 80 && r.title === r.title.toLowerCase());
    assert.ok(r.creator.length > 0 && r.creator.length <= 80);
    assert.ok(Number.isInteger(r.year) && r.year >= 1900 && r.year <= nowYear);
    assert.ok(r.why.length > 0 && r.why.length <= 140 && !/[–—-]/.test(r.why));
    assert.ok(r.flags.length >= 1 && r.flags.every((f) => FLAGS.includes(f)));
    assert.ok(FEELS.includes(r.feel));
    assert.ok(r.length.length > 0 && r.length.length <= 40);
  }
  // exactly one film, and it carries the poster path for the image-led card
  const films = DEBUG_REC_FIXTURE_RECS.filter((r) => r.type === "film");
  assert.equal(films.length, 1);
  assert.match((films[0] as { posterPath?: string }).posterPath ?? "", /^\/[A-Za-z0-9._-]+\.(jpg|png)$/);
});
