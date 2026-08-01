import test from "node:test";
import assert from "node:assert/strict";
import {
  starFindingsGate,
  countThoughts,
  killDecision,
  outcomeForFinding,
  outcomeForBooking,
  parseCandidates,
  buildSearchPrompt,
  buildPickPrompt,
  buildBookingPrompt,
  summarizeAgentReply,
  MAX_AGENT_STEPS,
  MAX_TASKS_PER_DAY,
  AGENT_REPLY_LOG_CAP,
  COST_PER_STEP_USD,
  IN_FLIGHT_WINDOW_MS,
  costForSteps,
  isTaskInFlight,
  type AgiMessage,
} from "./starFindings";

const OWNER = "Enlkbg0saoMqvx24r7ZLsBX8ctp2";

test("gate fails closed: empty/missing allowlist or a non-member caller denies", () => {
  assert.equal(starFindingsGate(undefined, OWNER).allowed, false);
  assert.equal(starFindingsGate("", OWNER).allowed, false);
  assert.equal(starFindingsGate(OWNER, undefined).allowed, false);
  assert.equal(starFindingsGate(OWNER, null).allowed, false);
  assert.equal(starFindingsGate(OWNER, "").allowed, false);
  assert.equal(starFindingsGate(OWNER, "someoneElse").allowed, false);
});

test("gate allows only a caller whose uid is on the allowlist; uid is the CALLER's own", () => {
  const g = starFindingsGate(` a , ${OWNER} , b `, OWNER);
  assert.equal(g.allowed, true);
  assert.equal(g.uid, OWNER);
  // a different allowlisted caller gets their own uid, never the first
  assert.deepEqual(starFindingsGate("a,b", "b"), { allowed: true, uid: "b" });
});

test("countThoughts counts only THOUGHT-typed messages", () => {
  const msgs: AgiMessage[] = [
    { id: "1", type: "THOUGHT", content: "thinking" },
    { id: "2", type: "LOG", content: "nav" },
    { id: "3", type: "THOUGHT", content: "more" },
    { id: "4", type: "QUESTION", content: "?" },
    { id: "5", type: "DONE", content: "[]" },
  ];
  assert.equal(countThoughts(msgs), 2);
  assert.equal(countThoughts([]), 0);
  assert.equal(countThoughts(undefined), 0);
});

test("killDecision: kills at exactly the step cap (>=), not one past it", () => {
  assert.deepEqual(killDecision({ thoughtCount: MAX_AGENT_STEPS - 1, elapsedMs: 0 }),
    { kill: false, reason: null });
  assert.deepEqual(killDecision({ thoughtCount: MAX_AGENT_STEPS, elapsedMs: 0 }),
    { kill: true, reason: "step_cap" });
  assert.deepEqual(killDecision({ thoughtCount: MAX_AGENT_STEPS + 5, elapsedMs: 0 }),
    { kill: true, reason: "step_cap" });
  // low custom threshold (the harness's step-kill proof uses 5)
  assert.equal(killDecision({ thoughtCount: 5, elapsedMs: 0, maxSteps: 5 }).kill, true);
  assert.equal(killDecision({ thoughtCount: 4, elapsedMs: 0, maxSteps: 5 }).kill, false);
});

test("killDecision: wall-clock ceiling kills with reason timeout; step cap wins ties", () => {
  assert.deepEqual(killDecision({ thoughtCount: 0, elapsedMs: 10, wallClockMs: 5 }),
    { kill: true, reason: "timeout" });
  assert.deepEqual(killDecision({ thoughtCount: 0, elapsedMs: 4, wallClockMs: 5 }),
    { kill: false, reason: null });
  // both tripped → step_cap reported first (billing-critical)
  assert.deepEqual(
    killDecision({ thoughtCount: 30, elapsedMs: 999999, wallClockMs: 5 }),
    { kill: true, reason: "step_cap" });
});

test("outcomeForFinding maps registration + url to the four card outcomes", () => {
  assert.deepEqual(outcomeForFinding(null), { status: "empty", card: "empty_handed" });
  assert.deepEqual(outcomeForFinding({ registrationNeeded: false }),
    { status: "found", card: "add_to_calendar" });
  assert.deepEqual(outcomeForFinding({ registrationNeeded: true, url: "https://x.org/e" }),
    { status: "found", card: "book_it" });
  assert.deepEqual(outcomeForFinding({ registrationNeeded: true, url: null }),
    { status: "found", card: "finish_signup" });
});

test("outcomeForBooking maps terminal signals to status/outcome", () => {
  assert.deepEqual(outcomeForBooking({ completed: true }), { status: "booked", outcome: "booked" });
  assert.deepEqual(outcomeForBooking({ blockedFields: ["dob", "phone"] }),
    { status: "handoff", outcome: "handoff" });
  assert.deepEqual(outcomeForBooking({ killReason: "step_cap" }),
    { status: "failed", outcome: "failed:step_cap" });
  assert.deepEqual(outcomeForBooking({ killReason: "timeout" }),
    { status: "failed", outcome: "failed:timeout" });
  assert.deepEqual(outcomeForBooking({ errored: true }),
    { status: "failed", outcome: "failed:error" });
  // ambiguous finish → partial (nothing completed, nothing blocked)
  assert.deepEqual(outcomeForBooking({}), { status: "partial", outcome: "partial" });
  // a step-cap kill outranks a stray "completed" flag
  assert.deepEqual(outcomeForBooking({ completed: true, killReason: "step_cap" }),
    { status: "failed", outcome: "failed:step_cap" });
});

test("parseCandidates: tolerates fences / wrapper objects, shape-checks, caps at 8", () => {
  const raw = "```json\n[" +
    '{"title":"Quiet Library Hour","date":"sat 2pm","venue":"Rondo","url":"https://sppl.org/e","registration_needed":true},' +
    '{"title":"","url":"https://x.org"},' +               // dropped: no title
    '{"title":"No URL","url":"not-a-url"},' +             // dropped: bad url
    '{"title":"Park Walk","date":"sun","venue":"Como","url":"https://stpaul.gov/como"}' +
    "]\n```";
  const cands = parseCandidates(raw);
  assert.equal(cands.length, 2);
  assert.equal(cands[0].title, "Quiet Library Hour");
  assert.equal(cands[0].registrationNeeded, true);
  assert.equal(cands[1].registrationNeeded, false);
  // wrapper object form
  assert.equal(parseCandidates('{"candidates":[{"title":"X","url":"https://a.b"}]}').length, 1);
  // garbage / empty
  assert.deepEqual(parseCandidates("not json at all"), []);
  assert.deepEqual(parseCandidates(undefined), []);
});

test("buildSearchPrompt hardcodes the city and demands a strict JSON array", () => {
  const p = buildSearchPrompt();
  assert.match(p, /Saint Paul, Minnesota/);
  assert.match(p, /FREE/);
  assert.match(p, /library/i);
  assert.match(p, /eventbrite/i);
  assert.match(p, /registrationNeeded/);
});

test("buildPickPrompt lists candidates 0-based and asks for lowercase no-dash why", () => {
  const { system, user } = buildPickPrompt([
    { title: "A", date: "sat", venue: "V", url: "https://a", registrationNeeded: false },
    { title: "B", date: "sun", venue: "W", url: "https://b", registrationNeeded: true },
  ]);
  assert.match(system, /lowercase/);
  assert.match(system, /index/);
  assert.match(user, /0\. A/);
  assert.match(user, /1\. B/);
});

test("buildBookingPrompt embeds ONLY name+email and the hard stop rules", () => {
  const p = buildBookingPrompt("Vikas Sabbi", "sabbi.vikas@gmail.com");
  assert.match(p, /name: Vikas Sabbi/);
  assert.match(p, /email: sabbi\.vikas@gmail\.com/);
  assert.match(p, /captcha/i);
  assert.match(p, /fields_blocked/);
  assert.match(p, /Never invent/i);
});

test("caps are the documented values", () => {
  // 30 → 15 (money): two production runs burned the full 30 for zero candidates
  // at $0.02/step. Halving the cap halves the worst case, $0.60 → $0.30.
  assert.equal(MAX_AGENT_STEPS, 15);
  assert.equal(MAX_TASKS_PER_DAY, 5);
  assert.equal(AGENT_REPLY_LOG_CAP, 1200);
  assert.equal(COST_PER_STEP_USD, 0.02);
  // the worst case one run can cost the owner
  assert.equal(costForSteps(MAX_AGENT_STEPS), 0.3);
});

// ── cost telemetry ───────────────────────────────────────────────────

test("costForSteps multiplies steps by the per-step rate and rounds to 4dp", () => {
  assert.equal(costForSteps(0), 0);
  assert.equal(costForSteps(1), 0.02);
  assert.equal(costForSteps(5), 0.1);
  assert.equal(costForSteps(15), 0.3);
  assert.equal(costForSteps(30), 0.6);        // what the old cap used to allow
  assert.equal(costForSteps(3, 0.015), 0.045);
});

test("costForSteps never yields NaN or a negative from a junk tally", () => {
  for (const bad of [undefined, null, NaN, -1, "nope", {}, []]) {
    assert.equal(costForSteps(bad), 0, `should read ${JSON.stringify(bad)} as 0`);
  }
  // a junk rate falls back to the documented one
  assert.equal(costForSteps(2, Number.NaN), 0.04);
  assert.equal(costForSteps(2, -1), 0.04);
});

// ── the in-flight guard (one ask must never become two billed agents) ──────

test("isTaskInFlight: a young `searching` task blocks a second launch", () => {
  const now = 1_000_000_000;
  assert.equal(isTaskInFlight({ status: "searching", createdAtMs: now - 1000, nowMs: now }), true);
  // right at the window edge is still live; one ms past it is not
  assert.equal(isTaskInFlight({
    status: "searching", createdAtMs: now - IN_FLIGHT_WINDOW_MS, nowMs: now }), true);
  assert.equal(isTaskInFlight({
    status: "searching", createdAtMs: now - IN_FLIGHT_WINDOW_MS - 1, nowMs: now }), false);
  // clock skew: a createdAt in the future is a doc written moments ago
  assert.equal(isTaskInFlight({ status: "searching", createdAtMs: now + 5000, nowMs: now }), true);
});

test("isTaskInFlight: only `searching` counts — a settled task never blocks", () => {
  const now = 1_000_000_000;
  for (const status of ["found", "empty", "failed", "booked", "confirmed", "handoff", "", undefined]) {
    assert.equal(
      isTaskInFlight({ status, createdAtMs: now - 1000, nowMs: now }), false,
      `status ${String(status)} must not block`);
  }
});

test("isTaskInFlight: FAILS OPEN on an unreadable createdAt (never a permanent lockout)", () => {
  const now = 1_000_000_000;
  for (const bad of [undefined, null, NaN, "nope", {}]) {
    assert.equal(isTaskInFlight({ status: "searching", createdAtMs: bad, nowMs: now }), false);
  }
  assert.equal(isTaskInFlight({ status: "searching", createdAtMs: now, nowMs: Number.NaN }), false);
  // an explicit window override is honoured
  assert.equal(isTaskInFlight({
    status: "searching", createdAtMs: now - 5000, nowMs: now, windowMs: 1000 }), false);
});

// ── prompt safety rules (MOVED here when findingsJsonRetry.test.ts was deleted;
//    the retry is gone, these rules are not) ──────────────────────────────

test("the JSON-only output contract is present in BOTH bias branches", () => {
  for (const p of [buildSearchPrompt(), buildSearchPrompt(undefined, true)]) {
    assert.match(p, /OUTPUT CONTRACT/);
    assert.match(p, /Your FINAL message must be ONLY the JSON array/);
    assert.match(p, /Do not describe what you found in words/);
    assert.match(p, /starting with\s+\[ and ending with \]/);
    assert.match(p, /your entire final message is exactly: \[\]/);
  }
});

test("the output contract sits at the END of the prompt (recency)", () => {
  for (const p of [buildSearchPrompt(), buildSearchPrompt(undefined, true)]) {
    assert.ok(
      p.trimEnd().endsWith("If you truly found nothing, your entire final message is exactly: []"),
      "the contract's closing line must be the prompt's last line");
    assert.ok(p.indexOf("OUTPUT CONTRACT") > p.indexOf("NEVER invent a time"));
    assert.ok(p.indexOf("OUTPUT CONTRACT") > p.indexOf("BE DECISIVE"));
    assert.ok(p.indexOf("OUTPUT CONTRACT") > p.indexOf("NOT CARE SERVICES"));
    assert.ok(p.indexOf("OUTPUT CONTRACT") > p.length * 0.8);
  }
});

test("the search prompt excludes clinical/therapeutic/medical events in BOTH branches", () => {
  for (const p of [buildSearchPrompt(), buildSearchPrompt(undefined, true)]) {
    assert.match(p, /NOT CARE SERVICES/);
    assert.match(p, /never care delivery/);
    assert.match(p, /clinical, therapeutic, or\s+medical-service event/);
    assert.match(p, /therapy or counseling/);
    assert.match(p, /talk with a mental health professional/i);
    assert.match(p, /support groups/);
    assert.match(p, /recovery meetings/);
    assert.match(p, /health screenings/);
    assert.match(p, /clinics/);
    assert.match(p, /health fairs/);
    assert.match(p, /illness-centered talks/);
    // …while the gentle non-clinical things are explicitly KEPT
    assert.match(p, /KEEP the genuinely gentle/);
    assert.match(p, /storytime/);
    assert.match(p, /gardens and nature/);
    assert.match(p, /crafts and open/);
    assert.match(p, /library programs, museum hours/);
  }
});

// ══════════════════════════════════════════════════════════════════════════
// SAFETY REGRESSION PINS.
//
// WHY THESE EXIST: a compression pass on buildSearchPrompt silently deleted the
// general gentleness rule ("nothing graphic, violent, frightening, grief
// centered, or otherwise distressing"), the "escape and a little warmth, not a
// mirror" framing, and four clinical classes including BLOOD DRIVES — and the
// tests were rewritten in the same pass to assert the COMPRESSED set, so
// nothing caught it. A safety rule vanishing with green tests is worse than the
// bug it was guarding against. These pins assert the rules THEMSELVES, in BOTH
// bias branches, and they are whitespace-tolerant (\s+, never \n) so a future
// re-wrap of the prompt lines can never be mistaken for a deletion.
//
// If one of these fails: RESTORE THE RULE. Do not adjust the assertion.
// ══════════════════════════════════════════════════════════════════════════

test("SAFETY: the gentleness + clinical rules are present in BOTH branches — do not compress these away", () => {
  for (const [label, p] of [
    ["bias off", buildSearchPrompt()],
    ["bias on", buildSearchPrompt(undefined, true)],
  ] as const) {
    // ── 1. the GENERAL gentleness rule. This is INDEPENDENT of the clinical
    // list below: it is what excludes a true crime walking tour, a war
    // memorial vigil or a horror film night, none of which are clinical.
    assert.match(
      p,
      /Only\s+inherently\s+gentle\s+outings:\s+nothing\s+graphic,\s+violent,\s+frightening,\s+grief\s+centered,\s+or\s+otherwise\s+distressing\./,
      `${label}: the general-gentleness sentence must be present VERBATIM`);

    // ── 2. the "escape and a little warmth, not a mirror" framing — the same
    // sentence the comfort-recs system prompt carries, adapted to events.
    assert.match(
      p,
      /A\s+gentle\s+outing\s+is\s+an\s+escape\s+and\s+a\s+little\s+warmth,\s+not\s+a\s+mirror\s+of\s+what\s+someone\s+is\s+going\s+through\./,
      `${label}: the escape-not-a-mirror framing must be present`);

    // ── 3. every clinical class needs its OWN token. A class with no token is
    // a class the agent has no instruction about. "blood drive" is the one
    // that matters most: a blood drive is not a clinic, not a screening and
    // not a health fair, so every other token here misses it, while it reads
    // exactly like a free, kind community event.
    const CLINICAL_TOKENS = [
      "therapy", "counseling", "mental health professional", "support group",
      "recovery", "grief", "caregiver", "psychiatric", "screening",
      "blood drive", "health fair", "medical advice", "illness",
      "twelve step", "bereavement", "addiction",
    ];
    for (const token of CLINICAL_TOKENS) {
      assert.match(
        p, new RegExp(token.replace(/ /g, "\\s+"), "i"),
        `${label}: the clinical class "${token}" lost its token`);
    }
    // vaccination OR clinic — one of the two must name the shot-clinic class.
    assert.ok(
      /vaccination/i.test(p) || /clinic/i.test(p),
      `${label}: neither "vaccination" nor "clinic" is present`);
  }
});

test("SAFETY: all THREE dateConfidence values are DEFINED in BOTH branches, not just listed", () => {
  // WHY: the compressed date block defined "exact" and "unknown" but never said
  // when to use "approximate", so an agent that INFERRED a time had no word for
  // what it had done and reached for "exact" — which suppresses the client's
  // "this time is approximate" honesty note and puts a confidently-wrong time
  // on a real calendar. Listing the enum in the schema line is NOT a definition.
  for (const [label, p] of [
    ["bias off", buildSearchPrompt()],
    ["bias on", buildSearchPrompt(undefined, true)],
  ] as const) {
    assert.match(
      p, /"exact"\s+only\s+when\s+the\s+page\s+states\s+BOTH\s+the\s+date\s+and\s+the\s+start\s+time/,
      `${label}: "exact" must be defined`);
    assert.match(
      p, /"approximate"\s+when\s+you\s+are\s+inferring\s+either\s+of\s+them/,
      `${label}: "approximate" must be DEFINED, not merely listed in the schema`);
    assert.match(
      p, /"unknown"\s+when\s+the\s+page\s+gives\s+no\s+clear\s+date\s+or\s+time/,
      `${label}: "unknown" must be defined`);
    // the unknown trigger is WIDER than the one literal phrase "see listing".
    assert.match(p, /"TBD"/, `${label}: "TBD" must trigger unknown`);
    assert.match(p, /"check\s+back"/, `${label}: "check back" must trigger unknown`);
    assert.match(
      p, /or\s+gives\s+no\s+clear\s+date\s+and\s+time/,
      `${label}: a listing with no clear date/time at all must trigger unknown`);
    // and the honest-unknown rule that all of it serves
    assert.match(p, /NEVER\s+invent\s+a\s+time/, `${label}: the never-invent rule`);
  }
});

test("the PICK prompt is a second gate on clinical candidates", () => {
  const { system } = buildPickPrompt([
    { title: "A", date: "sat", venue: "V", url: "https://a", registrationNeeded: false },
  ]);
  assert.match(system, /never pick a clinical, therapeutic, or medical event/);
  assert.match(system, /talk with a mental health/i);
  assert.match(system, /no therapy or counseling session/);
  assert.match(system, /no support group or recovery meeting/);
  assert.match(system, /no health screening, clinic, or medical advice session/);
  assert.match(system, /not care services/);
  // dino's voice survives: still lowercase, still asks for the same json
  assert.match(system, /lowercase/);
  assert.match(system, /"index": number, "why": string/);
});

test("the search prompt hard-stops at 2 or 3 candidates (no quota to fill)", () => {
  for (const p of [buildSearchPrompt(), buildSearchPrompt(undefined, true)]) {
    assert.match(p, /the instant you have 2 or 3 candidates/);
    assert.match(p, /Do not look\s+for more/);
    assert.match(p, /More than 3 is a failure, not thoroughness/);
    // the old "up to 6" quota language is GONE — it was read as a target
    assert.doesNotMatch(p, /up to 6/);
  }
});

// ── summarizeAgentReply (the raw-reply log line's shaping) ──────────────────

test("summarizeAgentReply truncates at the cap and reports the PRE-truncation length", () => {
  const long = "x".repeat(5000);
  const s = summarizeAgentReply(long);
  assert.equal(s.truncated.length, AGENT_REPLY_LOG_CAP);
  assert.equal(s.length, 5000);                 // original length, so a cap hit is obvious
  // a custom cap is honoured; junk caps fall back to the default
  assert.equal(summarizeAgentReply(long, 10).truncated.length, 10);
  assert.equal(summarizeAgentReply(long, 0).truncated.length, AGENT_REPLY_LOG_CAP);
  assert.equal(summarizeAgentReply(long, -5).truncated.length, AGENT_REPLY_LOG_CAP);
  assert.equal(summarizeAgentReply(long, Number.NaN).truncated.length, AGENT_REPLY_LOG_CAP);
  // under the cap is passed through whole
  assert.equal(summarizeAgentReply("short reply").truncated, "short reply");
});

test("summarizeAgentReply flattens newlines/tabs so the reply stays ONE log entry", () => {
  const s = summarizeAgentReply("line one\nline two\r\nline three\ttabbed");
  assert.equal(s.truncated, "line one line two line three tabbed");
  assert.doesNotMatch(s.truncated, /[\r\n\t]/);
  // leading/trailing whitespace is trimmed, runs collapse to a single space
  assert.equal(summarizeAgentReply("\n\n  a    b  \n").truncated, "a b");
});

test("summarizeAgentReply: looksJson is true for [ / { incl. behind a ```json fence", () => {
  assert.equal(summarizeAgentReply('[{"title":"x"}]').looksJson, true);
  assert.equal(summarizeAgentReply('{"candidates":[]}').looksJson, true);
  assert.equal(summarizeAgentReply('```json\n[{"title":"x"}]\n```').looksJson, true);
  assert.equal(summarizeAgentReply('```\n{"candidates":[]}\n```').looksJson, true);
  assert.equal(summarizeAgentReply('\n\n  [{"title":"x"}]').looksJson, true);
  // prose — the case we could not previously tell apart from a genuine "nothing found"
  assert.equal(
    summarizeAgentReply("I could not find any free gentle events this week.").looksJson,
    false);
  assert.equal(summarizeAgentReply("Here is the JSON: [{}]").looksJson, false);
});

test("summarizeAgentReply is safe on empty/undefined/non-string input", () => {
  const empty = { truncated: "", looksJson: false, length: 0 };
  assert.deepEqual(summarizeAgentReply(""), empty);
  assert.deepEqual(summarizeAgentReply(undefined), empty);
  assert.deepEqual(summarizeAgentReply(null), empty);
  assert.deepEqual(summarizeAgentReply(42), empty);
  assert.deepEqual(summarizeAgentReply({ a: 1 }), empty);
  // whitespace-only is not a crash and is not JSON
  assert.deepEqual(summarizeAgentReply("   \n  "), { truncated: "", looksJson: false, length: 6 });
});

test("summarizeAgentReply agrees with parseCandidates on the empty-vs-unparseable split", () => {
  // genuine "nothing found": valid JSON, zero candidates → looksJson TRUE
  const genuine = "[]";
  assert.equal(parseCandidates(genuine).length, 0);
  assert.equal(summarizeAgentReply(genuine).looksJson, true);
  // malformed/prose reply: also zero candidates → looksJson FALSE. That single
  // flag is what makes the two distinguishable in the log.
  const prose = "Sorry, the library calendar had nothing gentle and free this week.";
  assert.equal(parseCandidates(prose).length, 0);
  assert.equal(summarizeAgentReply(prose).looksJson, false);
});
