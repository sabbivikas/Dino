/**
 * Firestore security rules tests (run inside: npm test from this directory).
 * Requires Firebase emulator (spawned by npm script via firebase emulators:exec).
 */
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, Timestamp, serverTimestamp } = require("firebase/firestore");

const RULES_PATH = path.join(__dirname, "..", "firestore.rules");

describe("firestore.rules", () => {
  let testEnv;

  beforeAll(async () => {
    const rules = fs.readFileSync(RULES_PATH, "utf8");
    testEnv = await initializeTestEnvironment({
      projectId: "demo-dino-rules-test",
      firestore: { rules },
    });
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  it("denies unauthenticated read on a user document", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "users", "userA")));
  });

  it("allows a user to read and write their own user document", async () => {
    const db = testEnv.authenticatedContext("userA").firestore();
    await assertSucceeds(
      setDoc(doc(db, "users", "userA"), { userName: "A", lastSynced: Timestamp.now() })
    );
    await assertSucceeds(getDoc(doc(db, "users", "userA")));
  });

  it("denies a user from reading another user's document", async () => {
    const alice = testEnv.authenticatedContext("userA").firestore();
    const setup = testEnv.authenticatedContext("userB").firestore();
    await assertSucceeds(
      setDoc(doc(setup, "users", "userB"), { userName: "B" })
    );
    await assertFails(getDoc(doc(alice, "users", "userB")));
  });

  it("denies a user from writing another user's document", async () => {
    const alice = testEnv.authenticatedContext("userA").firestore();
    await assertFails(
      setDoc(doc(alice, "users", "userB"), { userName: "hijack" })
    );
  });

  it("allows nested subcollections only under the same uid", async () => {
    const alice = testEnv.authenticatedContext("userA").firestore();
    await assertSucceeds(
      setDoc(doc(alice, "users", "userA", "moods", "m1"), { note: "ok" })
    );
    await assertFails(
      getDoc(doc(alice, "users", "userB", "moods", "m1"))
    );
  });

  // rec delivery arc F2 — the no-leak rule: a held delivery (and its
  // payload) is invisible even to its owner; announced becomes readable.
  describe("recDeliveries (F2)", () => {
    beforeAll(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        const meta = {
          deliverAfter: Timestamp.now(), createdAt: Timestamp.now(),
          daypart: "afternoon", tz: "America/New_York", attempts: 0,
        };
        await setDoc(doc(db, "recDeliveries", "userA", "deliveries", "held1"),
          { ...meta, status: "held" });
        await setDoc(doc(db, "recDeliveries", "userA", "deliveries", "ann1"),
          { ...meta, status: "announced" });
        await setDoc(doc(db, "recDeliveries", "userA", "payloads", "held1"),
          { recs: [{ type: "music", title: "clair de lune" }] });
        await setDoc(doc(db, "recDeliveries", "userA", "payloads", "ann1"),
          { recs: [{ type: "music", title: "clair de lune" }] });
      });
    });

    it("denies the OWNER reading a held delivery (no leak)", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(getDoc(doc(alice, "recDeliveries", "userA", "deliveries", "held1")));
    });

    it("denies the OWNER reading a held payload (no leak)", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(getDoc(doc(alice, "recDeliveries", "userA", "payloads", "held1")));
    });

    it("allows the owner reading an announced delivery and its payload", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertSucceeds(getDoc(doc(alice, "recDeliveries", "userA", "deliveries", "ann1")));
      await assertSucceeds(getDoc(doc(alice, "recDeliveries", "userA", "payloads", "ann1")));
    });

    it("denies another user reading an announced delivery", async () => {
      const bob = testEnv.authenticatedContext("userB").firestore();
      await assertFails(getDoc(doc(bob, "recDeliveries", "userA", "deliveries", "ann1")));
      await assertFails(getDoc(doc(bob, "recDeliveries", "userA", "payloads", "ann1")));
    });

    it("denies every client write — deliveries are server-authored", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(setDoc(doc(alice, "recDeliveries", "userA", "deliveries", "held1"),
        { status: "announced" }, { merge: true }));
      await assertFails(setDoc(doc(alice, "recDeliveries", "userA", "deliveries", "mine"),
        { status: "announced", deliverAfter: Timestamp.now() }));
    });
  });

  // rec delivery arc F4 — the reveal's one client write: announced → opened
  // (+ server-stamped openedAt), owner only, nothing else may move.
  describe("recDeliveries opened flip (F4)", () => {
    const { updateDoc } = require("firebase/firestore");
    const meta = () => ({
      deliverAfter: Timestamp.now(), createdAt: Timestamp.now(),
      daypart: "afternoon", tz: "America/New_York", attempts: 0,
    });

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, "recDeliveries", "userA", "deliveries", "flip1"),
          { ...meta(), status: "announced" });
        await setDoc(doc(db, "recDeliveries", "userA", "deliveries", "heldF"),
          { ...meta(), status: "held" });
      });
    });

    it("allows the owner's announced → opened flip with a server-stamped openedAt", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertSucceeds(updateDoc(doc(alice, "recDeliveries", "userA", "deliveries", "flip1"),
        { status: "opened", openedAt: serverTimestamp() }));
    });

    it("denies opening a held delivery (no peeking past the hold)", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(updateDoc(doc(alice, "recDeliveries", "userA", "deliveries", "heldF"),
        { status: "opened", openedAt: serverTimestamp() }));
    });

    it("denies any status other than opened", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(updateDoc(doc(alice, "recDeliveries", "userA", "deliveries", "flip1"),
        { status: "expired", openedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(alice, "recDeliveries", "userA", "deliveries", "flip1"),
        { status: "held", openedAt: serverTimestamp() }));
    });

    it("denies touching any other field alongside the flip", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(updateDoc(doc(alice, "recDeliveries", "userA", "deliveries", "flip1"),
        { status: "opened", openedAt: serverTimestamp(), attempts: 99 }));
      await assertFails(updateDoc(doc(alice, "recDeliveries", "userA", "deliveries", "flip1"),
        { status: "opened", openedAt: serverTimestamp(), deliverAfter: Timestamp.now() }));
    });

    it("denies a client-chosen openedAt", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(updateDoc(doc(alice, "recDeliveries", "userA", "deliveries", "flip1"),
        { status: "opened", openedAt: Timestamp.fromMillis(1000) }));
    });

    it("denies another user flipping someone else's delivery", async () => {
      const bob = testEnv.authenticatedContext("userB").firestore();
      await assertFails(updateDoc(doc(bob, "recDeliveries", "userA", "deliveries", "flip1"),
        { status: "opened", openedAt: serverTimestamp() }));
    });
  });

  // rec delivery arc F2 — presence heartbeat: strict two-field shape,
  // server-stamped time, owner-write-only, nobody reads it back.
  describe("presence (F2)", () => {
    it("allows the owner's strict heartbeat", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertSucceeds(setDoc(doc(alice, "presence", "userA"),
        { lastActiveAt: serverTimestamp(), tz: "America/New_York" }));
    });

    it("denies a heartbeat with extra fields", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(setDoc(doc(alice, "presence", "userA"),
        { lastActiveAt: serverTimestamp(), tz: "America/New_York", mood: "drained" }));
    });

    it("denies a client-chosen timestamp", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(setDoc(doc(alice, "presence", "userA"),
        { lastActiveAt: Timestamp.fromMillis(1000), tz: "America/New_York" }));
    });

    it("denies writing another user's presence", async () => {
      const bob = testEnv.authenticatedContext("userB").firestore();
      await assertFails(setDoc(doc(bob, "presence", "userA"),
        { lastActiveAt: serverTimestamp(), tz: "America/New_York" }));
    });

    it("denies reading presence, even one's own", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(getDoc(doc(alice, "presence", "userA")));
    });
  });

  // rec delivery arc F3 — push token: owner-written strict shape, never
  // client-readable, deletable by the owner (the server-side mute).
  describe("pushTokens (F3)", () => {
    const good = () => ({ token: "fcm-token-abc123", platform: "ios", updatedAt: serverTimestamp() });

    it("allows the owner's strict token write", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertSucceeds(setDoc(doc(alice, "pushTokens", "userA"), good()));
    });

    it("denies extra fields", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(setDoc(doc(alice, "pushTokens", "userA"),
        { ...good(), mood: "drained" }));
    });

    it("denies a non-ios platform and a client-chosen timestamp", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(setDoc(doc(alice, "pushTokens", "userA"),
        { ...good(), platform: "android" }));
      await assertFails(setDoc(doc(alice, "pushTokens", "userA"),
        { token: "t", platform: "ios", updatedAt: Timestamp.fromMillis(1000) }));
    });

    it("denies an oversized or empty token", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(setDoc(doc(alice, "pushTokens", "userA"),
        { ...good(), token: "x".repeat(513) }));
      await assertFails(setDoc(doc(alice, "pushTokens", "userA"),
        { ...good(), token: "" }));
    });

    it("denies writing another user's token", async () => {
      const bob = testEnv.authenticatedContext("userB").firestore();
      await assertFails(setDoc(doc(bob, "pushTokens", "userA"), good()));
    });

    it("denies reading, even one's own; allows the owner's delete (the mute)", async () => {
      const alice = testEnv.authenticatedContext("userA").firestore();
      await assertFails(getDoc(doc(alice, "pushTokens", "userA")));
      const { deleteDoc } = require("firebase/firestore");
      await assertSucceeds(deleteDoc(doc(alice, "pushTokens", "userA")));
    });
  });
});
