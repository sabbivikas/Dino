import test from "node:test";
import assert from "node:assert/strict";
import { runAgentTask, parseEventData, type AgiTransport, type SessionHandle } from "./agiClient";
import type { AgiMessage } from "./starFindings";

// A scripted streaming fake: streamEvents yields the given messages in order.
// Records cancel/terminate/delete so tests can prove the kill + cleanup.
function fakeTransport(script: AgiMessage[]): AgiTransport & {
  cancelled: string[]; terminated: string[]; deleted: string[]; created: number; started: number;
  throwOnStream?: boolean;
} {
  const rec = {
    cancelled: [] as string[], terminated: [] as string[], deleted: [] as string[],
    created: 0, started: 0, throwOnStream: false,
  };
  return {
    ...rec,
    async createSession(): Promise<SessionHandle> { this.created++; return { id: "sess-1", agentUrl: "http://agent" }; },
    async startTask() { this.started++; },
    async *streamEvents(_h: SessionHandle) {
      if (this.throwOnStream) throw new Error("network boom");
      for (const m of script) yield m;
    },
    async cancel(h: SessionHandle) { this.cancelled.push(h.id); },
    async terminate(h: SessionHandle) { this.terminated.push(h.id); },
    async deleteSession(h: SessionHandle) { this.deleted.push(h.id); },
  };
}

const T = (n: number): AgiMessage[] =>
  Array.from({ length: n }, (_, k) => ({ id: `t-${k}`, type: "THOUGHT" as const, content: "thinking" }));

test("parseEventData maps the SSE data JSON to an AgiMessage", () => {
  const m = parseEventData('{"content":"hi","type":"THOUGHT","step":3}', 0);
  assert.equal(m?.type, "THOUGHT");
  assert.equal(m?.content, "hi");
  // unknown type folds to LOG; bad json → null
  assert.equal(parseEventData('{"content":"x","type":"WHAT"}', 1)?.type, "LOG");
  assert.equal(parseEventData("not json", 2), null);
});

test("step-kill: cancels + terminates + deletes the instant THOUGHTs reach the cap", async () => {
  // 5 THOUGHTs then a 6th that must never be pulled (cap = 5).
  const tx = fakeTransport([...T(5), { id: "x", type: "THOUGHT", content: "unreached" }]);
  const res = await runAgentTask({ prompt: "open ended", startUrl: "https://x", maxSteps: 5, transport: tx });
  assert.equal(res.outcome, "killed");
  assert.equal(res.killReason, "step_cap");
  assert.equal(res.thoughts, 5);
  assert.deepEqual(tx.cancelled, ["sess-1"]);
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"]);
});

test("clean finish (DONE): no cancel, but STILL terminates + deletes (finally)", async () => {
  const tx = fakeTransport([...T(2), { id: "d", type: "DONE", content: "[]" }]);
  const res = await runAgentTask({ prompt: "p", startUrl: "https://x", maxSteps: 30, transport: tx });
  assert.equal(res.outcome, "finished");
  assert.equal(res.killReason, null);
  assert.equal(res.lastContent, "[]");
  assert.equal(tx.cancelled.length, 0);
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"]);
});

test("QUESTION surfaces its content (booking handoff) and still cleans up", async () => {
  const tx = fakeTransport([
    { id: "q", type: "QUESTION", content: "what is your date of birth?" },
  ]);
  const res = await runAgentTask({ prompt: "book", startUrl: "https://x.org", transport: tx });
  assert.equal(res.outcome, "waiting");
  assert.equal(res.question, "what is your date of birth?");
  assert.deepEqual(tx.terminated, ["sess-1"]);
  assert.deepEqual(tx.deleted, ["sess-1"]);
});

test("a stream throw still terminates + deletes the session and reports error", async () => {
  const tx = fakeTransport([]);
  tx.throwOnStream = true;
  const res = await runAgentTask({ prompt: "p", startUrl: "https://x", transport: tx });
  assert.equal(res.outcome, "error");
  assert.equal(res.errored, true);
  assert.deepEqual(tx.deleted, ["sess-1"]);
});
