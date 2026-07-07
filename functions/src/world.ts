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
