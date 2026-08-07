import { test, before, after } from "node:test";
import assert from "node:assert";
import { App, deleteApp, initializeApp } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";
import { MONTHLY_STORY_SPEND_PATHS, MonthlyStoryBudgetPolicy, MonthlyStoryBudgetReservation,
  commitMonthlyStoryBudget, deterministicMonthlyStoryReservationId,
  markMonthlyStoryProviderCallStarted,
  reserveMonthlyStoryBudget } from "../monthlyStoryBudget";
import { FirestoreMonthlyStoryBudgetRepository, MonthlyStoryBudgetFirestoreDependency,
  MonthlyStoryBudgetQuery } from "../monthlyStoryBudgetRepository";
import { FirestoreDocument, FirestoreTransaction,
  MonthlyStoryFirestoreDependency } from "../monthlyStoryRepository";
import { FakeFirestore } from "../monthlyStoryFirestoreFake";

/**
 * EMULATOR SUITE — deliberately NOT part of `npm test`.
 *
 * It lives in `src/emulator/` (so it compiles to `lib/emulator/...`) precisely so the fast suite's
 * `node --test lib/*.test.js` glob, which does not recurse, cannot pick it up. Run it with
 * `npm run test:emulator`, which starts the Firestore emulator under a DEMO project id.
 *
 * What it is for: proving the things `FakeFirestore` cannot — real merge semantics, the real
 * error `create()` raises on a duplicate id, whether the emulator enforces composite indexes at
 * all, and what real transaction contention does. Findings are REPORTED (logged + asserted only
 * where the behavior is unambiguous); nothing here is a licence to change production code.
 */

const PROJECT_ID = "demo-monthly-story";
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? "";

const monthKey = "2026-07";
const dayKey = "2026-07-05";
const jobId = `ms_${"a".repeat(64)}`;
const MONTH_PATH = MONTHLY_STORY_SPEND_PATHS.monthly(monthKey);
const DAY_PATH = MONTHLY_STORY_SPEND_PATHS.daily(dayKey);

const policy: MonthlyStoryBudgetPolicy = { textGenerationEnabled: true, audioGenerationEnabled: true,
  monthlyBudgetMicros: 1_000, monthlyTextBudgetMicros: 600, monthlyAudioBudgetMicros: 400,
  dailyTextGenerationCap: 2, monthlyTextGenerationCap: 4, dailyAudioGenerationCap: 1,
  monthlyAudioGenerationCap: 2 };
const base = { jobId, stage: "text" as const, attempt: 1, monthKey, dayKey,
  amountMicros: 200, nowMillis: 100, expiresAtMillis: 200, policy };

/**
 * The one adapter under test beyond the repository itself: real `firebase-admin` Firestore handed
 * to the repository through the SAME injected-dependency seam the fake uses. No production file is
 * touched — the casts exist only because the repository's structural interfaces are deliberately
 * narrower than the admin SDK's classes.
 */
class AdminBudgetFirestore implements MonthlyStoryBudgetFirestoreDependency {
  constructor(readonly db: Firestore) {}

  doc(path: string): FirestoreDocument {
    return this.db.doc(path) as unknown as FirestoreDocument;
  }

  collection(path: string): ReturnType<MonthlyStoryFirestoreDependency["collection"]> {
    return this.db.collection(path) as unknown as ReturnType<MonthlyStoryFirestoreDependency["collection"]>;
  }

  collectionGroup(collectionId: string): MonthlyStoryBudgetQuery {
    return this.db.collectionGroup(collectionId) as unknown as MonthlyStoryBudgetQuery;
  }

  runTransaction<T>(operation: (transaction: FirestoreTransaction) => Promise<T>): Promise<T> {
    return this.db.runTransaction((transaction) =>
      operation(transaction as unknown as FirestoreTransaction));
  }
}

/** Counts how many times a transaction body is INVOKED, which is how a real retry becomes visible. */
class CountingAdminFirestore extends AdminBudgetFirestore {
  attempts = 0;

  runTransaction<T>(operation: (transaction: FirestoreTransaction) => Promise<T>): Promise<T> {
    return super.runTransaction((transaction) => {
      this.attempts += 1;
      return operation(transaction);
    });
  }
}

let app: App;
let db: Firestore;

/** Shape of an arbitrary thrown value, recorded verbatim so the report quotes reality. */
function describeError(error: unknown): Record<string, unknown> {
  if (typeof error !== "object" || error === null) return { thrown: String(error) };
  const value = error as Record<string, unknown> & { constructor?: { name?: string } };
  return { constructor: value.constructor?.name, name: value.name, code: value.code,
    message: value.message, details: value.details, status: value.status,
    ownKeys: Object.keys(value) };
}

async function clearFirestore(): Promise<void> {
  const response = await fetch(
    `http://${EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" });
  assert.ok(response.ok, `emulator wipe failed: ${response.status}`);
}

function repositoryOn(firestore: MonthlyStoryBudgetFirestoreDependency,
  warnings: { message: string; context: Record<string, unknown> }[] = []):
  FirestoreMonthlyStoryBudgetRepository {
  return new FirestoreMonthlyStoryBudgetRepository(firestore,
    (message, context) => warnings.push({ message, context }));
}

before(() => {
  // Fails LOUD rather than silently reaching for application-default credentials and a real
  // project: this file must never be able to touch anything but an emulator.
  assert.ok(EMULATOR_HOST !== "",
    "FIRESTORE_EMULATOR_HOST is unset — run this suite through `npm run test:emulator`");
  app = initializeApp({ projectId: PROJECT_ID }, `monthly-story-emulator-${Date.now()}`);
  db = getFirestore(app);
});

after(async () => {
  await deleteApp(app);
});

// ── 1. the merge write: {...cachedRaw, ...budgetValue} against real Firestore ──

test("EMULATOR: a budget reserve preserves the foreign fields sharing monthlyStorySpend/{month}",
  async () => {
    await clearFirestore();
    const firestore = new AdminBudgetFirestore(db);
    const repository = repositoryOn(firestore);

    // Exactly what monthlyStoryAudioRepository and the deterministic generation slot leave behind:
    // their own fields on the SAME documents, with none of the budget ledger's.
    const seededMonth = { audioReservedMicros: 500, audioCommittedMicros: 250,
      audioGenerationCount: 1, deterministicGenerationCount: 2, updatedAtMillis: 1,
      audioLease: { owner: "worker-1", expiresAtMillis: 9_999 }, audioProviderKey: "hume-v3" };
    const seededDay = { audioGenerationCount: 1, deterministicGenerationCount: 2, updatedAtMillis: 1 };
    await db.doc(MONTH_PATH).set(seededMonth);
    await db.doc(DAY_PATH).set(seededDay);

    const monthly = await repository.runTransaction((transaction) =>
      transaction.getMonthlySpend(monthKey));
    const daily = await repository.runTransaction((transaction) => transaction.getDailySpend(dayKey));
    assert.equal(monthly, null, "a foreign-only document means this ledger has nothing stored yet");
    assert.equal(daily, null);

    await reserveMonthlyStoryBudget(repository, base);

    const month = (await db.doc(MONTH_PATH).get()).data() as Record<string, unknown>;
    const day = (await db.doc(DAY_PATH).get()).data() as Record<string, unknown>;

    assert.equal(month.reservedMicros, 200, "the budget ledger's own write landed");
    // The point of the whole test: fields the budget ledger does not own survive byte-for-byte.
    assert.deepStrictEqual(month.audioReservedMicros, seededMonth.audioReservedMicros);
    assert.deepStrictEqual(month.audioCommittedMicros, seededMonth.audioCommittedMicros);
    assert.deepStrictEqual(month.deterministicGenerationCount, seededMonth.deterministicGenerationCount);
    assert.deepStrictEqual(month.audioLease, seededMonth.audioLease, "a nested map survives intact");
    assert.deepStrictEqual(month.audioProviderKey, seededMonth.audioProviderKey);
    assert.deepStrictEqual(day.deterministicGenerationCount, seededDay.deterministicGenerationCount);
    assert.equal(day.budgetTextGenerationCount, 1);

    // Was finding 1, now an ASSERTION: `audioGenerationCount` used to be a name BOTH ledgers wrote,
    // so the merge could not protect it and the budget ledger's own value won. The budget ledger's
    // counters are namespaced at the storage layer now, so the audio ledger's value survives.
    assert.equal(month.audioGenerationCount, seededMonth.audioGenerationCount);
    assert.equal(day.audioGenerationCount, seededDay.audioGenerationCount);
  });

// ── 1b. the cross-ledger field-name collision, against REAL Firestore ──

/**
 * The permanent guard for a corruption this suite ORIGINALLY DEMONSTRATED here: seeding
 * `audioGenerationCount: 1` and running a real budget reserve read the counter back as 0, because
 * both ledgers stored their generation count under that one name on these shared documents.
 *
 * Every ingredient is the real thing — real Firestore, real transaction, real merge semantics —
 * and the reserve is stage `"text"`, which has no business touching an audio counter at all. The
 * audio ledger's own refund path clamps at 0 while the budget's throws `ledger-mismatch` below 1,
 * so the two counters can never be collapsed into one; only a namespace can separate them.
 */
test("EMULATOR: a budget reserve cannot clobber the AUDIO ledger's audioGenerationCount", async () => {
  await clearFirestore();
  const repository = repositoryOn(new AdminBudgetFirestore(db));

  // Audio-ledger-shaped documents, exactly as `acquireAudioLease` leaves them when it runs first:
  // its counters and micros, and crucially NO monthKey / NO dayKey for the budget's parsers.
  await db.doc(MONTH_PATH).set({ audioGenerationCount: 3, audioReservedMicros: 500,
    updatedAtMillis: 1 });
  await db.doc(DAY_PATH).set({ audioGenerationCount: 5, updatedAtMillis: 1 });

  await reserveMonthlyStoryBudget(repository, base);

  const month = (await db.doc(MONTH_PATH).get()).data() as Record<string, unknown>;
  const day = (await db.doc(DAY_PATH).get()).data() as Record<string, unknown>;
  assert.equal(day.audioGenerationCount, 5,
    "the audio ledger's DAILY generation count survives a real budget reserve");
  assert.equal(month.audioGenerationCount, 3,
    "the audio ledger's MONTHLY generation count survives a real budget reserve");
  assert.equal(month.audioReservedMicros, 500);

  // The budget ledger's own counters landed, under their namespaced names and nowhere else.
  assert.equal(month.reservedMicros, 200);
  assert.equal(month.budgetTextGenerationCount, 1);
  assert.equal(month.budgetAudioGenerationCount, 0);
  assert.equal(day.budgetTextGenerationCount, 1);
  assert.equal(Object.keys(month).includes("textGenerationCount"), false,
    "the un-namespaced names are not written to real Firestore either");
  assert.equal(Object.keys(day).includes("textGenerationCount"), false);

  // And the round trip: the second reserve READS the first's stored counters back through the
  // namespaced names, so a half-renamed mapping cannot survive a real Firestore round trip.
  await reserveMonthlyStoryBudget(repository, { ...base, attempt: 2, nowMillis: 110,
    expiresAtMillis: 210 });
  const after = (await db.doc(MONTH_PATH).get()).data() as Record<string, unknown>;
  assert.equal(after.budgetTextGenerationCount, 2);
  assert.equal(after.audioGenerationCount, 3, "still untouched by a second reserve");
});

// ── 2. create() on a duplicate reservationId: real Firestore vs the fake ──

test("EMULATOR: create() on a duplicate reservationId — real error shape vs the fake's", async () => {
  await clearFirestore();
  const firestore = new AdminBudgetFirestore(db);
  const repository = repositoryOn(firestore);

  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  assert.equal(reservation.reservationId,
    deterministicMonthlyStoryReservationId(jobId, "text", 1));

  let realError: unknown = null;
  try {
    await repository.runTransaction(async (transaction) => {
      transaction.createReservation(reservation);
    });
  } catch (error) {
    realError = error;
  }

  const fake = new FakeFirestore();
  const fakeRepository = repositoryOn(fake);
  await fakeRepository.runTransaction(async (transaction) => {
    transaction.createReservation(reservation);
  });
  let fakeError: unknown = null;
  try {
    await fakeRepository.runTransaction(async (transaction) => {
      transaction.createReservation(reservation);
    });
  } catch (error) {
    fakeError = error;
  }

  console.log("[finding 2] real create() collision: %o", describeError(realError));
  console.log("[finding 2] fake create() collision: %o", describeError(fakeError));

  assert.ok(realError !== null, "real Firestore rejects a duplicate create()");
  assert.ok(fakeError !== null, "the fake rejects a duplicate create()");
  // The document is unchanged either way — the transaction did not partially apply.
  const stored = (await db.doc(
    MONTHLY_STORY_SPEND_PATHS.reservation(monthKey, reservation.reservationId)).get()).data();
  assert.equal((stored as Record<string, unknown>).status, "reserved");
});

// ── 3. the missing composite index: does the emulator enforce one at all? ──

test("EMULATOR: listExpiredReservations and whether the emulator enforces composite indexes",
  async () => {
    await clearFirestore();
    const firestore = new AdminBudgetFirestore(db);
    const warnings: { message: string; context: Record<string, unknown> }[] = [];
    const repository = repositoryOn(firestore, warnings);

    await reserveMonthlyStoryBudget(repository, base);

    let sweepError: unknown = null;
    let refs: unknown = null;
    try {
      refs = await repository.listExpiredReservations({ nowMillis: 201, limit: 10 });
    } catch (error) {
      sweepError = error;
    }
    console.log("[finding 3a] listExpiredReservations (index IS declared in firestore.indexes.json): " +
      "error=%o refs=%o warnings=%o", describeError(sweepError), refs, warnings);

    // Honest probe, NOT a contrived failure: a DIFFERENT composite query that no index in
    // firestore.indexes.json covers. If this also succeeds, the emulator does not enforce
    // composite-index requirements at all and the FAILED_PRECONDITION branch stays unproven.
    let probeError: unknown = null;
    let probeCount: number | null = null;
    try {
      const snapshot = await db.collectionGroup("reservations")
        .where("jobId", "==", jobId)
        .where("stage", "==", "text")
        .where("createdAtMillis", "<=", 10_000)
        .limit(5)
        .get();
      probeCount = snapshot.docs.length;
    } catch (error) {
      probeError = error;
    }
    console.log("[finding 3b] undeclared-composite-index probe: error=%o docs=%o",
      describeError(probeError), probeCount);

    if (probeError === null) {
      console.log("[finding 3c] The Firestore emulator served a query with NO matching composite " +
        "index. It does not enforce index requirements, so the repository's " +
        "isMissingIndexError / FAILED_PRECONDITION branch CANNOT be exercised here and remains " +
        "UNPROVEN against real Firestore. No fake error was contrived to hide that.");
    } else {
      console.log("[finding 3c] The emulator DID reject an unindexed query — the shape above is " +
        "the real one to compare against isMissingIndexError.");
    }
    // Deliberately no assertion on which way it went: both outcomes are findings, not failures.
    assert.ok(true);
  });

// ── 4. a reserve racing a settlement on the same ledger ──

test("EMULATOR: a duplicate reserve racing a commit on the SAME reservation", async () => {
  await clearFirestore();
  const firestore = new CountingAdminFirestore(db);
  const repository = repositoryOn(firestore);

  await reserveMonthlyStoryBudget(repository, base);
  firestore.attempts = 0;

  const outcomes = await Promise.allSettled([
    reserveMonthlyStoryBudget(repository, base),
    commitMonthlyStoryBudget(repository,
      { reservationId: deterministicMonthlyStoryReservationId(jobId, "text", 1),
        monthKey, actualMicros: 150, nowMillis: 150 }),
  ]);
  console.log("[finding 4a] same-reservation race: transaction bodies invoked=%d outcomes=%o",
    firestore.attempts,
    outcomes.map((outcome) => outcome.status === "fulfilled"
      ? { status: "fulfilled", value: JSON.parse(JSON.stringify(outcome.value)) }
      : { status: "rejected", error: describeError(outcome.reason) }));

  const month = (await db.doc(MONTH_PATH).get()).data() as Record<string, unknown>;
  const stored = (await db.doc(MONTHLY_STORY_SPEND_PATHS.reservation(monthKey,
    deterministicMonthlyStoryReservationId(jobId, "text", 1))).get()).data() as Record<string, unknown>;
  console.log("[finding 4a] month after race=%o reservation.status=%o reservation.committedMicros=%o",
    { reservedMicros: month.reservedMicros, committedMicros: month.committedMicros },
    stored.status, stored.committedMicros);
  assert.ok(true);
});

test("EMULATOR: two contending WRITERS of monthlyStorySpend/{month} — a fresh reserve vs a commit",
  async () => {
    await clearFirestore();
    const firestore = new CountingAdminFirestore(db);
    const repository = repositoryOn(firestore);

    await reserveMonthlyStoryBudget(repository, base);
    firestore.attempts = 0;

    const outcomes = await Promise.allSettled([
      // attempt 2 is a DIFFERENT reservation, so both transactions write the shared month/day docs.
      reserveMonthlyStoryBudget(repository, { ...base, attempt: 2, nowMillis: 120, expiresAtMillis: 220 }),
      commitMonthlyStoryBudget(repository,
        { reservationId: deterministicMonthlyStoryReservationId(jobId, "text", 1),
          monthKey, actualMicros: 150, nowMillis: 150 }),
    ]);
    console.log("[finding 4b] contending-writer race: transaction bodies invoked=%d " +
      "(2 would mean no retry; >2 means real Firestore retried) outcomes=%o",
    firestore.attempts,
    outcomes.map((outcome) => outcome.status === "fulfilled"
      ? { status: "fulfilled" }
      : { status: "rejected", error: describeError(outcome.reason) }));

    const month = (await db.doc(MONTH_PATH).get()).data() as Record<string, unknown>;
    console.log("[finding 4b] month after race=%o", { reservedMicros: month.reservedMicros,
      committedMicros: month.committedMicros,
      budgetTextGenerationCount: month.budgetTextGenerationCount, text: month.text });
    assert.ok(true);
  });

// ── 5. does real Firestore enforce reads-before-writes the way the fake claims? ──

test("EMULATOR: a get() issued after a write inside one real transaction", async () => {
  await clearFirestore();
  const firestore = new AdminBudgetFirestore(db);

  let readAfterWriteError: unknown = null;
  try {
    await firestore.runTransaction(async (transaction) => {
      transaction.set(firestore.doc(MONTH_PATH), { probe: 1 });
      await transaction.get(firestore.doc(DAY_PATH));
    });
  } catch (error) {
    readAfterWriteError = error;
  }
  console.log("[finding 5] real read-after-write inside a transaction: %o",
    describeError(readAfterWriteError));
  assert.ok(readAfterWriteError !== null,
    "real Firestore rejects a get() after a write — the fake's rule is faithful");
});

// ── 6. what markMonthlyStoryProviderCallStarted stores through a real round-trip ──

test("EMULATOR: providerCallStartedAtMillis null survives a real Firestore round-trip", async () => {
  await clearFirestore();
  const firestore = new AdminBudgetFirestore(db);
  const repository = repositoryOn(firestore);

  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  const raw = (await db.doc(MONTHLY_STORY_SPEND_PATHS.reservation(monthKey,
    reservation.reservationId)).get()).data() as Record<string, unknown>;
  // The parser CORRUPTS on anything but null or a safe integer, so a null that came back as
  // undefined (a real Firestore hazard) would be a live bug. It does not.
  assert.strictEqual(raw.providerCallStartedAtMillis, null,
    "null is stored as null, not dropped to undefined");

  const marked: MonthlyStoryBudgetReservation = await markMonthlyStoryProviderCallStarted(
    repository, { reservationId: reservation.reservationId, monthKey }, 150);
  assert.equal(marked.providerCallStartedAtMillis, 150);
  const after = (await db.doc(MONTHLY_STORY_SPEND_PATHS.reservation(monthKey,
    reservation.reservationId)).get()).data() as Record<string, unknown>;
  assert.equal(after.providerCallStartedAtMillis, 150);
});
