// recDelivery.ts — rec delivery arc F2: the timing policy for held comfort
// recs, as PURE functions (no firebase imports — node --test runs these
// directly). index.ts wires them to firestore.
//
// The policy, composed in this order (computeDeliverAfter / decideSweep):
//   1. HOLD    — a rec generated at mood-log time waits 45..90 random
//               minutes before it may be announced.
//   2. QUIET   — no announcement lands between 21:30 and 08:30 in the
//               USER'S LOCAL time (tz from the presence heartbeat). A
//               quiet-hours hit moves to the next 08:30 local, plus a
//               0..30 min jitter so pushed deliveries never herd.
//   3. CAP     — max ONE announcement per user per local day. A blocked
//               day moves to the NEXT local day's first slot (08:30 +
//               jitter), which is quiet-safe by construction.
//   4. SESSION — the sweep never announces into an active app session
//               (lastActiveAt within 3 min); it re-randomizes 15..30 min
//               later instead, re-pushed through QUIET.
// The sweep re-checks QUIET and CAP at announce time too (tz may have
// changed since scheduling), so quiet hours hold even against stale math.
//
// Timezone math uses Intl only (no deps). DST is handled by iterating the
// local→utc guess against the observed offset; 08:30 never sits inside a
// DST gap in any real zone, so the fixed point converges.

export const HOLD_MIN_MINUTES = 45;
export const HOLD_MAX_MINUTES = 90;
export const QUIET_START_MINUTES = 21 * 60 + 30;   // 21:30 local, inclusive
export const QUIET_END_MINUTES = 8 * 60 + 30;      // 08:30 local, exclusive
export const MORNING_JITTER_MAX_MINUTES = 30;      // anti-herd after a push
export const SESSION_ACTIVE_WINDOW_MS = 3 * 60 * 1000;
export const RESCHEDULE_MIN_MINUTES = 15;
export const RESCHEDULE_MAX_MINUTES = 30;
export const HELD_EXPIRY_MS = 72 * 3600 * 1000;    // a rec 3 days stale is a new day's problem
export const ANNOUNCED_EXPIRY_MS = 72 * 3600 * 1000; // an announced knock unanswered 3 days retires
// The content payload's server-side backstop TTL. The delete paths (open
// trigger + expiry sweep) reap it first; this only ever catches a payload
// those paths missed. Sized as ~2x the worst-case lifecycle: a payload can
// legitimately live HELD_EXPIRY_MS (up to 72h held) + ANNOUNCED_EXPIRY_MS
// (up to 72h announced-before-ignored) ~= 6 days, so 7 leaves almost no
// margin and could race a slow-to-open gift near the boundary; 14 never
// cuts off a claimable gift and only reaps genuinely-orphaned payloads.
export const PAYLOAD_RETENTION_DAYS = 14;           // client sees nothing; server-only backstop
export const SWEEP_BATCH_LIMIT = 200;

export const DELIVERY_STATUSES = ["held", "announced", "opened", "expired"] as const;
export type DeliveryStatus = (typeof DELIVERY_STATUSES)[number];

const MINUTE_MS = 60_000;
const DAY_MS = 24 * 3600 * 1000;

/** IANA zone the runtime actually knows; anything else falls back upstream. */
export function isValidTz(tz: unknown): tz is string {
  if (typeof tz !== "string" || tz.length === 0 || tz.length > 64) return false;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

interface LocalParts { year: number; month: number; day: number; hour: number; minute: number }

function localParts(ms: number, tz: string): LocalParts {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, hourCycle: "h23",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit",
  });
  const parts: Record<string, string> = {};
  for (const p of dtf.formatToParts(ms)) parts[p.type] = p.value;
  return {
    year: Number(parts.year), month: Number(parts.month), day: Number(parts.day),
    hour: Number(parts.hour) % 24, minute: Number(parts.minute),
  };
}

/** yyyy-MM-dd of the instant in the user's zone. */
export function localDayKey(ms: number, tz: string): string {
  const p = localParts(ms, tz);
  const mm = String(p.month).padStart(2, "0");
  const dd = String(p.day).padStart(2, "0");
  return `${p.year}-${mm}-${dd}`;
}

export function localMinutesOfDay(ms: number, tz: string): number {
  const p = localParts(ms, tz);
  return p.hour * 60 + p.minute;
}

/** 21:30 (inclusive) through 08:30 (exclusive), user-local. */
export function isQuietHours(ms: number, tz: string): boolean {
  const mod = localMinutesOfDay(ms, tz);
  return mod >= QUIET_START_MINUTES || mod < QUIET_END_MINUTES;
}

/** The UTC instant of a wall-clock time in tz (DST-aware fixed point). */
export function localTimeToUtcMs(
  year: number, month: number, day: number, hour: number, minute: number, tz: string
): number {
  const want = Date.UTC(year, month - 1, day, hour, minute);
  let guess = want;
  for (let i = 0; i < 3; i++) {
    const p = localParts(guess, tz);
    const have = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute);
    if (have === want) return guess;
    guess += want - have;
  }
  return guess;
}

/** The next quiet-hours exit (08:30 local) at or after ms. */
export function nextQuietExit(ms: number, tz: string): number {
  let anchor = ms;
  for (let i = 0; i < 4; i++) {
    const p = localParts(anchor, tz);
    const target = localTimeToUtcMs(p.year, p.month, p.day, 8, 30, tz);
    if (target >= ms) return target;
    anchor += DAY_MS;   // same local day's 08:30 already passed → next day
  }
  return anchor;   // unreachable in practice
}

/** Identity outside quiet hours; next 08:30 local (+ jitter) inside them. */
export function pushOutOfQuietHours(ms: number, tz: string, jitterMinutes = 0): number {
  if (!isQuietHours(ms, tz)) return ms;
  return nextQuietExit(ms, tz) + jitterMinutes * MINUTE_MS;
}

/** First allowed slot of the NEXT local day: 08:30 + jitter (quiet-safe). */
export function nextDayFirstSlot(ms: number, tz: string, jitterMinutes = 0): number {
  const todayKey = localDayKey(ms, tz);
  let anchor = ms;
  for (let i = 0; i < 3 && localDayKey(anchor, tz) === todayKey; i++) {
    anchor += DAY_MS;
  }
  const p = localParts(anchor, tz);
  return localTimeToUtcMs(p.year, p.month, p.day, 8, 30, tz) + jitterMinutes * MINUTE_MS;
}

/** Never a second announcement on a blocked local day — walk forward. */
export function applyDailyCap(
  ms: number, tz: string, blockedDayKeys: ReadonlySet<string>, jitterMinutes = 0
): number {
  let t = ms;
  for (let i = 0; i < 8 && blockedDayKeys.has(localDayKey(t, tz)); i++) {
    t = nextDayFirstSlot(t, tz, jitterMinutes);
  }
  return t;
}

/** Uniform 45..90 whole minutes. */
export function holdDelayMinutes(rand: () => number = Math.random): number {
  return HOLD_MIN_MINUTES + Math.floor(rand() * (HOLD_MAX_MINUTES - HOLD_MIN_MINUTES + 1));
}

/** Uniform 15..30 whole minutes (session-active back-off). */
export function rescheduleDelayMinutes(rand: () => number = Math.random): number {
  return RESCHEDULE_MIN_MINUTES + Math.floor(rand() * (RESCHEDULE_MAX_MINUTES - RESCHEDULE_MIN_MINUTES + 1));
}

function jitterMinutes(rand: () => number): number {
  return Math.floor(rand() * (MORNING_JITTER_MAX_MINUTES + 1));
}

/**
 * The full creation-time composition. rand is drawn twice, in order:
 * hold delay first, morning jitter second (tests inject a sequence).
 */
export function computeDeliverAfter(
  createdAtMs: number, tz: string, blockedDayKeys: ReadonlySet<string>,
  rand: () => number = Math.random
): number {
  const held = createdAtMs + holdDelayMinutes(rand) * MINUTE_MS;
  const jitter = jitterMinutes(rand);
  const daylit = pushOutOfQuietHours(held, tz, jitter);
  return applyDailyCap(daylit, tz, blockedDayKeys, jitter);
}

/**
 * F6 — the IGNORED knock-timing signal. An announcement the user never
 * opened, stale past 72h (measured from announcedAt, the moment the knock
 * landed), retires: the delivery flips announced → expired and its
 * announcement outcome flips shown → ignored ("the knock went unanswered").
 * Only announced docs qualify — a never-announced held expiry was never a
 * knock, so it emits no ignored signal.
 */
export function shouldExpireAnnounced(
  status: string, announcedAtMs: number | null, nowMs: number
): boolean {
  return status === "announced" && announcedAtMs !== null
    && nowMs - announcedAtMs >= ANNOUNCED_EXPIRY_MS;
}

/**
 * The content payload must not persist. It is deleted on open (the server
 * trigger below) and on expiry (the sweep), but the delete that matters is
 * the transition INTO 'opened': the client can never delete a payload under
 * the rules, so the server watches the status flip and purges the sibling
 * content doc. True only on a genuine transition into 'opened' — announce,
 * reschedule, an openedAt-only touch, or a re-write of an already-'opened'
 * doc all no-op, so the trigger stays cheap.
 */
export function shouldDeletePayloadOnTransition(
  beforeStatus: string, afterStatus: string
): boolean {
  return beforeStatus !== "opened" && afterStatus === "opened";
}

/**
 * The payload's backstop-TTL instant: nowMs + PAYLOAD_RETENTION_DAYS. Wired
 * into the create-time write (expiresAt) so an orphaned payload the delete
 * paths missed still self-reaps once the owner enables the Firestore TTL
 * policy on the payloads collection group (field expiresAt) in the console.
 */
export function payloadExpiresAtMs(nowMs: number): number {
  return nowMs + PAYLOAD_RETENTION_DAYS * DAY_MS;
}

/** Active = a heartbeat within the last 3 min (a future stamp counts too). */
export function isSessionActive(lastActiveAtMs: number | null, nowMs: number): boolean {
  if (lastActiveAtMs === null) return false;
  return nowMs - lastActiveAtMs < SESSION_ACTIVE_WINDOW_MS;
}

export type Daypart = "morning" | "afternoon" | "evening" | "night";

/** Same boundaries as the client's OutcomeLedger.daypart (one vocabulary). */
export function daypartFor(ms: number, tz: string): Daypart {
  const h = localParts(ms, tz).hour;
  if (h >= 5 && h <= 11) return "morning";
  if (h >= 12 && h <= 16) return "afternoon";
  if (h >= 17 && h <= 21) return "evening";
  return "night";
}

export interface SweepInput {
  status: string;
  createdAtMs: number;
  deliverAfterMs: number;
  tz: string;
  nowMs: number;
  lastActiveAtMs: number | null;
  lastAnnouncedDayKey: string | null;
}

export type SweepDecision =
  | { action: "skip" }
  | { action: "expire" }
  | { action: "reschedule"; deliverAfterMs: number; reason: "session" | "cap" | "quiet" }
  | { action: "announce"; dayKey: string };

/**
 * One due delivery → one decision. Runs INSIDE the sweep transaction, so
 * the status check makes announcing idempotent: a re-read doc that is no
 * longer 'held' is a skip, never a second announcement.
 */
export function decideSweep(input: SweepInput, rand: () => number = Math.random): SweepDecision {
  if (input.status !== "held") return { action: "skip" };           // idempotency gate
  if (input.deliverAfterMs > input.nowMs) return { action: "skip" };
  if (input.nowMs - input.createdAtMs > HELD_EXPIRY_MS) return { action: "expire" };
  if (isSessionActive(input.lastActiveAtMs, input.nowMs)) {
    const backedOff = input.nowMs + rescheduleDelayMinutes(rand) * MINUTE_MS;
    return {
      action: "reschedule",
      deliverAfterMs: pushOutOfQuietHours(backedOff, input.tz, jitterMinutes(rand)),
      reason: "session",
    };
  }
  const todayKey = localDayKey(input.nowMs, input.tz);
  if (input.lastAnnouncedDayKey === todayKey) {
    return {
      action: "reschedule",
      deliverAfterMs: nextDayFirstSlot(input.nowMs, input.tz, jitterMinutes(rand)),
      reason: "cap",
    };
  }
  // Announce-time quiet guard: deliverAfter may have been computed against
  // a stale tz, or the sweep tick may land a hair inside the window.
  if (isQuietHours(input.nowMs, input.tz)) {
    return {
      action: "reschedule",
      deliverAfterMs: pushOutOfQuietHours(input.nowMs, input.tz, jitterMinutes(rand)),
      reason: "quiet",
    };
  }
  return { action: "announce", dayKey: todayKey };
}

// ---------------------------------------------------------------------------
// F4 — the reveal's poster path (film only). TMDB's search result carries a
// poster_path like "/abc123.jpg"; anything not exactly that shape is dropped.
// The payload then either carries a safe path or nothing — the client renders
// its paper-only card on nothing, never a broken image.
export function posterPathOrNull(p: unknown): string | null {
  if (typeof p !== "string") return null;
  if (!/^\/[A-Za-z0-9._-]{1,95}\.(jpg|png)$/.test(p)) return null;
  return p;
}
