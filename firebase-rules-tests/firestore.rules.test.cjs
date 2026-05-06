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
const { doc, getDoc, setDoc, Timestamp } = require("firebase/firestore");

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
});
