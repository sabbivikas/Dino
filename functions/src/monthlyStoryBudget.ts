import { createHash } from "crypto";
import { MonthlyStoryControl } from "./monthlyStoryControl";
import { requireMonthKey } from "./monthlyStorySchema";

export type MonthlyStorySpendStage = "text" | "audio";

export type MonthlyStoryBudgetPolicy = {
  textGenerationEnabled: boolean;
  audioGenerationEnabled: boolean;
  monthlyBudgetMicros: number;
  monthlyTextBudgetMicros: number;
  monthlyAudioBudgetMicros: number;
  dailyTextGenerationCap: number;
  monthlyTextGenerationCap: number;
  dailyAudioGenerationCap: number;
  monthlyAudioGenerationCap: number;
};

export type MonthlyStoryStageTotals = {
  reservedMicros: number;
  committedMicros: number;
  releasedMicros: number;
};

export type MonthlyStoryMonthlySpend = {
  monthKey: string;
  ceilingMicros: number;
  textCeilingMicros: number;
  audioCeilingMicros: number;
  reservedMicros: number;
  committedMicros: number;
  releasedMicros: number;
  textGenerationCount?: number;
  audioGenerationCount?: number;
  text: MonthlyStoryStageTotals;
  audio: MonthlyStoryStageTotals;
  updatedAtMillis: number;
};

export type MonthlyStoryDailySpend = {
  dayKey: string;
  textGenerationCount: number;
  audioGenerationCount: number;
  updatedAtMillis: number;
};

export type MonthlyStoryBudgetReservation = {
  /**
   * Discriminator stamped on every reservation this module creates. `monthlyStoryAudioRepository`
   * keeps a SEPARATE, differently shaped spend ledger under the very same
   * `monthlyStorySpend/{month}/reservations/{id}` path, with the same `status: "reserved"` and
   * `expiresAtMillis` fields, so the collection-group sweep would happily match its documents.
   * Every sweep query filters on `ledger == "budget"` so it can only ever see this module's rows.
   * Chosen over a `stage != "audio"` filter deliberately: Firestore allows a range filter on only
   * one field per query and `!=` is an inequality, so it would collide with the `expiresAtMillis`
   * range; and `stage == "text"` would silently under-cover if this module's own audio stage is
   * ever wired up.
   */
  ledger: "budget";
  reservationId: string;
  jobId: string;
  monthKey: string;
  dayKey: string;
  stage: MonthlyStorySpendStage;
  attempt: number;
  amountMicros: number;
  committedMicros: number;
  status: "reserved" | "committed" | "released";
  providerCallStartedAtMillis: number | null;
  expiresAtMillis: number;
  createdAtMillis: number;
  updatedAtMillis: number;
};

export interface MonthlyStoryBudgetTransaction {
  getMonthlySpend(monthKey: string): Promise<MonthlyStoryMonthlySpend | null>;
  getDailySpend(dayKey: string): Promise<MonthlyStoryDailySpend | null>;
  getReservation(reservationId: string): Promise<MonthlyStoryBudgetReservation | null>;
  setMonthlySpend(value: MonthlyStoryMonthlySpend): void;
  setDailySpend(value: MonthlyStoryDailySpend): void;
  createReservation(value: MonthlyStoryBudgetReservation): void;
  setReservation(value: MonthlyStoryBudgetReservation): void;
}

export interface MonthlyStoryBudgetRepository {
  runTransaction<T>(operation: (transaction: MonthlyStoryBudgetTransaction) => Promise<T>): Promise<T>;
  /**
   * Reservations still in `status === "reserved"` whose `expiresAtMillis <= nowMillis`,
   * capped at `limit`. The sweep in `reserveMonthlyStoryBudget` uses this so abandoned
   * reservations cannot hold micros against the monthly ceiling forever.
   *
   * MUST additionally filter on `ledger == "budget"`. The reservation path is shared with the
   * audio repository's parallel ledger, whose documents carry the same `status`/`expiresAtMillis`
   * shape but none of this module's fields; releasing one would corrupt a ledger this module does
   * not own. Implementations that cannot enforce the filter must return nothing.
   */
  listExpiredReservations(input: { nowMillis: number; limit: number }):
    Promise<MonthlyStoryReservationRef[]>;
}

export type MonthlyStoryReservationRef = { reservationId: string; monthKey: string; dayKey: string };

/** One reservation the sweep could not release, with enough detail to act on it. */
export type MonthlyStoryReconcileFailure = {
  reservationId: string;
  code: string;
  /**
   * `true` for outcomes that are NORMAL in a sweep rather than anomalies, so a genuine problem
   * still stands out. The read-then-release spans two transactions, so a reservation can be
   * committed in between and the release then throws `reservation-state`; a foreign document that
   * slipped past the ledger filter throws `ledger-mismatch`. Anything else is unexpected.
   */
  expected: boolean;
};

export type MonthlyStoryReconcileResult = {
  released: number;
  failed: number;
  failures: MonthlyStoryReconcileFailure[];
};

/**
 * Optional sink for sweep failures. This module is deliberately PURE (it imports `crypto` and
 * local modules only, which the secret-scoping test depends on), so it never reaches for the
 * `firebase-functions` logger; the caller injects one of these, or reads the structured result.
 */
export type MonthlyStoryReconcileObserver = (failure: MonthlyStoryReconcileFailure) => void;

const EXPECTED_RECONCILE_FAILURE_CODES: readonly string[] = ["reservation-state", "ledger-mismatch"];

/** Reported instead of a reservation id when the sweep itself (not one row) failed. */
export const MONTHLY_STORY_SWEEP_FAILURE_ID = "*sweep*";

/** Bounded work a single reserve is willing to do on behalf of the sweep. */
export const MONTHLY_STORY_RESERVE_SWEEP_LIMIT = 10;

export class MonthlyStoryBudgetError extends Error {
  constructor(readonly code: "disabled" | "missing-policy" | "monthly-cap" | "stage-cap" |
    "daily-cap" | "invalid-amount" | "reservation-conflict" | "reservation-missing" |
    "reservation-state" | "reservation-expired" | "ledger-mismatch") {
    super(code);
    this.name = "MonthlyStoryBudgetError";
  }
}

export function monthlyStoryBudgetPolicy(control: MonthlyStoryControl): MonthlyStoryBudgetPolicy {
  return {
    textGenerationEnabled: control.textGenerationEnabled,
    audioGenerationEnabled: control.audioGenerationEnabled,
    monthlyBudgetMicros: control.monthlyBudgetMicros,
    monthlyTextBudgetMicros: control.monthlyTextBudgetMicros,
    monthlyAudioBudgetMicros: control.monthlyAudioBudgetMicros,
    dailyTextGenerationCap: control.dailyTextGenerationCap,
    monthlyTextGenerationCap: control.monthlyTextGenerationCap,
    dailyAudioGenerationCap: control.dailyAudioGenerationCap,
    monthlyAudioGenerationCap: control.monthlyAudioGenerationCap,
  };
}

function validNonNegative(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 0;
}

function validPolicy(policy: MonthlyStoryBudgetPolicy | null): policy is MonthlyStoryBudgetPolicy {
  return policy !== null && [policy.monthlyBudgetMicros, policy.monthlyTextBudgetMicros,
    policy.monthlyAudioBudgetMicros, policy.dailyTextGenerationCap, policy.monthlyTextGenerationCap,
    policy.dailyAudioGenerationCap, policy.monthlyAudioGenerationCap].every(validNonNegative) &&
    policy.monthlyTextBudgetMicros + policy.monthlyAudioBudgetMicros <= policy.monthlyBudgetMicros;
}

function requireDayKey(value: string): string {
  if (!/^\d{4}-(0[1-9]|1[0-2])-([0-2]\d|3[01])$/.test(value)) {
    throw new MonthlyStoryBudgetError("ledger-mismatch");
  }
  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
    throw new MonthlyStoryBudgetError("ledger-mismatch");
  }
  return value;
}

export function deterministicMonthlyStoryReservationId(
  jobId: string,
  stage: MonthlyStorySpendStage,
  attempt: number
): string {
  if (!/^ms_[a-f0-9]{64}$/.test(jobId) || !Number.isSafeInteger(attempt) || attempt < 1 || attempt > 100) {
    throw new MonthlyStoryBudgetError("reservation-conflict");
  }
  return `msr_${createHash("sha256").update(`${jobId}\0${stage}\0${attempt}`).digest("hex")}`;
}

function emptyMonthly(monthKey: string, policy: MonthlyStoryBudgetPolicy, nowMillis: number): MonthlyStoryMonthlySpend {
  const totals = (): MonthlyStoryStageTotals => ({ reservedMicros: 0, committedMicros: 0, releasedMicros: 0 });
  return { monthKey, ceilingMicros: policy.monthlyBudgetMicros,
    textCeilingMicros: policy.monthlyTextBudgetMicros, audioCeilingMicros: policy.monthlyAudioBudgetMicros,
    reservedMicros: 0, committedMicros: 0, releasedMicros: 0,
    textGenerationCount: 0,
    audioGenerationCount: 0,
    text: totals(), audio: totals(), updatedAtMillis: nowMillis };
}

function emptyDaily(dayKey: string, nowMillis: number): MonthlyStoryDailySpend {
  return { dayKey, textGenerationCount: 0, audioGenerationCount: 0, updatedAtMillis: nowMillis };
}

function verifyLedgerPolicy(ledger: MonthlyStoryMonthlySpend, policy: MonthlyStoryBudgetPolicy): void {
  if (ledger.ceilingMicros !== policy.monthlyBudgetMicros ||
      ledger.textCeilingMicros !== policy.monthlyTextBudgetMicros ||
      ledger.audioCeilingMicros !== policy.monthlyAudioBudgetMicros) {
    throw new MonthlyStoryBudgetError("ledger-mismatch");
  }
}

function stageTotals(ledger: MonthlyStoryMonthlySpend, stage: MonthlyStorySpendStage): MonthlyStoryStageTotals {
  return stage === "text" ? ledger.text : ledger.audio;
}

function generationEnabled(policy: MonthlyStoryBudgetPolicy, stage: MonthlyStorySpendStage): boolean {
  return stage === "text" ? policy.textGenerationEnabled : policy.audioGenerationEnabled;
}

function dailyCount(daily: MonthlyStoryDailySpend, stage: MonthlyStorySpendStage): number {
  return stage === "text" ? daily.textGenerationCount : daily.audioGenerationCount;
}

function dailyCap(policy: MonthlyStoryBudgetPolicy, stage: MonthlyStorySpendStage): number {
  return stage === "text" ? policy.dailyTextGenerationCap : policy.dailyAudioGenerationCap;
}

function stageCeiling(ledger: MonthlyStoryMonthlySpend, stage: MonthlyStorySpendStage): number {
  return stage === "text" ? ledger.textCeilingMicros : ledger.audioCeilingMicros;
}

/** Monthly generation counters are optional on the stored doc; normalize exactly as reserve does. */
function monthlyGenerationCount(ledger: MonthlyStoryMonthlySpend, stage: MonthlyStorySpendStage): number {
  const value = stage === "text" ? ledger.textGenerationCount : ledger.audioGenerationCount;
  return typeof value === "number" && validNonNegative(value) ? value : 0;
}

export async function reserveMonthlyStoryBudget(
  repository: MonthlyStoryBudgetRepository,
  input: { jobId: string; stage: MonthlyStorySpendStage; attempt: number; monthKey: string; dayKey: string;
    amountMicros: number; nowMillis: number; expiresAtMillis: number; policy: MonthlyStoryBudgetPolicy | null;
    onSweepFailure?: MonthlyStoryReconcileObserver }
): Promise<{ reservation: MonthlyStoryBudgetReservation; duplicate: boolean }> {
  if (!validPolicy(input.policy)) throw new MonthlyStoryBudgetError("missing-policy");
  const policy = input.policy;
  if (!generationEnabled(policy, input.stage) || policy.monthlyBudgetMicros === 0 ||
      stageCeiling(emptyMonthly("2000-01", policy, 0), input.stage) === 0 || dailyCap(policy, input.stage) === 0) {
    throw new MonthlyStoryBudgetError("disabled");
  }
  if (!Number.isSafeInteger(input.amountMicros) || input.amountMicros <= 0 ||
      !validNonNegative(input.nowMillis) || !validNonNegative(input.expiresAtMillis) ||
      input.expiresAtMillis <= input.nowMillis) throw new MonthlyStoryBudgetError("invalid-amount");
  const monthKey = requireMonthKey(input.monthKey);
  const dayKey = requireDayKey(input.dayKey);
  if (!dayKey.startsWith(`${monthKey}-`)) throw new MonthlyStoryBudgetError("ledger-mismatch");
  const reservationId = deterministicMonthlyStoryReservationId(input.jobId, input.stage, input.attempt);
  // Opportunistic sweep of expired reservations, so micros they still hold are freed
  // BEFORE this reserve's ceiling/cap checks run. Deliberately OUTSIDE the reserve's
  // own transaction — reconcile opens its own, and nesting would deadlock. Bounded to
  // MONTHLY_STORY_RESERVE_SWEEP_LIMIT so a reserve never does unbounded work, and
  // best-effort: a sweep failure (a missing composite index surfaces as
  // FAILED_PRECONDITION) must never fail an otherwise-valid reserve.
  try {
    await reconcileExpiredMonthlyStoryReservations(repository, null, input.nowMillis,
      MONTHLY_STORY_RESERVE_SWEEP_LIMIT, input.onSweepFailure);
  } catch (error) {
    // Continue — the reserve below is authoritative either way — but do NOT vanish: a sweep that
    // cannot even list its candidates would otherwise be invisible forever, and every subsequent
    // reserve would keep skipping reconciliation in silence.
    input.onSweepFailure?.({ reservationId: MONTHLY_STORY_SWEEP_FAILURE_ID,
      code: error instanceof MonthlyStoryBudgetError ? error.code : "sweep-failed", expected: false });
  }
  return repository.runTransaction(async (transaction) => {
    const existing = await transaction.getReservation(reservationId);
    if (existing) {
      if (existing.jobId !== input.jobId || existing.stage !== input.stage ||
          existing.attempt !== input.attempt || existing.amountMicros !== input.amountMicros ||
          existing.monthKey !== monthKey || existing.dayKey !== dayKey) {
        throw new MonthlyStoryBudgetError("reservation-conflict");
      }
      return { reservation: existing, duplicate: true };
    }
    const storedMonthly = await transaction.getMonthlySpend(monthKey) ??
      emptyMonthly(monthKey, policy, input.nowMillis);
    const monthly: MonthlyStoryMonthlySpend & { textGenerationCount: number; audioGenerationCount: number } = {
      ...storedMonthly,
      textGenerationCount: typeof storedMonthly.textGenerationCount === "number" &&
        validNonNegative(storedMonthly.textGenerationCount) ? storedMonthly.textGenerationCount : 0,
      audioGenerationCount: typeof storedMonthly.audioGenerationCount === "number" &&
        validNonNegative(storedMonthly.audioGenerationCount) ? storedMonthly.audioGenerationCount : 0,
    };
    const daily = await transaction.getDailySpend(dayKey) ?? emptyDaily(dayKey, input.nowMillis);
    verifyLedgerPolicy(monthly, policy);
    const stage = stageTotals(monthly, input.stage);
    if (monthly.reservedMicros + monthly.committedMicros + input.amountMicros > monthly.ceilingMicros) {
      throw new MonthlyStoryBudgetError("monthly-cap");
    }
    if (stage.reservedMicros + stage.committedMicros + input.amountMicros > stageCeiling(monthly, input.stage)) {
      throw new MonthlyStoryBudgetError("stage-cap");
    }
    if (dailyCount(daily, input.stage) >= dailyCap(policy, input.stage)) {
      throw new MonthlyStoryBudgetError("daily-cap");
    }
    if (input.stage === "text" && (policy.monthlyTextGenerationCap === 0 ||
        monthly.textGenerationCount >= policy.monthlyTextGenerationCap)) {
      throw new MonthlyStoryBudgetError("monthly-cap");
    }
    if (input.stage === "audio" && (policy.monthlyAudioGenerationCap === 0 ||
        monthly.audioGenerationCount >= policy.monthlyAudioGenerationCap)) {
      throw new MonthlyStoryBudgetError("monthly-cap");
    }
    const reservation: MonthlyStoryBudgetReservation = { ledger: "budget", reservationId, jobId: input.jobId,
      monthKey, dayKey,
      stage: input.stage, attempt: input.attempt, amountMicros: input.amountMicros,
      committedMicros: 0, status: "reserved", providerCallStartedAtMillis: null,
      expiresAtMillis: input.expiresAtMillis, createdAtMillis: input.nowMillis,
      updatedAtMillis: input.nowMillis };
    const updatedStage = { ...stage, reservedMicros: stage.reservedMicros + input.amountMicros };
    const updatedMonthly = { ...monthly, reservedMicros: monthly.reservedMicros + input.amountMicros,
      textGenerationCount: monthly.textGenerationCount + (input.stage === "text" ? 1 : 0),
      audioGenerationCount: monthly.audioGenerationCount + (input.stage === "audio" ? 1 : 0),
      [input.stage]: updatedStage, updatedAtMillis: input.nowMillis } as MonthlyStoryMonthlySpend;
    const updatedDaily = { ...daily,
      textGenerationCount: daily.textGenerationCount + (input.stage === "text" ? 1 : 0),
      audioGenerationCount: daily.audioGenerationCount + (input.stage === "audio" ? 1 : 0),
      updatedAtMillis: input.nowMillis };
    transaction.setMonthlySpend(updatedMonthly);
    transaction.setDailySpend(updatedDaily);
    transaction.createReservation(reservation);
    return { reservation, duplicate: false };
  });
}

export async function markMonthlyStoryProviderCallStarted(
  repository: MonthlyStoryBudgetRepository,
  reservationId: string,
  nowMillis: number
): Promise<MonthlyStoryBudgetReservation> {
  return repository.runTransaction(async (transaction) => {
    const reservation = await transaction.getReservation(reservationId);
    if (!reservation) throw new MonthlyStoryBudgetError("reservation-missing");
    if (reservation.status !== "reserved") throw new MonthlyStoryBudgetError("reservation-state");
    if (reservation.expiresAtMillis <= nowMillis) throw new MonthlyStoryBudgetError("reservation-expired");
    if (reservation.providerCallStartedAtMillis !== null) return reservation;
    const updated = { ...reservation, providerCallStartedAtMillis: nowMillis, updatedAtMillis: nowMillis };
    transaction.setReservation(updated);
    return updated;
  });
}

export async function commitMonthlyStoryBudget(
  repository: MonthlyStoryBudgetRepository,
  input: { reservationId: string; monthKey: string; actualMicros: number; nowMillis: number }
): Promise<MonthlyStoryBudgetReservation> {
  if (!validNonNegative(input.actualMicros)) throw new MonthlyStoryBudgetError("invalid-amount");
  const monthKey = requireMonthKey(input.monthKey);
  return repository.runTransaction(async (transaction) => {
    const reservation = await transaction.getReservation(input.reservationId);
    if (!reservation) throw new MonthlyStoryBudgetError("reservation-missing");
    if (reservation.monthKey !== monthKey) throw new MonthlyStoryBudgetError("ledger-mismatch");
    if (reservation.status === "committed" && reservation.committedMicros === input.actualMicros) return reservation;
    if (reservation.status !== "reserved" || input.actualMicros > reservation.amountMicros) {
      throw new MonthlyStoryBudgetError("reservation-state");
    }
    const monthly = await transaction.getMonthlySpend(monthKey);
    if (!monthly) throw new MonthlyStoryBudgetError("ledger-mismatch");
    const stage = stageTotals(monthly, reservation.stage);
    const released = reservation.amountMicros - input.actualMicros;
    if (monthly.reservedMicros < reservation.amountMicros || stage.reservedMicros < reservation.amountMicros ||
        monthly.committedMicros + input.actualMicros > monthly.ceilingMicros ||
        stage.committedMicros + input.actualMicros > stageCeiling(monthly, reservation.stage)) {
      throw new MonthlyStoryBudgetError("ledger-mismatch");
    }
    const updatedStage = { reservedMicros: stage.reservedMicros - reservation.amountMicros,
      committedMicros: stage.committedMicros + input.actualMicros,
      releasedMicros: stage.releasedMicros + released };
    transaction.setMonthlySpend({ ...monthly,
      reservedMicros: monthly.reservedMicros - reservation.amountMicros,
      committedMicros: monthly.committedMicros + input.actualMicros,
      releasedMicros: monthly.releasedMicros + released,
      [reservation.stage]: updatedStage, updatedAtMillis: input.nowMillis } as MonthlyStoryMonthlySpend);
    const updated: MonthlyStoryBudgetReservation = { ...reservation, committedMicros: input.actualMicros,
      status: "committed", updatedAtMillis: input.nowMillis };
    transaction.setReservation(updated);
    return updated;
  });
}

export async function releaseMonthlyStoryBudget(
  repository: MonthlyStoryBudgetRepository,
  input: { reservationId: string; monthKey: string; dayKey: string; nowMillis: number }
): Promise<MonthlyStoryBudgetReservation> {
  const monthKey = requireMonthKey(input.monthKey);
  const dayKey = requireDayKey(input.dayKey);
  return repository.runTransaction(async (transaction) => {
    const reservation = await transaction.getReservation(input.reservationId);
    if (!reservation) throw new MonthlyStoryBudgetError("reservation-missing");
    // Belt and braces with the sweep's `ledger == "budget"` filter: a document from the audio
    // repository's parallel ledger shares this collection path and must never be released here.
    if (reservation.ledger !== "budget") throw new MonthlyStoryBudgetError("ledger-mismatch");
    if (reservation.monthKey !== monthKey || reservation.dayKey !== dayKey) {
      throw new MonthlyStoryBudgetError("ledger-mismatch");
    }
    if (reservation.status === "released") return reservation;
    if (reservation.status !== "reserved") throw new MonthlyStoryBudgetError("reservation-state");
    const monthly = await transaction.getMonthlySpend(monthKey);
    const daily = await transaction.getDailySpend(dayKey);
    if (!monthly || !daily) throw new MonthlyStoryBudgetError("ledger-mismatch");
    const stage = stageTotals(monthly, reservation.stage);
    if (monthly.reservedMicros < reservation.amountMicros || stage.reservedMicros < reservation.amountMicros) {
      throw new MonthlyStoryBudgetError("ledger-mismatch");
    }
    // A job that died before the provider was called must give its generation slot back —
    // monthly as well as daily. Same guard as the daily refund below: if the provider DID
    // start, the attempt is spent and both counts stand.
    const refundsGenerationCount = reservation.providerCallStartedAtMillis === null;
    const monthlyCount = monthlyGenerationCount(monthly, reservation.stage);
    if (refundsGenerationCount && monthlyCount < 1) throw new MonthlyStoryBudgetError("ledger-mismatch");
    // Only the reservation's OWN stage counter moves, and only when refunding — folded into
    // the single monthly write below so there is never a second setMonthlySpend call.
    const monthlyCountRefund = refundsGenerationCount ?
      { [`${reservation.stage}GenerationCount`]: monthlyCount - 1 } : {};
    const updatedStage = { ...stage, reservedMicros: stage.reservedMicros - reservation.amountMicros,
      releasedMicros: stage.releasedMicros + reservation.amountMicros };
    transaction.setMonthlySpend({ ...monthly, ...monthlyCountRefund,
      reservedMicros: monthly.reservedMicros - reservation.amountMicros,
      releasedMicros: monthly.releasedMicros + reservation.amountMicros,
      [reservation.stage]: updatedStage, updatedAtMillis: input.nowMillis } as MonthlyStoryMonthlySpend);
    if (refundsGenerationCount) {
      const current = dailyCount(daily, reservation.stage);
      if (current < 1) throw new MonthlyStoryBudgetError("ledger-mismatch");
      transaction.setDailySpend({ ...daily,
        textGenerationCount: daily.textGenerationCount - (reservation.stage === "text" ? 1 : 0),
        audioGenerationCount: daily.audioGenerationCount - (reservation.stage === "audio" ? 1 : 0),
        updatedAtMillis: input.nowMillis });
    }
    const updated: MonthlyStoryBudgetReservation = { ...reservation, status: "released",
      updatedAtMillis: input.nowMillis };
    transaction.setReservation(updated);
    return updated;
  });
}

/**
 * Releases expired-but-still-reserved reservations. Callers may hand in explicit IDs
 * (the caller-driven path) or pass `null`/`undefined` to self-sweep via
 * `repository.listExpiredReservations`. Idempotent either way — every candidate is
 * re-read inside its own transaction and only released while still `reserved` and
 * expired.
 *
 * Each reservation is attempted independently: one bad document can never abort the sweep and
 * strand the ones behind it. Failures are NOT swallowed — every one is counted, tagged with its
 * reservation id and error code, classified expected-vs-unexpected, returned in the result, and
 * handed to the optional `onFailure` observer. A failure to LIST candidates still propagates: only
 * the caller knows whether a sweep that could not start is fatal.
 */
export async function reconcileExpiredMonthlyStoryReservations(
  repository: MonthlyStoryBudgetRepository,
  inputs: MonthlyStoryReservationRef[] | null | undefined,
  nowMillis: number,
  limit: number = MONTHLY_STORY_RESERVE_SWEEP_LIMIT,
  onFailure: MonthlyStoryReconcileObserver = () => undefined
): Promise<MonthlyStoryReconcileResult> {
  const targets = inputs ?? await repository.listExpiredReservations({ nowMillis, limit });
  const failures: MonthlyStoryReconcileFailure[] = [];
  let released = 0;
  for (const input of targets) {
    try {
      const reservation = await repository.runTransaction((transaction) =>
        transaction.getReservation(input.reservationId));
      if (reservation?.status === "reserved" && reservation.expiresAtMillis <= nowMillis) {
        await releaseMonthlyStoryBudget(repository, { ...input, nowMillis });
        released++;
      }
    } catch (error) {
      const code = error instanceof MonthlyStoryBudgetError ? error.code : "unexpected-error";
      const failure: MonthlyStoryReconcileFailure = { reservationId: input.reservationId, code,
        expected: EXPECTED_RECONCILE_FAILURE_CODES.includes(code) };
      failures.push(failure);
      onFailure(failure);
    }
  }
  return { released, failed: failures.length, failures };
}

export const MONTHLY_STORY_SPEND_PATHS = Object.freeze({
  monthly: (monthKey: string) => `monthlyStorySpend/${monthKey}`,
  daily: (dayKey: string) => `monthlyStoryDailySpend/${dayKey}`,
  reservation: (monthKey: string, reservationId: string) =>
    `monthlyStorySpend/${monthKey}/reservations/${reservationId}`,
});
