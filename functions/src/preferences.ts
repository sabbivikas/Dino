// Preference distillation (memory + shelf arc F2) — pure module so node
// tests hit it directly (same pattern as mission.ts / crisisNet.ts).
//
// The distiller reads a user's outcome ledger (ENUM BUCKETS ONLY — the
// ledger never contains content) and writes a small preference doc, also
// enum-only. Everything the model returns is clamped against allowlists;
// off-shape output means NO doc write, never a partial one.

export const PREF_REC_TYPES = ["music", "book", "film"];
export const PREF_GIFT_NEEDS = ["rest", "beauty", "hope", "wonder", "connection"];
export const PREF_DAYPARTS = ["morning", "afternoon", "evening", "night", "unknown"];
// F6 (rec delivery) distiller-facing note — NO behavior change here. The
// ledger now also carries KNOCK-TIMING signals: kind:"announcement" entries
// (itemType:"parcel", action ∈ shown|opened|ignored) each stamped with the
// daypart the knock landed in. A future distiller can group those by daypart
// to learn which knock time earns opens vs ignores — refining bestDaypart
// from the announcement lifecycle specifically (today bestDaypart is derived
// across ALL entries). buildDistillerInput already serializes them as ordinary
// enum tuples (announcement|parcel|none|<daypart>|<action>|unknown); the
// consumer that acts on them is a separate task.
export const PREF_FATIGUE = ["none", "mild", "high"];
export const PREF_MIN_OUTCOMES = 8;      // enough signal to say anything real
export const PREF_MAX_ENTRIES = 200;     // ledger retention cap (prune target)
export const PREF_MAX_AVOID_DOMAINS = 4;

export type LedgerEntry = {
  kind: string; itemType: string; sourceDomain?: string;
  moodContext: string; daypart: string; action: string;
  followupTrend?: string;
};

export type PreferenceDoc = {
  recTypesLanding: string[]; recTypesIgnored: string[];
  needKindsLanding: string[]; needKindsIgnored: string[];
  avoidDomains: string[];
  bestDaypart: string;
  giftFatigue: string;
  basedOnCount: number;
};

export const DISTILLER_PROMPT =
  "you are a quiet classifier. you receive a list of outcome records — small " +
  "enum tuples describing things a wellness companion brought a user and what " +
  "happened to each. distill them into preference buckets. respond with ONLY " +
  "a json object: {\"recTypesLanding\": [], \"recTypesIgnored\": [], " +
  "\"needKindsLanding\": [], \"needKindsIgnored\": [], \"avoidDomains\": [], " +
  "\"bestDaypart\": \"\", \"giftFatigue\": \"\"}. " +
  "landing means kept/opened/lateKept clearly outweigh ignores for that bucket; " +
  "ignored means the reverse, with at least 3 records of evidence. " +
  "avoidDomains: domains whose gifts were repeatedly ignored (max 4). " +
  "bestDaypart: the daypart where things land most, or unknown. " +
  "giftFatigue: none/mild/high from the recent gift ignore ratio. " +
  "when evidence is thin, leave lists empty and values unknown/none — " +
  "an empty answer is better than a guess.";

/** Compact enum lines — the only thing the model ever sees. */
export function buildDistillerInput(entries: LedgerEntry[]): string {
  return entries.map((e) => {
    const parts = [e.kind, e.itemType, e.moodContext, e.daypart, e.action,
                   e.followupTrend ?? "unknown"];
    if (e.sourceDomain) parts.push(e.sourceDomain);
    return parts.join("|");
  }).join("\n");
}

/** Clamp the model's output against the allowlists AND the user's own
 *  ledger (avoidDomains may only name domains that appear there). Returns
 *  null when the shape is wrong — the caller writes nothing. */
export function validatePrefs(parsed: unknown, entries: LedgerEntry[]): PreferenceDoc | null {
  if (typeof parsed !== "object" || parsed === null) return null;
  const p = parsed as Record<string, unknown>;
  const list = (v: unknown, allow: string[]): string[] | null => {
    if (v === undefined || v === null) return [];
    if (!Array.isArray(v)) return null;
    const out = v.filter((x): x is string => typeof x === "string" && allow.includes(x));
    return [...new Set(out)];
  };
  const recLanding = list(p.recTypesLanding, PREF_REC_TYPES);
  const recIgnored = list(p.recTypesIgnored, PREF_REC_TYPES);
  const needLanding = list(p.needKindsLanding, PREF_GIFT_NEEDS);
  const needIgnored = list(p.needKindsIgnored, PREF_GIFT_NEEDS);
  if (recLanding === null || recIgnored === null || needLanding === null || needIgnored === null) return null;

  const ledgerDomains = new Set(entries.map((e) => e.sourceDomain).filter(Boolean));
  let avoid: string[] = [];
  if (Array.isArray(p.avoidDomains)) {
    avoid = p.avoidDomains
      .filter((d): d is string => typeof d === "string" && ledgerDomains.has(d))
      .slice(0, PREF_MAX_AVOID_DOMAINS);
  } else if (p.avoidDomains !== undefined && p.avoidDomains !== null) {
    return null;
  }

  const bestDaypart = typeof p.bestDaypart === "string" && PREF_DAYPARTS.includes(p.bestDaypart)
    ? p.bestDaypart : "unknown";
  const giftFatigue = typeof p.giftFatigue === "string" && PREF_FATIGUE.includes(p.giftFatigue)
    ? p.giftFatigue : "none";

  return {
    recTypesLanding: recLanding, recTypesIgnored: recIgnored,
    needKindsLanding: needLanding, needKindsIgnored: needIgnored,
    avoidDomains: avoid, bestDaypart, giftFatigue,
    basedOnCount: entries.length,
  };
}
