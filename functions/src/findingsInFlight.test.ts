// findingsInFlight.test.ts — VERIFICATION-PASS proof for the in-flight guard.
//
// The other findings suites test PURE helpers. This one is different on
// purpose: it loads the REAL COMPILED `lib/index.js` and invokes the REAL
// `startFindingTask` handler, with the firebase/openai module graph stubbed in
// require.cache and a FAKE AGI TRANSPORT swapped into agiClient's exported
// `httpTransport`. That is the only injection seam the callable has (it calls
// runAgentTask WITHOUT a transport argument, and runAgentTask resolves
// `params.transport ?? exports.httpTransport`), so swapping the module export
// is what lets us assert an agent session is never created.
//
// WHAT THIS PROVES, end to end, on the production code path:
//   (a) the callable RETURNS the alreadyRunning outcome;
//   (b) NO agent session is created  (fake transport createSession call count 0);
//   (c) the daily counter is NOT incremented (runTransaction never reached).

import test from "node:test";
import assert from "node:assert/strict";
import { IN_FLIGHT_WINDOW_MS, MAX_TASKS_PER_DAY } from "./starFindings";

const OWNER = "Enlkbg0saoMqvx24r7ZLsBX8ctp2";

// ── recorded state ──────────────────────────────────────────────────────────

const agiCalls = {
  createSession: 0, startTask: 0, streamEvents: 0,
  cancel: 0, terminate: 0, deleteSession: 0,
};

const dbState = {
  /** "" means "no task doc at all" (the empty-latest case). */
  latestStatus: "searching",
  latestCreatedAtMs: 0,
  latestId: "task-live",
  parentData: {} as Record<string, unknown>,
  /** every runTransaction entry — the DAILY COUNTER path. */
  transactions: 0,
  /** every parent-doc set — the counter WRITE itself. */
  parentSets: [] as Record<string, unknown>[],
  /** every task-doc set — a doc is only created once a run really starts. */
  taskSets: [] as Record<string, unknown>[],
  newTaskDocs: 0,
};

function resetRecorders(): void {
  agiCalls.createSession = 0; agiCalls.startTask = 0; agiCalls.streamEvents = 0;
  agiCalls.cancel = 0; agiCalls.terminate = 0; agiCalls.deleteSession = 0;
  dbState.transactions = 0;
  dbState.parentSets = [];
  dbState.taskSets = [];
  dbState.newTaskDocs = 0;
}

// ── the fake AGI transport (the money assertion lives here) ─────────────────

const fakeTransport = {
  async createSession() {
    agiCalls.createSession++;
    return { id: "sess-should-not-exist", agentUrl: "http://never" };
  },
  async startTask() { agiCalls.startTask++; },
  // eslint-disable-next-line require-yield
  async *streamEvents() { agiCalls.streamEvents++; },
  async cancel() { agiCalls.cancel++; },
  async terminate() { agiCalls.terminate++; },
  async deleteSession() { agiCalls.deleteSession++; },
};

// ── the stubbed module graph ────────────────────────────────────────────────

function stubModule(id: string, exportsObj: Record<string, unknown>): void {
  const resolved = require.resolve(id);
  require.cache[resolved] = {
    id: resolved, filename: resolved, loaded: true, exports: exportsObj,
  } as unknown as NodeJS.Module;
}

/** onCall/onRequest/... all take (opts?, handler) — hand back the handler. */
function handlerOf(...args: unknown[]): unknown {
  return args[args.length - 1];
}

function installStubs(): void {
  const taskRef = {
    id: "task-new",
    async set(d: Record<string, unknown>) { dbState.taskSets.push(d); },
    async get() { return { exists: false, id: "task-new", data: () => undefined }; },
  };
  const tasksCollection = {
    orderBy() { return this; },
    limit() { return this; },
    async get() {
      if (!dbState.latestStatus) return { empty: true, docs: [] };
      return {
        empty: false,
        docs: [{
          id: dbState.latestId,
          data: () => ({
            status: dbState.latestStatus,
            createdAt: { toMillis: () => dbState.latestCreatedAtMs },
          }),
        }],
      };
    },
    doc() { dbState.newTaskDocs++; return taskRef; },
  };
  const parentRef = {
    id: OWNER,
    collection() { return tasksCollection; },
    async get() { return { exists: true, data: () => dbState.parentData }; },
    async set(d: Record<string, unknown>) { dbState.parentSets.push(d); },
  };
  const db = {
    collection() { return { doc: () => parentRef }; },
    async runTransaction(fn: (tx: unknown) => Promise<unknown>) {
      dbState.transactions++;
      return fn({
        async get() { return { data: () => dbState.parentData }; },
        set(_ref: unknown, d: Record<string, unknown>) { dbState.parentSets.push(d); },
      });
    },
  };

  const firestoreFn = (() => db) as unknown as Record<string, unknown> & (() => unknown);
  firestoreFn.FieldValue = { serverTimestamp: () => "SERVER_TS", delete: () => "DELETE" };
  firestoreFn.Timestamp = {
    now: () => ({ toMillis: () => Date.now() }),
    fromMillis: (ms: number) => ({ toMillis: () => ms }),
  };

  stubModule("firebase-admin", {
    __esModule: true,
    initializeApp: () => ({}),
    firestore: firestoreFn,
    auth: () => ({ getUser: async () => ({ email: "owner@example.com" }) }),
    messaging: () => ({ send: async () => "msg-id" }),
  });

  const logger = {
    info: () => undefined, warn: () => undefined,
    error: () => undefined, debug: () => undefined, log: () => undefined,
  };
  stubModule("firebase-functions/v1", {
    __esModule: true, logger,
    // index.ts registers one v1 auth trigger at module scope.
    auth: { user: () => ({ onCreate: handlerOf, onDelete: handlerOf }) },
    https: { onCall: handlerOf, onRequest: handlerOf },
    pubsub: { schedule: () => ({ onRun: handlerOf, timeZone: () => ({ onRun: handlerOf }) }) },
  });
  stubModule("firebase-functions/v2/https", {
    __esModule: true,
    onCall: handlerOf,
    onRequest: handlerOf,
    HttpsError: class HttpsError extends Error {
      code: string;
      constructor(code: string, message: string) { super(message); this.code = code; }
    },
  });
  stubModule("firebase-functions/v2/scheduler", { __esModule: true, onSchedule: handlerOf });
  stubModule("firebase-functions/v2/firestore", {
    __esModule: true, onDocumentCreated: handlerOf, onDocumentUpdated: handlerOf,
    onDocumentWritten: handlerOf, onDocumentDeleted: handlerOf,
  });
  stubModule("firebase-functions/params", {
    __esModule: true,
    defineSecret: (name: string) => ({ name, value: () => `stub-${name}` }),
    defineString: (name: string, opts?: { default?: string }) =>
      ({ name, value: () => opts?.default ?? `stub-${name}` }),
  });
  stubModule("firebase-functions/v2", { __esModule: true, setGlobalOptions: () => undefined });
  stubModule("openai", {
    __esModule: true,
    default: class OpenAIStub {
      chat = { completions: { create: async () => ({ choices: [] }) } };
    },
  });

  // The ONLY injection seam the callable exposes: runAgentTask resolves
  // `params.transport ?? exports.httpTransport`, and startFindingTask passes no
  // transport. Swapping the module export is therefore a genuine injection —
  // the REAL runAgentTask would drive THIS object if it were ever reached.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const agiMod = require("./agiClient");
  agiMod.httpTransport = fakeTransport;
}

type CallableRequest = { auth?: { uid: string }; data?: Record<string, unknown> };
type CallableResult = {
  taskId: string; status: string; steps: number; outcome: string;
  finding: unknown; tasksRemainingToday: number;
};

let startFindingTask: (req: CallableRequest) => Promise<CallableResult>;

test("load the REAL compiled startFindingTask handler with a stubbed module graph", () => {
  process.env.STAR_FINDINGS_UIDS = OWNER;
  installStubs();
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const index = require("./index");
  assert.equal(typeof index.startFindingTask, "function",
    "the onCall stub must have handed back the raw handler");
  startFindingTask = index.startFindingTask;
});

// ── (a) the callable RETURNS the alreadyRunning outcome ─────────────────────

test("IN-FLIGHT GUARD (a): a `searching` task inside IN_FLIGHT_WINDOW_MS returns alreadyRunning", async () => {
  resetRecorders();
  dbState.latestStatus = "searching";
  dbState.latestId = "task-live";
  dbState.latestCreatedAtMs = Date.now() - 30_000;   // 30s old: well inside the window
  dbState.parentData = { dayKey: new Date().toISOString().slice(0, 10), count: 2 };

  const res = await startFindingTask({ auth: { uid: OWNER }, data: {} });

  assert.equal(res.status, "alreadyRunning");
  assert.equal(res.outcome, "alreadyRunning");
  assert.equal(res.taskId, "task-live", "it hands back the LIVE task's id, not a new one");
  assert.equal(res.finding, null);
  assert.equal(res.steps, 0);
  // being told "the star is already out" must not spend a send
  assert.equal(res.tasksRemainingToday, MAX_TASKS_PER_DAY - 2);
});

// ── (b) NO agent session is created ─────────────────────────────────────────

test("IN-FLIGHT GUARD (b): NO agent session is created — the injected transport is never touched", async () => {
  resetRecorders();
  dbState.latestStatus = "searching";
  dbState.latestCreatedAtMs = Date.now() - 1_000;
  dbState.parentData = { dayKey: new Date().toISOString().slice(0, 10), count: 1 };

  const res = await startFindingTask({ auth: { uid: OWNER }, data: {} });

  assert.equal(res.status, "alreadyRunning");
  assert.equal(agiCalls.createSession, 0, "createSession must NEVER be called");
  assert.equal(agiCalls.startTask, 0);
  assert.equal(agiCalls.streamEvents, 0);
  // nothing was created, so there is nothing to tear down either
  assert.equal(agiCalls.terminate, 0);
  assert.equal(agiCalls.deleteSession, 0);
  // and no task doc was even allocated for a second run
  assert.equal(dbState.newTaskDocs, 0);
  assert.equal(dbState.taskSets.length, 0);
});

// ── (c) the daily counter is NOT incremented ────────────────────────────────

test("IN-FLIGHT GUARD (c): the daily counter transaction is never reached", async () => {
  resetRecorders();
  dbState.latestStatus = "searching";
  dbState.latestCreatedAtMs = Date.now() - 5_000;
  dbState.parentData = { dayKey: new Date().toISOString().slice(0, 10), count: 3 };

  const res = await startFindingTask({ auth: { uid: OWNER }, data: {} });

  assert.equal(res.status, "alreadyRunning");
  assert.equal(dbState.transactions, 0, "runTransaction (the 5/day counter) must not run");
  assert.deepEqual(dbState.parentSets, [], "no count write of any kind");
  // the reported remaining budget is UNCHANGED (3 used of 5)
  assert.equal(res.tasksRemainingToday, MAX_TASKS_PER_DAY - 3);
});

// ── the boundary: one ms past the window is NOT in flight ───────────────────

test("IN-FLIGHT GUARD: one ms past IN_FLIGHT_WINDOW_MS is NOT blocked — the counter runs again", async () => {
  resetRecorders();
  dbState.latestStatus = "searching";
  dbState.latestCreatedAtMs = Date.now() - IN_FLIGHT_WINDOW_MS - 5_000;   // stale doc
  dbState.parentData = { dayKey: new Date().toISOString().slice(0, 10), count: MAX_TASKS_PER_DAY };

  const res = await startFindingTask({ auth: { uid: OWNER }, data: {} });

  // it got PAST the guard (proving the guard is what blocked the cases above)…
  assert.equal(dbState.transactions, 1, "a stale doc must not lock the feature out");
  // …and was then stopped by the 5/day money ceiling instead, still with no agent
  assert.equal(res.status, "capReached");
  assert.equal(agiCalls.createSession, 0);
});

test("IN-FLIGHT GUARD: a settled latest task does not block (status is the discriminator)", async () => {
  for (const settled of ["found", "empty", "failed", "booked", "confirmed", "handoff"]) {
    resetRecorders();
    dbState.latestStatus = settled;
    dbState.latestCreatedAtMs = Date.now();          // young, but NOT searching
    dbState.parentData = { dayKey: new Date().toISOString().slice(0, 10), count: MAX_TASKS_PER_DAY };
    const res = await startFindingTask({ auth: { uid: OWNER }, data: {} });
    assert.notEqual(res.status, "alreadyRunning", `status ${settled} must not block`);
    assert.equal(dbState.transactions, 1, `status ${settled} must reach the counter`);
  }
});

// ── the MUTATION CONTROL ───────────────────────────────────────────────
// Without this, "createSession was never called" could be passing for the wrong
// reason (a broken stub, a throw before the agent call). Here the SAME handler,
// with the SAME injected transport, is allowed through — and it DOES create a
// session. That is what makes the zero-counts above meaningful.

test("CONTROL: with no live task and budget left, the SAME injected transport IS driven", async () => {
  resetRecorders();
  dbState.latestStatus = "";                        // no prior task at all
  dbState.parentData = { dayKey: "1970-01-01", count: 0 };

  const res = await startFindingTask({ auth: { uid: OWNER }, data: {} });

  assert.equal(agiCalls.createSession, 1, "the agent run IS reached on the happy path");
  assert.equal(agiCalls.startTask, 1);
  assert.equal(dbState.transactions, 1, "the daily counter IS incremented on the happy path");
  assert.equal(dbState.newTaskDocs, 1, "a task doc IS allocated on the happy path");
  assert.notEqual(res.status, "alreadyRunning");
  // and the session it created is still torn down (the finally block)
  assert.equal(agiCalls.terminate, 1);
  assert.equal(agiCalls.deleteSession, 1);
});

test("IN-FLIGHT GUARD is BEHIND the gate: a non-allowlisted caller is denied before any read", async () => {
  resetRecorders();
  dbState.latestStatus = "searching";
  dbState.latestCreatedAtMs = Date.now();
  await assert.rejects(
    () => startFindingTask({ auth: { uid: "someoneElse" }, data: {} }),
    /not enabled/);
  assert.equal(agiCalls.createSession, 0);
  assert.equal(dbState.transactions, 0);
});
