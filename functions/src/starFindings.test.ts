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
  assert.equal(MAX_AGENT_STEPS, 30);
  assert.equal(MAX_TASKS_PER_DAY, 5);
  assert.equal(AGENT_REPLY_LOG_CAP, 1200);
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
