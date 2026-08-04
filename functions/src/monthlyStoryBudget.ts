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
}

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
  };
}

function validNonNegative(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 0;
}

function validPolicy(policy: MonthlyStoryBudgetPolicy | null): policy is MonthlyStoryBudgetPolicy {
  return policy !== null && [policy.monthlyBudgetMicros, policy.monthlyTextBudgetMicros,
    policy.monthlyAudioBudgetMicros, policy.dailyTextGenerationCap, policy.monthlyTextGenerationCap,
    policy.dailyAudioGenerationCap].every(validNonNegative) &&
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

export async function reserveMonthlyStoryBudget(
  repository: MonthlyStoryBudgetRepository,
  input: { jobId: string; stage: MonthlyStorySpendStage; attempt: number; monthKey: string; dayKey: string;
    amountMicros: number; nowMillis: number; expiresAtMillis: number; policy: MonthlyStoryBudgetPolicy | null }
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
    const monthly: MonthlyStoryMonthlySpend & { textGenerationCount: number } = {
      ...storedMonthly,
      textGenerationCount: typeof storedMonthly.textGenerationCount === "number" &&
        validNonNegative(storedMonthly.textGenerationCount) ? storedMonthly.textGenerationCount : 0,
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
    const reservation: MonthlyStoryBudgetReservation = { reservationId, jobId: input.jobId,
      monthKey, dayKey,
      stage: input.stage, attempt: input.attempt, amountMicros: input.amountMicros,
      committedMicros: 0, status: "reserved", providerCallStartedAtMillis: null,
      expiresAtMillis: input.expiresAtMillis, createdAtMillis: input.nowMillis,
      updatedAtMillis: input.nowMillis };
    const updatedStage = { ...stage, reservedMicros: stage.reservedMicros + input.amountMicros };
    const updatedMonthly = { ...monthly, reservedMicros: monthly.reservedMicros + input.amountMicros,
      textGenerationCount: monthly.textGenerationCount + (input.stage === "text" ? 1 : 0),
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
    const updatedStage = { ...stage, reservedMicros: stage.reservedMicros - reservation.amountMicros,
      releasedMicros: stage.releasedMicros + reservation.amountMicros };
    transaction.setMonthlySpend({ ...monthly,
      reservedMicros: monthly.reservedMicros - reservation.amountMicros,
      releasedMicros: monthly.releasedMicros + reservation.amountMicros,
      [reservation.stage]: updatedStage, updatedAtMillis: input.nowMillis } as MonthlyStoryMonthlySpend);
    if (reservation.providerCallStartedAtMillis === null) {
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

export async function reconcileExpiredMonthlyStoryReservations(
  repository: MonthlyStoryBudgetRepository,
  inputs: { reservationId: string; monthKey: string; dayKey: string }[],
  nowMillis: number
): Promise<number> {
  let released = 0;
  for (const input of inputs) {
    const reservation = await repository.runTransaction((transaction) => transaction.getReservation(input.reservationId));
    if (reservation?.status === "reserved" && reservation.expiresAtMillis <= nowMillis) {
      await releaseMonthlyStoryBudget(repository, { ...input, nowMillis });
      released++;
    }
  }
  return released;
}

export const MONTHLY_STORY_SPEND_PATHS = Object.freeze({
  monthly: (monthKey: string) => `monthlyStorySpend/${monthKey}`,
  daily: (dayKey: string) => `monthlyStoryDailySpend/${dayKey}`,
  reservation: (monthKey: string, reservationId: string) =>
    `monthlyStorySpend/${monthKey}/reservations/${reservationId}`,
});
