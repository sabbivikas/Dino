import { test } from "node:test";
import assert from "node:assert";
import { FirestoreMonthlyStoryAudioRepository } from "./monthlyStoryAudioRepository";
import { MonthlyStoryAudioObject, MonthlyStoryAudioServiceError } from "./monthlyStoryAudioService";
import { deterministicMonthlyStoryJobId } from "./monthlyStoryJobs";
import { FirestoreDocument, FirestoreSnapshot, FirestoreTransaction,
  MONTHLY_STORY_PERSISTENCE_VALIDATION_VERSION,
  MonthlyStoryFirestoreDependency } from "./monthlyStoryRepository";

// The audio repository keeps its own spend ledger on `monthlyStorySpend/{month}` and
// `monthlyStoryDailySpend/{day}`, so these tests drive the real Firestore code path through a
// path-keyed in-memory fake rather than an in-memory repository that has no ledger at all.

const uid = "audio-user";
const monthKey = "2026-07";
const generationVersion = "gen-v1";
const leaseOwner = "worker-1";
const reservationMicros = 500;
const nowMillis = Date.UTC(2026, 6, 15, 12);
// Mirrors OWNER_KEY_VERSION inside monthlyStoryAudioRepository.ts.
const jobId = deterministicMonthlyStoryJobId(uid, monthKey, generationVersion, "monthly-story-owner-v1");
const STORY_PATH = `monthlyStories/${uid}/months/${monthKey}`;
const JOB_PATH = `monthlyStoryJobs/${jobId}`;
const MONTH_PATH = "monthlyStorySpend/2026-07";
const DAY_PATH = "monthlyStoryDailySpend/2026-07-15";
const RESERVATION_PATH = `monthlyStorySpend/2026-07/reservations/${jobId}_audio_1`;

type Operation = { kind: "get" | "set" | "create" | "delete"; path: string };

class FakeFirestore implements MonthlyStoryFirestoreDependency {
  readonly documents = new Map<string, Record<string, unknown>>();
  operations: Operation[] = [];

  doc(path: string): FirestoreDocument {
    const snapshot = () => this.snapshot(path);
    return { path, get: async () => snapshot(), delete: async () => { this.documents.delete(path); },
      set: async (data: unknown) => { this.documents.set(path, data as Record<string, unknown>); },
    } as unknown as FirestoreDocument;
  }

  collection(): never { throw new Error("collection queries are unused by these tests"); }

  private snapshot(path: string): FirestoreSnapshot {
    const value = this.documents.get(path);
    return { exists: value !== undefined, data: () => structuredClone(value) };
  }

  async runTransaction<T>(operation: (transaction: FirestoreTransaction) => Promise<T>): Promise<T> {
    const pathOf = (reference: unknown): string => (reference as { path: string }).path;
    const transaction: FirestoreTransaction = {
      get: async (reference) => {
        const path = pathOf(reference);
        this.operations.push({ kind: "get", path });
        return this.snapshot(path);
      },
      create: (reference, data) => {
        const path = pathOf(reference);
        this.operations.push({ kind: "create", path });
        if (this.documents.has(path)) throw new Error("already-exists");
        this.documents.set(path, structuredClone(data) as Record<string, unknown>);
      },
      set: (reference, data) => {
        const path = pathOf(reference);
        this.operations.push({ kind: "set", path });
        this.documents.set(path, structuredClone(data) as Record<string, unknown>);
      },
      delete: (reference) => {
        const path = pathOf(reference);
        this.operations.push({ kind: "delete", path });
        this.documents.delete(path);
      },
    };
    return operation(transaction);
  }
}

function storyDocument(): Record<string, unknown> {
  return { monthKey, generationVersion, compositionVersion: "composer-v1", signalSchemaVersion: 1,
    status: "textReady", script: "A steady month, told back to you. ".repeat(8),
    paragraphs: ["A steady month, told back to you."], wordCount: 120, profile: "rich",
    usedEvidenceIds: ["evidence-001"], usedClaimKeys: ["monthSteady"], usedSuggestionKeys: ["continueRest"],
    scriptHash: "a".repeat(64), createdAtMillis: 1, finalizedAtMillis: 2, expiresAtMillis: 3,
    audioStatus: "notRequested", deletionState: "active",
    validationVersion: MONTHLY_STORY_PERSISTENCE_VALIDATION_VERSION, compositionMode: "deterministic",
    providerRequestCount: 0, providerCostMicros: 0,
    storageCleanup: { state: "notRequired", updatedAtMillis: 2 } };
}

function jobDocument(): Record<string, unknown> {
  return { jobId, ownerKey: "b".repeat(64), monthKey, generationVersion, status: "textReady",
    leaseOwner: null, leaseExpiresAtMillis: null, textAttempts: 1, audioAttempts: 0,
    nextAttemptAtMillis: null, failureCode: null, textArtifactHash: "a".repeat(64),
    audioArtifactHash: null, audioTerminal: false, createdAtMillis: 1, updatedAtMillis: 2 };
}

async function leased(): Promise<{ firestore: FakeFirestore; repository: FirestoreMonthlyStoryAudioRepository }> {
  const firestore = new FakeFirestore();
  firestore.documents.set(STORY_PATH, storyDocument());
  firestore.documents.set(JOB_PATH, jobDocument());
  const repository = new FirestoreMonthlyStoryAudioRepository(firestore);
  const lease = await repository.acquireAudioLease({ uid, monthKey, generationVersion, nowMillis,
    leaseOwner, leaseDurationMillis: 60_000, maximumAttempts: 2, reservationMicros,
    dailyCap: 3, monthlyCap: 5, monthlyBudgetMicros: 10_000 });
  assert.equal(lease.kind, "acquired");
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 1);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 1);
  firestore.operations = [];
  return { firestore, repository };
}

function failure(overrides: { outcomeUncertain: boolean; billableMicros: number }) {
  return { uid, monthKey, generationVersion, leaseOwner, failureCode: "providerRejected",
    transient: false, nowMillis, ...overrides };
}

test("a failure that cost nothing and produced nothing refunds BOTH generation counters", async () => {
  const { firestore, repository } = await leased();
  await repository.markAudioFailure(failure({ outcomeUncertain: false, billableMicros: 0 }));
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "released");
  // micros arithmetic is exactly what it was before the counter refund existed
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioCommittedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros);
});

test("an UNCERTAIN outcome refunds NEITHER counter even when nothing was recorded as billable", async () => {
  const { firestore, repository } = await leased();
  await repository.markAudioFailure(failure({ outcomeUncertain: true, billableMicros: 0 }));
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 1,
    "the provider may have generated and billed; the cap must assume the attempt was spent");
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 1);
  // and the micros arithmetic is untouched by the counter rule
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioCommittedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "released");
});

test("a billable failure refunds neither counter and commits the billed micros", async () => {
  const { firestore, repository } = await leased();
  await repository.markAudioFailure(failure({ outcomeUncertain: true, billableMicros: reservationMicros }));
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 1);
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 1);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioCommittedMicros, reservationMicros);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, 0);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "committed");
});

test("a partially billable failure keeps both counters and splits the micros", async () => {
  const { firestore, repository } = await leased();
  await repository.markAudioFailure(failure({ outcomeUncertain: false, billableMicros: 200 }));
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 1);
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 1);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioCommittedMicros, 200);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros - 200);
});

test("a refund can never drive a generation counter below zero", async () => {
  const { firestore, repository } = await leased();
  firestore.documents.set(MONTH_PATH, { ...firestore.documents.get(MONTH_PATH), audioGenerationCount: 0 });
  firestore.documents.set(DAY_PATH, { ...firestore.documents.get(DAY_PATH), audioGenerationCount: 0 });
  await repository.markAudioFailure(failure({ outcomeUncertain: false, billableMicros: 0 }));
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros);
});

test("a corrupt stored generation counter fails closed instead of being refunded", async () => {
  const monthly = await leased();
  monthly.firestore.documents.set(MONTH_PATH,
    { ...monthly.firestore.documents.get(MONTH_PATH), audioGenerationCount: -1 });
  await assert.rejects(monthly.repository.markAudioFailure(
    failure({ outcomeUncertain: false, billableMicros: 0 })),
  (error: unknown) => error instanceof MonthlyStoryAudioServiceError && error.code === "persistence-failure");

  const daily = await leased();
  daily.firestore.documents.set(DAY_PATH,
    { ...daily.firestore.documents.get(DAY_PATH), audioGenerationCount: 1.5 });
  await assert.rejects(daily.repository.markAudioFailure(
    failure({ outcomeUncertain: false, billableMicros: 0 })),
  (error: unknown) => error instanceof MonthlyStoryAudioServiceError && error.code === "persistence-failure");
});

test("a second failure for the same attempt cannot double-refund either counter", async () => {
  const { firestore, repository } = await leased();
  await repository.markAudioFailure(failure({ outcomeUncertain: false, billableMicros: 0 }));
  await repository.markAudioFailure(failure({ outcomeUncertain: false, billableMicros: 0 }));
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros);
});

test("markAudioFailure issues every read before its first write", async () => {
  const { firestore, repository } = await leased();
  await repository.markAudioFailure(failure({ outcomeUncertain: false, billableMicros: 0 }));
  const firstWrite = firestore.operations.findIndex((operation) => operation.kind !== "get");
  const lastRead = firestore.operations.map((operation) => operation.kind)
    .lastIndexOf("get");
  assert.ok(firstWrite > 0, "the transaction writes");
  assert.ok(lastRead < firstWrite,
    "Firestore rejects a get() issued after a write inside the same transaction");
  assert.ok(firestore.operations.some((operation) => operation.kind === "get" && operation.path === DAY_PATH),
    "the daily ledger is read inside the transaction that refunds it");
});

test("a ready story keeps its generation counters: it consumed a real generation", async () => {
  const { firestore, repository } = await leased();
  const object: MonthlyStoryAudioObject = { path: `monthlyStories/${uid}/${monthKey}/${generationVersion}/story.mp3`,
    hash: "c".repeat(64), bytes: 1_024, durationMillis: 60_000, generatedAtMillis: nowMillis,
    providerRequestCount: 1, estimatedCostMicros: 400, ttsVersion: "tts-v1", voiceKey: "voice-1" };
  const ready = await repository.markAudioReady({ uid, monthKey, generationVersion, leaseOwner,
    object, nowMillis });
  assert.equal(ready.audioStatus, "ready");
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 1);
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 1);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioCommittedMicros, 400);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros - 400);
});

test("markAudioReady issues every read before its first write", async () => {
  const { firestore, repository } = await leased();
  const object: MonthlyStoryAudioObject = { path: `monthlyStories/${uid}/${monthKey}/${generationVersion}/story.mp3`,
    hash: "c".repeat(64), bytes: 1_024, durationMillis: 60_000, generatedAtMillis: nowMillis,
    providerRequestCount: 1, estimatedCostMicros: 400, ttsVersion: "tts-v1", voiceKey: "voice-1" };
  await repository.markAudioReady({ uid, monthKey, generationVersion, leaseOwner, object, nowMillis });
  const firstWrite = firestore.operations.findIndex((operation) => operation.kind !== "get");
  const lastRead = firestore.operations.map((operation) => operation.kind).lastIndexOf("get");
  assert.ok(firstWrite > 0, "the transaction writes");
  assert.ok(lastRead < firstWrite,
    "Firestore rejects a get() issued after a write inside the same transaction");
  for (const path of [RESERVATION_PATH, MONTH_PATH]) {
    assert.ok(firestore.operations.some((operation) => operation.kind === "get" && operation.path === path),
      `${path} is read inside the transaction that settles it`);
  }
});
