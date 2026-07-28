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
// THE 30-STEP KILL: billing is per thinking step, so the agent loop tallies
// THOUGHT messages and kills (cancel + DELETE session) the instant the tally
// reaches MAX_AGENT_STEPS. killDecision is the pure decision the loop calls on
// every poll; the actual cancel/DELETE lives in agiClient.ts.

// ── caps / constants ────────────────────────────────────────────────────────

/** Per-thinking-step kill: the agent is cancelled the instant THOUGHTs hit 30. */
export const MAX_AGENT_STEPS = 30;
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
 * Step margin the ONE-SHOT json retry needs before it is allowed to run. The
 * retry's thinking steps land on the SAME 30-step tally, so it may only start
 * while at least this many steps remain — the existing kill must never be
 * pushed past by the retry itself.
 */
export const JSON_RETRY_STEP_MARGIN = 5;

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

// ── the ONE-SHOT json retry (the "agent narrated instead of emitting" fix) ───
//
// THE BUG (task opPrIgf6Akl3TpIrXdjD): the agent SUCCEEDED — 4 steps of 30, six
// real gentle free Saint Paul events with dates, times and venues — then wrote
// them out in PROSE, said it would "compile the results now", and the session
// ended before the JSON array ever appeared. parseCandidates saw no array, the
// run reported `empty`, and 26 steps of budget went unused. Pure output-format
// failure, not a search failure. So: ask ONCE more, in the SAME session, for
// just the JSON — the events are already in the agent's context, so this is a
// formatting turn, not a second search.

/**
 * The follow-up message sent to the SAME session when the agent narrated
 * instead of emitting. The candidate schema is restated so the agent does not
 * have to reach back to the original prompt to re-format what it already found.
 */
export const JSON_RETRY_MESSAGE = [
  "STOP. Do not browse any further and do not describe anything in words.",
  "Reply with ONLY the JSON array of the candidates you just listed: no prose,",
  "no markdown fence, no explanation, no commentary before or after it.",
  "Your entire message must start with [ and end with ].",
  "Each object exactly:",
  '{ "title": string, "date": string, "venue": string, "url": string,',
  '  "registrationNeeded": boolean, "startISO": string|null, "endISO": string|null,',
  '  "dateConfidence": "exact"|"approximate"|"unknown" }',
  "If you truly have none, reply with [].",
].join("\n");

/**
 * The retry decision. PURE, never throws.
 *
 * Retry ONLY when all of these hold:
 *   • nothing parsed (candidates === 0) — a good reply is never re-asked;
 *   • the reply did NOT look like JSON — a genuine "[]" is an honest empty and
 *     asking again would just burn steps on the same answer;
 *   • we have not already retried — this is one-shot by contract;
 *   • at least JSON_RETRY_STEP_MARGIN steps of the cap remain, so the retry
 *     cannot be what pushes the run into the kill.
 */
export function shouldRetryForJson(params: {
  candidates: number;
  looksJson: boolean;
  stepsUsed: number;
  maxSteps?: number;
  alreadyRetried: boolean;
}): boolean {
  if (params.alreadyRetried) return false;
  if (!Number.isFinite(params.candidates) || params.candidates > 0) return false;
  if (params.looksJson) return false;
  const maxSteps = Number.isFinite(params.maxSteps as number)
    ? (params.maxSteps as number) : MAX_AGENT_STEPS;
  // an unreadable step tally is treated as "no budget left" (fail closed).
  if (!Number.isFinite(params.stepsUsed) || params.stepsUsed < 0) return false;
  return params.stepsUsed <= maxSteps - JSON_RETRY_STEP_MARGIN;
}

// ── prompt builders ──────────────────────────────────────────────────────────

/**
 * The search-agent prompt: free + gentle + this-week + Saint Paul hardcoded.
 * Explicitly steers to official / eventbrite / library / parks pages and asks
 * for a strict JSON candidate list.
 *
 * THE STRUCTURED-DATE CONTRACT (the fix for the "event landed on the wrong
 * day" bug): the free-text `date` field is display only — the client can't
 * schedule from "this saturday, 2pm", and used to fall back to a hardcoded
 * placeholder. The agent must now ALSO return startISO/endISO/dateConfidence,
 * and must say "unknown" rather than invent a time.
 *
 * `preferBookable` PREFERS registration portals, it does not RESTRICT to them.
 * The first shape of this bias narrowed the source list hard enough that a real
 * run (task oLCcj9OJzWwASFHIIWXp) burned 5 steps and came back with zero
 * candidates, while bias-off runs found 6 in the same budget. So the branch now
 * names registration sources as the preferred STARTING point and then requires
 * a fallback to general gentle listings — an honest candidate carrying
 * `registrationNeeded: false` beats an empty result. The bias must still never
 * cost extra steps, so the decisive early-JSON rule and the
 * do-not-open-each-event rule are repeated in that branch too.
 */
export function buildSearchPrompt(
  city: string = FINDINGS_CITY,
  preferBookable: boolean = false
): string {
  const lines = [
    `Find gentle, FREE, low-key things a tired person could do THIS WEEK in ${city}.`,
    "Good fits: a quiet library event, a park walk or nature program, a free community",
    "gathering, a calm class, an open studio, a small local reading. Avoid anything",
    "loud, crowded, ticketed, alcohol-centered, or high-energy.",
    "",
    "Prefer OFFICIAL sources: the city or county site, the public library calendar,",
    "the parks & recreation site, eventbrite, and venue/organizer pages. Only include",
    "an item you can point at a real, currently-live page for.",
    "",
    // CLINICAL EXCLUSION — mirrors the comfort-recs system prompt's rule ("only
    // inherently gentle content … never clinical or academic works, and never
    // books or films about mental illness, therapy, self help … comfort means
    // escape and warmth, not a mirror of what they are feeling"), adapted from
    // media to events so the two systems say the same thing. Owner-reported:
    // "Talk with a Mental Health Professional" surfaced twice as a finding.
    "NOT CARE SERVICES — dino brings small gentle outings, never care delivery.",
    "Only inherently gentle outings: nothing graphic, violent, frightening, grief",
    "centered, or otherwise distressing. EXCLUDE every clinical, therapeutic, or",
    "medical-service event, even a free and kind-sounding one:",
    "- therapy or counseling sessions, and \"talk with a mental health professional\"",
    "  style services, psychiatric or psychological consultations,",
    "- support groups, recovery or twelve step meetings, grief or bereavement",
    "  circles, caregiver support sessions,",
    "- health screenings, vaccination or flu shot clinics, blood drives, medical or",
    "  dental clinics, health fairs, and any medical advice or diagnosis session,",
    "- talks and workshops centered on mental illness, addiction, or illness.",
    "KEEP the genuinely gentle non-clinical things: storytime, gardens and nature",
    "walks, crafts and open studios, music, writing and other creative classes,",
    "library programs, museum hours, quiet community gatherings.",
    "A gentle outing is an escape and a little warmth, not a mirror of what someone",
    "is going through.",
  ];

  if (preferBookable) {
    lines.push(
      "",
      "BOOKABLE BIAS (this run PREFERS things you can actually sign up for). This",
      "is a PREFERENCE, not a restriction:",
      "- START with registration portals rather than plain calendars:",
      "  library program registration pages, eventbrite, community education class",
      "  catalogs, and parks and recreation class registration pages. Those are your",
      "  preferred first stop.",
      "- If those sources do not give you enough gentle free options, FALL BACK to the",
      "  general gentle event listings for the city rather than returning nothing. An",
      "  honest candidate with registrationNeeded false is far better than an empty",
      "  result.",
      "- Set registrationNeeded HONESTLY for each candidate, from what its listing",
      "  actually shows. Prefer — do not require — listings that ALREADY show a",
      "  register or sign up affordance on the listing page itself.",
      "- Returning zero candidates when gentle free events exist is a failure. Come",
      "  back with something suitable.",
      "Judge all of that from the listing/source page you are already on — do NOT open",
      "each event's detail page to verify registration. The SAME step budget applies:",
      "emit the JSON as soon as you have a few candidates; this bias must not cost you",
      "extra steps.",
    );
  }

  lines.push(
    "",
    "BE DECISIVE — you have a limited number of steps:",
    "- Read at most 2 or 3 official listing/calendar pages. Do NOT chase exact",
    "  per-event permalink URLs; the listing or calendar page url is acceptable.",
    "- Do NOT open each event's detail page to verify anything; judge every field",
    "  from the listing or source page you are already on.",
    "- As soon as you have up to 6 items (even 2 or 3 is fine), STOP browsing and",
    "  reply immediately with the JSON. Do not keep verifying.",
    "",
    "Return ONLY a JSON array (no prose, no markdown fence) of up to 6 candidates,",
    "each object exactly:",
    '{ "title": string, "date": string, "venue": string, "url": string,',
    '  "registrationNeeded": boolean, "startISO": string|null, "endISO": string|null,',
    '  "dateConfidence": "exact"|"approximate"|"unknown" }',
    "date is a short human phrase (e.g. \"this saturday, 2pm\"). registrationNeeded is",
    "true only if the page requires signing up / reserving a spot.",
    "",
    "THE DATE FIELDS ARE MACHINE-READ — they become a real calendar event:",
    "- startISO: ISO 8601 local datetime WITH an explicit offset, in the",
    `  America/Chicago timezone (${city}), e.g. "2026-08-02T14:00:00-05:00".`,
    "  An offset is REQUIRED; a bare \"2026-08-02T14:00\" is not acceptable.",
    "- endISO: same format for the end time. If the page does not state an end,",
    "  omit it or set it to null. Do not estimate it.",
    "- dateConfidence: \"exact\" only when the page states BOTH the date and the",
    "  start time; \"approximate\" when you are inferring one of them.",
    "- NEVER invent a time. If the listing only says something like \"see listing\"",
    "  or gives no clear date and time, set startISO to null and dateConfidence to",
    "  \"unknown\". An honest \"unknown\" is always better than a guessed time.",
    "",
    // THE OUTPUT CONTRACT LIVES LAST ON PURPOSE — recency. A run that had found
    // six good events narrated them in prose ("let me compile the results now")
    // and never emitted the array; the whole search was thrown away by a
    // formatting slip. Restating the contract as the final thing the agent reads
    // is the cheapest place to prevent that.
    "OUTPUT CONTRACT — a machine reads your answer, not a person:",
    "- Your FINAL message must be ONLY the JSON array. Nothing else.",
    "- Do not describe what you found in words. Your entire final message must",
    "  start with [ and end with ].",
    "- No prose before it, no summary after it, no markdown fence, no commentary,",
    "  and never a \"let me compile the results now\" style narration. Listing the",
    "  events in words instead of emitting the JSON is a FAILED run, even when you",
    "  found perfect events.",
    "- If you truly found nothing, your entire final message is exactly: []",
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
    "small gentle outings, not care services, so reach for the storytime, the",
    "garden, the walk, the craft table, the library or museum hour instead. if",
    "every option looks clinical, pick the least clinical one.",
    'reply with ONLY json: { "index": number, "why": string }.',
    "index is the 0-based position of your pick in the list. why is one soft",
    "sentence (<= 140 chars, lowercase, no dashes) about why it fits a quiet day.",
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
