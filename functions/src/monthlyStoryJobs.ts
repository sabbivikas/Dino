import { createHash } from "crypto";
import { requireGenerationVersion, requireMonthKey } from "./monthlyStorySchema";
import { monthlyStoryOwnerKey } from "./monthlyStoryRollout";

export const MONTHLY_STORY_JOB_STATUSES = ["pending", "textLeased", "textReady", "audioLeased",
  "audioVerificationRequired", "ready", "terminalFailure", "deleted"] as const;
export type MonthlyStoryJobStatus = typeof MONTHLY_STORY_JOB_STATUSES[number];
export type MonthlyStoryJobStage = "text" | "audio";

export const MONTHLY_STORY_RETRIABLE_FAILURE_CODES = ["providerTimeout", "rateLimited",
  "transientProvider", "leaseExpired", "persistenceFailure"] as const;
export const MONTHLY_STORY_TERMINAL_FAILURE_CODES = ["schemaInvalid", "safetyRejected",
  "budgetDenied", "attemptLimit", "providerRejected"] as const;
export type MonthlyStoryRetriableFailureCode = typeof MONTHLY_STORY_RETRIABLE_FAILURE_CODES[number];
export type MonthlyStoryTerminalFailureCode = typeof MONTHLY_STORY_TERMINAL_FAILURE_CODES[number];
export type MonthlyStoryFailureCode = MonthlyStoryRetriableFailureCode | MonthlyStoryTerminalFailureCode |
  "unknownAudioOutcome";

export type MonthlyStoryJob = {
  jobId: string;
  ownerKey: string;
  monthKey: string;
  generationVersion: string;
  status: MonthlyStoryJobStatus;
  leaseOwner: string | null;
  leaseExpiresAtMillis: number | null;
  textAttempts: number;
  audioAttempts: number;
  nextAttemptAtMillis: number | null;
  failureCode: MonthlyStoryFailureCode | null;
  textArtifactHash: string | null;
  audioArtifactHash: string | null;
  audioTerminal: boolean;
  createdAtMillis: number;
  updatedAtMillis: number;
};

export interface MonthlyStoryJobTransaction {
  get(jobId: string): Promise<MonthlyStoryJob | null>;
  create(job: MonthlyStoryJob): void;
  set(job: MonthlyStoryJob): void;
  hasActiveTombstone(ownerKey: string, monthKey: string, generationVersion: string, nowMillis: number): Promise<boolean>;
}

export interface MonthlyStoryJobRepository {
  runTransaction<T>(operation: (transaction: MonthlyStoryJobTransaction) => Promise<T>): Promise<T>;
}

export class MonthlyStoryJobError extends Error {
  constructor(readonly code: "tombstoned" | "lease-active" | "terminal-state" | "wrong-stage" |
    "lease-owner-mismatch" | "attempt-limit" | "retry-not-due" | "invalid-job") {
    super(code);
    this.name = "MonthlyStoryJobError";
  }
}

function exactJobObject(value: unknown): Record<string, unknown> {
  const fields = ["jobId", "ownerKey", "monthKey", "generationVersion", "status", "leaseOwner",
    "leaseExpiresAtMillis", "textAttempts", "audioAttempts", "nextAttemptAtMillis", "failureCode",
    "textArtifactHash", "audioArtifactHash", "audioTerminal", "createdAtMillis", "updatedAtMillis"];
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new MonthlyStoryJobError("invalid-job");
  }
  const data = value as Record<string, unknown>;
  if (Object.keys(data).length !== fields.length || Object.keys(data).some((key) => !fields.includes(key)) ||
      fields.some((key) => !Object.prototype.hasOwnProperty.call(data, key))) {
    throw new MonthlyStoryJobError("invalid-job");
  }
  return data;
}

function nullableMillis(value: unknown): number | null {
  if (value === null) return null;
  if (typeof value !== "number" || !validMillis(value)) throw new MonthlyStoryJobError("invalid-job");
  return value;
}

function nullableHash(value: unknown): string | null {
  if (value === null) return null;
  if (typeof value !== "string") throw new MonthlyStoryJobError("invalid-job");
  return artifactHash(value);
}

export function parseMonthlyStoryJob(value: unknown): MonthlyStoryJob {
  const data = exactJobObject(value);
  if (typeof data.jobId !== "string" || !/^ms_[a-f0-9]{64}$/.test(data.jobId) ||
      typeof data.ownerKey !== "string" || !/^[a-f0-9]{64}$/.test(data.ownerKey) ||
      typeof data.status !== "string" || !(MONTHLY_STORY_JOB_STATUSES as readonly string[]).includes(data.status) ||
      (data.leaseOwner !== null && (typeof data.leaseOwner !== "string" || !/^[A-Za-z0-9._-]{1,64}$/.test(data.leaseOwner))) ||
      typeof data.audioTerminal !== "boolean" ||
      typeof data.textAttempts !== "number" || !validNonNegativeInteger(data.textAttempts) ||
      typeof data.audioAttempts !== "number" || !validNonNegativeInteger(data.audioAttempts) ||
      (data.failureCode !== null && (typeof data.failureCode !== "string" ||
        ![...MONTHLY_STORY_RETRIABLE_FAILURE_CODES, ...MONTHLY_STORY_TERMINAL_FAILURE_CODES,
          "unknownAudioOutcome"].includes(data.failureCode as MonthlyStoryFailureCode)))) {
    throw new MonthlyStoryJobError("invalid-job");
  }
  const createdAtMillis = nullableMillis(data.createdAtMillis);
  const updatedAtMillis = nullableMillis(data.updatedAtMillis);
  if (createdAtMillis === null || updatedAtMillis === null || updatedAtMillis < createdAtMillis) {
    throw new MonthlyStoryJobError("invalid-job");
  }
  return {
    jobId: data.jobId, ownerKey: data.ownerKey,
    monthKey: requireMonthKey(data.monthKey), generationVersion: requireGenerationVersion(data.generationVersion),
    status: data.status as MonthlyStoryJobStatus, leaseOwner: data.leaseOwner as string | null,
    leaseExpiresAtMillis: nullableMillis(data.leaseExpiresAtMillis), textAttempts: data.textAttempts,
    audioAttempts: data.audioAttempts, nextAttemptAtMillis: nullableMillis(data.nextAttemptAtMillis),
    failureCode: data.failureCode as MonthlyStoryFailureCode | null,
    textArtifactHash: nullableHash(data.textArtifactHash), audioArtifactHash: nullableHash(data.audioArtifactHash),
    audioTerminal: data.audioTerminal, createdAtMillis, updatedAtMillis,
  };
}

function validMillis(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 0;
}

function validNonNegativeInteger(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 0;
}

function artifactHash(value: string): string {
  if (!/^[a-f0-9]{64}$/.test(value)) throw new MonthlyStoryJobError("invalid-job");
  return value;
}

function leaseOwner(value: string): string {
  if (!/^[A-Za-z0-9._-]{1,64}$/.test(value)) throw new MonthlyStoryJobError("invalid-job");
  return value;
}

export function deterministicMonthlyStoryJobId(
  uid: string,
  monthKey: string,
  generationVersion: string,
  ownerKeyVersion: string
): string {
  if (!uid || uid.length > 128 || !ownerKeyVersion || ownerKeyVersion.length > 256) {
    throw new MonthlyStoryJobError("invalid-job");
  }
  const month = requireMonthKey(monthKey);
  const version = requireGenerationVersion(generationVersion);
  return `ms_${createHash("sha256")
    .update("dino-monthly-story-job\0")
    .update(ownerKeyVersion)
    .update("\0")
    .update(uid)
    .update("\0")
    .update(month)
    .update("\0")
    .update(version)
    .digest("hex")}`;
}

export async function createMonthlyStoryJobIfAbsent(
  repository: MonthlyStoryJobRepository,
  input: { uid: string; ownerKeyVersion: string; monthKey: string; generationVersion: string; nowMillis: number }
): Promise<{ job: MonthlyStoryJob; created: boolean }> {
  const monthKey = requireMonthKey(input.monthKey);
  const generationVersion = requireGenerationVersion(input.generationVersion);
  if (!validMillis(input.nowMillis)) throw new MonthlyStoryJobError("invalid-job");
  const jobId = deterministicMonthlyStoryJobId(input.uid, monthKey, generationVersion, input.ownerKeyVersion);
  const ownerKey = monthlyStoryOwnerKey(input.uid, input.ownerKeyVersion);
  return repository.runTransaction(async (transaction) => {
    if (await transaction.hasActiveTombstone(ownerKey, monthKey, generationVersion, input.nowMillis)) {
      throw new MonthlyStoryJobError("tombstoned");
    }
    const existing = await transaction.get(jobId);
    if (existing) return { job: existing, created: false };
    const job: MonthlyStoryJob = {
      jobId, ownerKey, monthKey, generationVersion, status: "pending", leaseOwner: null,
      leaseExpiresAtMillis: null, textAttempts: 0, audioAttempts: 0, nextAttemptAtMillis: null,
      failureCode: null, textArtifactHash: null, audioArtifactHash: null, audioTerminal: false,
      createdAtMillis: input.nowMillis, updatedAtMillis: input.nowMillis,
    };
    transaction.create(job);
    return { job, created: true };
  });
}

function isTerminal(job: MonthlyStoryJob): boolean {
  return job.status === "ready" || job.status === "terminalFailure" || job.status === "deleted";
}

export async function acquireMonthlyStoryJobLease(
  repository: MonthlyStoryJobRepository,
  input: { jobId: string; stage: MonthlyStoryJobStage; leaseOwner: string; nowMillis: number;
    leaseDurationMillis: number; maximumAttempts: number }
): Promise<MonthlyStoryJob> {
  const owner = leaseOwner(input.leaseOwner);
  if (!validMillis(input.nowMillis) || !Number.isSafeInteger(input.leaseDurationMillis) ||
      input.leaseDurationMillis <= 0 || !Number.isSafeInteger(input.maximumAttempts) || input.maximumAttempts < 0) {
    throw new MonthlyStoryJobError("invalid-job");
  }
  return repository.runTransaction(async (transaction) => {
    const job = await transaction.get(input.jobId);
    if (!job) throw new MonthlyStoryJobError("invalid-job");
    if (isTerminal(job) || job.status === "audioVerificationRequired") {
      throw new MonthlyStoryJobError("terminal-state");
    }
    if (job.nextAttemptAtMillis !== null && job.nextAttemptAtMillis > input.nowMillis) {
      throw new MonthlyStoryJobError("retry-not-due");
    }
    if ((job.status === "textLeased" || job.status === "audioLeased") &&
        job.leaseExpiresAtMillis !== null && job.leaseExpiresAtMillis > input.nowMillis) {
      throw new MonthlyStoryJobError("lease-active");
    }
    const expectedStatus = input.stage === "text" ? "pending" : "textReady";
    const expiredSameStage = (input.stage === "text" && job.status === "textLeased") ||
      (input.stage === "audio" && job.status === "audioLeased");
    if (job.status !== expectedStatus && !expiredSameStage) throw new MonthlyStoryJobError("wrong-stage");
    if (input.stage === "audio" && job.audioTerminal) throw new MonthlyStoryJobError("terminal-state");
    const attempts = input.stage === "text" ? job.textAttempts : job.audioAttempts;
    if (attempts >= input.maximumAttempts) throw new MonthlyStoryJobError("attempt-limit");
    const updated: MonthlyStoryJob = {
      ...job,
      status: input.stage === "text" ? "textLeased" : "audioLeased",
      leaseOwner: owner,
      leaseExpiresAtMillis: input.nowMillis + input.leaseDurationMillis,
      textAttempts: input.stage === "text" ? job.textAttempts + 1 : job.textAttempts,
      audioAttempts: input.stage === "audio" ? job.audioAttempts + 1 : job.audioAttempts,
      nextAttemptAtMillis: null,
      failureCode: null,
      updatedAtMillis: input.nowMillis,
    };
    transaction.set(updated);
    return updated;
  });
}

function requireOwnedLease(job: MonthlyStoryJob, stage: MonthlyStoryJobStage, owner: string, nowMillis: number): void {
  const expected = stage === "text" ? "textLeased" : "audioLeased";
  if (job.status !== expected) throw new MonthlyStoryJobError("wrong-stage");
  if (job.leaseOwner !== owner) throw new MonthlyStoryJobError("lease-owner-mismatch");
  if (job.leaseExpiresAtMillis === null || job.leaseExpiresAtMillis <= nowMillis) {
    throw new MonthlyStoryJobError("wrong-stage");
  }
}

export async function completeMonthlyStoryText(
  repository: MonthlyStoryJobRepository,
  input: { jobId: string; leaseOwner: string; nowMillis: number; textArtifactHash: string }
): Promise<MonthlyStoryJob> {
  const owner = leaseOwner(input.leaseOwner);
  const hash = artifactHash(input.textArtifactHash);
  if (!validMillis(input.nowMillis)) throw new MonthlyStoryJobError("invalid-job");
  return repository.runTransaction(async (transaction) => {
    const job = await transaction.get(input.jobId);
    if (!job) throw new MonthlyStoryJobError("invalid-job");
    requireOwnedLease(job, "text", owner, input.nowMillis);
    const updated: MonthlyStoryJob = { ...job, status: "textReady", leaseOwner: null,
      leaseExpiresAtMillis: null, textArtifactHash: hash, failureCode: null,
      nextAttemptAtMillis: null, updatedAtMillis: input.nowMillis };
    transaction.set(updated);
    return updated;
  });
}

export async function completeMonthlyStoryAudio(
  repository: MonthlyStoryJobRepository,
  input: { jobId: string; leaseOwner: string; nowMillis: number; audioArtifactHash: string;
    objectExists: boolean; objectHashMatches: boolean }
): Promise<MonthlyStoryJob> {
  const owner = leaseOwner(input.leaseOwner);
  const hash = artifactHash(input.audioArtifactHash);
  if (!validMillis(input.nowMillis)) throw new MonthlyStoryJobError("invalid-job");
  return repository.runTransaction(async (transaction) => {
    const job = await transaction.get(input.jobId);
    if (!job) throw new MonthlyStoryJobError("invalid-job");
    requireOwnedLease(job, "audio", owner, input.nowMillis);
    const verified = input.objectExists && input.objectHashMatches;
    const updated: MonthlyStoryJob = { ...job,
      status: verified ? "ready" : "audioVerificationRequired",
      leaseOwner: null, leaseExpiresAtMillis: null,
      audioArtifactHash: hash, failureCode: verified ? null : "unknownAudioOutcome",
      updatedAtMillis: input.nowMillis };
    transaction.set(updated);
    return updated;
  });
}

export async function resolveMonthlyStoryAudioVerification(
  repository: MonthlyStoryJobRepository,
  input: { jobId: string; nowMillis: number; objectExists: boolean; objectHashMatches: boolean }
): Promise<MonthlyStoryJob> {
  if (!validMillis(input.nowMillis)) throw new MonthlyStoryJobError("invalid-job");
  return repository.runTransaction(async (transaction) => {
    const job = await transaction.get(input.jobId);
    if (!job || job.status !== "audioVerificationRequired" || !job.audioArtifactHash) {
      throw new MonthlyStoryJobError("wrong-stage");
    }
    const updated: MonthlyStoryJob = { ...job,
      status: input.objectExists && input.objectHashMatches ? "ready" : "textReady",
      audioArtifactHash: input.objectExists && input.objectHashMatches ? job.audioArtifactHash : null,
      failureCode: null, updatedAtMillis: input.nowMillis };
    transaction.set(updated);
    return updated;
  });
}

export async function recordMonthlyStoryJobFailure(
  repository: MonthlyStoryJobRepository,
  input: { jobId: string; stage: MonthlyStoryJobStage; leaseOwner: string; nowMillis: number;
    failureCode: MonthlyStoryRetriableFailureCode | MonthlyStoryTerminalFailureCode;
    nextAttemptAtMillis?: number }
): Promise<MonthlyStoryJob> {
  const owner = leaseOwner(input.leaseOwner);
  if (!validMillis(input.nowMillis)) throw new MonthlyStoryJobError("invalid-job");
  const retriable = (MONTHLY_STORY_RETRIABLE_FAILURE_CODES as readonly string[]).includes(input.failureCode);
  if (retriable && (!validMillis(input.nextAttemptAtMillis ?? -1) ||
      (input.nextAttemptAtMillis as number) <= input.nowMillis)) {
    throw new MonthlyStoryJobError("invalid-job");
  }
  return repository.runTransaction(async (transaction) => {
    const job = await transaction.get(input.jobId);
    if (!job) throw new MonthlyStoryJobError("invalid-job");
    requireOwnedLease(job, input.stage, owner, input.nowMillis);
    const updated: MonthlyStoryJob = { ...job,
      status: input.stage === "audio" ? "textReady" : (retriable ? "pending" : "terminalFailure"),
      leaseOwner: null, leaseExpiresAtMillis: null,
      nextAttemptAtMillis: retriable ? input.nextAttemptAtMillis as number : null,
      failureCode: input.failureCode,
      audioTerminal: input.stage === "audio" ? !retriable : job.audioTerminal,
      updatedAtMillis: input.nowMillis };
    transaction.set(updated);
    return updated;
  });
}

export async function markMonthlyStoryJobDeleted(
  repository: MonthlyStoryJobRepository,
  jobId: string,
  nowMillis: number
): Promise<MonthlyStoryJob> {
  if (!validMillis(nowMillis)) throw new MonthlyStoryJobError("invalid-job");
  return repository.runTransaction(async (transaction) => {
    const job = await transaction.get(jobId);
    if (!job) throw new MonthlyStoryJobError("invalid-job");
    const updated: MonthlyStoryJob = { ...job, status: "deleted", leaseOwner: null,
      leaseExpiresAtMillis: null, nextAttemptAtMillis: null, updatedAtMillis: nowMillis };
    transaction.set(updated);
    return updated;
  });
}
