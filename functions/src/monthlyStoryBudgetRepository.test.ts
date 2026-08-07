import { test } from "node:test";
import assert from "node:assert";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { MONTHLY_STORY_SPEND_PATHS, MonthlyStoryBudgetPolicy, commitMonthlyStoryBudget,
  deterministicMonthlyStoryReservationId, markMonthlyStoryProviderCallStarted,
  reconcileExpiredMonthlyStoryReservations, releaseMonthlyStoryBudget,
  reserveMonthlyStoryBudget } from "./monthlyStoryBudget";
import { MONTHLY_STORY_EXPIRED_RESERVATION_INDEX, MonthlyStoryBudgetRepositoryError,
  FirestoreMonthlyStoryBudgetRepository } from "./monthlyStoryBudgetRepository";
import { FakeFirestore } from "./monthlyStoryFirestoreFake";

// These tests drive the REAL Firestore code path through the strict FakeFirestore exported by
// monthlyStoryFirestoreFake.ts — the same fake that enforces "all reads before all writes",
// so every transaction below is checked against that rule for free. No second, permissive fake
// exists: a repository that reads after a write fails here the way it would fail in production.

const monthKey = "2026-07";
const dayKey = "2026-07-05";
const jobId = `ms_${"a".repeat(64)}`;
const reservationId = deterministicMonthlyStoryReservationId(jobId, "text", 1);
const MONTH_PATH = MONTHLY_STORY_SPEND_PATHS.monthly(monthKey);
const DAY_PATH = MONTHLY_STORY_SPEND_PATHS.daily(dayKey);
const RESERVATION_PATH = MONTHLY_STORY_SPEND_PATHS.reservation(monthKey, reservationId);

// A lease taken minutes before a UTC month boundary and swept minutes after it.
const CROSSING_MONTH = "2026-07";
const CROSSING_DAY = "2026-07-31";
const CROSSING_RESERVE_MILLIS = Date.UTC(2026, 6, 31, 23, 55);
const CROSSING_EXPIRY_MILLIS = Date.UTC(2026, 6, 31, 23, 56);
const CROSSING_SWEEP_MILLIS = Date.UTC(2026, 7, 1, 0, 5);
const NEXT_MONTH_PATH = MONTHLY_STORY_SPEND_PATHS.monthly("2026-08");
const NEXT_DAY_PATH = MONTHLY_STORY_SPEND_PATHS.daily("2026-08-01");

const policy: MonthlyStoryBudgetPolicy = { textGenerationEnabled: true, audioGenerationEnabled: true,
  monthlyBudgetMicros: 1_000, monthlyTextBudgetMicros: 600, monthlyAudioBudgetMicros: 400,
  dailyTextGenerationCap: 2, monthlyTextGenerationCap: 4, dailyAudioGenerationCap: 1,
  monthlyAudioGenerationCap: 2 };
const base = { jobId, stage: "text" as const, attempt: 1, monthKey, dayKey,
  amountMicros: 200, nowMillis: 100, expiresAtMillis: 200, policy };

type Warning = { message: string; context: Record<string, unknown> };

function setup(): { firestore: FakeFirestore; repository: FirestoreMonthlyStoryBudgetRepository;
  warnings: Warning[] } {
  const firestore = new FakeFirestore();
  const warnings: Warning[] = [];
  const repository = new FirestoreMonthlyStoryBudgetRepository(firestore,
    (message, context) => warnings.push({ message, context }));
  return { firestore, repository, warnings };
}

/**
 * A reservation exactly as `monthlyStoryAudioRepository.acquireAudioLease` creates it: the SAME
 * `monthlyStorySpend/{month}/reservations/{id}` path, the same `status`/`expiresAtMillis` shape,
 * and none of the budget ledger's fields — no `ledger`, `monthKey`, `dayKey`, or
 * `providerCallStartedAtMillis`.
 */
function audioReservationDocument(id: string): Record<string, unknown> {
  return { reservationId: id, jobId, stage: "audio", attempt: 1, status: "reserved",
    amountMicros: 500, committedMicros: 0, createdAtMillis: 1, updatedAtMillis: 1,
    expiresAtMillis: 100 };
}

const AUDIO_RESERVATION_ID = `${jobId}_audio_1`;
const AUDIO_RESERVATION_PATH = MONTHLY_STORY_SPEND_PATHS.reservation(monthKey, AUDIO_RESERVATION_ID);

/**
 * The fake enforces the rule per transaction attempt by throwing; this asserts it positively over
 * the operations of ONE transaction, so `firestore.operations` must be cleared beforehand when an
 * earlier transaction has already run in the same test.
 */
function readsPrecedeWrites(firestore: FakeFirestore): void {
  const firstWrite = firestore.operations.findIndex((operation) => operation.kind !== "get");
  const lastRead = firestore.operations.map((operation) => operation.kind).lastIndexOf("get");
  assert.ok(firstWrite > 0, "the transaction writes");
  assert.ok(lastRead < firstWrite,
    "Firestore rejects a get() issued after a write inside the same transaction");
}

// ── the sweep query: all three clauses, and the ledger clause above all ──

test("the expired sweep queries the reservations collection GROUP with all three clauses", async () => {
  const { firestore, repository } = setup();
  await repository.listExpiredReservations({ nowMillis: 500, limit: 7 });
  const query = firestore.queries.at(-1);
  assert.ok(query, "a collection-group query was built");
  assert.equal(query.collectionId, "reservations");
  assert.deepEqual(query.predicates, [
    { field: "ledger", operation: "==", value: "budget" },
    { field: "status", operation: "==", value: "reserved" },
    { field: "expiresAtMillis", operation: "<=", value: 500 },
  ]);
  assert.equal(query.limit, 7);
  // Stated separately and deliberately: dropping the `ledger` clause would silently hand the sweep
  // the audio repository's reservations, which share this collection group.
  assert.ok(query.predicates.some((predicate) => predicate.field === "ledger" &&
    predicate.operation === "==" && predicate.value === "budget"),
  "the sweep must filter on ledger == \"budget\"");
});

test("the ledger clause hides a foreign audio reservation from the sweep", async () => {
  const { firestore, repository } = setup();
  firestore.documents.set(AUDIO_RESERVATION_PATH, audioReservationDocument(AUDIO_RESERVATION_ID));
  await reserveMonthlyStoryBudget(repository, base);

  assert.deepEqual(await repository.listExpiredReservations({ nowMillis: 201, limit: 10 }),
    [{ reservationId, monthKey, dayKey }], "only this ledger's rows are listed");
  assert.deepEqual(await reconcileExpiredMonthlyStoryReservations(repository, null, 201),
    { released: 1, failed: 0, failures: [] });
  assert.equal(firestore.documents.get(AUDIO_RESERVATION_PATH)?.status, "reserved",
    "the audio ledger's reservation is untouched");
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "released");
  assert.equal(firestore.documents.get(MONTH_PATH)?.reservedMicros, 0);
});

test("the sweep reads month and day off the STORED document, never off a clock", async () => {
  const { firestore, repository } = setup();
  await reserveMonthlyStoryBudget(repository, base);
  firestore.documents.set(RESERVATION_PATH,
    { ...firestore.documents.get(RESERVATION_PATH), monthKey: "2026-07", dayKey: "2026-07-05" });
  assert.deepEqual(await repository.listExpiredReservations({ nowMillis: 201, limit: 10 }),
    [{ reservationId, monthKey: "2026-07", dayKey: "2026-07-05" }]);
});

// ── the missing composite index ──

test("FAILED_PRECONDITION is caught, warned about by index name, and swept as empty", async () => {
  const { firestore, repository, warnings } = setup();
  firestore.queryFailure = Object.assign(
    new Error("9 FAILED_PRECONDITION: The query requires an index."), { code: 9 });
  assert.deepEqual(await repository.listExpiredReservations({ nowMillis: 500, limit: 10 }), []);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0].message, /index/);
  assert.equal(warnings[0].context.index, MONTHLY_STORY_EXPIRED_RESERVATION_INDEX);
  assert.deepEqual(warnings[0].context.fields, ["ledger", "status", "expiresAtMillis"]);
});

test("a reserve still succeeds while the index is missing, and says so once per sweep", async () => {
  const { firestore, repository, warnings } = setup();
  firestore.queryFailure = Object.assign(
    new Error("9 FAILED_PRECONDITION: The query requires an index."), { code: 9 });
  const reserved = await reserveMonthlyStoryBudget(repository, base);
  assert.equal(reserved.duplicate, false);
  assert.equal(firestore.documents.get(MONTH_PATH)?.reservedMicros, 200);
  assert.equal(warnings.length, 1, "a swallowed sweep must never be silent");
});

test("any other query error propagates: the sweep's caller decides", async () => {
  const { firestore, repository, warnings } = setup();
  firestore.queryFailure = Object.assign(new Error("13 INTERNAL: backend error"), { code: 13 });
  await assert.rejects(repository.listExpiredReservations({ nowMillis: 500, limit: 10 }),
    /INTERNAL/);
  assert.deepEqual(warnings, []);
});

// ── audio-shaped documents are rejected, not parsed ──

test("getReservation returns null for an audio-shaped document at the shared path", async () => {
  const { firestore, repository } = setup();
  firestore.documents.set(AUDIO_RESERVATION_PATH, audioReservationDocument(AUDIO_RESERVATION_ID));
  const value = await repository.runTransaction((transaction) =>
    transaction.getReservation(AUDIO_RESERVATION_ID, monthKey));
  assert.equal(value, null, "a document without ledger === \"budget\" is not this ledger's to parse");
  assert.deepEqual(firestore.documents.get(AUDIO_RESERVATION_PATH),
    audioReservationDocument(AUDIO_RESERVATION_ID), "and it is left exactly as it was");
});

test("releasing an audio-shaped reservation cannot corrupt the audio ledger", async () => {
  const { firestore, repository } = setup();
  firestore.documents.set(AUDIO_RESERVATION_PATH, audioReservationDocument(AUDIO_RESERVATION_ID));
  await assert.rejects(releaseMonthlyStoryBudget(repository,
    { reservationId: AUDIO_RESERVATION_ID, monthKey, dayKey, nowMillis: 500 }),
  /reservation-missing/);
  assert.equal(firestore.documents.get(AUDIO_RESERVATION_PATH)?.status, "reserved");
  assert.equal(firestore.documents.has(MONTH_PATH), false);
});

// ── round trips through the real implementation ──

test("reserve -> commit writes every document at its MONTHLY_STORY_SPEND_PATHS address", async () => {
  const { firestore, repository } = setup();
  const reserved = await reserveMonthlyStoryBudget(repository, base);
  assert.equal(reserved.duplicate, false);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "reserved");
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.ledger, "budget");
  assert.equal(firestore.documents.get(MONTH_PATH)?.reservedMicros, 200);
  assert.equal(firestore.documents.get(DAY_PATH)?.budgetTextGenerationCount, 1);
  readsPrecedeWrites(firestore);

  await markMonthlyStoryProviderCallStarted(repository, { reservationId, monthKey }, 120);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.providerCallStartedAtMillis, 120);

  const committed = await commitMonthlyStoryBudget(repository,
    { reservationId, monthKey, actualMicros: 150, nowMillis: 150 });
  assert.equal(committed.status, "committed");
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "committed");
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.committedMicros, 150);
  assert.equal(firestore.documents.get(MONTH_PATH)?.reservedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.committedMicros, 150);
  assert.equal(firestore.documents.get(MONTH_PATH)?.releasedMicros, 50);
  assert.equal(firestore.documents.get(DAY_PATH)?.budgetTextGenerationCount, 1,
    "a committed generation keeps its daily slot");
});

test("reserve -> release refunds micros and both generation counters", async () => {
  const { firestore, repository } = setup();
  await reserveMonthlyStoryBudget(repository, base);
  assert.equal(firestore.documents.get(MONTH_PATH)?.budgetTextGenerationCount, 1);
  firestore.operations = [];
  const released = await releaseMonthlyStoryBudget(repository,
    { reservationId, monthKey, dayKey, nowMillis: 150 });
  assert.equal(released.status, "released");
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "released");
  assert.equal(firestore.documents.get(MONTH_PATH)?.reservedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.releasedMicros, 200);
  assert.equal(firestore.documents.get(MONTH_PATH)?.budgetTextGenerationCount, 0);
  assert.equal(firestore.documents.get(DAY_PATH)?.budgetTextGenerationCount, 0);
  readsPrecedeWrites(firestore);
});

// ── the UTC month boundary ──

test("a reservation swept AFTER a UTC month boundary settles against its ORIGINAL month", async () => {
  const { firestore, repository } = setup();
  await reserveMonthlyStoryBudget(repository, { ...base, monthKey: CROSSING_MONTH, dayKey: CROSSING_DAY,
    nowMillis: CROSSING_RESERVE_MILLIS, expiresAtMillis: CROSSING_EXPIRY_MILLIS });
  const crossingMonthPath = MONTHLY_STORY_SPEND_PATHS.monthly(CROSSING_MONTH);
  const crossingDayPath = MONTHLY_STORY_SPEND_PATHS.daily(CROSSING_DAY);
  const crossingReservationPath = MONTHLY_STORY_SPEND_PATHS.reservation(CROSSING_MONTH, reservationId);
  assert.equal(firestore.documents.get(crossingMonthPath)?.reservedMicros, 200);

  // The sweep runs in August and takes its month/day from the stored reservation, not the clock.
  assert.deepEqual(await reconcileExpiredMonthlyStoryReservations(repository, null, CROSSING_SWEEP_MILLIS),
    { released: 1, failed: 0, failures: [] });
  assert.equal(firestore.documents.get(crossingMonthPath)?.reservedMicros, 0,
    "reserved micros must return to 0 in the month that reserved them");
  assert.equal(firestore.documents.get(crossingMonthPath)?.releasedMicros, 200);
  assert.equal(firestore.documents.get(crossingMonthPath)?.budgetTextGenerationCount, 0);
  assert.equal(firestore.documents.get(crossingDayPath)?.budgetTextGenerationCount, 0);
  assert.equal(firestore.documents.get(crossingReservationPath)?.status, "released");
  assert.equal(firestore.documents.has(NEXT_MONTH_PATH), false,
    "the settling month must not be credited with spend it never reserved");
  assert.equal(firestore.documents.has(NEXT_DAY_PATH), false);
});

test("an explicit release across the boundary also addresses the original month", async () => {
  const { firestore, repository } = setup();
  await reserveMonthlyStoryBudget(repository, { ...base, monthKey: CROSSING_MONTH, dayKey: CROSSING_DAY,
    nowMillis: CROSSING_RESERVE_MILLIS, expiresAtMillis: CROSSING_EXPIRY_MILLIS });
  await releaseMonthlyStoryBudget(repository, { reservationId, monthKey: CROSSING_MONTH,
    dayKey: CROSSING_DAY, nowMillis: CROSSING_SWEEP_MILLIS });
  assert.equal(firestore.documents.get(MONTHLY_STORY_SPEND_PATHS.monthly(CROSSING_MONTH))?.reservedMicros, 0);
  assert.equal(firestore.documents.has(NEXT_MONTH_PATH), false);
  assert.ok(firestore.operations.every((operation) => !operation.path.includes("2026-08")),
    "no August document is even read");
});

// ── malformed and shared documents ──

test("a corrupt budget document fails CLOSED rather than reading as empty", async () => {
  const monthly = setup();
  monthly.firestore.documents.set(MONTH_PATH, { monthKey, ceilingMicros: "lots" });
  await assert.rejects(reserveMonthlyStoryBudget(monthly.repository, base),
    (error: unknown) => error instanceof MonthlyStoryBudgetRepositoryError &&
      error.code === "persistence-failure");

  const reservation = setup();
  await reserveMonthlyStoryBudget(reservation.repository, base);
  reservation.firestore.documents.set(RESERVATION_PATH,
    { ...reservation.firestore.documents.get(RESERVATION_PATH), amountMicros: -1 });
  await assert.rejects(commitMonthlyStoryBudget(reservation.repository,
    { reservationId, monthKey, actualMicros: 10, nowMillis: 150 }),
  (error: unknown) => error instanceof MonthlyStoryBudgetRepositoryError &&
      error.code === "persistence-failure");
  assert.equal(reservation.firestore.documents.get(MONTH_PATH)?.reservedMicros, 200,
    "nothing is written on a corrupt read");
});

test("a spend document holding only the audio ledger's fields reads as empty, and survives a reserve",
  async () => {
    const { firestore, repository } = setup();
    // Exactly what monthlyStoryAudioRepository and the deterministic slot leave behind: their own
    // fields on the SAME documents, with none of this ledger's.
    firestore.documents.set(MONTH_PATH, { audioReservedMicros: 500, audioGenerationCount: 1,
      deterministicGenerationCount: 2, updatedAtMillis: 1 });
    firestore.documents.set(DAY_PATH, { audioGenerationCount: 1, deterministicGenerationCount: 2,
      updatedAtMillis: 1 });
    const monthly = await repository.runTransaction((transaction) =>
      transaction.getMonthlySpend(monthKey));
    const daily = await repository.runTransaction((transaction) => transaction.getDailySpend(dayKey));
    assert.equal(monthly, null, "a foreign-only document means this ledger has nothing stored yet");
    assert.equal(daily, null);

    await reserveMonthlyStoryBudget(repository, base);
    assert.equal(firestore.documents.get(MONTH_PATH)?.reservedMicros, 200);
    assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, 500,
      "a budget write must not erase the audio ledger sharing this document");
    assert.equal(firestore.documents.get(MONTH_PATH)?.deterministicGenerationCount, 2);
    assert.equal(firestore.documents.get(DAY_PATH)?.deterministicGenerationCount, 2);
    assert.equal(firestore.documents.get(DAY_PATH)?.budgetTextGenerationCount, 1);
    assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 1,
      "the audio ledger's own counter is namespaced apart and survives too");
    assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 1);
  });

// ── the cross-ledger FIELD-NAME collision on the shared spend documents ──

/**
 * REGRESSION TEST for a real, empirically confirmed corruption, not a hypothetical.
 *
 * `monthlyStoryAudioRepository` counts ITS generations in a field called `audioGenerationCount` on
 * `monthlyStorySpend/{month}` and `monthlyStoryDailySpend/{day}`. The budget ledger used to store
 * its own, unrelated counter of the same name on the very same documents. When the AUDIO ledger
 * created the document first it carried no `monthKey`/`dayKey`, so this repository's parsers
 * correctly returned null, `reserveMonthlyStoryBudget` started from `emptyMonthly`/`emptyDaily`
 * with counters at 0, and wrote BOTH counters unconditionally — and the `{...cachedRaw,
 * ...budgetValue}` merge cannot protect a field that `budgetValue` itself contains. The audio
 * ledger's count was silently reset to 0, which hands a user back audio generations their cap had
 * already spent. It fired for a stage `"text"` reserve, which never touches audio at all.
 *
 * The fix is a STORAGE-level namespace: this repository reads and writes
 * `budgetTextGenerationCount`/`budgetAudioGenerationCount`, so the two ledgers no longer share a
 * field name. The domain type keeps its `textGenerationCount`/`audioGenerationCount` fields.
 */
test("a budget reserve cannot clobber the AUDIO ledger's audioGenerationCount", async () => {
  const { firestore, repository } = setup();
  // Audio-ledger-shaped documents, created by acquireAudioLease before the budget ledger ever ran:
  // its counters, none of the budget ledger's fields, and crucially NO monthKey / NO dayKey.
  firestore.documents.set(MONTH_PATH,
    { audioGenerationCount: 3, audioReservedMicros: 500, updatedAtMillis: 1 });
  firestore.documents.set(DAY_PATH, { audioGenerationCount: 5, updatedAtMillis: 1 });

  // A TEXT reserve. It has no business touching an audio counter at all.
  await reserveMonthlyStoryBudget(repository, base);

  const month = firestore.documents.get(MONTH_PATH);
  const day = firestore.documents.get(DAY_PATH);
  assert.equal(day?.audioGenerationCount, 5,
    "the audio ledger's DAILY generation count survives a budget reserve");
  assert.equal(month?.audioGenerationCount, 3,
    "the audio ledger's MONTHLY generation count survives a budget reserve");
  assert.equal(month?.audioReservedMicros, 500,
    "and the audio ledger's micros, which never collided, still survive too");
  // The budget ledger's own write still landed, under its own names.
  assert.equal(month?.reservedMicros, 200);
  assert.equal(month?.budgetTextGenerationCount, 1);
  assert.equal(day?.budgetTextGenerationCount, 1);
});

test("the budget ledger's generation counters are stored under NAMESPACED field names", async () => {
  const { firestore, repository } = setup();
  await reserveMonthlyStoryBudget(repository, base);
  const month = firestore.documents.get(MONTH_PATH) as Record<string, unknown>;
  const day = firestore.documents.get(DAY_PATH) as Record<string, unknown>;

  // Namespaced names are what is stored...
  assert.equal(month.budgetTextGenerationCount, 1);
  assert.equal(month.budgetAudioGenerationCount, 0);
  assert.equal(day.budgetTextGenerationCount, 1);
  assert.equal(day.budgetAudioGenerationCount, 0);
  // ...and the bare names, which the AUDIO ledger owns, are not written by this repository at all.
  // A future refactor that "tidies" the mapping away reintroduces the collision and fails here.
  assert.equal(Object.keys(month).includes("audioGenerationCount"), false,
    "audioGenerationCount belongs to monthlyStoryAudioRepository — this ledger must not write it");
  assert.equal(Object.keys(month).includes("textGenerationCount"), false);
  assert.equal(Object.keys(day).includes("audioGenerationCount"), false,
    "audioGenerationCount belongs to monthlyStoryAudioRepository — this ledger must not write it");
  assert.equal(Object.keys(day).includes("textGenerationCount"), false);
});

test("the budget ledger reads its own namespaced counters back — write and read cannot disagree",
  async () => {
    const { firestore, repository } = setup();
    await reserveMonthlyStoryBudget(repository, base);
    // The SECOND reserve has to SEE the first one's stored counters through the namespaced names.
    // A half-renamed mapping (write namespaced, read bare, or the reverse) reads 0 here and writes
    // 1 again instead of 2.
    await reserveMonthlyStoryBudget(repository, { ...base, attempt: 2, nowMillis: 110,
      expiresAtMillis: 210 });
    assert.equal(firestore.documents.get(MONTH_PATH)?.budgetTextGenerationCount, 2);
    assert.equal(firestore.documents.get(DAY_PATH)?.budgetTextGenerationCount, 2);

    // ...and a settlement cycle decrements the same stored fields it incremented.
    await releaseMonthlyStoryBudget(repository, { reservationId:
      deterministicMonthlyStoryReservationId(jobId, "text", 2), monthKey, dayKey, nowMillis: 150 });
    assert.equal(firestore.documents.get(MONTH_PATH)?.budgetTextGenerationCount, 1);
    assert.equal(firestore.documents.get(DAY_PATH)?.budgetTextGenerationCount, 1);
    await commitMonthlyStoryBudget(repository,
      { reservationId, monthKey, actualMicros: 150, nowMillis: 160 });
    assert.equal(firestore.documents.get(MONTH_PATH)?.budgetTextGenerationCount, 1,
      "a committed generation keeps its monthly slot");
    assert.equal(firestore.documents.get(MONTH_PATH)?.reservedMicros, 0);
  });

test("an absent document reads as null, not as an error", async () => {
  const { repository } = setup();
  const values = await repository.runTransaction(async (transaction) => ({
    monthly: await transaction.getMonthlySpend(monthKey),
    daily: await transaction.getDailySpend(dayKey),
    reservation: await transaction.getReservation(reservationId, monthKey),
  }));
  assert.deepEqual(values, { monthly: null, daily: null, reservation: null });
});

test("the repository derives no month or day from a clock", () => {
  const sourceRoot = __dirname.endsWith("lib") ? join(__dirname, "..", "src") : __dirname;
  const source = readFileSync(join(sourceRoot, "monthlyStoryBudgetRepository.ts"), "utf8");
  for (const prohibited of ["Date.now(", "new Date(", "Date.UTC(", "toISOString("]) {
    assert.equal(source.includes(prohibited), false, prohibited);
  }
});
