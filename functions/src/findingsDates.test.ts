// findingsDates.test.ts — pure tests for the STRUCTURED-DATE fix and the
// BOOKABLE-BIAS toggle.
//
// New test FILE (no existing test file is modified).
//
// THE BUG THESE COVER: the finding's only date was free text ("this saturday
// 2pm"), so the client could not schedule from it and fell back to a hardcoded
// "tomorrow 18:00" — a Jul 28 find landed on Jul 29. The fix moves the date to
// the AGENT-OUTPUT level (startISO/endISO/dateConfidence), and the whole point
// is that a time the agent will not vouch for must never reach the calendar.

import test from "node:test";
import assert from "node:assert/strict";
import {
  sanitizeStartISO,
  coerceDateConfidence,
  parsePreferBookable,
  parseCandidates,
  buildSearchPrompt,
  outcomeForFinding,
} from "./starFindings";

/** A fixed "now" so every bound in these tests is deterministic. */
const NOW = new Date("2026-07-28T12:00:00-05:00");

// ── sanitizeStartISO ────────────────────────────────────────────────────────

test("sanitizeStartISO accepts a well-formed ISO 8601 WITH an explicit offset", () => {
  assert.equal(sanitizeStartISO("2026-08-02T14:00:00-05:00", NOW), "2026-08-02T14:00:00-05:00");
  // Z is an explicit offset; seconds and fractional seconds are optional
  assert.equal(sanitizeStartISO("2026-08-02T19:00:00Z", NOW), "2026-08-02T19:00:00Z");
  assert.equal(sanitizeStartISO("2026-08-02T14:00-05:00", NOW), "2026-08-02T14:00-05:00");
  assert.equal(sanitizeStartISO("2026-08-02T14:00:00.500-05:00", NOW), "2026-08-02T14:00:00.500-05:00");
  // surrounding whitespace is trimmed, not baked in
  assert.equal(sanitizeStartISO("  2026-08-02T14:00:00-05:00 ", NOW), "2026-08-02T14:00:00-05:00");
});

test("sanitizeStartISO REJECTS an offset-less local time (it would be re-read in the wrong zone)", () => {
  assert.equal(sanitizeStartISO("2026-08-02T14:00:00", NOW), null);
  assert.equal(sanitizeStartISO("2026-08-02T14:00", NOW), null);
  assert.equal(sanitizeStartISO("2026-08-02", NOW), null);
  assert.equal(sanitizeStartISO("2026-08-02 14:00:00-05:00", NOW), null);   // space, not T
  assert.equal(sanitizeStartISO("2026-08-02T14:00:00-5:00", NOW), null);    // malformed offset
});

test("sanitizeStartISO rejects the past beyond a ~1h grace, and keeps the grace window", () => {
  assert.equal(sanitizeStartISO("2026-07-20T14:00:00-05:00", NOW), null);   // last week
  assert.equal(sanitizeStartISO("2025-08-02T14:00:00-05:00", NOW), null);   // last year
  assert.equal(sanitizeStartISO("2026-07-28T09:00:00-05:00", NOW), null);   // 3h ago
  // inside the grace: an event that started 30 minutes ago still schedules
  assert.equal(sanitizeStartISO("2026-07-28T11:30:00-05:00", NOW), "2026-07-28T11:30:00-05:00");
  // right now is fine
  assert.equal(sanitizeStartISO("2026-07-28T12:00:00-05:00", NOW), "2026-07-28T12:00:00-05:00");
});

test("sanitizeStartISO rejects an absurd future (> 1 year out) but allows inside a year", () => {
  assert.equal(sanitizeStartISO("2126-08-02T14:00:00-05:00", NOW), null);   // typo'd century
  assert.equal(sanitizeStartISO("2028-08-02T14:00:00-05:00", NOW), null);   // 2 years out
  assert.equal(sanitizeStartISO("2027-06-02T14:00:00-05:00", NOW), "2027-06-02T14:00:00-05:00");
});

test("sanitizeStartISO returns null for garbage / wrong types, and never throws", () => {
  assert.equal(sanitizeStartISO("see listing", NOW), null);
  assert.equal(sanitizeStartISO("this saturday, 2pm", NOW), null);
  assert.equal(sanitizeStartISO("", NOW), null);
  assert.equal(sanitizeStartISO("   ", NOW), null);
  assert.equal(sanitizeStartISO(undefined, NOW), null);
  assert.equal(sanitizeStartISO(null, NOW), null);
  assert.equal(sanitizeStartISO(42, NOW), null);
  assert.equal(sanitizeStartISO({ startISO: "2026-08-02T14:00:00-05:00" }, NOW), null);
  assert.equal(sanitizeStartISO(["2026-08-02T14:00:00-05:00"], NOW), null);
  // shape-valid but not a real instant → Date.parse is NaN
  assert.equal(sanitizeStartISO("2026-13-45T99:99:00-05:00", NOW), null);
});

// ── dateConfidence coercion ─────────────────────────────────────────────────

test("coerceDateConfidence is always unknown with no startISO", () => {
  assert.equal(coerceDateConfidence("exact", false), "unknown");
  assert.equal(coerceDateConfidence("approximate", false), "unknown");
  assert.equal(coerceDateConfidence(undefined, false), "unknown");
});

test("coerceDateConfidence honors the enum and lands unlabeled times on approximate", () => {
  assert.equal(coerceDateConfidence("exact", true), "exact");
  assert.equal(coerceDateConfidence("  EXACT ", true), "exact");
  assert.equal(coerceDateConfidence("approximate", true), "approximate");
  assert.equal(coerceDateConfidence("unknown", true), "unknown");
  // a real time the agent never labeled → the honest middle, never "exact"
  assert.equal(coerceDateConfidence(undefined, true), "approximate");
  assert.equal(coerceDateConfidence("pretty sure", true), "approximate");
  assert.equal(coerceDateConfidence(7, true), "approximate");
});

// ── parseCandidates carries (and disowns) the machine date ──────────────────

test("parseCandidates carries a valid structured date through", () => {
  const raw = JSON.stringify([{
    title: "Hatha Yoga Class", date: "this sunday, 2pm", venue: "SPPL",
    url: "https://sppl.org/e", registration_needed: false,
    startISO: "2026-08-02T14:00:00-05:00", endISO: "2026-08-02T15:00:00-05:00",
    dateConfidence: "exact",
  }]);
  const [c] = parseCandidates(raw, NOW);
  assert.equal(c.startISO, "2026-08-02T14:00:00-05:00");
  assert.equal(c.endISO, "2026-08-02T15:00:00-05:00");
  assert.equal(c.dateConfidence, "exact");
  assert.equal(c.date, "this sunday, 2pm");   // free text still there for display
});

test('parseCandidates DISOWNS the time when the agent says "unknown"', () => {
  const raw = JSON.stringify([{
    title: "Park Walk", url: "https://stpaul.gov/como", date: "see listing",
    startISO: "2026-08-02T14:00:00-05:00", dateConfidence: "unknown",
  }]);
  const [c] = parseCandidates(raw, NOW);
  assert.equal(c.startISO, null, "a time the agent won't vouch for must not survive");
  assert.equal(c.dateConfidence, "unknown");
});

test("parseCandidates nulls a bad/offset-less/past start and forces unknown", () => {
  const cases = [
    { startISO: "2026-08-02T14:00:00", dateConfidence: "exact" },   // no offset
    { startISO: "2026-07-01T14:00:00-05:00", dateConfidence: "exact" }, // past
    { startISO: "see listing", dateConfidence: "exact" },
    {},                                                              // absent entirely
  ];
  for (const extra of cases) {
    const [c] = parseCandidates(JSON.stringify([
      { title: "T", url: "https://x.org/e", ...extra },
    ]), NOW);
    assert.equal(c.startISO, null);
    assert.equal(c.endISO, null);
    assert.equal(c.dateConfidence, "unknown");
  }
});

test("parseCandidates drops an end that is not strictly after the start", () => {
  const mk = (endISO: string) => parseCandidates(JSON.stringify([{
    title: "T", url: "https://x.org/e",
    startISO: "2026-08-02T14:00:00-05:00", endISO, dateConfidence: "exact",
  }]), NOW)[0];
  assert.equal(mk("2026-08-02T13:00:00-05:00").endISO, null);   // before
  assert.equal(mk("2026-08-02T14:00:00-05:00").endISO, null);   // equal
  assert.equal(mk("2026-08-02T16:30:00-05:00").endISO, "2026-08-02T16:30:00-05:00");
});

test("parseCandidates still shape-checks and still defaults with no now passed", () => {
  // the legacy shape (no date fields at all) parses cleanly, just date-less
  const [c] = parseCandidates('[{"title":"A","url":"https://a.b","date":"sat"}]');
  assert.equal(c.title, "A");
  assert.equal(c.startISO, null);
  assert.equal(c.dateConfidence, "unknown");
  assert.deepEqual(parseCandidates("garbage", NOW), []);
});

// ── outcome/state mapping (the card's action still keys off registration) ────

test("outcome mapping is unchanged by the date fields", () => {
  assert.deepEqual(outcomeForFinding(null), { status: "empty", card: "empty_handed" });
  assert.deepEqual(
    outcomeForFinding({ registrationNeeded: false }),
    { status: "found", card: "add_to_calendar" });
  assert.deepEqual(
    outcomeForFinding({ registrationNeeded: true, url: "https://x.org/e" }),
    { status: "found", card: "book_it" });
  assert.deepEqual(
    outcomeForFinding({ registrationNeeded: true, url: null }),
    { status: "found", card: "finish_signup" });
  // a date-less candidate is still a normal found candidate on the server —
  // it is the CLIENT that refuses to fabricate an event from it.
  const dateless = parseCandidates(
    '[{"title":"T","url":"https://x.org/e","date":"see listing"}]', NOW)[0];
  assert.equal(dateless.startISO, null);
  assert.equal(outcomeForFinding(dateless).card, "add_to_calendar");
});

// ── the prompt's structured-date contract ───────────────────────────────────

test("buildSearchPrompt demands the machine-readable date fields and forbids invention", () => {
  const p = buildSearchPrompt();
  assert.match(p, /startISO/);
  assert.match(p, /endISO/);
  assert.match(p, /dateConfidence/);
  assert.match(p, /America\/Chicago/);
  assert.match(p, /2026-08-02T14:00:00-05:00/);      // the worked example
  assert.match(p, /NEVER invent a time/);
  assert.match(p, /see listing/);
  assert.match(p, /An offset is REQUIRED/);
  assert.match(p, /MACHINE-READ/);
  // the free-text field survives for display
  assert.match(p, /"date": string/);
});

// ── the preferBookable toggle ───────────────────────────────────────────────

test("parsePreferBookable: absent → false, booleans pass, everything else is rejected", () => {
  assert.deepEqual(parsePreferBookable(undefined), { ok: true, value: false });
  assert.deepEqual(parsePreferBookable(null), { ok: true, value: false });
  assert.deepEqual(parsePreferBookable(true), { ok: true, value: true });
  assert.deepEqual(parsePreferBookable(false), { ok: true, value: false });
  // strict: no quiet coercion of truthy junk
  for (const bad of ["true", "false", 1, 0, "", [], {}, "yes"]) {
    assert.deepEqual(parsePreferBookable(bad), { ok: false }, `should reject ${JSON.stringify(bad)}`);
  }
});

test("preferBookable PREFERS registration sources and demands a fallback, ONLY when true", () => {
  const off = buildSearchPrompt();
  const on = buildSearchPrompt(undefined, true);
  const bookableOnly = [
    /BOOKABLE BIAS/,
    // the registration sources are still named, and named FIRST
    /registration portals/,
    /library program registration pages/,
    /community education class/i,
    /parks and recreation class registration/,
    // …but the bias PREFERS rather than RESTRICTS: an explicit fallback to the
    // general listings, and an honest registrationNeeded.
    /PREFERENCE, not a restriction/,
    /FALL BACK to the general gentle event listings/,
    /rather than returning nothing/,
    /Set registrationNeeded HONESTLY/,
  ];
  for (const re of bookableOnly) {
    assert.match(on, re, `preferBookable=true must mention ${re}`);
    assert.doesNotMatch(off, re, `preferBookable=false must NOT mention ${re}`);
  }
  // the preferred sources are introduced BEFORE the fallback escape hatch
  assert.ok(
    on.indexOf("library program registration pages") < on.indexOf("FALL BACK"),
    "registration sources must be listed first, the fallback second");
  // the performance rules that got runs down to 5-6 steps survive the softening.
  // The bias no longer RE-STATES them (that repetition was prompt bloat); the
  // shared BE DECISIVE block below the branch is the single place they live.
  for (const p of [off, on]) {
    assert.match(p, /Do NOT open each event's detail page/);
    assert.match(p, /the instant you have 2 or 3 candidates/);
  }
  // explicit default arg parity: buildSearchPrompt() === buildSearchPrompt(city, false)
  assert.equal(off, buildSearchPrompt(undefined, false));
});

test("the do-not-open-each-event rule and the step budget hold in BOTH branches", () => {
  for (const p of [buildSearchPrompt(), buildSearchPrompt(undefined, true)]) {
    assert.match(p, /Do NOT open each event's detail page/);
    assert.match(p, /BE DECISIVE/);
    assert.match(p, /STOP browsing and reply/);
    assert.match(p, /limited number of steps/);
  }
});

test("preferBookable never changes the city or the gentle/free framing", () => {
  const on = buildSearchPrompt(undefined, true);
  assert.match(on, /Saint Paul, Minnesota/);
  assert.match(on, /FREE/);
  assert.match(on, /Avoid anything/);
  assert.match(buildSearchPrompt("Duluth, Minnesota", true), /Duluth, Minnesota/);
});
