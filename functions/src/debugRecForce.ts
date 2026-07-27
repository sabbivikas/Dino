// debugRecForce.ts — OWNER-ONLY TestFlight debug trigger (rec delivery arc).
// Pure helpers for the forceRecDeliveryDebug onRequest in index.ts — no
// firebase imports so node --test runs these directly.
//
// THE GATE (fail closed, twice over): the endpoint acts ONLY on the first
// uid in the DEBUG_REC_FORCE_UIDS env allowlist — no uid parameter exists,
// so firing for another account is structurally impossible — and every
// request must carry the DEBUG_REC_FORCE_KEY shared secret. Missing/empty
// env, a short key, or a mismatch all deny.
//
// CADENCE SAFETY: the handler never touches comfortRecLimits (the daily
// counter), never sets lastAnnouncedDayKey, and never writes a SHOWN
// outcome. Docs are marked debug:true so ?cleanup=1 erases them from the
// 30-day announcedAt window the real cooldown/cap reads.

export interface DebugGateResult {
  allowed: boolean;
  uid: string;
}

/** Deny unless the allowlist is non-empty AND the shared key matches. */
export function debugRecForceGate(
  uidsEnv: string | undefined, keyEnv: string | undefined, providedKey: string
): DebugGateResult {
  const uids = String(uidsEnv ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const key = String(keyEnv ?? "");
  if (uids.length === 0 || key.length < 24 || !providedKey || providedKey !== key) {
    return { allowed: false, uid: "" };
  }
  return { allowed: true, uid: uids[0] };
}

/** Held-mode delay: 1..90 minutes, garbage → 1. */
export function clampDelayMinutes(v: unknown): number {
  const n = Number(v);
  if (!Number.isFinite(n)) return 1;
  return Math.min(90, Math.max(1, Math.trunc(n)));
}

// Fixture recs — zero model calls, deterministic, and shaped exactly like
// runComfortRecGeneration's sanitized output (types/flags/feels from the
// allowlists, lowercase, capped lengths; totoro carries a real posterPath so
// the image-led reveal card exercises the tmdb pipeline on TestFlight).
export const DEBUG_REC_FIXTURE_RECS = [
  {
    type: "film", title: "my neighbor totoro", creator: "hayao miyazaki", year: 1988,
    why: "a soft green world where nothing bad happens and the rain is a friend",
    flags: ["not graphic"], feel: "hopeful", length: "about 86 minutes",
    posterPath: "/rtGDOeG9LzoerkDGZF9dnVeLppL.jpg",
  },
  {
    type: "book", title: "the wind in the willows", creator: "kenneth grahame", year: 1908,
    why: "riverbank friendships and picnics that ask nothing of you",
    flags: ["no distressing themes"], feel: "cozy", length: "a slow weekend read",
  },
  {
    type: "music", title: "music for airports", creator: "brian eno", year: 1978,
    why: "air that hums quietly while you set the day down",
    flags: ["a soft one"], feel: "quiet", length: "about 48 minutes",
  },
];
