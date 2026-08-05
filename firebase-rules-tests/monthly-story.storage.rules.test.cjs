const fs = require("fs");
const path = require("path");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { deleteObject, getBytes, ref, uploadBytes } = require("firebase/storage");

const RULES_PATH = path.join(__dirname, "..", "storage.rules");

describe("monthly story Storage rules", () => {
  let testEnv;
  const audioPath = "monthlyStories/synthetic-user-a/2026-07/v1/story.mp3";

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: "demo-dino-rules-test",
      storage: { rules: fs.readFileSync(RULES_PATH, "utf8") },
    });
  });

  beforeEach(async () => {
    await testEnv.clearStorage();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(ref(context.storage(), audioPath), new Uint8Array([0, 1, 2]),
        { contentType: "audio/mp4" });
    });
  });
  afterAll(async () => { if (testEnv) await testEnv.cleanup(); });

  it("allows only the authenticated owner to read future story audio", async () => {
    const alice = testEnv.authenticatedContext("synthetic-user-a").storage();
    const bob = testEnv.authenticatedContext("synthetic-user-b").storage();
    const anonymous = testEnv.unauthenticatedContext().storage();
    await assertSucceeds(getBytes(ref(alice, audioPath)));
    await assertFails(getBytes(ref(bob, audioPath)));
    await assertFails(getBytes(ref(anonymous, audioPath)));
  });

  it("denies every client create, overwrite, and delete", async () => {
    const alice = testEnv.authenticatedContext("synthetic-user-a").storage();
    await assertFails(uploadBytes(ref(alice, "monthlyStories/synthetic-user-a/2026-08/v1/story.mp3"),
      new Uint8Array([3]), { contentType: "audio/mp4" }));
    await assertFails(uploadBytes(ref(alice, audioPath), new Uint8Array([4]), { contentType: "audio/mp4" }));
    await assertFails(deleteObject(ref(alice, audioPath)));
  });

  it("leaves existing owner-only journal photo behavior unchanged", async () => {
    const alice = testEnv.authenticatedContext("synthetic-user-a").storage();
    const bob = testEnv.authenticatedContext("synthetic-user-b").storage();
    const photo = ref(alice, "users/synthetic-user-a/journalPhotos/synthetic.jpg");
    await assertSucceeds(uploadBytes(photo, new Uint8Array([1, 2, 3]), { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(photo));
    await assertFails(getBytes(ref(bob, "users/synthetic-user-a/journalPhotos/synthetic.jpg")));
  });
});
