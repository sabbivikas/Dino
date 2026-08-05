const { initializeApp, deleteApp } = require("firebase/app");
const { getAuth, connectAuthEmulator, signInWithEmailAndPassword } = require("firebase/auth");
const { createRequire } = require("node:module");
const path = require("node:path");
const functionsRequire = createRequire(path.resolve(__dirname, "../functions/package.json"));
const { initializeApp: initializeAdminApp, deleteApp: deleteAdminApp } = functionsRequire("firebase-admin/app");
const { getAuth: getAdminAuth } = functionsRequire("firebase-admin/auth");
const { getFirestore } = functionsRequire("firebase-admin/firestore");
const { approvedMonthlyStoryEvaluationFixture } = require("../functions/lib/monthlyStorySyntheticEvaluationFixtures");

const PROJECT_ID = "demo-dino-stage9";
const APP_VERSION = "1.0.0";
const MONTH_KEY = "2026-07";
const GENERATION_VERSION = "deterministic-v1";
const NOW = Date.now();
const emulatorEnabled = Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST &&
  process.env.FIRESTORE_EMULATOR_HOST && process.env.FUNCTIONS_EMULATOR_HOST);

const suite = emulatorEnabled ? describe : describe.skip;

suite("monthly-story callable envelopes", () => {
  let clientApp;
  let adminApp;
  let db;
  let internalToken;
  let internalUid;
  let normalToken;
  let normalUid;

  const control = (overrides = {}) => ({
    visible: true,
    enrollmentEnabled: true,
    signalUploadEnabled: true,
    textGenerationEnabled: true,
    audioGenerationEnabled: false,
    rolloutBasisPoints: 10_000,
    minimumAppVersion: APP_VERSION,
    dailyTextGenerationCap: 2,
    monthlyTextGenerationCap: 2,
    dailyAudioGenerationCap: 0,
    monthlyAudioGenerationCap: 0,
    monthlyBudgetMicros: 0,
    monthlyTextBudgetMicros: 0,
    monthlyAudioBudgetMicros: 0,
    maxTextAttempts: 2,
    maxAudioAttempts: 0,
    generationVersion: GENERATION_VERSION,
    signalSchemaVersion: 1,
    scriptPromptVersion: "deterministic-v1",
    criticPromptVersion: "none-v1",
    ttsVersion: "none-v1",
    humeConfigurationVersion: "none-v1",
    approvedVoiceKey: "disabled",
    maximumAudioScriptCharacters: 0,
    audioRequestTimeoutSeconds: 0,
    humeCostMicrosPerThousandCharacters: 0,
    updatedAt: Date.now(),
    ...overrides,
  });

  const tester = (overrides = {}) => ({
    enabled: true,
    updatedAt: Date.now() - 1_000,
    expiresAt: Date.now() + 60 * 60 * 1_000,
    ...overrides,
  });

  const enabledSettings = () => ({
    enabled: true,
    useJournalThemes: true,
    useHealthPatterns: true,
    audioEnabled: false,
    timezone: "UTC",
    timezoneEffectiveMonth: MONTH_KEY,
    settingsVersion: 1,
  });

  async function clearFirestore() {
    const host = process.env.FIRESTORE_EMULATOR_HOST;
    const response = await fetch(`http://${host}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, {
      method: "DELETE",
    });
    expect(response.ok).toBe(true);
  }

  async function seedAccess(options = {}) {
    await db.doc("featureFlags/monthlyStory").set(options.control ?? control());
    if (options.internal !== false) {
      await db.doc(`monthlyStoryInternalTesters/${internalUid}`).set(options.tester ?? tester());
    }
  }

  async function callable(name, data, token = internalToken, rawBody) {
    const headers = { "content-type": "application/json" };
    if (token) headers.authorization = `Bearer ${token}`;
    const response = await fetch(`http://${process.env.FUNCTIONS_EMULATOR_HOST}/${PROJECT_ID}/us-central1/${name}`, {
      method: "POST",
      headers,
      body: rawBody ?? JSON.stringify({ data }),
    });
    return { status: response.status, body: await response.json() };
  }

  function expectGenericError(response, expectedStatus) {
    expect(response.body).toHaveProperty("error");
    if (expectedStatus) expect(response.body.error.status).toBe(expectedStatus);
    expect(["monthly story unavailable", "request unavailable", "Bad Request"]).toContain(response.body.error.message);
    const serialized = JSON.stringify(response.body);
    expect(serialized).not.toContain(internalUid);
    expect(serialized).not.toContain(normalUid);
    expect(serialized).not.toMatch(/internal-access-denied|control-invalid|signal-invalid|deleted-tombstone|stack/i);
  }

  beforeAll(async () => {
    adminApp = initializeAdminApp({ projectId: PROJECT_ID }, "stage9-admin");
    await getAdminAuth(adminApp).createUser({ uid: "synthetic-user-a",
      email: "internal-stage9@example.test", password: "synthetic-password-1!" });
    await getAdminAuth(adminApp).createUser({ uid: "synthetic-user-b",
      email: "normal-stage9@example.test", password: "synthetic-password-2!" });
    clientApp = initializeApp({ projectId: PROJECT_ID, apiKey: "synthetic-emulator-key" }, "stage9-client");
    const auth = getAuth(clientApp);
    connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, { disableWarnings: true });
    const internal = await signInWithEmailAndPassword(auth, "internal-stage9@example.test", "synthetic-password-1!");
    internalUid = internal.user.uid;
    internalToken = await internal.user.getIdToken();
    const normal = await signInWithEmailAndPassword(auth, "normal-stage9@example.test", "synthetic-password-2!");
    normalUid = normal.user.uid;
    normalToken = await normal.user.getIdToken();
    db = getFirestore(adminApp);
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  afterAll(async () => {
    await Promise.all([deleteApp(clientApp), deleteAdminApp(adminApp)]);
  });

  test("rejects unauthenticated, normal, missing, and expired internal accounts", async () => {
    await seedAccess();
    expectGenericError(await callable("getMonthlyStoryInternalAvailability", { appVersion: APP_VERSION }, null),
      "UNAUTHENTICATED");
    expectGenericError(await callable("getMonthlyStoryInternalAvailability", { appVersion: APP_VERSION }, normalToken),
      "PERMISSION_DENIED");

    await clearFirestore();
    await seedAccess({ internal: false });
    expectGenericError(await callable("getMonthlyStoryInternalAvailability", { appVersion: APP_VERSION }),
      "PERMISSION_DENIED");

    await db.doc(`monthlyStoryInternalTesters/${internalUid}`).set(tester({ expiresAt: Date.now() - 1 }));
    expectGenericError(await callable("getMonthlyStoryInternalAvailability", { appVersion: APP_VERSION }),
      "PERMISSION_DENIED");
  });

  test.each([
    ["missing control", null],
    ["stale control", control({ updatedAt: Date.now() - 25 * 60 * 60 * 1_000 })],
    ["visibility disabled", control({ visible: false })],
    ["enrollment disabled", control({ enrollmentEnabled: false })],
    ["zero rollout", control({ rolloutBasisPoints: 0 })],
  ])("fails closed for %s", async (_label, controlDocument) => {
    await db.doc(`monthlyStoryInternalTesters/${internalUid}`).set(tester());
    if (controlDocument) await db.doc("featureFlags/monthlyStory").set(controlDocument);
    expectGenericError(await callable("getMonthlyStoryInternalAvailability", { appVersion: APP_VERSION }),
      "FAILED_PRECONDITION");
  });

  test("rejects incompatible versions, malformed envelopes, unknown fields, and UID spoofing", async () => {
    await seedAccess({ control: control({ minimumAppVersion: "99.0.0" }) });
    expectGenericError(await callable("getMonthlyStoryInternalAvailability", { appVersion: APP_VERSION }),
      "FAILED_PRECONDITION");

    await db.doc("featureFlags/monthlyStory").set(control());
    expectGenericError(await callable("getMonthlyStoryInternalAvailability", undefined, internalToken,
      JSON.stringify({ wrong: {} })));
    expectGenericError(await callable("getMonthlyStoryInternalAvailability",
      { appVersion: APP_VERSION, unexpected: true }));
    expectGenericError(await callable("updateMonthlyStoryInternalSettings",
      { appVersion: APP_VERSION, settings: enabledSettings(), uid: normalUid }));
  });

  test("all six callables honor defaults, settings, deterministic reuse, remote disable, and deletion", async () => {
    await seedAccess();

    const availability = await callable("getMonthlyStoryInternalAvailability", { appVersion: APP_VERSION });
    expect(availability.body.result).toMatchObject({ visible: true, enrollmentEnabled: true,
      signalUploadEnabled: true, textGenerationEnabled: true, generationVersion: GENERATION_VERSION });

    const defaults = await callable("getMonthlyStoryInternalSettings", { appVersion: APP_VERSION });
    expect(defaults.body.result).toMatchObject({ enabled: false, useJournalThemes: false,
      useHealthPatterns: false, audioEnabled: false });

    const updated = await callable("updateMonthlyStoryInternalSettings",
      { appVersion: APP_VERSION, settings: enabledSettings() });
    expect(updated.body.result).toMatchObject({ enabled: true, useJournalThemes: true,
      useHealthPatterns: true, audioEnabled: false });

    const request = { appVersion: APP_VERSION, monthKey: MONTH_KEY, generationVersion: GENERATION_VERSION,
      signal: approvedMonthlyStoryEvaluationFixture("rich-work-home-projects") };
    const generated = await callable("generateMonthlyStoryInternal", request);
    expect(generated.body.result.reused).toBe(false);
    expect(generated.body.result.story).toMatchObject({ monthKey: MONTH_KEY, status: "textReady",
      compositionMode: "deterministic", providerRequestCount: 0, providerCostMicros: 0 });

    const repeated = await callable("generateMonthlyStoryInternal", request);
    expect(repeated.body.result.reused).toBe(true);
    expect(repeated.body.result.story.scriptHash).toBe(generated.body.result.story.scriptHash);

    const loaded = await callable("loadMonthlyStoryInternalStory",
      { appVersion: APP_VERSION, monthKey: MONTH_KEY });
    expect(loaded.body.result.story.scriptHash).toBe(generated.body.result.story.scriptHash);

    await db.doc("featureFlags/monthlyStory").set(control({ visible: false }));
    expectGenericError(await callable("generateMonthlyStoryInternal", request), "FAILED_PRECONDITION");
    expectGenericError(await callable("updateMonthlyStoryInternalSettings",
      { appVersion: APP_VERSION, settings: enabledSettings() }), "FAILED_PRECONDITION");
    const openWhileDisabled = await callable("loadMonthlyStoryInternalStory",
      { appVersion: APP_VERSION, monthKey: MONTH_KEY });
    expect(openWhileDisabled.body.result.story.scriptHash).toBe(generated.body.result.story.scriptHash);

    const deletionPayload = { appVersion: APP_VERSION, monthKey: MONTH_KEY,
      generationVersion: GENERATION_VERSION };
    expect((await callable("deleteMonthlyStoryInternal", deletionPayload)).body.result).toEqual({ deleted: true });
    expect((await callable("deleteMonthlyStoryInternal", deletionPayload)).body.result).toEqual({ deleted: true });
    expect((await callable("loadMonthlyStoryInternalStory",
      { appVersion: APP_VERSION, monthKey: MONTH_KEY })).body.result.story).toBeNull();

    await db.doc("featureFlags/monthlyStory").set(control());
    expectGenericError(await callable("generateMonthlyStoryInternal", request), "ALREADY_EXISTS");
  }, 60_000);

  test("rejects zero monthly cap and invalid or arbitrary signals before persistence", async () => {
    await seedAccess({ control: control({ monthlyTextGenerationCap: 0 }) });
    await db.doc(`monthlyStorySettings/${internalUid}`).set({ ...enabledSettings(), updatedAt: Date.now() });
    const validSignal = approvedMonthlyStoryEvaluationFixture("rich-work-home-projects");
    expectGenericError(await callable("generateMonthlyStoryInternal", {
      appVersion: APP_VERSION, monthKey: MONTH_KEY, generationVersion: GENERATION_VERSION, signal: validSignal,
    }), "FAILED_PRECONDITION");

    await db.doc("featureFlags/monthlyStory").set(control());
    expectGenericError(await callable("generateMonthlyStoryInternal", {
      appVersion: APP_VERSION, monthKey: MONTH_KEY, generationVersion: GENERATION_VERSION,
      signal: { ...validSignal, rawJournalText: "synthetic but prohibited" },
    }), "INVALID_ARGUMENT");
  });
});
