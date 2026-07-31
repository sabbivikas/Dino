// agiClient.ts — fetch-based client for the AGI browser-agent vendor, plus the
// event-stream orchestrator that enforces the step kill. The pure decision
// (killDecision) + THOUGHT tally live in starFindings.ts; this module does the
// IO and the cancel / terminate / DELETE.
//
// TWO PLANES (verified live against api.agi.tech):
//   • control plane  https://api.agi.tech/v1
//       POST   /sessions          {agent_name}      → {session_id, agent_url}
//       DELETE /sessions/:id                          → tear the sandbox down
//   • agent plane    <agent_url> (the session's own host)
//       POST   /user_message      {content, start_url, max_steps}
//       GET    /events            → SSE: `data: {type,content,step}` per event
//       POST   /cancel  /terminate                    → stop the running agent
//
// BILLING SAFETY (non-negotiable): AGI bills per thinking step. runAgentTask
// consumes the /events SSE stream, tallies THOUGHT events live, and the instant
// the tally reaches the cap it cancels + terminates + DELETEs the session. It
// ALSO enforces a wall-clock ceiling (AbortController) with the same kill. And
// it ALWAYS terminates + deletes the session in a finally block, so a crash,
// throw, or early return can never leak a billed sandbox.

import {
  countThoughts,
  killDecision,
  MAX_AGENT_STEPS,
  WALL_CLOCK_MS,
  type AgiMessage,
  type AgiMessageType,
  type KillReason,
} from "./starFindings";

const AGI_BASE = process.env.AGI_API_BASE || "https://api.agi.tech/v1";

function authHeaders(): Record<string, string> {
  const key = process.env.AGI_API_KEY || "";
  return { Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
}

// ── session handle + transport (injectable so the loop is testable) ──────────

export interface SessionHandle {
  id: string;        // control-plane session_id
  agentUrl: string;  // agent-plane base
}

export interface StartTaskRequest {
  content: string;
  startUrl?: string;
  maxSteps?: number;
  stepDelaySeconds?: number;
}

export interface AgiTransport {
  createSession(agentName: string): Promise<SessionHandle>;
  startTask(handle: SessionHandle, req: StartTaskRequest): Promise<void>;
  /** Yield each agent event in order until the stream ends or `signal` aborts. */
  streamEvents(handle: SessionHandle, signal: AbortSignal): AsyncIterable<AgiMessage>;
  cancel(handle: SessionHandle): Promise<void>;
  terminate(handle: SessionHandle): Promise<void>;
  deleteSession(handle: SessionHandle): Promise<void>;
}

const KNOWN_TYPES: AgiMessageType[] = ["THOUGHT", "QUESTION", "USER", "DONE", "ERROR", "LOG"];

/** Parse one SSE `data:` JSON payload into an AgiMessage (defensive). */
export function parseEventData(dataJson: string, seq: number): AgiMessage | null {
  let o: Record<string, unknown>;
  try { o = JSON.parse(dataJson) as Record<string, unknown>; } catch { return null; }
  const typeRaw = String(o.type ?? "LOG").toUpperCase();
  const type = (KNOWN_TYPES.includes(typeRaw as AgiMessageType) ? typeRaw : "LOG") as AgiMessageType;
  const content = typeof o.content === "string" ? o.content : JSON.stringify(o.content ?? "");
  const id = o.step != null ? `${o.step}-${type}-${seq}` : String(seq);
  return { id, type, content };
}

async function controlFetch(path: string, init: RequestInit): Promise<unknown> {
  const res = await fetch(`${AGI_BASE}${path}`, init);
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`agi ${init.method ?? "GET"} ${path} → ${res.status} ${body.slice(0, 200)}`);
  }
  const text = await res.text();
  try { return text ? JSON.parse(text) : {}; } catch { return { raw: text }; }
}

/** The real fetch-based transport. */
export const httpTransport: AgiTransport = {
  async createSession(agentName: string): Promise<SessionHandle> {
    const json = (await controlFetch("/sessions", {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ agent_name: agentName }),
    })) as Record<string, unknown>;
    const id = json.session_id ?? json.id;
    const agentUrl = json.agent_url;
    if (!id || typeof agentUrl !== "string") {
      throw new Error(`agi createSession: missing session_id/agent_url in ${JSON.stringify(json).slice(0, 200)}`);
    }
    return { id: String(id), agentUrl };
  },

  async startTask(handle: SessionHandle, req: StartTaskRequest): Promise<void> {
    const body: Record<string, unknown> = { content: req.content };
    if (req.startUrl) body.start_url = req.startUrl;
    if (req.maxSteps != null) body.max_steps = req.maxSteps;
    if (req.stepDelaySeconds != null) body.step_delay_seconds = req.stepDelaySeconds;
    const res = await fetch(`${handle.agentUrl}/user_message`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const t = await res.text().catch(() => "");
      throw new Error(`agi startTask → ${res.status} ${t.slice(0, 200)}`);
    }
  },

  async *streamEvents(handle: SessionHandle, signal: AbortSignal): AsyncIterable<AgiMessage> {
    const res = await fetch(`${handle.agentUrl}/events`, {
      method: "GET",
      headers: { ...authHeaders(), Accept: "text/event-stream" },
      signal,
    });
    if (!res.ok || !res.body) throw new Error(`agi events → ${res.status}`);
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buf = "";
    let seq = 0;
    try {
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buf += decoder.decode(value, { stream: true });
        // SSE blocks are separated by a blank line.
        let idx: number;
        while ((idx = buf.indexOf("\n\n")) >= 0) {
          const block = buf.slice(0, idx);
          buf = buf.slice(idx + 2);
          const dataLines = block.split("\n")
            .filter((l) => l.startsWith("data:"))
            .map((l) => l.slice(5).trim());
          if (dataLines.length === 0) continue;
          const msg = parseEventData(dataLines.join("\n"), seq++);
          if (msg) yield msg;
        }
      }
    } finally {
      await reader.cancel().catch(() => { /* swallow */ });
    }
  },

  async cancel(handle: SessionHandle): Promise<void> {
    await fetch(`${handle.agentUrl}/cancel`, { method: "POST", headers: authHeaders() })
      .catch(() => { /* terminate/delete are the real stop */ });
  },

  async terminate(handle: SessionHandle): Promise<void> {
    await fetch(`${handle.agentUrl}/terminate`, { method: "POST", headers: authHeaders() })
      .catch(() => { /* delete is the backstop */ });
  },

  async deleteSession(handle: SessionHandle): Promise<void> {
    await fetch(`${AGI_BASE}/sessions/${encodeURIComponent(handle.id)}`, {
      method: "DELETE",
      headers: authHeaders(),
    }).catch(() => { /* never throw from cleanup */ });
  },
};

// ── the orchestrator ─────────────────────────────────────────────────────────

export interface RunResult {
  outcome: "finished" | "killed" | "waiting" | "error";
  killReason: KillReason;
  thoughts: number;
  durationMs: number;
  messages: AgiMessage[];
  lastContent: string;      // terminal DONE content, or the last message's content
  question: string | null;  // the QUESTION content when waiting_for_input
  errored: boolean;
}

export interface RunParams {
  prompt: string;
  startUrl?: string;
  agentName?: string;
  maxSteps?: number;
  wallClockMs?: number;
  stepDelaySeconds?: number;
  transport?: AgiTransport;
  now?: () => number;
}

function lastOfType(messages: readonly AgiMessage[], type: AgiMessageType): AgiMessage | undefined {
  for (let i = messages.length - 1; i >= 0; i--) if (messages[i].type === type) return messages[i];
  return undefined;
}

/** The reply that counts: the last DONE's content, else the last message's. */
function terminalContent(messages: readonly AgiMessage[]): string {
  const done = lastOfType(messages, "DONE");
  return done?.content ?? (messages.length ? messages[messages.length - 1].content : "");
}

/**
 * Run one agent phase to completion, a kill, or a QUESTION. Consumes the SSE
 * event stream, tallies THOUGHTs, and enforces both the step cap and the
 * wall-clock ceiling. ALWAYS terminates + deletes the session (finally); adds a
 * cancel when the run was killed. A leaked sandbox is a billed sandbox.
 */
export async function runAgentTask(params: RunParams): Promise<RunResult> {
  const transport = params.transport ?? httpTransport;
  const maxSteps = params.maxSteps ?? MAX_AGENT_STEPS;
  const wallClockMs = params.wallClockMs ?? WALL_CLOCK_MS;
  const now = params.now ?? Date.now;

  const startedAt = now();
  const all: AgiMessage[] = [];
  let handle: SessionHandle | null = null;
  let outcome: RunResult["outcome"] = "error";
  let killReason: KillReason = null;
  let errored = false;
  let question: string | null = null;

  const controller = new AbortController();
  let timedOut = false;
  const wallTimer = setTimeout(() => { timedOut = true; controller.abort(); }, wallClockMs);

  // One pass over the event stream, ending on a terminal message or a kill.
  // `all` is cumulative and there is deliberately no de-duplication: if the
  // vendor ever replayed events we would over-count, which errs toward killing
  // sooner — the safe direction for a per-step bill.
  const consume = async (h: SessionHandle): Promise<RunResult["outcome"]> => {
    for await (const msg of transport.streamEvents(h, controller.signal)) {
      all.push(msg);

      if (msg.type === "QUESTION") { outcome = "waiting"; question = msg.content; return outcome; }
      if (msg.type === "ERROR") { outcome = "error"; errored = true; return outcome; }
      if (msg.type === "DONE") { outcome = "finished"; return outcome; }

      const decision = killDecision({
        thoughtCount: countThoughts(all),
        elapsedMs: now() - startedAt,
        maxSteps,
        wallClockMs,
      });
      if (decision.kill) { killReason = decision.reason; outcome = "killed"; return outcome; }
    }
    return outcome;
  };

  try {
    handle = await transport.createSession(params.agentName ?? "agi-0");
    await transport.startTask(handle, {
      content: params.prompt,
      startUrl: params.startUrl,
      maxSteps,
      stepDelaySeconds: params.stepDelaySeconds,
    });

    await consume(handle);
  } catch (err) {
    if (timedOut) {
      outcome = "killed";
      killReason = "timeout";
    } else {
      outcome = "error";
      errored = true;
      all.push({ id: "err", type: "ERROR", content: err instanceof Error ? err.message : String(err) });
    }
  } finally {
    clearTimeout(wallTimer);
    controller.abort(); // close the SSE stream if still open
    if (handle) {
      if (outcome === "killed") await transport.cancel(handle).catch(() => { /* */ });
      await transport.terminate(handle).catch(() => { /* */ });
      await transport.deleteSession(handle).catch(() => { /* */ });
    }
  }

  return {
    outcome,
    killReason,
    thoughts: countThoughts(all),
    durationMs: now() - startedAt,
    messages: all,
    lastContent: terminalContent(all),
    question,
    errored,
  };
}
