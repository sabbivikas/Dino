import { test } from "node:test";
import assert from "node:assert";
import {
  ANNOUNCEMENT_KIND, ANNOUNCEMENT_ITEM_TYPE, ANNOUNCEMENT_ACTIONS,
  OUTCOME_DAYPARTS, ANNOUNCEMENT_MOOD_CONTEXT, ANNOUNCEMENT_ID_PREFIX,
  OUTCOME_RETENTION_DAYS, ANNOUNCEMENT_OUTCOME_KEYS,
  announcementOutcomeId, isOutcomeDaypart, isAnnouncementAction,
  buildAnnouncementOutcome,
} from "./outcomes";

// --- F6: the announcement (knock-timing) outcome vocabulary -----------------

test("announcement enum allowlists are closed (client OutcomeLedger twins)", () => {
  assert.equal(ANNOUNCEMENT_KIND, "announcement");
  assert.equal(ANNOUNCEMENT_ITEM_TYPE, "parcel");
  assert.deepEqual([...ANNOUNCEMENT_ACTIONS], ["shown", "opened", "ignored"]);
  assert.deepEqual([...OUTCOME_DAYPARTS], ["morning", "afternoon", "evening", "night"]);
  assert.equal(ANNOUNCEMENT_MOOD_CONTEXT, "none");
  assert.equal(OUTCOME_RETENTION_DAYS, 365);
});

test("announcementOutcomeId is deterministic (dedupe by identity)", () => {
  assert.equal(announcementOutcomeId("d1"), "ann_d1");
  assert.equal(ANNOUNCEMENT_ID_PREFIX + "d1", announcementOutcomeId("d1"));
  // a push-tap reveal and a shelf-catch reveal of the SAME delivery land on
  // the SAME doc — the open can never be double-recorded
  assert.equal(announcementOutcomeId("d1"), announcementOutcomeId("d1"));
  assert.notEqual(announcementOutcomeId("d1"), announcementOutcomeId("d2"));
});

test("daypart / action guards accept only the allowlist", () => {
  for (const dp of OUTCOME_DAYPARTS) assert.ok(isOutcomeDaypart(dp));
  assert.ok(!isOutcomeDaypart("dawn"));
  assert.ok(!isOutcomeDaypart(undefined));
  assert.ok(!isOutcomeDaypart(3));
  for (const a of ANNOUNCEMENT_ACTIONS) assert.ok(isAnnouncementAction(a));
  assert.ok(!isAnnouncementAction("kept"));      // a rec/gift action, not a knock action
  assert.ok(!isAnnouncementAction("notTonight"));
  assert.ok(!isAnnouncementAction(null));
});

test("buildAnnouncementOutcome carries the daypart on each action", () => {
  for (const action of ANNOUNCEMENT_ACTIONS) {
    for (const daypart of OUTCOME_DAYPARTS) {
      const doc = buildAnnouncementOutcome(action, daypart);
      assert.ok(doc, `built ${action}/${daypart}`);
      assert.equal(doc!.kind, "announcement");
      assert.equal(doc!.itemType, "parcel");
      assert.equal(doc!.moodContext, "none");
      assert.equal(doc!.daypart, daypart);          // DAYPART travels with each
      assert.equal(doc!.action, action);
      assert.equal(doc!.needsFollowup, false);       // a knock never mood-followups
    }
  }
});

test("buildAnnouncementOutcome rejects off-enum input (writes NOTHING)", () => {
  assert.equal(buildAnnouncementOutcome("shown", "dawn"), null);
  assert.equal(buildAnnouncementOutcome("shown", ""), null);
  // a bad action (cast past the type) is rejected too
  assert.equal(buildAnnouncementOutcome("kept" as never, "evening"), null);
  assert.equal(buildAnnouncementOutcome("" as never, "evening"), null);
});

test("PRIVACY: a built announcement outcome carries only enum + timestamp keys", () => {
  const doc = buildAnnouncementOutcome("shown", "evening")!;
  // every key of the built body is in the closed allowlist — no room for a
  // title, link, rec id, source domain, or any free text on this channel
  for (const k of Object.keys(doc)) {
    assert.ok((ANNOUNCEMENT_OUTCOME_KEYS as readonly string[]).includes(k),
      `unexpected key on announcement outcome: ${k}`);
  }
  // and explicitly: none of the content-shaped keys ever appear
  for (const forbidden of ["title", "link", "url", "recId", "deliveryId",
                           "sourceDomain", "text", "creator"]) {
    assert.ok(!(forbidden in doc), `forbidden key present: ${forbidden}`);
  }
  // the only string values are the fixed enums — no dynamic content leaks
  assert.deepEqual(
    Object.values(doc).filter((v) => typeof v === "string").sort(),
    ["announcement", "evening", "none", "parcel", "shown"].sort());
});
