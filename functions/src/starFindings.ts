// starFindings.ts — EXPERIMENTAL "star findings" demo (owner + flag gated).
// PURE module: no firebase imports, no network — so `node --test` runs these
// helpers directly. index.ts wires them to Firestore/FCM and agiClient.ts
// runs the real agent loop that consumes the prompt builders + kill decision.
//
// THE GATE (fail closed): mirrors debugRecForce's env-allowlist shape. The
// STAR_FINDINGS_UIDS env var is the allowlist; the onCall checks the CALLER's
// request.auth.uid against it (membership — there is NO uid parameter, so
// firing for another account is structurally impossible). Missing/empty env,
// or a caller not on the list, denies.
//
// THE 15-STEP KILL: billing is per thinking step, so the agent loop tallies
// THOUGHT messages and kills (cancel + DELETE session) the instant the tally
// reaches MAX_AGENT_STEPS. killDecision is the pure decision the loop calls on
// every poll; the actual cancel/DELETE lives in agiClient.ts.

// ── caps / constants ────────────────────────────────────────────────────────

/**
 * Per-thinking-step kill: the agent is cancelled the instant THOUGHTs hit this.
 *
 * WAS 30. Two production runs both burned the full 30 for zero candidates ($0.60
 * each at the owner's $0.02/step) while sitting on ONE listing page they had
 * already mined by step 15. The converging shape of this prompt finished in 5-6
 * steps, so 15 is twice the budget a good run has ever needed and halves the
 * worst case to $0.30.
 */
export const MAX_AGENT_STEPS = 15;
/** What one thinking step costs the owner, in USD (vendor's per-step rate). */
export const COST_PER_STEP_USD = 0.02;
/**
 * How long a task doc may sit in `searching` before a NEW send is allowed
 * again. The client used to abandon a live run at the callable's ~70s default
 * and invite a second launch — two billed agents for one ask.
 */
export const IN_FLIGHT_WINDOW_MS = 10 * 60 * 1000;
/** Daily task ceiling per uid (the starFindings/{uid} dayKey counter). */
export const MAX_TASKS_PER_DAY = 5;
/** Overall wall-clock ceiling for one agent phase (~6 min), same hard kill. */
export const WALL_CLOCK_MS = 6 * 60 * 1000;
/** The demo is hardcoded to one city (owner decision — English-only demo). */
export const FINDINGS_CITY = "Saint Paul, Minnesota";
/**
 * How much of the agent's raw final message we mirror into ONE log line.
 * Diagnosability only: an `outcome: empty` run is otherwise indistinguishable
 * from "the agent replied with prose that parsed to zero candidates".
 */
export const AGENT_REPLY_LOG_CAP = 1200;

/**
 * What one run cost the owner, in USD. PURE. Unreadable/negative step tallies
 * read as 0 rather than NaN, so a log line can never carry a broken number.
 * Rounded to 4dp so a float tail never lands in a log or a task doc.
 */
export function costForSteps(steps: unknown, perStep: number = COST_PER_STEP_USD): number {
  const n = Number(steps);
  if (!Number.isFinite(n) || n <= 0) return 0;
  const rate = Number.isFinite(perStep) && perStep > 0 ? perStep : COST_PER_STEP_USD;
  return Math.round(n * rate * 10000) / 10000;
}

/**
 * Is the caller's most recent task still a LIVE, billing run? PURE.
 *
 * The guard that stops one ask from becoming two billed agents: a client that
 * gave up on a slow callable and tapped again used to launch a second run
 * beside the first. Only a doc that is BOTH `searching` AND young counts — a
 * crashed function leaves a doc stuck in `searching` forever, and that must not
 * lock the feature out for good.
 *
 * FAILS OPEN on an unreadable createdAt (a half-written doc must not be a
 * permanent block); the 5/day counter is still the hard money ceiling.
 */
export function isTaskInFlight(params: {
  status: unknown;
  createdAtMs: unknown;
  nowMs: number;
  windowMs?: number;
}): boolean {
  if (params.status !== "searching") return false;
  const created = Number(params.createdAtMs);
  const now = Number(params.nowMs);
  if (!Number.isFinite(created) || !Number.isFinite(now)) return false;
  const windowMs = Number.isFinite(params.windowMs as number) && (params.windowMs as number) > 0
    ? (params.windowMs as number) : IN_FLIGHT_WINDOW_MS;
  const age = now - created;
  // a future createdAt is clock skew on a doc written moments ago — still live.
  if (age < 0) return true;
  return age <= windowMs;
}

// ── the gate (fail closed) ───────────────────────────────────────────────────

export interface FindingsGateResult {
  allowed: boolean;
  uid: string;
}

/** Deny unless the allowlist is non-empty AND the caller's uid is on it. */
export function starFindingsGate(
  uidsEnv: string | undefined,
  requestUid: string | undefined | null
): FindingsGateResult {
  const uids = String(uidsEnv ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const uid = String(requestUid ?? "");
  if (uids.length === 0 || !uid || !uids.includes(uid)) {
    return { allowed: false, uid: "" };
  }
  return { allowed: true, uid };
}

// ── THOUGHT counting + the kill decision ─────────────────────────────────────

export type AgiMessageType = "THOUGHT" | "QUESTION" | "USER" | "DONE" | "ERROR" | "LOG";

export interface AgiMessage {
  id: string;
  type: AgiMessageType;
  content: string;
}

/** The billed unit: count messages whose type is exactly "THOUGHT". */
export function countThoughts(messages: readonly AgiMessage[] | undefined): number {
  if (!Array.isArray(messages)) return 0;
  return messages.reduce((n, m) => (m && m.type === "THOUGHT" ? n + 1 : n), 0);
}

export type KillReason = "step_cap" | "timeout" | null;

export interface KillDecision {
  kill: boolean;
  reason: KillReason;
}

/**
 * The pure kill decision, evaluated on every poll. Step cap is checked first
 * (it is the billing-critical one). `>=` on both bounds so the loop kills the
 * instant the tally REACHES the cap, never one step past it.
 */
export function killDecision(params: {
  thoughtCount: number;
  elapsedMs: number;
  maxSteps?: number;
  wallClockMs?: number;
}): KillDecision {
  const maxSteps = params.maxSteps ?? MAX_AGENT_STEPS;
  const wallClockMs = params.wallClockMs ?? WALL_CLOCK_MS;
  if (params.thoughtCount >= maxSteps) return { kill: true, reason: "step_cap" };
  if (params.elapsedMs >= wallClockMs) return { kill: true, reason: "timeout" };
  return { kill: false, reason: null };
}

// ── outcome enums / mapping ──────────────────────────────────────────────────

/** Task-doc outcomes (owner telemetry). Every task doc lands on exactly one. */
export type FindingOutcome =
  | "found"       // search returned a picked candidate
  | "empty"       // agent came back with nothing
  | "partial"     // stopped before a submit (test policy) / degraded
  | "booked"      // registration completed by the agent
  | "handoff"     // form needs fields we won't fill → hand back the url
  | "confirmed"   // no registration needed → client does the calendar write
  | "failed";     // step-cap / timeout / error

/** The four card outcomes the client renders (per the finding). */
export type CardOutcome = "add_to_calendar" | "book_it" | "finish_signup" | "empty_handed";

/**
 * Map a finished search agent's parsed finding to a task status + card outcome.
 * `null` finding → empty-handed warm state.
 */
export function outcomeForFinding(
  finding: { registrationNeeded?: boolean; url?: string | null } | null
): { status: FindingOutcome; card: CardOutcome } {
  if (!finding) return { status: "empty", card: "empty_handed" };
  if (finding.registrationNeeded) {
    // has a url to finish signup at? offer book-it; else finish-signup link.
    return finding.url
      ? { status: "found", card: "book_it" }
      : { status: "found", card: "finish_signup" };
  }
  return { status: "found", card: "add_to_calendar" };
}

/**
 * Map a finished BOOKING agent's terminal signal to the confirmFinding status.
 *   completed         → booked
 *   blocked fields    → handoff (+ the url the owner finishes at)
 *   step-cap/timeout  → failed:<reason>
 *   error             → failed:error
 */
export function outcomeForBooking(signal: {
  completed?: boolean;
  blockedFields?: readonly string[] | null;
  killReason?: KillReason;
  errored?: boolean;
}): { status: FindingOutcome; outcome: string } {
  if (signal.killReason === "step_cap") return { status: "failed", outcome: "failed:step_cap" };
  if (signal.killReason === "timeout") return { status: "failed", outcome: "failed:timeout" };
  if (signal.errored) return { status: "failed", outcome: "failed:error" };
  if (signal.blockedFields && signal.blockedFields.length > 0) {
    return { status: "handoff", outcome: "handoff" };
  }
  if (signal.completed) return { status: "booked", outcome: "booked" };
  // ambiguous finish with nothing completed and nothing blocked → partial.
  return { status: "partial", outcome: "partial" };
}

// ── candidate shape + parsing ────────────────────────────────────────────────

/**
 * How much the agent trusts the machine-readable start it reported. The agent
 * is instructed to say "unknown" rather than guess — an invented time is worse
 * than no time at all, because the client turns it into a real calendar event.
 */
export type DateConfidence = "exact" | "approximate" | "unknown";

/**
 * The human-facing half of a candidate — everything the pick prompt needs.
 * Split out so the pick step (and its tests) stay independent of the
 * machine-date fields.
 */
export interface FindingCandidateCore {
  title: string;
  date: string;         // free text as the agent reports it ("this saturday 2pm")
  venue: string;
  url: string;
  registrationNeeded: boolean;
}

export interface FindingCandidate extends FindingCandidateCore {
  /** ISO 8601 WITH an explicit offset, or null when the listing gives no time. */
  startISO: string | null;
  /** Optional end; null when unknown (the client then uses a 1 hour hold). */
  endISO: string | null;
  dateConfidence: DateConfidence;
  /** The event's OWN image from the listing, https-sanitized, or null when the
   *  listing shows none. NEVER a stock/unrelated photo — the client falls back
   *  to a generated gradient card rather than showing an invented image. */
  imageUrl: string | null;
}

/** Explicit-offset ISO 8601 only. A bare "2026-08-02T14:00" has no offset, so
 *  it would be re-interpreted in whatever timezone reads it — rejected. */
const ISO_WITH_OFFSET =
  /^\d{4}-\d{2}-\d{2}[Tt]\d{2}:\d{2}(:\d{2})?(\.\d{1,6})?([Zz]|[+-]\d{2}:\d{2})$/;

/** Anything more than this far in the past is a stale/hallucinated listing. */
const PAST_GRACE_MS = 60 * 60 * 1000;          // ~1h
/** Anything further out than this is an absurd future (agent typo'd the year). */
const MAX_FUTURE_MS = 365 * 24 * 60 * 60 * 1000; // 1 year

/**
 * Validate one machine-readable datetime from the agent. PURE.
 *
 * Accepts ONLY a well-formed ISO 8601 datetime carrying an explicit UTC offset
 * (or Z). Rejects: non-strings, offset-less local times, unparseable garbage,
 * anything more than ~1h in the past, and anything more than a year out.
 * Returns the trimmed original on success, null on every rejection — never
 * throws, so one bad candidate can never take the whole search down.
 */
export function sanitizeStartISO(raw: unknown, now: Date = new Date()): string | null {
  if (typeof raw !== "string") return null;
  const s = raw.trim();
  if (!s || s.length > 40) return null;
  if (!ISO_WITH_OFFSET.test(s)) return null;
  const t = Date.parse(s);
  if (!Number.isFinite(t)) return null;
  const nowMs = now.getTime();
  if (t < nowMs - PAST_GRACE_MS) return null;
  if (t > nowMs + MAX_FUTURE_MS) return null;
  return s;
}

/**
 * Coerce the agent's confidence to the enum. PURE.
 *
 * With no valid startISO there is nothing to be confident ABOUT, so the answer
 * is always "unknown". With a valid startISO an unrecognised/missing label
 * lands on "approximate" — we have a real time but the agent never vouched for
 * it, and "approximate" is the honest middle (the client says so in the event).
 */
export function coerceDateConfidence(raw: unknown, hasStartISO: boolean): DateConfidence {
  if (!hasStartISO) return "unknown";
  const v = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  if (v === "exact" || v === "approximate" || v === "unknown") return v;
  return "approximate";
}

/**
 * Strict validation of the startFindingTask `preferBookable` param. PURE.
 * Absent → false. Present but not a boolean → rejected (the caller turns this
 * into invalid-argument); "true"/1 are NOT quietly accepted.
 */
export function parsePreferBookable(raw: unknown): { ok: true; value: boolean } | { ok: false } {
  if (raw === undefined || raw === null) return { ok: true, value: false };
  if (typeof raw === "boolean") return { ok: true, value: raw };
  return { ok: false };
}

/** Longest image url we will store or pass through. */
export const IMAGE_URL_MAX = 600;
/** A path ending in a genuine raster image extension. */
const IMAGE_EXT_RE = /\.(jpe?g|png|webp|gif|avif)($|[?#])/i;
/** A path living under a plausible image / media / cdn segment. */
const IMAGE_PATH_RE = /\/(images?|img|photos?|media|cdn|assets|uploads|thumb(?:nail)?s?)\//i;
/** A host that is itself an image / cdn host (token at a name boundary). */
const IMAGE_HOST_RE = /(?:^|[.-])(images?|img|cdn|media|static|assets|photos?|pics?)(?:$|[.-])/i;

/**
 * Validate the event's own listing image url. PURE, never throws.
 *
 * Accepts ONLY: a well-formed https url, under the length cap, on a real host,
 * whose path either ends in a raster image extension OR sits under a plausible
 * image/media/cdn segment. Everything else — http, data:, offsite trackers with
 * no image shape, garbage, non-strings — returns null. A null here is HONEST:
 * the client draws a generated gradient card, never a broken slot or an
 * invented photo.
 */
export function sanitizeImageUrl(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const s = raw.trim();
  if (!s || s.length > IMAGE_URL_MAX) return null;
  let u: URL;
  try { u = new URL(s); } catch { return null; }
  if (u.protocol !== "https:") return null;
  if (!u.hostname || !u.hostname.includes(".")) return null;
  const path = u.pathname;
  const looksImage =
    IMAGE_EXT_RE.test(path) || IMAGE_PATH_RE.test(path) || IMAGE_HOST_RE.test(u.hostname);
  if (!looksImage) return null;
  return s;
}

// ── og:image AFTER the search (zero agent steps) ──────────────────────────
//
// WHY THIS EXISTS: asking the agent for `imageUrl` was one of the two step
// sinks that capped both production runs — it went visual-scrollback hunting
// for the banner next to each listing row. So the search prompt no longer
// mentions images at all; instead the SERVER fetches the ONE picked finding's
// url once and reads its og:image. Costs no agent steps and no vendor call.
//
// HONEST LIMITATION: the finding's url is usually a LISTING page (sppl.org/
// events), not a per-event page, so og:image is frequently the SITE's generic
// banner or logo rather than the event's own photo. That is inherent to this
// approach, not a bug — and a miss simply yields null, which the client already
// renders as its generated gradient card.

/** Longest raw meta content we will even look at (before resolution). */
const OG_CONTENT_MAX = 2000;

/** Minimal HTML entity decode for a url sitting in a meta content attribute. */
function decodeEntities(s: string): string {
  return s
    .replace(/&(?:amp|#38|#x26);/gi, "&")
    .replace(/&(?:quot|#34|#x22);/gi, "\"")
    .replace(/&(?:apos|#39|#x27);/gi, "'")
    .replace(/&(?:lt|#60|#x3c);/gi, "<")
    .replace(/&(?:gt|#62|#x3e);/gi, ">");
}

/** Read one attribute out of a single `<meta ...>` tag (quoted or bare). */
function metaAttr(tag: string, name: string): string | null {
  const re = new RegExp(`\\b${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s"'>]+))`, "i");
  const m = re.exec(tag);
  if (!m) return null;
  return (m[1] ?? m[2] ?? m[3] ?? "").trim();
}

/** Resolve a possibly relative / protocol-relative url against the page url. */
function resolveAgainstPage(raw: string, pageUrl: unknown): string | null {
  const s = decodeEntities(raw).trim();
  if (!s || s.length > OG_CONTENT_MAX) return null;
  const base = typeof pageUrl === "string" ? pageUrl.trim() : "";
  // `new URL(s, base)` already handles absolute, protocol-relative (//x) and
  // root-relative (/x) forms; the bare-absolute retry covers a junk base.
  if (base) {
    try { return new URL(s, base).toString(); } catch { /* fall through */ }
  }
  try { return new URL(s).toString(); } catch { return null; }
}

/**
 * Pull the page's og:image (falling back to twitter:image) out of raw HTML and
 * resolve it to an absolute url. PURE, never throws.
 *
 * Returns the FIRST og:image when several are present, and only falls back to
 * twitter:image when there is no og:image at all. The result is NOT trusted —
 * the caller runs it through sanitizeImageUrl, which is what enforces https,
 * the length cap, and a plausible image shape.
 */
export function extractOgImage(html: unknown, pageUrl: unknown): string | null {
  if (typeof html !== "string" || !html) return null;
  let og: string | null = null;
  let tw: string | null = null;
  const tags = html.match(/<meta\b[^>]*>/gi);
  if (!tags) return null;
  for (const tag of tags) {
    const key = (metaAttr(tag, "property") ?? metaAttr(tag, "name") ?? "").toLowerCase();
    const isOg = key === "og:image" || key === "og:image:url" || key === "og:image:secure_url";
    const isTw = key === "twitter:image" || key === "twitter:image:src";
    if (!isOg && !isTw) continue;
    const content = metaAttr(tag, "content");
    if (!content) continue;
    if (isOg && og === null) og = content;
    else if (isTw && tw === null) tw = content;
    if (og !== null) break;   // an og:image always wins; stop at the first one
  }
  const raw = og ?? tw;
  return raw ? resolveAgainstPage(raw, pageUrl) : null;
}

/**
 * How many sends the caller has left today. PURE. `used` is the day counter
 * (any non-finite / negative reading is treated as 0 used, i.e. full budget is
 * NOT assumed — a bad reading counts as none used so the idle line stays
 * generous rather than falsely at zero). Clamped to [0, cap].
 */
export function tasksRemainingToday(used: unknown, cap: number = MAX_TASKS_PER_DAY): number {
  const limit = Number.isFinite(cap) && cap > 0 ? Math.floor(cap) : MAX_TASKS_PER_DAY;
  const u = Number(used);
  const usedN = Number.isFinite(u) && u > 0 ? Math.floor(u) : 0;
  return Math.max(0, limit - usedN);
}

/**
 * Parse the agent's search reply into candidates. Accepts either a raw JSON
 * array or an object with a `candidates` array, and tolerates a ```json fence.
 * Never throws — a parse miss yields []. Each candidate is shape-checked and
 * capped so a chatty model can't blow the doc up.
 */
export function parseCandidates(
  raw: string | undefined,
  now: Date = new Date()
): FindingCandidate[] {
  if (!raw || typeof raw !== "string") return [];
  const cleaned = raw.replace(/```json/gi, "").replace(/```/g, "").trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    // last resort: pull the first [...] block out of prose.
    const m = cleaned.match(/\[[\s\S]*\]/);
    if (!m) return [];
    try { parsed = JSON.parse(m[0]); } catch { return []; }
  }
  const arr = Array.isArray(parsed)
    ? parsed
    : (parsed && typeof parsed === "object" && Array.isArray((parsed as Record<string, unknown>).candidates))
      ? (parsed as Record<string, unknown>).candidates as unknown[]
      : [];
  const out: FindingCandidate[] = [];
  for (const item of arr) {
    if (!item || typeof item !== "object") continue;
    const o = item as Record<string, unknown>;
    const title = typeof o.title === "string" ? o.title.trim().slice(0, 120) : "";
    const url = typeof o.url === "string" ? o.url.trim().slice(0, 400) : "";
    if (!title || !/^https?:\/\//i.test(url)) continue;

    // machine-readable date: validated hard, and DISOWNED whenever the agent
    // itself says "unknown" — a time the agent won't vouch for must never
    // become a real calendar event on someone's phone.
    let startISO = sanitizeStartISO(o.startISO ?? o.start_iso, now);
    const dateConfidence = coerceDateConfidence(
      o.dateConfidence ?? o.date_confidence, startISO !== null);
    if (dateConfidence === "unknown") startISO = null;
    let endISO = startISO ? sanitizeStartISO(o.endISO ?? o.end_iso, now) : null;
    // an end that is not strictly after the start is meaningless — drop it.
    if (endISO && startISO && Date.parse(endISO) <= Date.parse(startISO)) endISO = null;

    out.push({
      title,
      date: typeof o.date === "string" ? o.date.trim().slice(0, 80) : "",
      venue: typeof o.venue === "string" ? o.venue.trim().slice(0, 120) : "",
      url,
      registrationNeeded:
        o.registrationNeeded === true || o.registration_needed === true ||
        o.registrationNeeded === "true" || o.registration_needed === "true",
      startISO,
      endISO,
      dateConfidence,
      imageUrl: sanitizeImageUrl(o.imageUrl ?? o.image_url ?? o.image),
    });
    if (out.length >= 8) break;
  }
  return out;
}

// ── raw-reply summarising (diagnosability) ───────────────────────────────────

export interface AgentReplySummary {
  /** Single-line, cap-truncated copy of the reply — fits in ONE log entry. */
  truncated: string;
  /** Did the reply LOOK like JSON (starts with [ or { once fences are gone)? */
  looksJson: boolean;
  /** Length of the ORIGINAL reply, before flattening or truncation. */
  length: number;
}

/**
 * Shape the agent's raw final message for a log line. PURE, never throws.
 *
 * WHY: a task that lands on `outcome: empty` is currently ambiguous — the agent
 * may have genuinely found nothing, or it may have replied with prose/malformed
 * JSON that `parseCandidates` turned into zero candidates. Logging the reply
 * (single-lined so it stays one entry, and truncated so a chatty model can't
 * flood the log) plus `looksJson` makes the two cases distinguishable at a
 * glance. `length` is the PRE-truncation length, so a cap hit is obvious.
 *
 * Only the agent's own text about public event listings goes through here — no
 * user PII, and never any credential: the API key and auth headers live in
 * agiClient's request options and are never part of a message body.
 */
export function summarizeAgentReply(
  raw: unknown,
  cap: number = AGENT_REPLY_LOG_CAP
): AgentReplySummary {
  if (typeof raw !== "string" || raw.length === 0) {
    return { truncated: "", looksJson: false, length: 0 };
  }
  const limit = Number.isFinite(cap) && cap > 0 ? Math.floor(cap) : AGENT_REPLY_LOG_CAP;
  // looksJson is judged the same way parseCandidates sees it: fences stripped.
  const fenceless = raw.replace(/```json/gi, "").replace(/```/g, "").trim();
  const looksJson = fenceless.startsWith("[") || fenceless.startsWith("{");
  const flat = raw.replace(/[\r\n\t]+/g, " ").replace(/ {2,}/g, " ").trim();
  return { truncated: flat.slice(0, limit), looksJson, length: raw.length };
}

// ── prompt builders ──────────────────────────────────────────────────────────

/**
 * The search-agent prompt: free + gentle + this-week + Saint Paul hardcoded.
 *
 * KEPT DELIBERATELY SHORT. This prompt grew from ~1.2k chars (a shape that
 * converged in 5-6 steps with 6 candidates) to ~6k, and at 6k it stopped
 * converging at all: two production runs sat on ONE listing page and burned the
 * whole 30-step cap for zero candidates. Every line here has to earn its place,
 * because the agent reads length as licence to keep working.
 *
 * The two step sinks the long version created, both removed:
 *   • `imageUrl` capture — sent the agent visual-scrollback hunting for the
 *     banner beside each listing row. Images now come from a server-side
 *     og:image fetch AFTER the pick (see extractOgImage), at zero agent steps.
 *   • "up to 6 items" — read as a QUOTA ("I need one more from Saturday").
 *     The target is now an unambiguous hard stop at 2 or 3.
 *
 * WHAT SURVIVED, and why: the do-NOT-open-each-detail-page rule and the
 * emit-immediately rule (they are what got runs down to 5-6 steps); the
 * structured-date contract (it is the fix for events landing on the wrong day);
 * the clinical exclusion (safety, mirrors the comfort-recs rule); and the
 * JSON-only output contract, still LAST for recency.
 *
 * `preferBookable` PREFERS registration portals, it does not RESTRICT to them:
 * a restrictive earlier shape burned 5 steps for zero candidates while bias-off
 * runs found 6 in the same budget, so the fallback to general listings is part
 * of the bias, not an escape from it.
 */
export function buildSearchPrompt(
  city: string = FINDINGS_CITY,
  preferBookable: boolean = false
): string {
  const lines = [
    `Find gentle, FREE, low-key things a tired person could do THIS WEEK in ${city}:`,
    "a quiet library event, a park or nature walk, a calm class, an open studio, a",
    "small reading, a free community gathering. Avoid anything loud, crowded,",
    "ticketed, alcohol-centered, or high-energy.",
    "",
    "Sources: city/county site, public library calendar, parks & recreation,",
    "eventbrite, lu.ma, venue/organizer pages; only a real, currently-live page. On",
    "eventbrite use its FREE filter and the wellness, community, outdoor, arts and",
    "family categories; skip nightlife, bar, brewery, 21+, high-intensity fitness.",
    "",
    // CLINICAL EXCLUSION — mirrors the comfort-recs system prompt's rule ("never
    // clinical … comfort means escape and warmth, not a mirror of what they are
    // feeling"), adapted from media to events. Compressed, NOT relaxed: every
    // excluded class below is the same one the long version named.
    "NOT CARE SERVICES — dino brings gentle outings, never care delivery. EXCLUDE",
    "every clinical, therapeutic, or medical-service event even when free and kind",
    "sounding: therapy or counseling, \"talk with a mental health professional\"",
    "services, support groups, recovery meetings, grief circles, health screenings,",
    "clinics, health fairs, illness-centered talks. KEEP the genuinely gentle",
    "non-clinical things: storytime, gardens and nature walks, crafts and open",
    "studios, music, writing classes, library programs, museum hours.",
  ];

  if (preferBookable) {
    lines.push(
      "",
      "BOOKABLE BIAS (a PREFERENCE, not a restriction): START with registration portals",
      "— library program registration pages, eventbrite, lu.ma,",
      "community education class catalogs, parks and recreation class registration.",
      "If those run dry, FALL BACK to the general gentle event listings",
      "rather than returning nothing. Set registrationNeeded HONESTLY from the listing.",
    );
  }

  lines.push(
    "",
    "BE DECISIVE — you have a limited number of steps and each costs money:",
    "- Read at most 2 or 3 listing/calendar pages; the listing url is fine, do NOT",
    "  chase per-event permalinks.",
    "- Do NOT open each event's detail page; judge every field from the listing",
    "  page you are already on.",
    "- STOP browsing and reply the instant you have 2 or 3 candidates. Do not look",
    "  for more. More than 3 is a failure, not thoroughness.",
    "",
    "Each object exactly:",
    '{ "title": string, "date": string, "venue": string, "url": string,',
    '  "registrationNeeded": boolean, "startISO": string|null, "endISO": string|null,',
    '  "dateConfidence": "exact"|"approximate"|"unknown" }',
    "date is a short human phrase (\"this saturday, 2pm\"); registrationNeeded is",
    "true only if the page requires signing up. startISO/endISO are MACHINE-READ",
    "into a real calendar event: ISO 8601 in America/Chicago, e.g.",
    "\"2026-08-02T14:00:00-05:00\". An offset is REQUIRED; endISO is null when the",
    "page states no end. dateConfidence is \"exact\" only when the page states BOTH",
    "the date and the start time. NEVER invent a time: if the listing only says",
    "\"see listing\", startISO is null and dateConfidence \"unknown\".",
    "",
    // THE OUTPUT CONTRACT LIVES LAST ON PURPOSE — recency. A run that had found
    // six good events narrated them in prose and never emitted the array; the
    // whole search was thrown away by a formatting slip. Restating the contract
    // as the final thing the agent reads is the cheapest place to prevent that.
    "OUTPUT CONTRACT: Your FINAL message must be ONLY the JSON array, starting with",
    "[ and ending with ]. Do not describe what you found in words: no prose, no",
    "fence, no narration around it.",
    "If you truly found nothing, your entire final message is exactly: []",
  );
  return lines.join("\n");
}

/**
 * The pick prompt (gpt-4.1-mini): choose ONE gentle fit from the candidates and
 * write dino's "why" in a lowercase, warm, no-dashes voice. JSON out.
 *
 * The clinical exclusion is repeated here as a SAFETY NET: the search prompt
 * already forbids care-delivery events, but the pick step is the last gate
 * before a finding reaches someone's phone, and a clinical listing that slipped
 * through the search must not be the thing dino hands them. Same intent as the
 * comfort-recs system prompt's "never clinical … not a mirror of what they are
 * feeling" rule, adapted to events.
 */
export function buildPickPrompt(candidates: readonly FindingCandidateCore[]): {
  system: string;
  user: string;
} {
  const system = [
    "you are dino, a gentle companion. you speak in lowercase, warm and plain,",
    "never using dashes. you are picking ONE thing for a tired person's week.",
    "never pick a clinical, therapeutic, or medical event, even a free and kind",
    "sounding one: no therapy or counseling session, no \"talk with a mental health",
    "professional\" style service, no support group or recovery meeting, no grief",
    "circle, no health screening, clinic, or medical advice session. dino brings",
    "gentle outings, not care services: reach for the storytime, the garden, the",
    "walk, the craft table, the library or museum hour. if every option looks",
    "clinical, pick the least clinical one.",
    'reply with ONLY json: { "index": number, "why": string }.',
    "index is the 0-based position of your pick. why is one soft sentence",
    "(<= 140 chars, lowercase, no dashes) about why it fits a quiet day.",
  ].join("\n");
  const list = candidates
    .map((c, i) => `${i}. ${c.title} — ${c.date} @ ${c.venue} (${c.url})`)
    .join("\n");
  const user = `here are this week's candidates:\n${list}\n\npick the gentlest single fit.`;
  return { system, user };
}

// ── client reachability: the push's door + the task response shape ───────────
//
// Two bugs made a FINISHED server task unreachable from the client:
//   1. the finding push carried no data payload, so a tap had no deep link and
//      fell through to home;
//   2. getFindingTask demanded a taskId, so a client that lost the id (killed
//      mid-call, or freshly installed) could not ask "what happened?" at all.
// These pure helpers are the fix's testable core; index.ts wires them to FCM
// and Firestore.

/** The door a finding push opens: dino://finding/{taskId}. Empty id → "". */
export function findingDeepLink(taskId: string | undefined | null): string {
  const id = String(taskId ?? "").trim();
  return id ? `dino://finding/${id}` : "";
}

/** The getFindingTask response shape (identical for by-id and latest lookups). */
export interface FindingTaskPayload {
  taskId: string;
  status: string;
  finding: unknown;
  steps: number;
  outcome: string;
}

/**
 * A user who has never sent a star out is NOT an error — a first-ever cold
 * open must be quiet, so "latest task" answers with this instead of not-found.
 */
export function noFindingTask(): FindingTaskPayload {
  return { taskId: "", status: "none", finding: null, steps: 0, outcome: "" };
}

/**
 * Shape one task doc into the response. Every field is defaulted so a doc
 * written by an older shape (or a half-written doc) still answers cleanly.
 */
export function findingTaskPayload(
  id: string | undefined | null,
  data: Record<string, unknown> | undefined | null
): FindingTaskPayload {
  const d = data ?? {};
  const status = typeof d.status === "string" && d.status ? d.status : "failed";
  const steps = Number(d.steps);
  return {
    taskId: String(id ?? ""),
    status,
    finding: d.finding ?? null,
    steps: Number.isFinite(steps) ? steps : 0,
    outcome: typeof d.outcome === "string" ? d.outcome : "",
  };
}

/**
 * The booking-agent prompt: fill ONLY name + email. If the form demands DOB,
 * phone, payment, a login, or a captcha → STOP and report fields_blocked.
 * Never invent values. (name+email is the only PII that ever reaches the agent,
 * and only in this booking phase — see index.ts confirmFinding.)
 */
export function buildBookingPrompt(name: string, email: string): string {
  const safeName = String(name ?? "").trim().slice(0, 80);
  const safeEmail = String(email ?? "").trim().slice(0, 120);
  return [
    "Register for this free event using ONLY the two values below. Fill the name",
    "field and the email field, then submit if the form asks for nothing else.",
    "",
    `name: ${safeName}`,
    `email: ${safeEmail}`,
    "",
    "HARD RULES:",
    "- Use ONLY these two values. Never invent or guess any other field value.",
    "- If the form requires a date of birth, phone number, payment/card details, a",
    "  login/account, or a captcha, DO NOT proceed. STOP and reply with exactly:",
    '  { "status": "fields_blocked", "blockedFields": [ ...the field names... ] }',
    "- If it submits cleanly with just name + email, reply with exactly:",
    '  { "status": "completed" }',
  ].join("\n");
}
