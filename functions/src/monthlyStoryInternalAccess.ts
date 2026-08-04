import { MonthlyStoryControl, parseMonthlyStoryControl } from "./monthlyStoryControl";
import { MonthlyStoryRepository } from "./monthlyStoryRepository";
import { monthlyStoryRolloutEligible } from "./monthlyStoryRollout";
import { authenticatedMonthlyStoryUid } from "./monthlyStorySchema";

export const MONTHLY_STORY_INTERNAL_TESTER_COLLECTION = "monthlyStoryInternalTesters";

export class MonthlyStoryInternalAccessError extends Error {
  constructor(readonly code: "authentication-required" | "internal-access-denied" |
    "feature-unavailable" | "app-version-unsupported") {
    super(code);
    this.name = "MonthlyStoryInternalAccessError";
  }
}

type TimestampLike = { toMillis(): number };

function timestampMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) return value;
  if (typeof value === "object" && value !== null && "toMillis" in value &&
      typeof (value as TimestampLike).toMillis === "function") {
    const result = (value as TimestampLike).toMillis();
    return Number.isSafeInteger(result) && result >= 0 ? result : null;
  }
  return null;
}

export function parseMonthlyStoryInternalTester(value: unknown, nowMillis: number): boolean {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;
  const data = value as Record<string, unknown>;
  if (Object.keys(data).length !== 3 || !["enabled", "updatedAt", "expiresAt"]
    .every((field) => Object.prototype.hasOwnProperty.call(data, field)) || data.enabled !== true) return false;
  const updatedAt = timestampMillis(data.updatedAt); const expiresAt = timestampMillis(data.expiresAt);
  return updatedAt !== null && expiresAt !== null && updatedAt <= nowMillis && expiresAt > nowMillis;
}

function versionParts(value: string): number[] | null {
  if (!/^\d{1,4}(?:\.\d{1,4}){0,3}$/.test(value)) return null;
  return value.split(".").map(Number);
}

export function monthlyStoryAppVersionIsCompatible(current: string, minimum: string): boolean {
  const left = versionParts(current); const right = versionParts(minimum);
  if (!left || !right) return false;
  for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
    const a = left[index] ?? 0; const b = right[index] ?? 0;
    if (a !== b) return a > b;
  }
  return true;
}

export async function requireMonthlyStoryInternalAccount(input: { auth: { uid?: unknown } | null | undefined;
  repository: MonthlyStoryRepository; nowMillis: number }): Promise<string> {
  let uid: string;
  try { uid = authenticatedMonthlyStoryUid(input.auth); } catch {
    throw new MonthlyStoryInternalAccessError("authentication-required");
  }
  const tester = await input.repository.loadInternalTesterDocument(uid);
  if (!parseMonthlyStoryInternalTester(tester, input.nowMillis)) {
    throw new MonthlyStoryInternalAccessError("internal-access-denied");
  }
  return uid;
}

export async function requireMonthlyStoryInternalAvailability(input: {
  auth: { uid?: unknown } | null | undefined; repository: MonthlyStoryRepository;
  appVersion: string; nowMillis: number;
}): Promise<{ uid: string; control: MonthlyStoryControl }> {
  const uid = await requireMonthlyStoryInternalAccount(input);
  const parsed = parseMonthlyStoryControl(await input.repository.loadControlDocument(), input.nowMillis);
  if (!parsed.accepted || !parsed.control.visible || !parsed.control.enrollmentEnabled ||
      parsed.control.rolloutBasisPoints === 0) {
    throw new MonthlyStoryInternalAccessError("feature-unavailable");
  }
  if (!monthlyStoryAppVersionIsCompatible(input.appVersion, parsed.control.minimumAppVersion)) {
    throw new MonthlyStoryInternalAccessError("app-version-unsupported");
  }
  if (!monthlyStoryRolloutEligible(uid, parsed.control.generationVersion,
    parsed.control.rolloutBasisPoints)) throw new MonthlyStoryInternalAccessError("feature-unavailable");
  return { uid, control: parsed.control };
}
