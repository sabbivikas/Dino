import { test } from "node:test";
import assert from "node:assert";
import {
  REC_ANNOUNCEMENT_TITLE_LOC_KEY, REC_ANNOUNCEMENT_BODY_LOC_KEY,
  REC_ANNOUNCEMENT_CATEGORY, REC_PUSH_TOKEN_MAX_LENGTH,
  recRevealDeepLink, isPlausiblePushToken, buildRecAnnouncementMessage,
} from "./recAnnounce";

// THE ANNOUNCEMENT IS CONTENT-FREE (owner rubric): the push may name a
// delivery to open and nothing else. Every assertion below exists to make
// a future "just add the rec title to the push" diff fail loudly.

test("loc keys are the catalog keys the app ships", () => {
  assert.equal(REC_ANNOUNCEMENT_TITLE_LOC_KEY, "rec_announcement_title");
  assert.equal(REC_ANNOUNCEMENT_BODY_LOC_KEY, "rec_announcement_body");
});

test("message shape: token + apns only — no notification block, no data block", () => {
  const m = buildRecAnnouncementMessage("tok123", "d1") as Record<string, unknown>;
  assert.deepEqual(Object.keys(m).sort(), ["apns", "token"]);
  assert.equal("notification" in m, false);
  assert.equal("data" in m, false);
});

test("apns alert carries loc-keys ONLY — never literal title or body text", () => {
  const m = buildRecAnnouncementMessage("tok123", "d1");
  const alert = m.apns.payload.aps.alert as Record<string, unknown>;
  // admin-sdk camelCase → APNs wire keys: titleLocKey → title-loc-key,
  // locKey → loc-key (the BODY's localization key — verified on-sim).
  assert.deepEqual(Object.keys(alert).sort(), ["locKey", "titleLocKey"]);
  assert.equal(alert.titleLocKey, REC_ANNOUNCEMENT_TITLE_LOC_KEY);
  assert.equal(alert.locKey, REC_ANNOUNCEMENT_BODY_LOC_KEY);
});

test("custom payload names the delivery and the door — nothing else", () => {
  const m = buildRecAnnouncementMessage("tok123", "d1");
  const payload = m.apns.payload as Record<string, unknown>;
  assert.deepEqual(Object.keys(payload).sort(), ["aps", "deepLink", "deliveryId"]);
  assert.equal(payload.deliveryId, "d1");
  assert.equal(payload.deepLink, "dino://rec-reveal/d1");
});

test("content-free proof: every string leaf is structural, none is content", () => {
  // even if a rec-shaped object were somehow threaded through, this walks
  // the real message and pins the complete set of string leaves.
  const m = buildRecAnnouncementMessage("tokXYZ", "deliv42");
  const leaves: string[] = [];
  const walk = (v: unknown) => {
    if (typeof v === "string") leaves.push(v);
    else if (v && typeof v === "object") Object.values(v).forEach(walk);
  };
  walk(m);
  assert.deepEqual(leaves.sort(), [
    "10", "REC_ANNOUNCEMENT", "default", "deliv42",
    "dino://rec-reveal/deliv42",
    "rec_announcement_body", "rec_announcement_title", "tokXYZ",
  ].sort());
  assert.equal(m.apns.payload.aps.category, REC_ANNOUNCEMENT_CATEGORY);
});

test("deep link is the F4 reveal route", () => {
  assert.equal(recRevealDeepLink("abc"), "dino://rec-reveal/abc");
});

test("token plausibility: bounds and whitespace", () => {
  assert.equal(isPlausiblePushToken("a"), true);
  assert.equal(isPlausiblePushToken("x".repeat(REC_PUSH_TOKEN_MAX_LENGTH)), true);
  assert.equal(isPlausiblePushToken("x".repeat(REC_PUSH_TOKEN_MAX_LENGTH + 1)), false);
  assert.equal(isPlausiblePushToken(""), false);
  assert.equal(isPlausiblePushToken("has space"), false);
  assert.equal(isPlausiblePushToken(undefined), false);
  assert.equal(isPlausiblePushToken(42), false);
});
