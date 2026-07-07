//
// Pure Firecrawl credit-guard logic — no firebase imports, node:test-able.
// The product is free; credits are real money. These guards make overspend
// structurally impossible: a hard per-run source cap, a minimum interval
// between runs (manual triggers included), and a monthly credit tally so
// spend is visible in plain logs.
//

export const REC_MAX_SOURCES_PER_RUN = 25;
export const REC_MIN_RUN_INTERVAL_DAYS = 5;

/** Hard cap: never scrape more than `cap` sources in one run. */
export function capSources<T>(sources: T[], cap = REC_MAX_SOURCES_PER_RUN): { kept: T[]; dropped: number } {
  if (sources.length <= cap) return { kept: sources, dropped: 0 };
  return { kept: sources.slice(0, cap), dropped: sources.length - cap };
}

/**
 * Frequency guard: a run may only start if the previous run started at least
 * `minIntervalDays` ago (or never). Applies to scheduled AND manual triggers —
 * a duplicated scheduler job, an accidental manual run, or a retry storm can
 * never double-spend.
 */
export function shouldRun(lastRunAtMs: number | null, nowMs: number,
                          minIntervalDays = REC_MIN_RUN_INTERVAL_DAYS): boolean {
  if (lastRunAtMs === null) return true;
  return nowMs - lastRunAtMs >= minIntervalDays * 24 * 3600 * 1000;
}

/** "2026-07" — the monthly credit-counter key (UTC). */
export function monthKey(d: Date): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

/** The one-line budget log emitted by every completed run. */
export function creditSummary(scraped: number, monthTotal: number): string {
  return `rec pool: scraped ${scraped} sources, ~${scraped} credits, this month total ~${monthTotal}`;
}
