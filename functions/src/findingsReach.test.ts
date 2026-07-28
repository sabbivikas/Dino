// findingsReach.test.ts — pure tests for the CLIENT-REACHABILITY fix.
//
// New test FILE (no existing test file is modified). Covers the two helpers
// that make a finished server task reachable: the push's deep link, and the
// getFindingTask response shape — including the "never sent a star out" answer
// that must stay quiet instead of throwing not-found.

import test from "node:test";
import assert from "node:assert/strict";
import {
  findingDeepLink,
  findingTaskPayload,
  noFindingTask,
} from "./starFindings";

const REAL_TASK = "fOBoTl257mhN96RRvEjP";

test("findingDeepLink builds the dino://finding/{taskId} door the push carries", () => {
  assert.equal(findingDeepLink(REAL_TASK), `dino://finding/${REAL_TASK}`);
  // the client parses url.host === "finding" and takes the last path component
  const url = new URL(findingDeepLink(REAL_TASK));
  assert.equal(url.protocol, "dino:");
  assert.equal(url.host, "finding");
  assert.equal(url.pathname.split("/").pop(), REAL_TASK);
});

test("findingDeepLink is empty (never a broken door) for a missing id", () => {
  assert.equal(findingDeepLink(""), "");
  assert.equal(findingDeepLink("   "), "");
  assert.equal(findingDeepLink(undefined), "");
  assert.equal(findingDeepLink(null), "");
  // whitespace around a real id is trimmed, not baked into the url
  assert.equal(findingDeepLink(` ${REAL_TASK} `), `dino://finding/${REAL_TASK}`);
});

test("findingTaskPayload shapes a real found task doc", () => {
  const payload = findingTaskPayload(REAL_TASK, {
    status: "found",
    steps: 8,
    outcome: "found",
    dayKey: "2026-07-27",
    finding: {
      title: "Hatha Yoga Class",
      venue: "SPPL",
      registrationNeeded: false,
      outcome: "add_to_calendar",
    },
  });
  assert.equal(payload.taskId, REAL_TASK);
  assert.equal(payload.status, "found");
  assert.equal(payload.steps, 8);
  assert.equal(payload.outcome, "found");
  assert.deepEqual(payload.finding, {
    title: "Hatha Yoga Class",
    venue: "SPPL",
    registrationNeeded: false,
    outcome: "add_to_calendar",
  });
});

test("findingTaskPayload defaults every field (half-written / legacy docs)", () => {
  assert.deepEqual(findingTaskPayload("t1", {}), {
    taskId: "t1", status: "failed", finding: null, steps: 0, outcome: "",
  });
  assert.deepEqual(findingTaskPayload("t1", undefined), {
    taskId: "t1", status: "failed", finding: null, steps: 0, outcome: "",
  });
  assert.deepEqual(findingTaskPayload("t1", null), {
    taskId: "t1", status: "failed", finding: null, steps: 0, outcome: "",
  });
  // a searching doc (no finding / no steps yet) survives the shaping
  assert.deepEqual(findingTaskPayload("t2", { status: "searching" }), {
    taskId: "t2", status: "searching", finding: null, steps: 0, outcome: "",
  });
  // junk types never leak through
  assert.equal(findingTaskPayload("t3", { steps: "lots" }).steps, 0);
  assert.equal(findingTaskPayload("t3", { outcome: 42 }).outcome, "");
  assert.equal(findingTaskPayload("t3", { status: "" }).status, "failed");
  assert.equal(findingTaskPayload(undefined, { status: "found" }).taskId, "");
});

test("noFindingTask is the quiet first-ever-cold-open answer, and is fresh each call", () => {
  assert.deepEqual(noFindingTask(), {
    taskId: "", status: "none", finding: null, steps: 0, outcome: "",
  });
  // the client keys off status "none" to stay plainly idle
  assert.equal(noFindingTask().status, "none");
  // never a shared mutable singleton (one caller cannot poison the next)
  const a = noFindingTask();
  a.status = "mutated";
  assert.equal(noFindingTask().status, "none");
});
