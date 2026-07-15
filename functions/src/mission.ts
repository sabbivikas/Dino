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

/** Validate one raw mission result against every rule. The url must be one
 *  the mission ACTUALLY SAW (search result or read page) — an invented url
 *  never survives. Returns null on any violation: silence, never a broken
 *  gift. */
export function validateGift(raw: unknown, seenUrls: string[]): Gift | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const ALLOWED = ["title", "source", "excerpt", "url", "whyOneLine"];
  for (const k of Object.keys(r)) {
    if (!ALLOWED.includes(k)) return null;
  }
  const title = clean(r.title, 80);
  const source = clean(r.source, 60);
  const excerpt = clean(r.excerpt, 280);
  const whyOneLine = clean(r.whyOneLine, 120);
  const url = String(r.url ?? "").trim();
  if (!title || !source || !excerpt || !whyOneLine) return null;
  if (excerpt.split(/\s+/).length > 40) return null;          // copyright: short excerpt only
  if (whyOneLine.split(/\s+/).length > 14) return null;
  if (!url.startsWith("https://")) return null;
  if (!seenUrls.includes(url)) return null;                    // must be a url the mission really visited
  const combined = `${title} ${source} ${excerpt} ${whyOneLine}`;
  for (const term of GIFT_BLOCK_TERMS) {
    if (combined.includes(term)) return null;                  // gentleness net
  }
  return { title, source, excerpt, url, whyOneLine };
}
