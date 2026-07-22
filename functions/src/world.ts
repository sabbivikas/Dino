//
// Pure DINO WORLD logic — no firebase imports, so the node:test suite can
// load it without initializing the admin SDK.
//

// Privacy floor: countries with fewer logs than this per day fold into
// "elsewhere" in the aggregate AND in live pulses. Lowered 5 → 3 while
// adoption ramps (user-approved 2026-07-07); revisit upward at scale.
export const WORLD_PRIVACY_FLOOR = 3;

export const WORLD_MOOD_VALUES = ["clear", "partlyCloudy", "overwhelmed", "drained"];

/** ISO-3166 alpha-2 uppercase, anything else is "elsewhere". */
export function normalizeCountry(raw: unknown): string {
  const c = String(raw ?? "").toUpperCase();
  return /^[A-Z]{2}$/.test(c) ? c : "elsewhere";
}

/**
 * A live pulse may name a country ONLY when the public aggregate already
 * shows it (i.e. it cleared the privacy floor today). A single real-time
 * event must never single out a country the aggregate deliberately hides.
 */
export function foldPulseCountry(country: string, aggregateHasCountry: boolean): string {
  if (country === "elsewhere") return "elsewhere";
  return aggregateHasCountry ? country : "elsewhere";
}

// ---------------------------------------------------------------------------
// UTC-Gregorian day semantics. The client's dayKey field can be corrupted by
// device calendars (a Thai device's .current calendar wrote Buddhist-year
// "2569-…" keys), so the SERVER createdAt timestamp is the only day
// authority for aggregation, retention, and sorting.
// ---------------------------------------------------------------------------

/** UTC-Gregorian day key ("yyyy-MM-dd") for a moment — the world's shared day. */
export function utcDayKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/**
 * Year-sanity filter for an aggregate `days` map: keeps only well-formed
 * "yyyy-MM-dd" keys whose year is within [currentUTCYear-1, currentUTCYear+1].
 * This is the auto-purge — corrupted device-calendar keys ("2569-…") stored
 * by pre-fix runs sort lexically AFTER every real day, so they could never
 * age out of the newest-7 retention; applying this to the MERGED map before
 * the retention sort drops them on the first run.
 */
export function sanitizeAggregateDayKeys<T>(days: Record<string, T>, nowMs: number): Record<string, T> {
  const currentYear = new Date(nowMs).getUTCFullYear();
  const out: Record<string, T> = {};
  for (const [key, value] of Object.entries(days)) {
    const m = /^(\d{4})-\d{2}-\d{2}$/.exec(key);
    if (!m) continue;
    const year = Number(m[1]);
    if (year < currentYear - 1 || year > currentYear + 1) continue;
    out[key] = value;
  }
  return out;
}

/** Newest-`limit` dayKeys (lexicographic == chronological for yyyy-MM-dd). */
export function retainNewestDays<T>(days: Record<string, T>, limit: number): Record<string, T> {
  const keep = Object.keys(days).sort().slice(-limit);
  const out: Record<string, T> = {};
  for (const k of keep) out[k] = days[k];
  return out;
}

/**
 * Groups raw worldMood docs by SERVER createdAt (UTC-Gregorian day) →
 * country → mood → count. The doc's own dayKey field is intentionally
 * ignored (see above); docs without a usable createdAt are skipped.
 */
export function groupWorldMoodDocs(
  docs: Array<Record<string, unknown>>
): Record<string, Record<string, Record<string, number>>> {
  const grouped: Record<string, Record<string, Record<string, number>>> = {};
  for (const d of docs) {
    const mood = String(d.mood ?? "");
    if (!WORLD_MOOD_VALUES.includes(mood)) continue;
    const createdAt = d.createdAt as { toDate?: () => Date } | null | undefined;
    if (!createdAt || typeof createdAt.toDate !== "function") continue;
    const dayKey = utcDayKey(createdAt.toDate());
    const country = normalizeCountry(d.countryCode);
    grouped[dayKey] ??= {};
    grouped[dayKey][country] ??= {};
    grouped[dayKey][country][mood] = (grouped[dayKey][country][mood] ?? 0) + 1;
  }
  return grouped;
}
