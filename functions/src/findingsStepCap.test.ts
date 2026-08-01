// findingsStepCap.test.ts — VERIFICATION-PASS proof for the 15-step kill and
// the no-leaked-billed-session guarantee.
//
// The pre-existing agiClient suite proves the kill at a synthetic cap of 5.
// This file proves it at the REAL shipped cap (MAX_AGENT_STEPS === 15) and
// proves that terminate + deleteSession fire from the `finally` on EVERY exit:
// the step-cap kill, the wall-clock kill (both the in-stream check and the
// AbortController path), the error path, and a throw from cleanup itself.
//
// deleteSession is the assertion that matters for money: cancel/terminate stop
// the agent, but DELETE /sessions/:id is what tears the billed sandbox down.

import test from "node:test";
import assert from "node:assert/strict";
import { runAgentTask, type AgiTransport, type SessionHandle } from "./agiClient";
import {
  MAX_AGENT_STEPS,
  MAX_BOOKING_STEPS,
  COST_PER_STEP_USD,
  MAX_SEARCH_COST_USD,
  MAX_BOOKING_COST_USD,
  MAX_FINDING_PLUS_BOOKING_COST_USD,
  WALL_CLOCK_MS,
  costForSteps,
  type AgiMessage,
} from "./starFindings";

type Recorder = AgiTransport & {
  cancelled: string[]; terminated: string[]; deleted: string[];
  created: number; started: number; pulled: number;
  /** how many THOUGHTs the stream was ALLOWED to hand over before the kill. */
  yielded: number;
};

/**
 * A scripted transport that counts how many messages were actually PULLED off
 * the stream. `pulled` is the proof the loop stopped consuming — a cap that
 * only reports "killed" after draining the whole stream would still be billed.
 */
function recordingTransport(script: AgiMessage[], opts: {
  throwOnStream?: boolean;
  hangUntilAbort?: boolean;
  throwOnTerminate?: boolean;
} = {}): Recorder {
  const rec: Recorder = {
    cancelled: [], terminated: [], deleted: [], created: 0, started: 0, pulled: 0, yielded: 0,
    async createSession(): Promise<SessionHandle> {
      rec.created++;
      return { id: "sess-1", agentUrl: "http://agent" };
    },
    async startTask() { rec.started++; },
    async *streamEvents(_h: SessionHandle, signal: AbortSignal) {
      if (opts.throwOnStream) throw new Error("network boom");
      if (opts.hangUntilAbort) {
        await new Promise<void>((resolve) => {
          if (signal.aborted) return resolve();
          signal.addEventListener("abort", () => resolve(), { once: true });
        });
        throw Object.assign(new Error("aborted"), { name: "AbortError" });
      }
      for (const m of script) { rec.pulled++; rec.yielded++; yield m; }
    },
    async cancel(h: SessionHandle) { rec.cancelled.push(h.id); },
    async terminate(h: SessionHandle) {
      rec.terminated.push(h.id);
      if (opts.throwOnTerminate) throw new Error("terminate 500");
    },
    async deleteSession(h: SessionHandle) { rec.deleted.push(h.id); },
  };
  return rec;
}

const thoughts = (n: number): AgiMessage[] =>
  Array.from({ length: n }, (_, k) => ({ id: `t-${k}`, type: "THOUGHT" as const, content: `step ${k}` }));

// ── the 15-step kill ────────────────────────────────────────────────────────

test("STEP CAP: at exactly 15 THOUGHTs the run is killed with reason step_cap", async () => {
  // 15 real THOUGHTs, then 5 more the loop must NEVER pull (each would bill).
  const tx = recordingTransport([...thoughts(MAX_AGENT_STEPS), ...thoughts(5)]);
  const res = await runAgentTask({ prompt: "search", startUrl: "https://x", transport: tx });

  assert.equal(MAX_AGENT_STEPS, 15, "the shipped cap this test is about");
  assert.equal(res.outcome, "killed");
  assert.equal(res.killReason, "step_cap");
  assert.equal(res.thoughts, 15, "the tally stops AT the cap, never past it");
  assert.equal(tx.pulled, 15, "the loop pulled exactly 15 messages and stopped consuming");
});

test("STEP CAP: the kill fires WITHOUT an explicit maxSteps — the default is the shipped cap", async () => {
  const tx = recordingTransport(thoughts(MAX_AGENT_STEPS + 10));
  const res = await runAgentTask({ prompt: "search", startUrl: "https://x", transport: tx });
  assert.equal(res.killReason, "step_cap");
  assert.equal(res.thoughts, MAX_AGENT_STEPS);
});

test("STEP CAP: 14 THOUGHTs then DONE finishes cleanly — the cap does not fire early", async () => {
  const tx = recordingTransport([
    ...thoughts(MAX_AGENT_STEPS - 1),
    { id: "d", type: "DONE", content: "[]" },
  ]);
  const res = await runAgentTask({ prompt: "search", startUrl: "https://x", transport: tx });
  assert.equal(res.outcome, "finished");
  assert.equal(res.killReason, null);
  assert.equal(res.thoughts, 14);
});

// ── SEARCH and BOOKING do not share a cap ────────────────────────────
//
// A search converges in 6-8 steps, so 15 is generous for it. A BOOKING run
// starts on a LISTING page and realistically needs 8-14 steps before it even
// reaches a form — under the search cap it was structurally likely to die
// before filling a single field, and the booking path has never once executed
// to completion. These pin the split so a future "tidy up the constants" pass
// cannot quietly collapse them back into one.

test("SPLIT CAP: search (15) and booking (25) are DISTINCT constants", () => {
  assert.equal(MAX_AGENT_STEPS, 15, "the search cap");
  assert.equal(MAX_BOOKING_STEPS, 25, "the booking cap");
  assert.notEqual(
    MAX_AGENT_STEPS, MAX_BOOKING_STEPS,
    "search and booking must NOT share a cap");
  assert.ok(
    MAX_BOOKING_STEPS > MAX_AGENT_STEPS,
    "booking needs 8-14 steps just to reach a form, so its cap must be the larger one");
});

test("SPLIT CAP: the BOOKING path runs to 25, where the search cap would have killed it at 15", async () => {
  // 20 THOUGHTs: past the SEARCH cap, inside the BOOKING cap. This is exactly
  // the window where a real booking reaches the form.
  const tx = recordingTransport([
    ...thoughts(20),
    { id: "d", type: "DONE", content: '{ "status": "completed" }' },
  ]);
  // the SEARCH cap would have killed this exact run
  assert.ok(20 > MAX_AGENT_STEPS, "20 steps is past the search cap");
  const res = await runAgentTask({
    prompt: "book", startUrl: "https://x", transport: tx, maxSteps: MAX_BOOKING_STEPS,
  });
  assert.equal(res.outcome, "finished", "a 20-step booking finishes under the booking cap");
  assert.equal(res.killReason, null);
  assert.equal(res.thoughts, 20);
});

test("SPLIT CAP: the booking cap still kills — at 25, not at 15", async () => {
  const tx = recordingTransport(thoughts(MAX_BOOKING_STEPS + 5));
  const res = await runAgentTask({
    prompt: "book", startUrl: "https://x", transport: tx, maxSteps: MAX_BOOKING_STEPS,
  });
  assert.equal(res.killReason, "step_cap");
  assert.equal(res.thoughts, MAX_BOOKING_STEPS, "the tally stops AT 25");
  assert.equal(tx.pulled, MAX_BOOKING_STEPS, "and stopped consuming there");
  assert.deepEqual(tx.deleted, ["sess-1"], "the billed sandbox is still torn down");
});

// ── cost telemetry: search and booking exposure, separately ──────────────

test("COST: search max $0.30, booking max $0.50, one finding + one booking $0.80", () => {
  assert.equal(COST_PER_STEP_USD, 0.02);
  assert.equal(costForSteps(MAX_AGENT_STEPS), 0.30);
  assert.equal(costForSteps(MAX_BOOKING_STEPS), 0.50);
  // the documented figures must MATCH what the math actually produces — a
  // constant drifting away from its own comment is how a cost claim goes stale.
  assert.equal(MAX_SEARCH_COST_USD, costForSteps(MAX_AGENT_STEPS));
  assert.equal(MAX_BOOKING_COST_USD, costForSteps(MAX_BOOKING_STEPS));
  assert.equal(MAX_FINDING_PLUS_BOOKING_COST_USD, 0.80);
  assert.equal(
    MAX_SEARCH_COST_USD + MAX_BOOKING_COST_USD,
    MAX_FINDING_PLUS_BOOKING_COST_USD,
    "the pair figure must be the sum of the two phase figures");
});

test("TIMING: a full 25-step booking fits inside the wall clock, which fits inside the client's wait", () => {
  // observed ~6.6s per step (1s stepDelaySeconds + the vendor's own latency).
  const SECONDS_PER_STEP = 6.6;
  const CLIENT_TIMEOUT_MS = 300 * 1000;   // FindingsService.confirmFindingTimeout
  const bookingWorstCaseMs = MAX_BOOKING_STEPS * SECONDS_PER_STEP * 1000;
  assert.ok(bookingWorstCaseMs < WALL_CLOCK_MS,
    `a 25-step booking (~${bookingWorstCaseMs / 1000}s) must finish inside the wall clock (${WALL_CLOCK_MS / 1000}s)`);
  assert.ok(WALL_CLOCK_MS < CLIENT_TIMEOUT_MS,
    "the server must always finish before the client stops waiting on a BILLING run");
});

// ── the cleanup guarantee (no leaked billed session) ────────────────────────

test("CLEANUP on the step-cap kill: cancel + terminate + DELETE all fire", async () => {
  const tx = recordingTransport(thoughts(MAX_AGENT_STEPS + 3));
  const res = await runAgentTask({ prompt: "search", startUrl: "https://x", transport: tx });
  assert.equal(res.killReason, "step_cap");
  assert.deepEqual(tx.cancelled, ["sess-1"], "a kill adds a cancel");
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"], "DELETE /sessions/:id — the billed sandbox is torn down");
});

test("CLEANUP on the ERROR path: a stream throw still terminates + DELETEs", async () => {
  const tx = recordingTransport([], { throwOnStream: true });
  const res = await runAgentTask({ prompt: "search", startUrl: "https://x", transport: tx });
  assert.equal(res.outcome, "error");
  assert.equal(res.errored, true);
  assert.equal(tx.created, 1, "a session WAS created, so it MUST be torn down");
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"]);
});

test("CLEANUP on the WALL-CLOCK path (AbortController): timeout kill still terminates + DELETEs", async () => {
  // the stream never yields; the wall-clock timer aborts it.
  const tx = recordingTransport([], { hangUntilAbort: true });
  const res = await runAgentTask({
    prompt: "search", startUrl: "https://x", transport: tx, wallClockMs: 40,
  });
  assert.equal(res.outcome, "killed");
  assert.equal(res.killReason, "timeout");
  assert.deepEqual(tx.cancelled, ["sess-1"]);
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"]);
});

test("CLEANUP on the WALL-CLOCK path (in-stream check): timeout kill still terminates + DELETEs", async () => {
  // an injected clock that jumps past the ceiling after the first THOUGHT, so
  // killDecision's elapsedMs branch is what fires rather than the abort.
  let t = 0;
  const tx = recordingTransport(thoughts(5));
  const res = await runAgentTask({
    prompt: "search", startUrl: "https://x", transport: tx,
    wallClockMs: 1000, now: () => (t += 900),
  });
  assert.equal(res.outcome, "killed");
  assert.equal(res.killReason, "timeout");
  assert.equal(tx.pulled, 2, "the loop stopped consuming as soon as the clock tripped");
  assert.deepEqual(tx.cancelled, ["sess-1"]);
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"]);
});

test("CLEANUP is not defeated by a THROWING terminate — the DELETE still fires", async () => {
  const tx = recordingTransport(thoughts(MAX_AGENT_STEPS), { throwOnTerminate: true });
  const res = await runAgentTask({ prompt: "search", startUrl: "https://x", transport: tx });
  assert.equal(res.killReason, "step_cap");
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"], "a failed terminate must not skip the DELETE");
});

test("CLEANUP: a QUESTION (booking handoff) also terminates + DELETEs, with no cancel", async () => {
  const tx = recordingTransport([
    ...thoughts(3),
    { id: "q", type: "QUESTION", content: "date of birth?" },
  ]);
  const res = await runAgentTask({ prompt: "book", startUrl: "https://x", transport: tx });
  assert.equal(res.outcome, "waiting");
  assert.deepEqual(tx.cancelled, [], "a handoff is not a kill");
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"]);
});
