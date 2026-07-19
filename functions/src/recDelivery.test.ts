import { test } from "node:test";
import assert from "node:assert";
import {
  HOLD_MIN_MINUTES, HOLD_MAX_MINUTES,
  RESCHEDULE_MIN_MINUTES, RESCHEDULE_MAX_MINUTES,
  isValidTz, localDayKey, isQuietHours, localTimeToUtcMs,
  pushOutOfQuietHours, nextDayFirstSlot, applyDailyCap,
  holdDelayMinutes, rescheduleDelayMinutes, computeDeliverAfter,
  isSessionActive, daypartFor, decideSweep, posterPathOrNull,
} from "./recDelivery";

// --- F4: the reveal's poster path gate --------------------------------------

test("posterPathOrNull accepts exactly tmdb's poster shape", () => {
  assert.equal(posterPathOrNull("/rtGDOeG9LzoerkDGZF9dnVeLppL.jpg"), "/rtGDOeG9LzoerkDGZF9dnVeLppL.jpg");
  assert.equal(posterPathOrNull("/a_b-c.9.png"), "/a_b-c.9.png");
});

test("posterPathOrNull drops anything else (never a broken image)", () => {
  assert.equal(posterPathOrNull(undefined), null);
  assert.equal(posterPathOrNull(42), null);
  assert.equal(posterPathOrNull(""), null);
  assert.equal(posterPathOrNull("no-leading-slash.jpg"), null);
  assert.equal(posterPathOrNull("/nested/path.jpg"), null);
  assert.equal(posterPathOrNull("https://evil.example/x.jpg"), null);
  assert.equal(posterPathOrNull("/query.jpg?x=1"), null);
  assert.equal(posterPathOrNull("/noextension"), null);
  assert.equal(posterPathOrNull("/" + "a".repeat(120) + ".jpg"), null);
});

// QUIET HOURS ARE SACRED (owner rubric): every boundary below is asserted
// to the minute, in the USER'S zone, across the overnight wrap and DST.

const NY = "America/New_York";   // UTC-5 in winter, DST-shifting
const TOKYO = "Asia/Tokyo";      // UTC+9, no DST
const MIN = 60_000;

/** deterministic rand: returns the given values in order (last repeats) */
const seq = (...vals: number[]) => {
  let i = 0;
  return () => {
    const v = vals[Math.min(i, vals.length - 1)];
    i += 1;
    return v;
  };
};

/** wall-clock instant in a zone (winter dates dodge DST unless testing it) */
const at = (y: number, mo: number, d: number, hh: number, mm: number, tz: string) =>
  localTimeToUtcMs(y, mo, d, hh, mm, tz);

// --- timezone plumbing -----------------------------------------------------

test("localTimeToUtcMs matches the known winter offset", () => {
  // 21:29 local jan 15 in new york (est, utc-5) = 02:29 utc jan 16
  assert.equal(at(2026, 1, 15, 21, 29, NY), Date.UTC(2026, 0, 16, 2, 29));
  // 08:30 local in tokyo (utc+9) = 23:30 utc the previous day
  assert.equal(at(2026, 1, 16, 8, 30, TOKYO), Date.UTC(2026, 0, 15, 23, 30));
});

test("localTimeToUtcMs is dst aware (us spring forward 2026-03-08)", () => {
  // 08:30 edt (utc-4) the morning after the jump = 12:30 utc
  assert.equal(at(2026, 3, 8, 8, 30, NY), Date.UTC(2026, 2, 8, 12, 30));
  // the evening before is still est (utc-5)
  assert.equal(at(2026, 3, 7, 21, 31, NY), Date.UTC(2026, 2, 8, 2, 31));
});

test("localDayKey follows the user's zone, not utc", () => {
  const ms = Date.UTC(2026, 0, 15, 23, 30);   // 23:30 utc
  assert.equal(localDayKey(ms, TOKYO), "2026-01-16");
  assert.equal(localDayKey(ms, NY), "2026-01-15");
});

test("isValidTz accepts real zones only", () => {
  assert.ok(isValidTz("America/New_York"));
  assert.ok(isValidTz("Asia/Tokyo"));
  assert.equal(isValidTz("Not/AZone"), false);
  assert.equal(isValidTz(""), false);
  assert.equal(isValidTz(undefined), false);
  assert.equal(isValidTz("x".repeat(65)), false);
});

// --- quiet hours boundaries ------------------------------------------------

test("quiet hours boundaries to the minute (21:29 in, 21:30 out, 08:30 in)", () => {
  assert.equal(isQuietHours(at(2026, 1, 15, 21, 29, NY), NY), false);
  assert.equal(isQuietHours(at(2026, 1, 15, 21, 30, NY), NY), true);
  assert.equal(isQuietHours(at(2026, 1, 15, 21, 31, NY), NY), true);
  assert.equal(isQuietHours(at(2026, 1, 16, 3, 0, NY), NY), true);    // overnight wrap
  assert.equal(isQuietHours(at(2026, 1, 16, 8, 29, NY), NY), true);
  assert.equal(isQuietHours(at(2026, 1, 16, 8, 30, NY), NY), false);
  assert.equal(isQuietHours(at(2026, 1, 16, 14, 0, NY), NY), false);
});

test("quiet hours follow the user's zone, never the server's", () => {
  const ms = Date.UTC(2026, 0, 15, 22, 0);   // 22:00 utc
  // tokyo: 07:00 next morning — quiet; new york: 17:00 — daytime
  assert.equal(isQuietHours(ms, TOKYO), true);
  assert.equal(isQuietHours(ms, NY), false);
});

test("pushOutOfQuietHours: 21:31 moves to the next 08:30, 21:29 does not move", () => {
  const evening = at(2026, 1, 15, 21, 31, NY);
  assert.equal(pushOutOfQuietHours(evening, NY), at(2026, 1, 16, 8, 30, NY));
  const beforeCurfew = at(2026, 1, 15, 21, 29, NY);
  assert.equal(pushOutOfQuietHours(beforeCurfew, NY), beforeCurfew);
});

test("pushOutOfQuietHours: early morning moves forward to the same day's 08:30", () => {
  assert.equal(pushOutOfQuietHours(at(2026, 1, 16, 3, 0, NY), NY), at(2026, 1, 16, 8, 30, NY));
  assert.equal(pushOutOfQuietHours(at(2026, 1, 16, 8, 29, NY), NY), at(2026, 1, 16, 8, 30, NY));
  // exactly 08:30 is already out
  const opening = at(2026, 1, 16, 8, 30, NY);
  assert.equal(pushOutOfQuietHours(opening, NY), opening);
});

test("pushOutOfQuietHours applies jitter only when pushed", () => {
  const evening = at(2026, 1, 15, 22, 0, NY);
  assert.equal(pushOutOfQuietHours(evening, NY, 30), at(2026, 1, 16, 9, 0, NY));
  const midday = at(2026, 1, 15, 14, 0, NY);
  assert.equal(pushOutOfQuietHours(midday, NY, 30), midday);
});

test("a push across the dst jump lands on 08:30 in the NEW offset", () => {
  const evening = at(2026, 3, 7, 21, 31, NY);   // est
  assert.equal(pushOutOfQuietHours(evening, NY), Date.UTC(2026, 2, 8, 12, 30));   // 08:30 edt
});

// --- randomization bounds --------------------------------------------------

test("hold delay spans exactly 45..90 minutes", () => {
  assert.equal(holdDelayMinutes(seq(0)), HOLD_MIN_MINUTES);
  assert.equal(holdDelayMinutes(seq(0.9999999)), HOLD_MAX_MINUTES);
  for (let i = 0; i < 500; i++) {
    const d = holdDelayMinutes();
    assert.ok(d >= HOLD_MIN_MINUTES && d <= HOLD_MAX_MINUTES, `out of bounds: ${d}`);
  }
});

test("session back-off spans exactly 15..30 minutes", () => {
  assert.equal(rescheduleDelayMinutes(seq(0)), RESCHEDULE_MIN_MINUTES);
  assert.equal(rescheduleDelayMinutes(seq(0.9999999)), RESCHEDULE_MAX_MINUTES);
  for (let i = 0; i < 500; i++) {
    const d = rescheduleDelayMinutes();
    assert.ok(d >= RESCHEDULE_MIN_MINUTES && d <= RESCHEDULE_MAX_MINUTES, `out of bounds: ${d}`);
  }
});

// --- the full creation-time composition ------------------------------------

test("midday rec: deliverAfter is createdAt + the random hold, untouched", () => {
  const created = at(2026, 1, 15, 13, 0, NY);
  // rand 0.5 → 45 + floor(0.5*46) = 68 minutes; jitter draw unused (no push)
  assert.equal(computeDeliverAfter(created, NY, new Set(), seq(0.5, 0)), created + 68 * MIN);
});

test("20:44 + 45min = 21:29 stays; 20:46 + 45min = 21:31 pushes to 08:30", () => {
  const safe = at(2026, 1, 15, 20, 44, NY);
  assert.equal(computeDeliverAfter(safe, NY, new Set(), seq(0)), safe + 45 * MIN);
  const late = at(2026, 1, 15, 20, 46, NY);
  assert.equal(computeDeliverAfter(late, NY, new Set(), seq(0)), at(2026, 1, 16, 8, 30, NY));
});

test("an overnight rec (23:50 + 45min) waits for the same morning's 08:30", () => {
  const nightOwl = at(2026, 1, 15, 23, 50, NY);
  assert.equal(computeDeliverAfter(nightOwl, NY, new Set(), seq(0)), at(2026, 1, 16, 8, 30, NY));
});

test("quiet push happens in the user's zone (tokyo evening, utc midday)", () => {
  const created = at(2026, 1, 15, 21, 0, TOKYO);   // 12:00 utc — midday to a utc clock
  // + 90 min → 22:30 tokyo → quiet → next tokyo 08:30
  assert.equal(computeDeliverAfter(created, TOKYO, new Set(), seq(0.9999999, 0)),
    at(2026, 1, 16, 8, 30, TOKYO));
});

// --- one announcement per day ----------------------------------------------

test("1/day cap: a blocked day moves the rec to the NEXT day's 08:30", () => {
  const created = at(2026, 1, 15, 13, 0, NY);
  const blocked = new Set(["2026-01-15"]);
  assert.equal(computeDeliverAfter(created, NY, blocked, seq(0)), at(2026, 1, 16, 8, 30, NY));
});

test("1/day cap walks past consecutive blocked days", () => {
  const midday = at(2026, 1, 15, 13, 0, NY);
  const blocked = new Set(["2026-01-15", "2026-01-16"]);
  assert.equal(applyDailyCap(midday, NY, blocked), at(2026, 1, 17, 8, 30, NY));
});

test("nextDayFirstSlot is tomorrow 08:30 local, quiet-safe, jitter additive", () => {
  const lateNight = at(2026, 1, 15, 23, 45, NY);
  const slot = nextDayFirstSlot(lateNight, NY);
  assert.equal(slot, at(2026, 1, 16, 8, 30, NY));
  assert.equal(isQuietHours(slot, NY), false);
  assert.equal(nextDayFirstSlot(lateNight, NY, 12), at(2026, 1, 16, 8, 42, NY));
});

// --- session awareness -----------------------------------------------------

test("isSessionActive: 3 minute window, null-safe, future-stamp counts", () => {
  const now = Date.UTC(2026, 0, 15, 18, 0);
  assert.equal(isSessionActive(null, now), false);
  assert.equal(isSessionActive(now - 2 * MIN, now), true);
  assert.equal(isSessionActive(now - 3 * MIN, now), false);
  assert.equal(isSessionActive(now - 4 * MIN, now), false);
  assert.equal(isSessionActive(now + 30_000, now), true);
});

// --- the sweep decision (idempotency, cap, session, quiet guard) -----------

const baseInput = () => {
  const nowMs = at(2026, 1, 15, 15, 0, NY);   // 15:00 — daytime
  return {
    status: "held",
    createdAtMs: nowMs - 60 * MIN,
    deliverAfterMs: nowMs - 5 * MIN,
    tz: NY,
    nowMs,
    lastActiveAtMs: null as number | null,
    lastAnnouncedDayKey: null as string | null,
  };
};

test("a due, quiet-free, uncapped, inactive delivery announces (once)", () => {
  const d = decideSweep(baseInput(), seq(0));
  assert.deepEqual(d, { action: "announce", dayKey: "2026-01-15" });
});

test("idempotent: anything not 'held' is a skip — never a second announcement", () => {
  for (const status of ["announced", "opened", "expired"]) {
    assert.deepEqual(decideSweep({ ...baseInput(), status }, seq(0)), { action: "skip" });
  }
});

test("not due yet is a skip", () => {
  const input = baseInput();
  input.deliverAfterMs = input.nowMs + 5 * MIN;
  assert.deepEqual(decideSweep(input, seq(0)), { action: "skip" });
});

test("a held rec 3 days stale expires instead of announcing", () => {
  const input = baseInput();
  input.createdAtMs = input.nowMs - 73 * 3600 * 1000;
  assert.deepEqual(decideSweep(input, seq(0)), { action: "expire" });
});

test("active session (heartbeat 2 min ago) → back off 15..30 min, still held", () => {
  const input = baseInput();
  input.lastActiveAtMs = input.nowMs - 2 * MIN;
  const lo = decideSweep(input, seq(0));
  assert.equal(lo.action, "reschedule");
  if (lo.action === "reschedule") {
    assert.equal(lo.reason, "session");
    assert.equal(lo.deliverAfterMs, input.nowMs + 15 * MIN);
  }
  const hi = decideSweep(input, seq(0.9999999, 0));
  if (hi.action === "reschedule") assert.equal(hi.deliverAfterMs, input.nowMs + 30 * MIN);
});

test("a 4-minute-old heartbeat no longer blocks the announcement", () => {
  const input = baseInput();
  input.lastActiveAtMs = input.nowMs - 4 * MIN;
  assert.equal(decideSweep(input, seq(0)).action, "announce");
});

test("second rec, same local day: the cap defers it to tomorrow's first slot", () => {
  const input = baseInput();
  input.lastAnnouncedDayKey = "2026-01-15";
  const d = decideSweep(input, seq(0));
  assert.equal(d.action, "reschedule");
  if (d.action === "reschedule") {
    assert.equal(d.reason, "cap");
    assert.equal(d.deliverAfterMs, at(2026, 1, 16, 8, 30, NY));
  }
});

test("yesterday's announcement never blocks today", () => {
  const input = baseInput();
  input.lastAnnouncedDayKey = "2026-01-14";
  assert.equal(decideSweep(input, seq(0)).action, "announce");
});

test("announce-time quiet guard: a due rec at 22:00 local still waits", () => {
  const input = baseInput();
  input.nowMs = at(2026, 1, 15, 22, 0, NY);
  input.deliverAfterMs = input.nowMs - 5 * MIN;
  input.createdAtMs = input.nowMs - 60 * MIN;
  const d = decideSweep(input, seq(0));
  assert.equal(d.action, "reschedule");
  if (d.action === "reschedule") {
    assert.equal(d.reason, "quiet");
    assert.equal(d.deliverAfterMs, at(2026, 1, 16, 8, 30, NY));
  }
});

// --- daypart vocabulary ----------------------------------------------------

test("daypartFor matches the client's OutcomeLedger boundaries", () => {
  assert.equal(daypartFor(at(2026, 1, 15, 9, 0, NY), NY), "morning");
  assert.equal(daypartFor(at(2026, 1, 15, 13, 0, NY), NY), "afternoon");
  assert.equal(daypartFor(at(2026, 1, 15, 19, 0, NY), NY), "evening");
  assert.equal(daypartFor(at(2026, 1, 15, 23, 0, NY), NY), "night");
  assert.equal(daypartFor(at(2026, 1, 16, 3, 0, NY), NY), "night");
});
