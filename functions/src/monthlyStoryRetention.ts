import { requireMonthKey } from "./monthlyStorySchema";

export const MONTHLY_STORY_RETENTION_MONTHS = 12;
export const MONTHLY_STORY_TOMBSTONE_RETENTION_MONTHS = 15;

export type MonthlyStoryRetentionMetadata = {
  finalizedAtMillis: number;
  expiresAtMillis: number;
  deletionEligibleAtMillis: number;
  deletionRequestedAtMillis: number | null;
};

export type MonthlyStoryStorageCleanupMetadata = {
  state: "notRequired" | "pending" | "complete";
  eligibleAtMillis: number;
  updatedAtMillis: number;
};

function monthEndExclusiveUtc(monthKey: string): Date {
  const valid = requireMonthKey(monthKey);
  const year = Number(valid.slice(0, 4));
  const month = Number(valid.slice(5, 7));
  return new Date(Date.UTC(year, month, 1));
}

function addUtcMonths(date: Date, months: number): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, 1));
}

/** Finalized records use a UTC month boundary thereafter, independent of device timezone. */
export function monthlyStoryExpiresAtMillis(monthKey: string): number {
  return addUtcMonths(monthEndExclusiveUtc(monthKey), MONTHLY_STORY_RETENTION_MONTHS).getTime();
}

export function monthlyStoryTombstoneExpiresAtMillis(monthKey: string): number {
  return addUtcMonths(monthEndExclusiveUtc(monthKey), MONTHLY_STORY_TOMBSTONE_RETENTION_MONTHS).getTime();
}

export function createMonthlyStoryRetentionMetadata(
  monthKey: string,
  finalizedAtMillis: number
): MonthlyStoryRetentionMetadata {
  if (!Number.isSafeInteger(finalizedAtMillis) || finalizedAtMillis < 0) throw new Error("invalid-finalized-time");
  const expiresAtMillis = monthlyStoryExpiresAtMillis(monthKey);
  if (finalizedAtMillis >= expiresAtMillis) throw new Error("finalization-after-expiry");
  return { finalizedAtMillis, expiresAtMillis, deletionEligibleAtMillis: expiresAtMillis,
    deletionRequestedAtMillis: null };
}

export function requestMonthlyStoryDeletion(
  metadata: MonthlyStoryRetentionMetadata,
  requestedAtMillis: number
): MonthlyStoryRetentionMetadata {
  if (!Number.isSafeInteger(requestedAtMillis) || requestedAtMillis < 0) throw new Error("invalid-deletion-time");
  return { ...metadata, deletionRequestedAtMillis: requestedAtMillis,
    deletionEligibleAtMillis: Math.min(metadata.deletionEligibleAtMillis, requestedAtMillis) };
}

export function monthlyStoryDeletionIsEligible(
  metadata: MonthlyStoryRetentionMetadata,
  nowMillis: number
): boolean {
  return Number.isSafeInteger(nowMillis) && nowMillis >= metadata.deletionEligibleAtMillis;
}

export function createMonthlyStoryStorageCleanupMetadata(
  hasAudioObject: boolean,
  eligibleAtMillis: number,
  nowMillis: number
): MonthlyStoryStorageCleanupMetadata {
  if (![eligibleAtMillis, nowMillis].every((value) => Number.isSafeInteger(value) && value >= 0)) {
    throw new Error("invalid-cleanup-time");
  }
  return { state: hasAudioObject ? "pending" : "notRequired", eligibleAtMillis, updatedAtMillis: nowMillis };
}

export function completeMonthlyStoryStorageCleanup(
  metadata: MonthlyStoryStorageCleanupMetadata,
  nowMillis: number
): MonthlyStoryStorageCleanupMetadata {
  if (!Number.isSafeInteger(nowMillis) || nowMillis < metadata.updatedAtMillis) throw new Error("invalid-cleanup-time");
  return { ...metadata, state: "complete", updatedAtMillis: nowMillis };
}
