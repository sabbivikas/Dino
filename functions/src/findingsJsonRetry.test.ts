// findingsJsonRetry.test.ts — pure tests for the ONE-SHOT JSON RETRY, the
// hard JSON-only output contract, and the clinical/therapeutic exclusion.
//
// New test FILE (no existing test file is modified).
//
// THE BUG THESE COVER (task opPrIgf6Akl3TpIrXdjD): the agent used 4 of its 30
// steps, found six real gentle free Saint Paul events, then NARRATED them in
// prose ("Let me compile the results now") and the session ended before the
// JSON array appeared. parseCandidates saw nothing, the run reported `empty`,
// and 26 steps of budget went unused. That is an output-format failure, not a
// search failure — so we ask ONCE more, in the SAME session, for just the JSON.

import test from "node:test";
import assert from "node:assert/strict";
import {
  shouldRetryForJson,
  JSON_RETRY_MESSAGE,
  JSON_RETRY_STEP_MARGIN,
  MAX_AGENT_STEPS,
  buildSearchPrompt,
  buildPickPrompt,
  parseCandidates,
  summarizeAgentReply,
  type AgiMessage,
} from "./starFindings";
import {
  runAgentTask,
  type AgiTransport,
  type SessionHandle,
  type StartTaskRequest,
} from "./agiClient";

// ── shouldRetryForJson (the budget-gated decision) ──────────────────────────

/** The exact shape of the incident: prose, nothing parsed, 4 of 30 steps. */
const INCIDENT = {
  candidates: 0,
  looksJson: false,
  stepsUsed: 4,
  maxSteps: MAX_AGENT_STEPS,
  alreadyRetried: false,
};

test("shouldRetryForJson RETRIES the incident: prose, zero candidates, budget left", () => {
  assert.equal(shouldRetryForJson(INCIDENT), true);
  // and the margin is the documented one
  assert.equal(JSON_RETRY_STEP_MARGIN, 5);
});

test("shouldRetryForJson NEVER retries twice", () => {
  assert.equal(shouldRetryForJson({ ...INCIDENT, alreadyRetried: true }), false);
});

test("shouldRetryForJson does not retry a reply that already parsed", () => {
  assert.equal(shouldRetryForJson({ ...INCIDENT, candidates: 1 }), false);
  assert.equal(shouldRetryForJson({ ...INCIDENT, candidates: 6 }), false);
});

test("shouldRetryForJson does not retry a genuine [] (looksJson true)", () => {
  // the agent answered in the contract's own language and found nothing —
  // asking again would burn steps to receive the same honest empty.
  assert.equal(shouldRetryForJson({ ...INCIDENT, looksJson: true }), false);
  assert.equal(summarizeAgentReply("[]").looksJson, true);
  assert.equal(parseCandidates("[]").length, 0);
});

test("shouldRetryForJson keeps a hard margin under the step cap", () => {
  const at = (stepsUsed: number) => shouldRetryForJson({ ...INCIDENT, stepsUsed });
  // 30 - 5 = 25 is the last step count that may still start a retry
  assert.equal(at(MAX_AGENT_STEPS - JSON_RETRY_STEP_MARGIN), true);      // 25
  assert.equal(at(MAX_AGENT_STEPS - JSON_RETRY_STEP_MARGIN + 1), false); // 26
  assert.equal(at(MAX_AGENT_STEPS - 1), false);                          // 29
  assert.equal(at(MAX_AGENT_STEPS), false);                              // 30
  assert.equal(at(MAX_AGENT_STEPS + 9), false);                          // over
  assert.equal(at(0), true);
  // a custom (low) cap gets the same margin, so a tiny budget never retries
  assert.equal(shouldRetryForJson({ ...INCIDENT, stepsUsed: 1, maxSteps: 5 }), false);
  assert.equal(shouldRetryForJson({ ...INCIDENT, stepsUsed: 0, maxSteps: 5 }), true);
  assert.equal(shouldRetryForJson({ ...INCIDENT, stepsUsed: 0, maxSteps: 3 }), false);
});

test("shouldRetryForJson fails closed on unreadable numbers", () => {
  assert.equal(shouldRetryForJson({ ...INCIDENT, stepsUsed: Number.NaN }), false);
  assert.equal(shouldRetryForJson({ ...INCIDENT, stepsUsed: -1 }), false);
  assert.equal(shouldRetryForJson({ ...INCIDENT, candidates: Number.NaN }), false);
  // a junk cap falls back to the documented 30
  assert.equal(shouldRetryForJson({ ...INCIDENT, maxSteps: Number.NaN }), true);
  assert.equal(
    shouldRetryForJson({ ...INCIDENT, stepsUsed: 26, maxSteps: Number.NaN }), false);
});

// ── the retry message ───────────────────────────────────────────────────────

test("JSON_RETRY_MESSAGE asks for ONLY the array and offers the honest empty", () => {
  assert.match(JSON_RETRY_MESSAGE, /ONLY the JSON array/);
  assert.match(JSON_RETRY_MESSAGE, /no prose/);
  assert.match(JSON_RETRY_MESSAGE, /no markdown fence/);
  assert.match(JSON_RETRY_MESSAGE, /start with \[ and end with \]/);
  assert.match(JSON_RETRY_MESSAGE, /If you truly have none, reply with \[\]/);
  // the schema rides along so the agent re-formats rather than re-searches
  assert.match(JSON_RETRY_MESSAGE, /registrationNeeded/);
  assert.match(JSON_RETRY_MESSAGE, /startISO/);
  assert.match(JSON_RETRY_MESSAGE, /dateConfidence/);
  assert.match(JSON_RETRY_MESSAGE, /Do not browse any further/);
});

// ── the JSON-only OUTPUT CONTRACT (both branches, and LAST) ─────────────────

test("the JSON-only output contract is present in BOTH bias branches", () => {
  for (const p of [buildSearchPrompt(), buildSearchPrompt(undefined, true)]) {
    assert.match(p, /OUTPUT CONTRACT/);
    assert.match(p, /Your FINAL message must be ONLY the JSON array/);
    assert.match(p, /Do not describe what you found in words/);
    assert.match(p, /start with \[ and end with \]/);
    assert.match(p, /let me compile the results now/);
    assert.match(p, /is a FAILED run/);
    assert.match(p, /your entire final message is exactly: \[\]/);
  }
});

test("the output contract sits at the END of the prompt (recency)", () => {
  for (const p of [buildSearchPrompt(), buildSearchPrompt(undefined, true)]) {
    // it is the LAST thing the agent reads
    assert.ok(
      p.trimEnd().endsWith("- If you truly found nothing, your entire final message is exactly: []"),
      "the contract's closing line must be the prompt's last line");
    // …after every other block, including the date rules and the bias branch
    assert.ok(p.indexOf("OUTPUT CONTRACT") > p.indexOf("NEVER invent a time"));
    assert.ok(p.indexOf("OUTPUT CONTRACT") > p.indexOf("BE DECISIVE"));
    assert.ok(p.indexOf("OUTPUT CONTRACT") > p.indexOf("NOT CARE SERVICES"));
    // and it lives in the final tenth of the prompt
    assert.ok(p.indexOf("OUTPUT CONTRACT") > p.length * 0.8);
  }
});

// ── clinical / therapeutic / medical exclusion ──────────────────────────────
//
// Owner: "Talk with a Mental Health Professional" surfaced twice as a finding.
// Findings must exclude care-delivery content the same way the comfort recs do
// ("never clinical or academic works … comfort means escape and warmth, not a
// mirror of what they are feeling").

test("the search prompt excludes clinical/therapeutic/medical events in BOTH branches", () => {
  for (const p of [buildSearchPrompt(), buildSearchPrompt(undefined, true)]) {
    assert.match(p, /NOT CARE SERVICES/);
    assert.match(p, /never care delivery/);
    assert.match(p, /clinical, therapeutic, or\nmedical-service event/);
    assert.match(p, /therapy or counseling sessions/);
    assert.match(p, /talk with a mental health professional/i);
    assert.match(p, /support groups/);
    assert.match(p, /recovery or twelve step meetings/);
    assert.match(p, /health screenings/);
    assert.match(p, /vaccination or flu shot clinics/);
    assert.match(p, /medical advice or diagnosis session/);
    assert.match(p, /not a mirror of what someone/);
    // …while the gentle non-clinical things are explicitly KEPT
    assert.match(p, /KEEP the genuinely gentle non-clinical things/);
    assert.match(p, /storytime/);
    assert.match(p, /gardens and nature/);
    assert.match(p, /crafts and open studios/);
    assert.match(p, /library programs, museum hours/);
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

// ── the same-session follow-up in runAgentTask ──────────────────────────────

/**
 * A scripted transport whose /events stream yields a DIFFERENT script per open,
 * so a first turn and a follow-up turn can be modeled independently. Records
 * every startTask so the test can prove the follow-up went to the SAME session
 * without a start_url.
 */
function scriptedTransport(scripts: AgiMessage[][]): AgiTransport & {
  created: number; starts: StartTaskRequest[]; opens: number;
  cancelled: string[]; terminated: string[]; deleted: string[];
  throwOnStart2?: boolean;
} {
  return {
    created: 0,
    starts: [] as StartTaskRequest[],
    opens: 0,
    cancelled: [] as string[],
    terminated: [] as string[],
    deleted: [] as string[],
    throwOnStart2: false,
    async createSession(): Promise<SessionHandle> {
      this.created++;
      return { id: "sess-1", agentUrl: "http://agent" };
    },
    async startTask(_h: SessionHandle, req: StartTaskRequest) {
      if (this.throwOnStart2 && this.starts.length === 1) {
        this.starts.push(req);
        throw new Error("follow-up post failed");
      }
      this.starts.push(req);
    },
    async *streamEvents() {
      const script = scripts[this.opens++] ?? [];
      for (const m of script) yield m;
    },
    async cancel(h: SessionHandle) { this.cancelled.push(h.id); },
    async terminate(h: SessionHandle) { this.terminated.push(h.id); },
    async deleteSession(h: SessionHandle) { this.deleted.push(h.id); },
  };
}

const T = (n: number): AgiMessage[] =>
  Array.from({ length: n }, (_, k) => ({ id: `t-${k}`, type: "THOUGHT" as const, content: "thinking" }));

const NARRATION =
  "I found six gentle free events. Garden Storytime is Saturday at 10am at the " +
  "Rice Street library. Let me compile the results now.";
const JSON_REPLY = '[{"title":"Garden Storytime","url":"https://sppl.org/e","date":"sat 10am"}]';

test("follow-up: the retry goes to the SAME session and its JSON becomes the reply", async () => {
  const tx = scriptedTransport([
    [...T(4), { id: "d1", type: "DONE", content: NARRATION }],
    [...T(2), { id: "d2", type: "DONE", content: JSON_REPLY }],
  ]);
  const res = await runAgentTask({
    prompt: "search", startUrl: "https://x", maxSteps: MAX_AGENT_STEPS, transport: tx,
    followUp: (first) => shouldRetryForJson({
      candidates: parseCandidates(first.lastContent).length,
      looksJson: summarizeAgentReply(first.lastContent).looksJson,
      stepsUsed: first.thoughts,
      maxSteps: MAX_AGENT_STEPS,
      alreadyRetried: false,
    }) ? JSON_RETRY_MESSAGE : null,
  });
  assert.equal(res.retried, true);
  assert.equal(res.retryError, null);
  assert.equal(res.lastContent, JSON_REPLY);
  assert.equal(parseCandidates(res.lastContent).length, 1, "the narrated run now yields a candidate");
  // ONE session: created once, torn down once — the retry reuses it.
  assert.equal(tx.created, 1);
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"]);
  assert.equal(tx.cancelled.length, 0);
  // two messages, the second carrying the retry text, NO start_url, and only
  // the REMAINING step budget (30 - 4).
  assert.equal(tx.starts.length, 2);
  assert.equal(tx.starts[0].content, "search");
  assert.equal(tx.starts[1].content, JSON_RETRY_MESSAGE);
  assert.equal(tx.starts[1].startUrl, undefined);
  assert.equal(tx.starts[1].maxSteps, MAX_AGENT_STEPS - 4);
  // steps are CUMULATIVE across both turns (owner cost telemetry)
  assert.equal(res.thoughts, 6);
});

test("follow-up: returning null leaves the run exactly as it was (one message)", async () => {
  const tx = scriptedTransport([[...T(3), { id: "d", type: "DONE", content: "[]" }]]);
  const res = await runAgentTask({
    prompt: "search", startUrl: "https://x", maxSteps: MAX_AGENT_STEPS, transport: tx,
    followUp: () => null,
  });
  assert.equal(res.retried, false);
  assert.equal(res.lastContent, "[]");
  assert.equal(res.thoughts, 3);
  assert.equal(tx.starts.length, 1);
});

test("follow-up: never offered after a step-cap kill (no budget, session dying)", async () => {
  const tx = scriptedTransport([[...T(6)], [{ id: "d", type: "DONE", content: JSON_REPLY }]]);
  let asked = 0;
  const res = await runAgentTask({
    prompt: "search", startUrl: "https://x", maxSteps: 5, transport: tx,
    followUp: () => { asked++; return JSON_RETRY_MESSAGE; },
  });
  assert.equal(asked, 0, "a killed run must never be asked to retry");
  assert.equal(res.retried, false);
  assert.equal(res.outcome, "killed");
  assert.equal(res.killReason, "step_cap");
  assert.equal(tx.starts.length, 1);
  assert.deepEqual(tx.cancelled, ["sess-1"]);
});

test("follow-up: never offered after an ERROR", async () => {
  const tx = scriptedTransport([[{ id: "e", type: "ERROR", content: "boom" }]]);
  let asked = 0;
  await runAgentTask({
    prompt: "search", startUrl: "https://x", transport: tx,
    followUp: () => { asked++; return JSON_RETRY_MESSAGE; },
  });
  assert.equal(asked, 0);
  assert.equal(tx.starts.length, 1);
});

test("follow-up: the retry's steps land on the SAME cap and the kill still fires", async () => {
  // 20 steps then narration, then a retry that keeps thinking: the kill must
  // fire at exactly 30 THOUGHTs total. The cap is not raised for the retry.
  const tx = scriptedTransport([
    [...T(20), { id: "d1", type: "DONE", content: NARRATION }],
    [...T(25), { id: "d2", type: "DONE", content: JSON_REPLY }],
  ]);
  const res = await runAgentTask({
    prompt: "search", startUrl: "https://x", maxSteps: MAX_AGENT_STEPS, transport: tx,
    followUp: () => JSON_RETRY_MESSAGE,
  });
  assert.equal(res.retried, true);
  assert.equal(res.outcome, "killed");
  assert.equal(res.killReason, "step_cap");
  assert.equal(res.thoughts, MAX_AGENT_STEPS, "never one step past the cap");
  // the retry was handed only the remaining budget, and the session is cleaned up
  assert.equal(tx.starts[1].maxSteps, MAX_AGENT_STEPS - 20);
  assert.deepEqual(tx.cancelled, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"]);
});

test("follow-up: a failed retry post degrades to the first result, never to an error", async () => {
  const tx = scriptedTransport([[...T(4), { id: "d1", type: "DONE", content: NARRATION }]]);
  tx.throwOnStart2 = true;
  const res = await runAgentTask({
    prompt: "search", startUrl: "https://x", maxSteps: MAX_AGENT_STEPS, transport: tx,
    followUp: () => JSON_RETRY_MESSAGE,
  });
  assert.equal(res.retried, true);
  assert.match(String(res.retryError), /follow-up post failed/);
  assert.equal(res.errored, false, "a retry failure must not become a failed run");
  assert.equal(res.outcome, "finished");
  assert.equal(res.lastContent, NARRATION);
  assert.deepEqual(tx.deleted, ["sess-1"], "the session is still torn down");
});

test("follow-up: a trailing QUESTION can still be answered with the retry", async () => {
  const tx = scriptedTransport([
    [...T(3), { id: "q", type: "QUESTION", content: NARRATION }],
    [{ id: "d", type: "DONE", content: JSON_REPLY }],
  ]);
  const res = await runAgentTask({
    prompt: "search", startUrl: "https://x", maxSteps: MAX_AGENT_STEPS, transport: tx,
    followUp: () => JSON_RETRY_MESSAGE,
  });
  assert.equal(res.retried, true);
  assert.equal(res.question, null, "the follow-up answered the question");
  assert.equal(res.lastContent, JSON_REPLY);
});

test("a run with no followUp behaves exactly as before (retried false)", async () => {
  const tx = scriptedTransport([[...T(2), { id: "d", type: "DONE", content: "[]" }]]);
  const res = await runAgentTask({ prompt: "p", startUrl: "https://x", transport: tx });
  assert.equal(res.retried, false);
  assert.equal(res.retryError, null);
  assert.equal(res.outcome, "finished");
  assert.equal(res.lastContent, "[]");
  assert.equal(tx.starts.length, 1);
});
