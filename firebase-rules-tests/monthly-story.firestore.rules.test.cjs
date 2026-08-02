const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { deleteDoc, doc, getDoc, serverTimestamp, setDoc } = require("firebase/firestore");

const RULES_PATH = path.join(__dirname, "..", "firestore.rules");

describe("monthly story Firestore rules", () => {
  let testEnv;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: "demo-dino-rules-test",
      firestore: { rules: fs.readFileSync(RULES_PATH, "utf8") },
    });
  });

  beforeEach(async () => testEnv.clearFirestore());
  afterAll(async () => { if (testEnv) await testEnv.cleanup(); });

  const settings = () => ({ enabled: false, useJournalThemes: false, useHealthPatterns: false,
    audioEnabled: false, timezone: "UTC", timezoneEffectiveMonth: "2026-08",
    settingsVersion: 1, updatedAt: serverTimestamp() });

  it("denies all client reads and writes to the control document", async () => {
    const alice = testEnv.authenticatedContext("synthetic-user-a").firestore();
    await assertFails(getDoc(doc(alice, "featureFlags", "monthlyStory")));
    await assertFails(setDoc(doc(alice, "featureFlags", "monthlyStory"), { visible: true }));
  });

  it("allows strict owner settings only and rejects cross-user or unknown fields", async () => {
    const alice = testEnv.authenticatedContext("synthetic-user-a").firestore();
    const bob = testEnv.authenticatedContext("synthetic-user-b").firestore();
    await assertSucceeds(setDoc(doc(alice, "monthlyStorySettings", "synthetic-user-a"), settings()));
    await assertSucceeds(getDoc(doc(alice, "monthlyStorySettings", "synthetic-user-a")));
    await assertFails(getDoc(doc(bob, "monthlyStorySettings", "synthetic-user-a")));
    await assertFails(setDoc(doc(bob, "monthlyStorySettings", "synthetic-user-a"), settings()));
    await assertFails(setDoc(doc(alice, "monthlyStorySettings", "synthetic-user-a"),
      { ...settings(), uid: "synthetic-user-b" }));
    await assertFails(setDoc(doc(alice, "monthlyStorySettings", "synthetic-user-a"),
      { ...settings(), timezoneEffectiveMonth: "not-a-month" }));
    await assertSucceeds(deleteDoc(doc(alice, "monthlyStorySettings", "synthetic-user-a")));
  });

  it("allows owner reads but denies every client signal write", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "monthlyStorySignals", "synthetic-user-a", "months", "2026-07"),
        { schemaVersion: 1 });
    });
    const alice = testEnv.authenticatedContext("synthetic-user-a").firestore();
    const bob = testEnv.authenticatedContext("synthetic-user-b").firestore();
    await assertSucceeds(getDoc(doc(alice, "monthlyStorySignals", "synthetic-user-a", "months", "2026-07")));
    await assertFails(getDoc(doc(bob, "monthlyStorySignals", "synthetic-user-a", "months", "2026-07")));
    await assertFails(setDoc(doc(alice, "monthlyStorySignals", "synthetic-user-a", "months", "2026-08"),
      { schemaVersion: 1 }));
  });

  it("allows owner story reads but denies story writes and cross-user reads", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "monthlyStories", "synthetic-user-a", "months", "2026-07"),
        { status: "pending" });
    });
    const alice = testEnv.authenticatedContext("synthetic-user-a").firestore();
    const bob = testEnv.authenticatedContext("synthetic-user-b").firestore();
    await assertSucceeds(getDoc(doc(alice, "monthlyStories", "synthetic-user-a", "months", "2026-07")));
    await assertFails(getDoc(doc(bob, "monthlyStories", "synthetic-user-a", "months", "2026-07")));
    await assertFails(setDoc(doc(alice, "monthlyStories", "synthetic-user-a", "months", "2026-08"),
      { status: "ready" }));
  });

  it("denies all client access to jobs, spend, reservations, daily spend, and tombstones", async () => {
    const alice = testEnv.authenticatedContext("synthetic-user-a").firestore();
    const paths = [
      ["monthlyStoryJobs", "synthetic-job"],
      ["monthlyStorySpend", "2026-07"],
      ["monthlyStorySpend", "2026-07", "reservations", "synthetic-reservation"],
      ["monthlyStoryDailySpend", "2026-07-01"],
      ["monthlyStoryDeleted", "synthetic-user-a", "months", "2026-07"],
    ];
    for (const segments of paths) {
      const reference = doc(alice, ...segments);
      await assertFails(getDoc(reference));
      await assertFails(setDoc(reference, { status: "synthetic" }));
    }
  });

  it("leaves existing user and feedback rules unchanged", async () => {
    const alice = testEnv.authenticatedContext("synthetic-user-a").firestore();
    await assertSucceeds(setDoc(doc(alice, "users", "synthetic-user-a"), { existing: true }));
    await assertSucceeds(getDoc(doc(alice, "users", "synthetic-user-a")));
    await assertSucceeds(setDoc(doc(alice, "feedback", "synthetic-feedback"), { synthetic: true }));
  });
});
