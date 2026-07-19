// outcomes.ts — rec delivery arc F6: the announcement (knock-timing) outcome
// vocabulary, as PURE functions (no firebase imports — node --test runs these
// directly). index.ts wires them to firestore; the sweep is the only writer of
// SHOWN and IGNORED, so those signals are server-authored and un-forgeable.
//
// WHY A SEPARATE 'announcement' KIND (not a facet on the rec outcome): the
// knock is a different event from the reveal. The rec outcome (kind:'rec')
// records what was brought and what happened to the REC; the announcement
// outcome records the KNOCK — was it answered, and in which daypart. Folding
// them would conflate "the rec was revealed" with "the knock was sent". A
// distinct kind keeps each lifecycle clean and drops straight into the
// distiller's existing enum-tuple read shape
// (kind|itemType|moodContext|daypart|action|followupTrend).
//
// THE PRIVACY CONTRACT, AS DATA: an announcement outcome carries ONLY enum
// buckets (+ server timestamps). itemType is a fixed 'parcel' — the knock
// itself, never its contents — so no title, link, id, or free text can ride
// this channel. buildAnnouncementOutcome returns null on any off-enum input
// (the caller then writes NOTHING — never a partial or widened doc), exactly
// the discipline validatePrefs uses on the way out.

export const ANNOUNCEMENT_KIND = "announcement";
export const ANNOUNCEMENT_ITEM_TYPE = "parcel";       // the knock, not its contents
export const ANNOUNCEMENT_ACTIONS = ["shown", "opened", "ignored"] as const;
export const OUTCOME_DAYPARTS = ["morning", "afternoon", "evening", "night"] as const;
export const ANNOUNCEMENT_MOOD_CONTEXT = "none";      // a knock carries no mood bucket
export const ANNOUNCEMENT_ID_PREFIX = "ann_";
export const OUTCOME_RETENTION_DAYS = 365;            // client OutcomeLedger.retentionDays twin

export type AnnouncementAction = (typeof ANNOUNCEMENT_ACTIONS)[number];
export type OutcomeDaypart = (typeof OUTCOME_DAYPARTS)[number];

/**
 * The enum-only body of an announcement outcome. All three parties (the
 * announce write, the reveal's opened flip, the expiry's ignored flip) key
 * the SAME doc off this deterministic id, so the knock's lifecycle lives in
 * one place and re-fires collapse (dedupe by identity).
 */
export function announcementOutcomeId(deliveryId: string): string {
  return ANNOUNCEMENT_ID_PREFIX + deliveryId;
}

export function isOutcomeDaypart(v: unknown): v is OutcomeDaypart {
  return typeof v === "string" && (OUTCOME_DAYPARTS as readonly string[]).includes(v);
}

export function isAnnouncementAction(v: unknown): v is AnnouncementAction {
  return typeof v === "string" && (ANNOUNCEMENT_ACTIONS as readonly string[]).includes(v);
}

export type AnnouncementOutcomeBody = {
  kind: string;
  itemType: string;
  moodContext: string;
  daypart: string;
  action: string;
  needsFollowup: boolean;
};

/**
 * Build the enum-only announcement outcome body (the caller adds the server
 * timestamps shownAt / expiresAt / actionAt). Returns null on a bad daypart
 * or action — off-enum in means NOTHING written, never a partial doc.
 *
 * needsFollowup is ALWAYS false: a knock never rides the client's mood
 * followup sweep (that sweep queries needsFollowup==true). Knock timing is a
 * daypart signal, not a mood-trend one.
 */
export function buildAnnouncementOutcome(
  action: AnnouncementAction, daypart: string
): AnnouncementOutcomeBody | null {
  if (!isAnnouncementAction(action)) return null;
  if (!isOutcomeDaypart(daypart)) return null;
  return {
    kind: ANNOUNCEMENT_KIND,
    itemType: ANNOUNCEMENT_ITEM_TYPE,
    moodContext: ANNOUNCEMENT_MOOD_CONTEXT,
    daypart,
    action,
    needsFollowup: false,
  };
}

/**
 * The COMPLETE set of keys an announcement outcome may ever carry — enum
 * buckets plus server timestamps, nothing else. The privacy proof asserts a
 * built doc is a subset of this: there is structurally no place for a title,
 * a link, a rec id, a source domain, or any free text on this channel.
 */
export const ANNOUNCEMENT_OUTCOME_KEYS = [
  "kind", "itemType", "moodContext", "daypart", "action",
  "needsFollowup", "shownAt", "expiresAt", "actionAt",
] as const;
