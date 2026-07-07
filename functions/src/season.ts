//
// Pure season logic for gentle recommendations — no firebase imports, so the
// node:test suite can load it without initializing the admin SDK.
//
// Meteorological northern-hemisphere mapping for now.
// TODO(phase 2): southern-hemisphere users see inverted seasons — once the
// location opt-in lands, flip the mapping by hemisphere.
//

export type RecSeason = "spring" | "summer" | "autumn" | "winter";

export const REC_SEASON_VALUES = ["any", "spring", "summer", "autumn", "winter"];

/** month is 1-12 */
export function seasonForMonth(month: number): RecSeason {
  if (month === 12 || month === 1 || month === 2) return "winter";
  if (month >= 3 && month <= 5) return "spring";
  if (month >= 6 && month <= 8) return "summer";
  return "autumn";
}

/** "any" is always eligible; a tagged season only in its season. */
export function isSeasonEligible(itemSeason: string, current: RecSeason): boolean {
  return itemSeason === "any" || itemSeason === current;
}

/** Rotating seasonal source slots scrape only in their months (1-12). */
export function isSlotActive(months: number[], month: number): boolean {
  return months.includes(month);
}
