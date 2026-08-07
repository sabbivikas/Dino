import { test } from "node:test";
import assert from "node:assert";
import { FirestoreMonthlyStoryAudioRepository } from "./monthlyStoryAudioRepository";
import { MonthlyStoryAudioObject, MonthlyStoryAudioServiceError } from "./monthlyStoryAudioService";
import { deterministicMonthlyStoryJobId } from "./monthlyStoryJobs";
import { MONTHLY_STORY_PERSISTENCE_VALIDATION_VERSION } from "./monthlyStoryRepository";
import { FakeFirestore } from "./monthlyStoryFirestoreFake";

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

// A lease taken minutes before a UTC month boundary and settled minutes after it. `monthKey` is the
// STORY's month and stays 2026-07; what moves is the billing/day key derived from the wall clock.
const CROSSING_LEASE_MILLIS = Date.UTC(2026, 6, 31, 23, 55);
const CROSSING_SETTLE_MILLIS = Date.UTC(2026, 7, 1, 0, 5);
const NEXT_MONTH_PATH = "monthlyStorySpend/2026-08";
const NEXT_MONTH_RESERVATION_PATH = `monthlyStorySpend/2026-08/reservations/${jobId}_audio_1`;
const LEASE_DAY_PATH = "monthlyStoryDailySpend/2026-07-31";
const SETTLE_DAY_PATH = "monthlyStoryDailySpend/2026-08-01";

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

// Same fixture as `leased()`, but with the lease instant under the caller's control so a lease can
// be taken on one side of a UTC month boundary and settled on the other.
async function leasedAt(leaseMillis: number):
  Promise<{ firestore: FakeFirestore; repository: FirestoreMonthlyStoryAudioRepository }> {
  const firestore = new FakeFirestore();
  firestore.documents.set(STORY_PATH, storyDocument());
  firestore.documents.set(JOB_PATH, jobDocument());
  const repository = new FirestoreMonthlyStoryAudioRepository(firestore);
  const lease = await repository.acquireAudioLease({ uid, monthKey, generationVersion,
    nowMillis: leaseMillis, leaseOwner, leaseDurationMillis: 60_000, maximumAttempts: 2,
    reservationMicros, dailyCap: 3, monthlyCap: 5, monthlyBudgetMicros: 10_000 });
  assert.equal(lease.kind, "acquired");
  firestore.operations = [];
  return { firestore, repository };
}

function audioObject(estimatedCostMicros: number, generatedAtMillis: number): MonthlyStoryAudioObject {
  return { path: `monthlyStories/${uid}/${monthKey}/${generationVersion}/story.mp3`,
    hash: "c".repeat(64), bytes: 1_024, durationMillis: 60_000, generatedAtMillis,
    providerRequestCount: 1, estimatedCostMicros, ttsVersion: "tts-v1", voiceKey: "voice-1" };
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

// A lease reserves against the billing month current when it is TAKEN; settlement recomputes the
// month from its own clock. Everything below pins settlement to the month the reservation actually
// lives in, so a lease that spans a UTC month boundary cannot strand its reserved micros.

test("markAudioReady settles a boundary-crossing lease against the ORIGINAL month", async () => {
  const { firestore, repository } = await leasedAt(CROSSING_LEASE_MILLIS);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, reservationMicros);
  const ready = await repository.markAudioReady({ uid, monthKey, generationVersion, leaseOwner,
    object: audioObject(400, CROSSING_SETTLE_MILLIS), nowMillis: CROSSING_SETTLE_MILLIS });
  assert.equal(ready.audioStatus, "ready");
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, 0,
    "reserved micros must return to 0 in the month that reserved them");
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioCommittedMicros, 400);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros - 400);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "committed");
  assert.equal(firestore.documents.has(NEXT_MONTH_PATH), false,
    "the completion month must not be credited with spend it never reserved");
  assert.equal(firestore.documents.has(NEXT_MONTH_RESERVATION_PATH), false);
});

test("markAudioFailure releases a boundary-crossing lease against the ORIGINAL month", async () => {
  const { firestore, repository } = await leasedAt(CROSSING_LEASE_MILLIS);
  await repository.markAudioFailure({ ...failure({ outcomeUncertain: false, billableMicros: 0 }),
    nowMillis: CROSSING_SETTLE_MILLIS });
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, 0,
    "reserved micros must return to 0 in the month that reserved them");
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioCommittedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "released");
  assert.equal(firestore.documents.has(NEXT_MONTH_PATH), false);
  assert.equal(firestore.documents.has(NEXT_MONTH_RESERVATION_PATH), false);
});

test("a daily counter is refunded on the day the reservation was CREATED, not the completion day", async () => {
  const { firestore, repository } = await leasedAt(CROSSING_LEASE_MILLIS);
  assert.equal(firestore.documents.get(LEASE_DAY_PATH)?.audioGenerationCount, 1);
  await repository.markAudioFailure({ ...failure({ outcomeUncertain: false, billableMicros: 0 }),
    nowMillis: CROSSING_SETTLE_MILLIS });
  assert.equal(firestore.documents.get(LEASE_DAY_PATH)?.audioGenerationCount, 0,
    "the day that was incremented at lease time is the day that gets the slot back");
  assert.equal(firestore.documents.has(SETTLE_DAY_PATH), false,
    "the completion day never incremented, so it must not be decremented");
  assert.ok(firestore.operations.some((operation) => operation.kind === "get" && operation.path === LEASE_DAY_PATH));
  assert.ok(firestore.operations.every((operation) => operation.path !== SETTLE_DAY_PATH));
});

test("the probe rolls the YEAR back too: a Dec-to-Jan lease settles against December", async () => {
  const leaseMillis = Date.UTC(2025, 11, 31, 23, 55);
  const settleMillis = Date.UTC(2026, 0, 1, 0, 5);
  const decemberMonthPath = "monthlyStorySpend/2025-12";
  const decemberReservationPath = `monthlyStorySpend/2025-12/reservations/${jobId}_audio_1`;
  const { firestore, repository } = await leasedAt(leaseMillis);
  assert.equal(firestore.documents.get(decemberMonthPath)?.audioReservedMicros, reservationMicros);
  await repository.markAudioReady({ uid, monthKey, generationVersion, leaseOwner,
    object: audioObject(400, settleMillis), nowMillis: settleMillis });
  assert.equal(firestore.documents.get(decemberMonthPath)?.audioReservedMicros, 0,
    "2026-01 must probe back to 2025-12, not 2026-00");
  assert.equal(firestore.documents.get(decemberMonthPath)?.audioCommittedMicros, 400);
  assert.equal(firestore.documents.get(decemberReservationPath)?.status, "committed");
  assert.equal(firestore.documents.has("monthlyStorySpend/2026-01"), false);
});

test("audioAttempts === 0 skips settlement entirely: no reservation is read or written", async () => {
  const firestore = new FakeFirestore();
  firestore.documents.set(STORY_PATH, storyDocument());
  firestore.documents.set(JOB_PATH, jobDocument());
  const repository = new FirestoreMonthlyStoryAudioRepository(firestore);
  // The object-reconciliation path: the audio object already exists in storage, so no lease was
  // ever taken and no reservation exists to settle.
  const ready = await repository.markAudioReady({ uid, monthKey, generationVersion,
    leaseOwner: "object-reconciliation", object: audioObject(400, nowMillis), nowMillis });
  assert.equal(ready.audioStatus, "ready");
  assert.equal(ready.audioHash, "c".repeat(64));
  assert.equal(firestore.documents.get(STORY_PATH)?.audioStatus, "ready");
  assert.equal(firestore.documents.get(JOB_PATH)?.status, "ready");
  assert.equal(firestore.documents.get(JOB_PATH)?.audioTerminal, true);
  assert.ok(firestore.operations.every((operation) => !operation.path.includes("/reservations/")),
    "no reservation id may be fabricated for an attempt that never took a lease");
  assert.ok(firestore.operations.every((operation) => !operation.path.startsWith("monthlyStorySpend/")),
    "no ledger doc is touched when there is nothing to settle");
});

test("an in-month lease settles exactly as before: markAudioReady never probes the previous month", async () => {
  const { firestore, repository } = await leased();
  await repository.markAudioReady({ uid, monthKey, generationVersion, leaseOwner,
    object: audioObject(400, nowMillis), nowMillis });
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioCommittedMicros, 400);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros - 400);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 1);
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 1);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "committed");
  assert.ok(firestore.operations.every((operation) => !operation.path.includes("2026-06")),
    "the reservation is found in the current month, so the previous month is never read");
});

test("an in-month lease settles exactly as before: markAudioFailure never probes the previous month", async () => {
  const { firestore, repository } = await leased();
  await repository.markAudioFailure(failure({ outcomeUncertain: false, billableMicros: 0 }));
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "released");
  assert.ok(firestore.operations.every((operation) => !operation.path.includes("2026-06")),
    "the reservation is found in the current month, so the previous month is never read");
});

test("a reservation with an unusable createdAtMillis skips the daily refund instead of throwing", async () => {
  const { firestore, repository } = await leased();
  firestore.documents.set(RESERVATION_PATH,
    { ...firestore.documents.get(RESERVATION_PATH), createdAtMillis: "not-a-timestamp" });
  await repository.markAudioFailure(failure({ outcomeUncertain: false, billableMicros: 0 }));
  // the settlement still completes: micros are released and the monthly counter is refunded
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReservedMicros, 0);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioReleasedMicros, reservationMicros);
  assert.equal(firestore.documents.get(MONTH_PATH)?.audioGenerationCount, 0);
  assert.equal(firestore.documents.get(RESERVATION_PATH)?.status, "released");
  // but the daily cap is left over-counted rather than decremented against a guessed day
  assert.equal(firestore.documents.get(DAY_PATH)?.audioGenerationCount, 1);
  assert.ok(firestore.operations.every((operation) => operation.path !== DAY_PATH));
});
