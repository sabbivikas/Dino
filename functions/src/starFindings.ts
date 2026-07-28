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

export interface FindingCandidate {
  title: string;
  date: string;         // free text as the agent reports it ("this saturday 2pm")
  venue: string;
  url: string;
  registrationNeeded: boolean;
}

/**
 * Parse the agent's search reply into candidates. Accepts either a raw JSON
 * array or an object with a `candidates` array, and tolerates a ```json fence.
 * Never throws — a parse miss yields []. Each candidate is shape-checked and
 * capped so a chatty model can't blow the doc up.
 */
export function parseCandidates(raw: string | undefined): FindingCandidate[] {
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
    out.push({
      title,
      date: typeof o.date === "string" ? o.date.trim().slice(0, 80) : "",
      venue: typeof o.venue === "string" ? o.venue.trim().slice(0, 120) : "",
      url,
      registrationNeeded:
        o.registrationNeeded === true || o.registration_needed === true ||
        o.registrationNeeded === "true" || o.registration_needed === "true",
    });
    if (out.length >= 8) break;
  }
  return out;
}

// ── prompt builders ──────────────────────────────────────────────────────────

/**
 * The search-agent prompt: free + gentle + this-week + Saint Paul hardcoded.
 * Explicitly steers to official / eventbrite / library / parks pages and asks
 * for a strict JSON candidate list (title/date/venue/url/registrationNeeded).
 */
export function buildSearchPrompt(city: string = FINDINGS_CITY): string {
  return [
    `Find gentle, FREE, low-key things a tired person could do THIS WEEK in ${city}.`,
    "Good fits: a quiet library event, a park walk or nature program, a free community",
    "gathering, a calm class, an open studio, a small local reading. Avoid anything",
    "loud, crowded, ticketed, alcohol-centered, or high-energy.",
    "",
    "Prefer OFFICIAL sources: the city or county site, the public library calendar,",
    "the parks & recreation site, eventbrite, and venue/organizer pages. Only include",
    "an item you can point at a real, currently-live page for.",
    "",
    "BE DECISIVE — you have a limited number of steps:",
    "- Read at most 2 or 3 official listing/calendar pages. Do NOT chase exact",
    "  per-event permalink URLs; the listing or calendar page url is acceptable.",
    "- As soon as you have up to 6 items (even 2 or 3 is fine), STOP browsing and",
    "  reply immediately with the JSON. Do not keep verifying.",
    "",
    "Return ONLY a JSON array (no prose, no markdown fence) of up to 6 candidates,",
    "each object exactly:",
    '{ "title": string, "date": string, "venue": string, "url": string, "registrationNeeded": boolean }',
    "date is a short human phrase (e.g. \"this saturday, 2pm\"). registrationNeeded is",
    "true only if the page requires signing up / reserving a spot.",
  ].join("\n");
}

/**
 * The pick prompt (gpt-4.1-mini): choose ONE gentle fit from the candidates and
 * write dino's "why" in a lowercase, warm, no-dashes voice. JSON out.
 */
export function buildPickPrompt(candidates: readonly FindingCandidate[]): {
  system: string;
  user: string;
} {
  const system = [
    "you are dino, a gentle companion. you speak in lowercase, warm and plain,",
    "never using dashes. you are picking ONE thing for a tired person's week.",
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
