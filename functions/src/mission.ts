//
// mission.ts — the pure heart of an expedition mission (F2): gift shape
// validation and the gentleness net. No network, no secrets — node tested.
// Discipline mirrors generateComfortRecs: allowlisted fields, capped
// lengths, lowercase, no dashes, and ANY invalid field = null = silence.
//

export type Gift = {
  title: string;
  source: string;
  excerpt: string;
  url: string;
  whyOneLine: string;
};

// same spirit as the recs clinical ban + the crisis nets: comfort is escape
// and warmth. any of these in any field kills the gift quietly.
const GIFT_BLOCK_TERMS = [
  "suicide", "self harm", "depression", "depressed", "anxiety", "anxious",
  "therapy", "therapist", "trauma", "grief", "mourning", "death", "died",
  "dying", "killed", "killing", "murder", "war", "shooting", "violence",
  "cancer", "diagnosis", "disease", "abuse", "overdose", "crisis",
  "paywall", "subscribe to read", "mental illness", "self help",
];

function clean(s: unknown, cap: number): string {
  return String(s ?? "")
    .toLowerCase()
    .replace(/[–—-]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, cap);
}

// ── Trusted sources per needKind — the expedition looks HERE FIRST —─────
// small human stories and the living world over the institutional and the
// abstract. connection shares hope's human warmth pool; rest gets calm,
// human scale long form homes.
export const TRUSTED_SOURCES: Record<string, string[]> = {
  hope:       ["goodnewsnetwork.org", "positive.news", "reasonstobecheerful.world", "happyeconews.com"],
  connection: ["positive.news", "goodnewsnetwork.org", "reasonstobecheerful.world", "happyeconews.com"],
  beauty:     ["poetryfoundation.org", "poets.org", "themarginalian.org"],
  wonder:     ["atlasobscura.com", "apod.nasa.gov", "nationalgeographic.com", "bbc.com"],
  rest:       ["themarginalian.org", "emergencemagazine.org", "orionmagazine.org", "atlasobscura.com"],
};

/** Trusted sources for a needKind, rotated: sources NOT recently used for
 *  this user come first, so gifts don't get samey. Pure. */
export function trustedSourcesFor(needKind: string, recentlyUsed: string[]): string[] {
  const base = TRUSTED_SOURCES[needKind] ?? TRUSTED_SOURCES.hope;
  const fresh = base.filter((s) => !recentlyUsed.includes(s));
  const used = base.filter((s) => recentlyUsed.includes(s));
  return [...fresh, ...used];
}

export type GiftCheck = {
  gift: Gift | null;
  /** "shape" failures may fall back to another model; "gentle" failures
   *  NEVER do — a bad gift does not get a second chance at being bad. */
  reason: "ok" | "shape" | "gentle";
};

/** Validate one raw mission result against every rule. The url must be one
 *  the mission ACTUALLY SAW (search result or read page) — an invented url
 *  never survives. */
export function validateGiftWithReason(raw: unknown, seenUrls: string[]): GiftCheck {
  const shape: GiftCheck = { gift: null, reason: "shape" };
  if (typeof raw !== "object" || raw === null) return shape;
  const r = raw as Record<string, unknown>;
  const ALLOWED = ["title", "source", "excerpt", "url", "whyOneLine"];
  for (const k of Object.keys(r)) {
    if (!ALLOWED.includes(k)) return shape;
  }
  const title = clean(r.title, 80);
  const source = clean(r.source, 60);
  const excerpt = clean(r.excerpt, 280);
  const whyOneLine = clean(r.whyOneLine, 120);
  const url = String(r.url ?? "").trim();
  if (!title || !source || !excerpt || !whyOneLine) return shape;
  if (excerpt.split(/\s+/).length > 40) return shape;          // copyright: short excerpt only
  if (whyOneLine.split(/\s+/).length > 14) return shape;
  if (!url.startsWith("https://")) return shape;
  if (!seenUrls.includes(url)) return shape;                   // must be a url the mission really visited
  const combined = `${title} ${source} ${excerpt} ${whyOneLine}`;
  for (const term of GIFT_BLOCK_TERMS) {
    if (combined.includes(term)) return { gift: null, reason: "gentle" };   // gentleness net — final
  }
  return { gift: { title, source, excerpt, url, whyOneLine }, reason: "ok" };
}

/** Back compat shim — same contract as before (null on any violation). */
export function validateGift(raw: unknown, seenUrls: string[]): Gift | null {
  return validateGiftWithReason(raw, seenUrls).gift;
}
