import { MONTHLY_STORY_CONTROL_PATH } from "./monthlyStoryControl";
import { MonthlyStoryJob, MonthlyStoryJobRepository, MonthlyStoryJobTransaction,
  parseMonthlyStoryJob } from "./monthlyStoryJobs";
import { MonthlyStoryClaimKey, isMonthlyStoryClaimKey } from "./monthlyStoryClaims";
import { MonthlyStoryNarrativeClass } from "./monthlyStoryNarrativePlan";
import { monthlyStoryOwnerKey } from "./monthlyStoryRollout";
import { MonthlyStoryDeletedTombstone, MONTHLY_STORY_PATHS, parseMonthlyStoryDeletedTombstone,
  requireGenerationVersion, requireMonthKey } from "./monthlyStorySchema";

export const MONTHLY_STORY_PERSISTENCE_VALIDATION_VERSION = "script-validator-v1";
export const MONTHLY_STORY_REPOSITORY_OWNER_KEY_VERSION = "monthly-story-owner-v1";

export type MonthlyStoryPersistedText = {
  monthKey: string;
  generationVersion: string;
  compositionVersion: string;
  signalSchemaVersion: number;
  status: "textReady";
  script: string;
  paragraphs: string[];
  wordCount: number;
  profile: MonthlyStoryNarrativeClass;
  usedEvidenceIds: string[];
  usedClaimKeys: MonthlyStoryClaimKey[];
  usedSuggestionKeys: MonthlyStoryClaimKey[];
  scriptHash: string;
  createdAtMillis: number;
  finalizedAtMillis: number;
  expiresAtMillis: number;
  audioStatus: "notRequested";
  deletionState: "active";
  validationVersion: typeof MONTHLY_STORY_PERSISTENCE_VALIDATION_VERSION;
  compositionMode: "deterministic";
  providerRequestCount: 0;
  providerCostMicros: 0;
  storageCleanup: { state: "notRequired"; updatedAtMillis: number };
};

export type MonthlyStoryGenerationSlotInput = {
  jobId: string;
  monthKey: string;
  dayKey: string;
  dailyCap: number;
  monthlyCap: number;
  nowMillis: number;
};

export type MonthlyStoryDeletionEnumeration = {
  documentTrees: string[];
  jobIds: string[];
  reservationJobIds: string[];
  deterministicUsageJobIds: string[];
  storagePrefixes: string[];
};

export interface MonthlyStoryRepository {
  loadControlDocument(): Promise<unknown | null>;
  loadSettingsDocument(uid: string): Promise<unknown | null>;
  loadSignalDocument(uid: string, monthKey: string): Promise<unknown | null>;
  loadDeletedTombstone(uid: string, monthKey: string): Promise<MonthlyStoryDeletedTombstone | null>;
  loadStory(uid: string, monthKey: string): Promise<MonthlyStoryPersistedText | null>;
  jobRepository(uid: string, expectedOwnerKey: string): MonthlyStoryJobRepository;
  reserveDeterministicGenerationSlot(input: MonthlyStoryGenerationSlotInput): Promise<{ duplicate: boolean }>;
  persistStoryAndCompleteJob(input: { uid: string; story: MonthlyStoryPersistedText; jobId: string;
    leaseOwner: string; nowMillis: number }): Promise<{ story: MonthlyStoryPersistedText; duplicate: boolean }>;
  deleteStoryMetadata(uid: string, monthKey: string): Promise<void>;
  enumerateAccountDeletion(uid: string, ownerKeyVersion: string): Promise<MonthlyStoryDeletionEnumeration>;
}

export class MonthlyStoryRepositoryError extends Error {
  constructor(readonly code: "invalid-repository-input" | "daily-generation-cap" |
    "monthly-generation-cap" | "lease-conflict" | "story-conflict" | "persistence-failure") {
    super(code);
    this.name = "MonthlyStoryRepositoryError";
  }
}

function uidToken(uid: string): string {
  if (!/^[A-Za-z0-9._:-]{1,128}$/.test(uid)) throw new MonthlyStoryRepositoryError("invalid-repository-input");
  return uid;
}

function jobIdToken(jobId: string): string {
  if (!/^ms_[a-f0-9]{64}$/.test(jobId)) throw new MonthlyStoryRepositoryError("invalid-repository-input");
  return jobId;
}

function millis(value: number): number {
  if (!Number.isSafeInteger(value) || value < 0) throw new MonthlyStoryRepositoryError("invalid-repository-input");
  return value;
}

function stringList(value: unknown, maximum: number, pattern: RegExp): string[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > maximum ||
      value.some((item) => typeof item !== "string" || !pattern.test(item)) ||
      new Set(value).size !== value.length) throw new MonthlyStoryRepositoryError("persistence-failure");
  return [...value] as string[];
}

export function parseMonthlyStoryPersistedText(value: unknown): MonthlyStoryPersistedText {
  const fields = ["monthKey", "generationVersion", "compositionVersion", "signalSchemaVersion", "status",
    "script", "paragraphs", "wordCount", "profile", "usedEvidenceIds", "usedClaimKeys",
    "usedSuggestionKeys", "scriptHash", "createdAtMillis", "finalizedAtMillis", "expiresAtMillis",
    "audioStatus", "deletionState", "validationVersion", "compositionMode", "providerRequestCount",
    "providerCostMicros", "storageCleanup"];
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new MonthlyStoryRepositoryError("persistence-failure");
  }
  const data = value as Record<string, unknown>;
  if (Object.keys(data).length !== fields.length || Object.keys(data).some((key) => !fields.includes(key))) {
    throw new MonthlyStoryRepositoryError("persistence-failure");
  }
  const createdAtMillis = millis(data.createdAtMillis as number);
  const finalizedAtMillis = millis(data.finalizedAtMillis as number);
  const expiresAtMillis = millis(data.expiresAtMillis as number);
  const paragraphs = stringList(data.paragraphs, 16, /^.{1,4000}$/s);
  const usedEvidenceIds = stringList(data.usedEvidenceIds, 32, /^[a-z0-9._-]{8,64}$/);
  const usedClaimKeys = stringList(data.usedClaimKeys, 32, /^[A-Za-z][A-Za-z0-9]{1,63}$/);
  const usedSuggestionKeys = stringList(data.usedSuggestionKeys, 3, /^[A-Za-z][A-Za-z0-9]{1,63}$/);
  const storage = data.storageCleanup as Record<string, unknown> | null;
  if (typeof data.script !== "string" || data.script.length < 1 || data.script.length > 20_000 ||
      typeof data.compositionVersion !== "string" || !/^[A-Za-z0-9._-]{1,32}$/.test(data.compositionVersion) ||
      !Number.isSafeInteger(data.signalSchemaVersion) || (data.signalSchemaVersion as number) < 1 ||
      !Number.isSafeInteger(data.wordCount) || (data.wordCount as number) < 80 || (data.wordCount as number) > 300 ||
      !["rich", "standard", "moodOnly"].includes(String(data.profile)) || data.status !== "textReady" ||
      typeof data.scriptHash !== "string" || !/^[a-f0-9]{64}$/.test(data.scriptHash) ||
      data.audioStatus !== "notRequested" || data.deletionState !== "active" ||
      data.validationVersion !== MONTHLY_STORY_PERSISTENCE_VALIDATION_VERSION ||
      data.compositionMode !== "deterministic" || data.providerRequestCount !== 0 || data.providerCostMicros !== 0 ||
      createdAtMillis > finalizedAtMillis || finalizedAtMillis >= expiresAtMillis ||
      storage === null || storage.state !== "notRequired" || storage.updatedAtMillis !== finalizedAtMillis ||
      usedClaimKeys.some((key) => !isMonthlyStoryClaimKey(key)) ||
      usedSuggestionKeys.some((key) => !isMonthlyStoryClaimKey(key))) {
    throw new MonthlyStoryRepositoryError("persistence-failure");
  }
  return { monthKey: requireMonthKey(data.monthKey),
    generationVersion: requireGenerationVersion(data.generationVersion),
    compositionVersion: data.compositionVersion, signalSchemaVersion: data.signalSchemaVersion as number,
    status: "textReady", script: data.script, paragraphs,
    wordCount: data.wordCount as number, profile: data.profile as MonthlyStoryNarrativeClass,
    usedEvidenceIds, usedClaimKeys: usedClaimKeys as MonthlyStoryClaimKey[],
    usedSuggestionKeys: usedSuggestionKeys as MonthlyStoryClaimKey[], scriptHash: data.scriptHash,
    createdAtMillis, finalizedAtMillis, expiresAtMillis, audioStatus: "notRequested",
    deletionState: "active", validationVersion: MONTHLY_STORY_PERSISTENCE_VALIDATION_VERSION,
    compositionMode: "deterministic", providerRequestCount: 0, providerCostMicros: 0,
    storageCleanup: { state: "notRequired", updatedAtMillis: finalizedAtMillis } };
}

type FirestoreSnapshot = { exists: boolean; id?: string; data(): unknown };
type FirestoreDocument = { get(): Promise<FirestoreSnapshot>; delete(): Promise<void> };
type FirestoreTransaction = { get(reference: unknown): Promise<FirestoreSnapshot>;
  create(reference: unknown, data: unknown): void; set(reference: unknown, data: unknown): void;
  delete(reference: unknown): void };
type FirestoreQuerySnapshot = { docs: { id: string; data(): unknown }[] };
type FirestoreQuery = { where(field: string, operation: "==", value: unknown): FirestoreQuery;
  get(): Promise<FirestoreQuerySnapshot> };
export interface MonthlyStoryFirestoreDependency {
  doc(path: string): FirestoreDocument;
  collection(path: string): FirestoreQuery;
  runTransaction<T>(operation: (transaction: FirestoreTransaction) => Promise<T>): Promise<T>;
}

function snapshotData(snapshot: FirestoreSnapshot): unknown | null {
  return snapshot.exists ? snapshot.data() : null;
}

export class FirestoreMonthlyStoryRepository implements MonthlyStoryRepository {
  constructor(private readonly firestore: MonthlyStoryFirestoreDependency) {}

  async loadControlDocument(): Promise<unknown | null> {
    return snapshotData(await this.firestore.doc(MONTHLY_STORY_CONTROL_PATH).get());
  }
  async loadSettingsDocument(uid: string): Promise<unknown | null> {
    return snapshotData(await this.firestore.doc(MONTHLY_STORY_PATHS.settings(uidToken(uid))).get());
  }
  async loadSignalDocument(uid: string, monthKey: string): Promise<unknown | null> {
    return snapshotData(await this.firestore.doc(MONTHLY_STORY_PATHS.signal(uidToken(uid),
      requireMonthKey(monthKey))).get());
  }
  async loadDeletedTombstone(uid: string, monthKey: string): Promise<MonthlyStoryDeletedTombstone | null> {
    const value = snapshotData(await this.firestore.doc(MONTHLY_STORY_PATHS.tombstone(uidToken(uid),
      requireMonthKey(monthKey))).get());
    return value === null ? null : parseMonthlyStoryDeletedTombstone(value);
  }
  async loadStory(uid: string, monthKey: string): Promise<MonthlyStoryPersistedText | null> {
    const value = snapshotData(await this.firestore.doc(MONTHLY_STORY_PATHS.story(uidToken(uid),
      requireMonthKey(monthKey))).get());
    return value === null ? null : parseMonthlyStoryPersistedText(value);
  }

  jobRepository(uid: string, expectedOwnerKey: string): MonthlyStoryJobRepository {
    const ownerUid = uidToken(uid);
    if (expectedOwnerKey !== monthlyStoryOwnerKey(ownerUid, MONTHLY_STORY_REPOSITORY_OWNER_KEY_VERSION)) {
      throw new MonthlyStoryRepositoryError("invalid-repository-input");
    }
    return { runTransaction: async <T>(operation: (transaction: MonthlyStoryJobTransaction) => Promise<T>) =>
      this.firestore.runTransaction(async (transaction) => operation({
        get: async (jobId) => {
          const value = snapshotData(await transaction.get(this.firestore.doc(`monthlyStoryJobs/${jobIdToken(jobId)}`)));
          return value === null ? null : parseMonthlyStoryJob(value);
        },
        create: (job) => transaction.create(this.firestore.doc(`monthlyStoryJobs/${jobIdToken(job.jobId)}`), job),
        set: (job) => transaction.set(this.firestore.doc(`monthlyStoryJobs/${jobIdToken(job.jobId)}`), job),
        hasActiveTombstone: async (ownerKey, monthKey, generationVersion, nowMillis) => {
          if (ownerKey !== expectedOwnerKey) throw new MonthlyStoryRepositoryError("lease-conflict");
          const value = snapshotData(await transaction.get(this.firestore.doc(
            MONTHLY_STORY_PATHS.tombstone(ownerUid, requireMonthKey(monthKey)))));
          if (value === null) return false;
          const tombstone = parseMonthlyStoryDeletedTombstone(value);
          return tombstone.generationVersion === generationVersion && tombstone.expiresAtMillis > nowMillis;
        },
      })) };
  }

  async reserveDeterministicGenerationSlot(input: MonthlyStoryGenerationSlotInput): Promise<{ duplicate: boolean }> {
    jobIdToken(input.jobId); requireMonthKey(input.monthKey); millis(input.nowMillis);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(input.dayKey) || !Number.isSafeInteger(input.dailyCap) ||
        input.dailyCap < 1 || !Number.isSafeInteger(input.monthlyCap) || input.monthlyCap < 1) {
      throw new MonthlyStoryRepositoryError("invalid-repository-input");
    }
    return this.firestore.runTransaction(async (transaction) => {
      const usageRef = this.firestore.doc(`monthlyStorySpend/${input.monthKey}/deterministicJobs/${input.jobId}`);
      if ((await transaction.get(usageRef)).exists) return { duplicate: true };
      const dayRef = this.firestore.doc(`monthlyStoryDailySpend/${input.dayKey}`);
      const monthRef = this.firestore.doc(`monthlyStorySpend/${input.monthKey}`);
      const day = snapshotData(await transaction.get(dayRef)) as Record<string, unknown> | null;
      const month = snapshotData(await transaction.get(monthRef)) as Record<string, unknown> | null;
      const dailyCount = Number(day?.deterministicGenerationCount ?? 0);
      const monthlyCount = Number(month?.deterministicGenerationCount ?? 0);
      if (!Number.isSafeInteger(dailyCount) || dailyCount >= input.dailyCap) {
        throw new MonthlyStoryRepositoryError("daily-generation-cap");
      }
      if (!Number.isSafeInteger(monthlyCount) || monthlyCount >= input.monthlyCap) {
        throw new MonthlyStoryRepositoryError("monthly-generation-cap");
      }
      transaction.set(dayRef, { ...(day ?? {}), deterministicGenerationCount: dailyCount + 1,
        updatedAtMillis: input.nowMillis });
      transaction.set(monthRef, { ...(month ?? {}), deterministicGenerationCount: monthlyCount + 1,
        updatedAtMillis: input.nowMillis });
      transaction.create(usageRef, { jobId: input.jobId, compositionMode: "deterministic",
        providerRequestCount: 0, providerCostMicros: 0, createdAtMillis: input.nowMillis });
      return { duplicate: false };
    });
  }

  async persistStoryAndCompleteJob(input: { uid: string; story: MonthlyStoryPersistedText; jobId: string;
    leaseOwner: string; nowMillis: number }): Promise<{ story: MonthlyStoryPersistedText; duplicate: boolean }> {
    const uid = uidToken(input.uid); const story = parseMonthlyStoryPersistedText(input.story);
    jobIdToken(input.jobId); millis(input.nowMillis);
    if (!/^[A-Za-z0-9._-]{1,64}$/.test(input.leaseOwner)) {
      throw new MonthlyStoryRepositoryError("invalid-repository-input");
    }
    return this.firestore.runTransaction(async (transaction) => {
      const jobRef = this.firestore.doc(`monthlyStoryJobs/${input.jobId}`);
      const storyRef = this.firestore.doc(MONTHLY_STORY_PATHS.story(uid, story.monthKey));
      const jobValue = snapshotData(await transaction.get(jobRef));
      if (jobValue === null) throw new MonthlyStoryRepositoryError("lease-conflict");
      const job = parseMonthlyStoryJob(jobValue);
      const existingValue = snapshotData(await transaction.get(storyRef));
      if (existingValue !== null) {
        const existing = parseMonthlyStoryPersistedText(existingValue);
        if (existing.scriptHash !== story.scriptHash) throw new MonthlyStoryRepositoryError("story-conflict");
        return { story: existing, duplicate: true };
      }
      if (job.status !== "textLeased" || job.leaseOwner !== input.leaseOwner ||
          job.leaseExpiresAtMillis === null || job.leaseExpiresAtMillis <= input.nowMillis) {
        throw new MonthlyStoryRepositoryError("lease-conflict");
      }
      transaction.create(storyRef, story);
      transaction.set(jobRef, { ...job, status: "ready", leaseOwner: null, leaseExpiresAtMillis: null,
        textArtifactHash: story.scriptHash, audioTerminal: true, failureCode: null,
        nextAttemptAtMillis: null, updatedAtMillis: input.nowMillis });
      return { story, duplicate: false };
    });
  }

  async deleteStoryMetadata(uid: string, monthKey: string): Promise<void> {
    try {
      await this.firestore.doc(MONTHLY_STORY_PATHS.story(uidToken(uid), requireMonthKey(monthKey))).delete();
    } catch {
      throw new MonthlyStoryRepositoryError("persistence-failure");
    }
  }

  async enumerateAccountDeletion(uid: string, ownerKeyVersion: string): Promise<MonthlyStoryDeletionEnumeration> {
    const safeUid = uidToken(uid); const ownerKey = monthlyStoryOwnerKey(safeUid, ownerKeyVersion);
    const jobs = await this.firestore.collection("monthlyStoryJobs").where("ownerKey", "==", ownerKey).get();
    const jobIds = jobs.docs.map((document) => jobIdToken(document.id));
    return { documentTrees: [`monthlyStorySettings/${safeUid}`, `monthlyStorySignals/${safeUid}`,
      `monthlyStories/${safeUid}`, `monthlyStoryDeleted/${safeUid}`], jobIds,
    reservationJobIds: [...jobIds], deterministicUsageJobIds: [...jobIds],
    storagePrefixes: [`monthlyStories/${safeUid}/`] };
  }
}

export class InMemoryMonthlyStoryRepository implements MonthlyStoryRepository {
  controlDocument: unknown | null = null;
  readonly settings = new Map<string, unknown>();
  readonly signals = new Map<string, unknown>();
  readonly tombstones = new Map<string, MonthlyStoryDeletedTombstone>();
  readonly stories = new Map<string, MonthlyStoryPersistedText>();
  readonly jobs = new Map<string, MonthlyStoryJob>();
  readonly generationSlots = new Set<string>();
  readonly dailyCounts = new Map<string, number>();
  readonly monthlyCounts = new Map<string, number>();
  failPersistence = false;
  failDeletion = false;
  private queue: Promise<void> = Promise.resolve();

  private atomic<T>(operation: () => Promise<T>): Promise<T> {
    const run = this.queue.then(operation);
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }
  loadControlDocument(): Promise<unknown | null> { return Promise.resolve(structuredClone(this.controlDocument)); }
  loadSettingsDocument(uid: string): Promise<unknown | null> {
    return Promise.resolve(structuredClone(this.settings.get(uidToken(uid)) ?? null));
  }
  loadSignalDocument(uid: string, monthKey: string): Promise<unknown | null> {
    return Promise.resolve(structuredClone(this.signals.get(`${uidToken(uid)}/${requireMonthKey(monthKey)}`) ?? null));
  }
  loadDeletedTombstone(uid: string, monthKey: string): Promise<MonthlyStoryDeletedTombstone | null> {
    return Promise.resolve(structuredClone(this.tombstones.get(`${uidToken(uid)}/${requireMonthKey(monthKey)}`) ?? null));
  }
  loadStory(uid: string, monthKey: string): Promise<MonthlyStoryPersistedText | null> {
    return Promise.resolve(structuredClone(this.stories.get(`${uidToken(uid)}/${requireMonthKey(monthKey)}`) ?? null));
  }
  jobRepository(uid: string, expectedOwnerKey: string): MonthlyStoryJobRepository {
    const safeUid = uidToken(uid);
    if (expectedOwnerKey !== monthlyStoryOwnerKey(safeUid, MONTHLY_STORY_REPOSITORY_OWNER_KEY_VERSION)) {
      throw new MonthlyStoryRepositoryError("invalid-repository-input");
    }
    return { runTransaction: async <T>(operation: (transaction: MonthlyStoryJobTransaction) => Promise<T>) =>
      this.atomic(async () => {
        const jobs = new Map(Array.from(this.jobs, ([key, value]) => [key, structuredClone(value)]));
        const result = await operation({ get: async (id) => structuredClone(jobs.get(id) ?? null),
          create: (job) => { if (jobs.has(job.jobId)) throw new Error("already-exists");
            jobs.set(job.jobId, structuredClone(job)); },
          set: (job) => jobs.set(job.jobId, structuredClone(job)),
          hasActiveTombstone: async (ownerKey, monthKey, generationVersion, nowMillis) => {
            if (ownerKey !== expectedOwnerKey) throw new MonthlyStoryRepositoryError("lease-conflict");
            const value = this.tombstones.get(`${safeUid}/${monthKey}`);
            return value !== undefined && value.generationVersion === generationVersion &&
              value.expiresAtMillis > nowMillis;
          } });
        this.jobs.clear(); for (const [key, value] of jobs) this.jobs.set(key, value);
        return result;
      }) };
  }
  reserveDeterministicGenerationSlot(input: MonthlyStoryGenerationSlotInput): Promise<{ duplicate: boolean }> {
    return this.atomic(async () => {
      if (this.generationSlots.has(input.jobId)) return { duplicate: true };
      const daily = this.dailyCounts.get(input.dayKey) ?? 0;
      const monthly = this.monthlyCounts.get(input.monthKey) ?? 0;
      if (daily >= input.dailyCap) throw new MonthlyStoryRepositoryError("daily-generation-cap");
      if (monthly >= input.monthlyCap) throw new MonthlyStoryRepositoryError("monthly-generation-cap");
      this.dailyCounts.set(input.dayKey, daily + 1); this.monthlyCounts.set(input.monthKey, monthly + 1);
      this.generationSlots.add(input.jobId); return { duplicate: false };
    });
  }
  persistStoryAndCompleteJob(input: { uid: string; story: MonthlyStoryPersistedText; jobId: string;
    leaseOwner: string; nowMillis: number }): Promise<{ story: MonthlyStoryPersistedText; duplicate: boolean }> {
    return this.atomic(async () => {
      if (this.failPersistence) throw new MonthlyStoryRepositoryError("persistence-failure");
      const key = `${uidToken(input.uid)}/${input.story.monthKey}`;
      const existing = this.stories.get(key);
      if (existing) {
        if (existing.scriptHash !== input.story.scriptHash) throw new MonthlyStoryRepositoryError("story-conflict");
        return { story: structuredClone(existing), duplicate: true };
      }
      const job = this.jobs.get(input.jobId);
      if (!job || job.status !== "textLeased" || job.leaseOwner !== input.leaseOwner ||
          job.leaseExpiresAtMillis === null || job.leaseExpiresAtMillis <= input.nowMillis) {
        throw new MonthlyStoryRepositoryError("lease-conflict");
      }
      const story = parseMonthlyStoryPersistedText(input.story);
      this.stories.set(key, structuredClone(story));
      this.jobs.set(input.jobId, { ...job, status: "ready", leaseOwner: null, leaseExpiresAtMillis: null,
        textArtifactHash: story.scriptHash, audioTerminal: true, failureCode: null,
        nextAttemptAtMillis: null, updatedAtMillis: input.nowMillis });
      return { story: structuredClone(story), duplicate: false };
    });
  }
  async deleteStoryMetadata(uid: string, monthKey: string): Promise<void> {
    if (this.failDeletion) throw new MonthlyStoryRepositoryError("persistence-failure");
    this.stories.delete(`${uidToken(uid)}/${requireMonthKey(monthKey)}`);
  }
  enumerateAccountDeletion(uid: string, ownerKeyVersion: string): Promise<MonthlyStoryDeletionEnumeration> {
    const safeUid = uidToken(uid); const ownerKey = monthlyStoryOwnerKey(safeUid, ownerKeyVersion);
    const jobIds = [...this.jobs.values()].filter((job) => job.ownerKey === ownerKey).map((job) => job.jobId);
    return Promise.resolve({ documentTrees: [`monthlyStorySettings/${safeUid}`, `monthlyStorySignals/${safeUid}`,
      `monthlyStories/${safeUid}`, `monthlyStoryDeleted/${safeUid}`], jobIds,
    reservationJobIds: [...jobIds], deterministicUsageJobIds: [...jobIds],
    storagePrefixes: [`monthlyStories/${safeUid}/`] });
  }
}
