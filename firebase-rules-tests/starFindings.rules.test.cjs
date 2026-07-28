/**
 * STAR FINDINGS (experimental owner-only demo) firestore.rules tests — a NEW
 * test file (existing suites untouched). Runs inside the same emulator via the
 * repo's `npm test` (firebase emulators:exec … jest). Proves the additive
 * starFindings block: server-write-only, owner-read-own, everyone-else-denied.
 */
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, Timestamp } = require("firebase/firestore");

const RULES_PATH = path.join(__dirname, "..", "firestore.rules");

describe("firestore.rules — starFindings (demo)", () => {
  let testEnv;

  beforeAll(async () => {
    const rules = fs.readFileSync(RULES_PATH, "utf8");
    testEnv = await initializeTestEnvironment({
      projectId: "demo-dino-rules-test",
      firestore: { rules },
    });
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "starFindings", "userA"), {
        dayKey: "2026-07-27", count: 1, updatedAt: Timestamp.now(),
      });
      await setDoc(doc(db, "starFindings", "userA", "tasks", "t1"), {
        status: "found", steps: 12, outcome: "found", dayKey: "2026-07-27",
        durationMs: 45000, createdAt: Timestamp.now(),
      });
    });
  });

  afterAll(async () => {
    if (testEnv) await testEnv.cleanup();
  });

  it("allows the owner reading their own starFindings parent doc", async () => {
    const alice = testEnv.authenticatedContext("userA").firestore();
    await assertSucceeds(getDoc(doc(alice, "starFindings", "userA")));
  });

  it("allows the owner reading their own task doc", async () => {
    const alice = testEnv.authenticatedContext("userA").firestore();
    await assertSucceeds(getDoc(doc(alice, "starFindings", "userA", "tasks", "t1")));
  });

  it("denies another user reading someone else's findings (parent + task)", async () => {
    const bob = testEnv.authenticatedContext("userB").firestore();
    await assertFails(getDoc(doc(bob, "starFindings", "userA")));
    await assertFails(getDoc(doc(bob, "starFindings", "userA", "tasks", "t1")));
  });

  it("denies an unauthenticated read", async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, "starFindings", "userA")));
  });

  it("denies the owner WRITING their own parent doc (server-write-only)", async () => {
    const alice = testEnv.authenticatedContext("userA").firestore();
    await assertFails(setDoc(doc(alice, "starFindings", "userA"), { count: 99 }));
  });

  it("denies the owner WRITING a task doc (server-write-only)", async () => {
    const alice = testEnv.authenticatedContext("userA").firestore();
    await assertFails(setDoc(doc(alice, "starFindings", "userA", "tasks", "forge"), {
      status: "booked", outcome: "booked",
    }));
  });
});
