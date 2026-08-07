import { MONTHLY_STORY_SPEND_PATHS, MonthlyStoryBudgetRepository, MonthlyStoryBudgetReservation,
  MonthlyStoryBudgetTransaction, MonthlyStoryDailySpend, MonthlyStoryMonthlySpend,
  MonthlyStoryReservationRef, MonthlyStorySpendStage, MonthlyStoryStageTotals } from "./monthlyStoryBudget";
import { MonthlyStoryFirestoreDependency, snapshotData } from "./monthlyStoryRepository";
import { requireDay, requireMonthKey } from "./monthlyStorySchema";

/**
 * NO CLOCK IN THIS FILE. Every `monthKey` and `dayKey` is either handed in by the caller or read
 * off the stored document; none is ever computed from the wall clock. A reservation is created in
 * exactly one month and settles against THAT month, so a settlement running a minute after a UTC
 * month boundary must still address the month that holds the reservation. Not a convention:
 * `monthlyStoryBudgetRepository.test.ts` asserts that no clock call appears in this source file.
 */

/** Collection id of the month-partitioned reservation subcollection. */
export const MONTHLY_STORY_RESERVATIONS_COLLECTION_ID = "reservations";

/**
 * The composite index the expired-reservation sweep needs, named in the warning that is logged when
 * Firestore rejects the query for want of it. Mirrors firestore.indexes.json exactly.
 */
export const MONTHLY_STORY_EXPIRED_RESERVATION_INDEX =
  "reservations (ledger ASC, status ASC, expiresAtMillis ASC) [COLLECTION_GROUP]";

/** gRPC status code Firestore raises when a query has no matching composite index. */
const FAILED_PRECONDITION_CODE = 9;

export type MonthlyStoryBudgetQuery = {
  where(field: string, operation: "==" | "<=", value: unknown): MonthlyStoryBudgetQuery;
  limit(count: number): MonthlyStoryBudgetQuery;
  get(): Promise<{ docs: { id: string; data(): unknown }[] }>;
};

/**
 * The one capability the budget ledger needs beyond {@link MonthlyStoryFirestoreDependency}:
 * reservations live under `monthlyStorySpend/{month}/reservations`, so finding expired ones across
 * all months is a COLLECTION-GROUP query. Declared as a separate interface, and combined below,
 * so every existing implementer of the base dependency keeps compiling untouched.
 */
export interface MonthlyStoryCollectionGroupDependency {
  collectionGroup(collectionId: string): MonthlyStoryBudgetQuery;
}

export type MonthlyStoryBudgetFirestoreDependency =
  MonthlyStoryFirestoreDependency & MonthlyStoryCollectionGroupDependency;

/**
 * A stored document that cannot be trusted. Deliberately NOT a `MonthlyStoryBudgetError`: the sweep
 * classifies unknown errors as UNEXPECTED, which is exactly what corruption is, whereas every
 * `MonthlyStoryBudgetError` code it knows about is either expected or a caller mistake.
 */
export class MonthlyStoryBudgetRepositoryError extends Error {
  constructor(readonly code: "persistence-failure" | "invalid-repository-input") {
    super(code);
    this.name = "MonthlyStoryBudgetRepositoryError";
  }
}

export type MonthlyStoryBudgetWarning =
  (message: string, context: Record<string, unknown>) => void;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function corrupt(): never {
  throw new MonthlyStoryBudgetRepositoryError("persistence-failure");
}

function nonNegativeInteger(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) corrupt();
  return value as number;
}

function reservationIdToken(value: string): string {
  if (!/^[A-Za-z0-9_-]{1,200}$/.test(value)) {
    throw new MonthlyStoryBudgetRepositoryError("invalid-repository-input");
  }
  return value;
}

function stageTotals(value: unknown): MonthlyStoryStageTotals {
  if (!isRecord(value)) corrupt();
  return { reservedMicros: nonNegativeInteger(value.reservedMicros),
    committedMicros: nonNegativeInteger(value.committedMicros),
    releasedMicros: nonNegativeInteger(value.releasedMicros) };
}

/** Optional on the stored document, but a value that IS present has to be usable. */
function optionalCount(value: unknown): number | undefined {
  return value === undefined ? undefined : nonNegativeInteger(value);
}

/**
 * MALFORMED-DOCUMENT POLICY (all three parsers below):
 *
 *   absent document                        -> null       (nothing stored yet)
 *   present, carries no budget-ledger field -> null       (see the shared-document note)
 *   present, is a foreign AUDIO reservation -> null       (rejected on the `ledger` discriminator)
 *   present, claims to be ours, does not parse -> THROW   (persistence-failure)
 *
 * Returning null for a corrupt budget document would be actively dangerous rather than merely
 * lossy: a monthly ledger read as null is treated by `reserveMonthlyStoryBudget` as "no spend this
 * month", which resets the ceiling accounting and lets the budget be spent again; a reservation
 * read as null makes a live hold look absent, so reserve would re-create it and commit/release
 * would report `reservation-missing` on money that is genuinely held. Money counters fail CLOSED.
 *
 * SHARED DOCUMENTS: `monthlyStorySpend/{month}` and `monthlyStoryDailySpend/{day}` are written by
 * `monthlyStoryAudioRepository`'s parallel ledger and by the deterministic generation slot too. A
 * document holding only those foreign fields means this ledger has nothing stored yet, so the
 * discriminator is a field only this ledger writes: `monthKey` for the month, `dayKey` for the day.
 */
export function parseMonthlyStoryMonthlySpendDocument(value: unknown): MonthlyStoryMonthlySpend | null {
  if (value === null || value === undefined) return null;
  if (!isRecord(value)) corrupt();
  if (value.monthKey === undefined) return null;
  if (typeof value.monthKey !== "string") corrupt();
  return { monthKey: value.monthKey,
    ceilingMicros: nonNegativeInteger(value.ceilingMicros),
    textCeilingMicros: nonNegativeInteger(value.textCeilingMicros),
    audioCeilingMicros: nonNegativeInteger(value.audioCeilingMicros),
    reservedMicros: nonNegativeInteger(value.reservedMicros),
    committedMicros: nonNegativeInteger(value.committedMicros),
    releasedMicros: nonNegativeInteger(value.releasedMicros),
    textGenerationCount: optionalCount(value.textGenerationCount),
    audioGenerationCount: optionalCount(value.audioGenerationCount),
    text: stageTotals(value.text), audio: stageTotals(value.audio),
    updatedAtMillis: nonNegativeInteger(value.updatedAtMillis) };
}

export function parseMonthlyStoryDailySpendDocument(value: unknown): MonthlyStoryDailySpend | null {
  if (value === null || value === undefined) return null;
  if (!isRecord(value)) corrupt();
  if (value.dayKey === undefined) return null;
  if (typeof value.dayKey !== "string") corrupt();
  return { dayKey: value.dayKey,
    textGenerationCount: nonNegativeInteger(value.textGenerationCount),
    audioGenerationCount: nonNegativeInteger(value.audioGenerationCount),
    updatedAtMillis: nonNegativeInteger(value.updatedAtMillis) };
}

/**
 * `monthlyStoryAudioRepository` writes ITS reservations to the very same
 * `monthlyStorySpend/{month}/reservations/{id}` path with a different shape: no `ledger`, no
 * `monthKey`, no `dayKey`, no `providerCallStartedAtMillis`. Those documents are rejected on the
 * `ledger` discriminator and never parsed — parsing one would invent a `monthKey`/`dayKey` for a
 * ledger this module does not own and then settle it against the wrong counters.
 *
 * The stored `monthKey` is validated for SHAPE but never compared with the month this read was
 * addressed at: that comparison belongs to the `reservation.monthKey !== monthKey` guards in
 * commit and release, which stay live as defense in depth.
 */
export function parseMonthlyStoryBudgetReservationDocument(value: unknown, reservationId: string):
MonthlyStoryBudgetReservation | null {
  if (value === null || value === undefined) return null;
  if (!isRecord(value)) corrupt();
  if (value.ledger !== "budget") return null;
  if (typeof value.status !== "string" || !["reserved", "committed", "released"].includes(value.status)) corrupt();
  if (typeof value.stage !== "string" || !["text", "audio"].includes(value.stage)) corrupt();
  if (typeof value.jobId !== "string" || typeof value.monthKey !== "string" ||
      typeof value.dayKey !== "string") corrupt();
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(value.monthKey) ||
      !/^\d{4}-(0[1-9]|1[0-2])-([0-2]\d|3[01])$/.test(value.dayKey)) corrupt();
  if (value.providerCallStartedAtMillis !== null &&
      !Number.isSafeInteger(value.providerCallStartedAtMillis)) corrupt();
  if (value.reservationId !== reservationId) corrupt();
  return { ledger: "budget", reservationId, jobId: value.jobId,
    monthKey: value.monthKey, dayKey: value.dayKey,
    stage: value.stage as MonthlyStorySpendStage,
    attempt: nonNegativeInteger(value.attempt),
    amountMicros: nonNegativeInteger(value.amountMicros),
    committedMicros: nonNegativeInteger(value.committedMicros),
    status: value.status as MonthlyStoryBudgetReservation["status"],
    providerCallStartedAtMillis: value.providerCallStartedAtMillis as number | null,
    expiresAtMillis: nonNegativeInteger(value.expiresAtMillis),
    createdAtMillis: nonNegativeInteger(value.createdAtMillis),
    updatedAtMillis: nonNegativeInteger(value.updatedAtMillis) };
}

function isMissingIndexError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const code = (error as { code?: unknown }).code;
  if (code === FAILED_PRECONDITION_CODE || code === "failed-precondition" ||
      code === "FAILED_PRECONDITION") return true;
  const message = (error as { message?: unknown }).message;
  return typeof message === "string" && message.includes("FAILED_PRECONDITION");
}

/**
 * Firestore-backed {@link MonthlyStoryBudgetRepository}.
 *
 * Constructor shape mirrors `FirestoreMonthlyStoryAudioRepository`: one injected Firestore
 * dependency, plus an optional warning sink so this module never imports a logger of its own.
 */
export class FirestoreMonthlyStoryBudgetRepository implements MonthlyStoryBudgetRepository {
  constructor(private readonly firestore: MonthlyStoryBudgetFirestoreDependency,
    private readonly warn: MonthlyStoryBudgetWarning =
    (message, context) => console.warn(message, context)) {}

  /**
   * All three clauses are REQUIRED, and `ledger == "budget"` most of all: without it this query
   * also matches `monthlyStoryAudioRepository`'s reservations, which share this collection group
   * and carry the same `status`/`expiresAtMillis` shape. The clause is enforced by a test that
   * inspects the predicates the query was built with, not by this comment.
   */
  async listExpiredReservations(input: { nowMillis: number; limit: number }):
  Promise<MonthlyStoryReservationRef[]> {
    const query = this.firestore.collectionGroup(MONTHLY_STORY_RESERVATIONS_COLLECTION_ID)
      .where("ledger", "==", "budget")
      .where("status", "==", "reserved")
      .where("expiresAtMillis", "<=", input.nowMillis)
      .limit(input.limit);
    let snapshot;
    try {
      snapshot = await query.get();
    } catch (error) {
      // The index is declared in firestore.indexes.json but may not be DEPLOYED, and Firestore
      // answers that with FAILED_PRECONDITION. Swallowing it silently would leave a sweep that
      // does nothing forever, with expired reservations piling up against the monthly ceiling and
      // no symptom but inexplicable `monthly-cap` errors — so log loudly, naming the index, and
      // return no candidates. Every other error propagates: the sweep's caller decides.
      if (!isMissingIndexError(error)) throw error;
      this.warn("monthlyStoryBudget expired-reservation sweep found no index and swept nothing", {
        index: MONTHLY_STORY_EXPIRED_RESERVATION_INDEX,
        collectionGroup: MONTHLY_STORY_RESERVATIONS_COLLECTION_ID,
        fields: ["ledger", "status", "expiresAtMillis"],
        remedy: "deploy firestore.indexes.json",
      });
      return [];
    }
    const refs: MonthlyStoryReservationRef[] = [];
    for (const document of snapshot.docs) {
      const data = document.data();
      // Belt and braces with the `ledger` clause above, and the month/day come off the STORED
      // document — never off a clock — so the release addresses the month that holds the hold.
      if (!isRecord(data) || data.ledger !== "budget") continue;
      if (typeof data.monthKey !== "string" || typeof data.dayKey !== "string") {
        this.warn("monthlyStoryBudget sweep skipped a reservation with no usable month or day", {
          reservationId: document.id,
        });
        continue;
      }
      refs.push({ reservationId: document.id, monthKey: data.monthKey, dayKey: data.dayKey });
    }
    return refs;
  }

  runTransaction<T>(operation: (transaction: MonthlyStoryBudgetTransaction) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (firestoreTransaction) => {
      // Raw documents captured during the transaction's READ phase, keyed by path. Writes merge
      // onto them instead of replacing the document, because `monthlyStorySpend/{month}` and
      // `monthlyStoryDailySpend/{day}` are SHARED with the audio ledger and the deterministic
      // generation slot: a plain set() would erase counters this module does not own. Nothing here
      // issues a read of its own, so the module's read-before-write ordering is preserved exactly.
      const merges = new Map<string, Record<string, unknown>>();
      const read = async (path: string): Promise<unknown> => {
        const value = snapshotData(await firestoreTransaction.get(this.firestore.doc(path)));
        if (isRecord(value)) merges.set(path, value);
        return value;
      };
      const mergedSet = (path: string, value: Record<string, unknown>): void => {
        firestoreTransaction.set(this.firestore.doc(path), { ...(merges.get(path) ?? {}), ...value });
      };
      const monthlyPath = (monthKey: string): string =>
        MONTHLY_STORY_SPEND_PATHS.monthly(requireMonthKey(monthKey));
      const dailyPath = (dayKey: string): string =>
        MONTHLY_STORY_SPEND_PATHS.daily(requireDay(dayKey));
      const reservationPath = (monthKey: string, reservationId: string): string =>
        MONTHLY_STORY_SPEND_PATHS.reservation(requireMonthKey(monthKey), reservationIdToken(reservationId));
      const transaction: MonthlyStoryBudgetTransaction = {
        getMonthlySpend: async (monthKey) =>
          parseMonthlyStoryMonthlySpendDocument(await read(monthlyPath(monthKey))),
        getDailySpend: async (dayKey) =>
          parseMonthlyStoryDailySpendDocument(await read(dailyPath(dayKey))),
        getReservation: async (reservationId, monthKey) =>
          parseMonthlyStoryBudgetReservationDocument(
            await read(reservationPath(monthKey, reservationId)), reservationId),
        setMonthlySpend: (value) => mergedSet(monthlyPath(value.monthKey),
          value as unknown as Record<string, unknown>),
        setDailySpend: (value) => mergedSet(dailyPath(value.dayKey),
          value as unknown as Record<string, unknown>),
        // A reservation document is owned outright by this ledger (nobody else writes THIS id), so
        // it is created and replaced whole rather than merged.
        createReservation: (value) => firestoreTransaction.create(
          this.firestore.doc(reservationPath(value.monthKey, value.reservationId)), value),
        setReservation: (value) => firestoreTransaction.set(
          this.firestore.doc(reservationPath(value.monthKey, value.reservationId)), value),
      };
      return operation(transaction);
    });
  }
}
