import { MonthlyStoryAudioObject, MonthlyStoryAudioRepository, MonthlyStoryAudioServiceError,
  AudioLeaseResult } from "./monthlyStoryAudioService";
import { FirestoreMonthlyStoryRepository, MonthlyStoryFirestoreDependency, MonthlyStoryPersistedText,
  parseMonthlyStoryPersistedText, snapshotData } from "./monthlyStoryRepository";
import { deterministicMonthlyStoryJobId, parseMonthlyStoryJob } from "./monthlyStoryJobs";
import { MONTHLY_STORY_PATHS, parseMonthlyStoryDeletedTombstone, requireGenerationVersion,
  requireMonthKey } from "./monthlyStorySchema";

const OWNER_KEY_VERSION = "monthly-story-owner-v1";

function dayKey(millis: number): string { return new Date(millis).toISOString().slice(0, 10); }
function billingMonth(millis: number): string { return new Date(millis).toISOString().slice(0, 7); }
function count(value: unknown): number {
  const result = Number(value ?? 0);
  if (!Number.isSafeInteger(result) || result < 0) throw new MonthlyStoryAudioServiceError("persistence-failure");
  return result;
}

export class FirestoreMonthlyStoryAudioRepository implements MonthlyStoryAudioRepository {
  private readonly stories: FirestoreMonthlyStoryRepository;
  constructor(private readonly firestore: MonthlyStoryFirestoreDependency) {
    this.stories = new FirestoreMonthlyStoryRepository(firestore);
  }
  loadStory(uid: string, monthKey: string): Promise<MonthlyStoryPersistedText | null> {
    return this.stories.loadStory(uid, monthKey);
  }
  async hasActiveTombstone(uid: string, monthKey: string, generationVersion: string,
    nowMillis: number): Promise<boolean> {
    const tombstone = await this.stories.loadDeletedTombstone(uid, monthKey);
    return tombstone !== null && tombstone.generationVersion === generationVersion &&
      tombstone.expiresAtMillis > nowMillis;
  }

  async acquireAudioLease(input: { uid: string; monthKey: string; generationVersion: string; nowMillis: number;
    leaseOwner: string; leaseDurationMillis: number; maximumAttempts: number; reservationMicros: number;
    dailyCap: number; monthlyCap: number; monthlyBudgetMicros: number }): Promise<AudioLeaseResult> {
    const monthKey = requireMonthKey(input.monthKey);
    const generationVersion = requireGenerationVersion(input.generationVersion);
    const jobId = deterministicMonthlyStoryJobId(input.uid, monthKey, generationVersion, OWNER_KEY_VERSION);
    return this.firestore.runTransaction(async (transaction) => {
      const storyRef = this.firestore.doc(MONTHLY_STORY_PATHS.story(input.uid, monthKey));
      const tombstoneRef = this.firestore.doc(MONTHLY_STORY_PATHS.tombstone(input.uid, monthKey));
      const jobRef = this.firestore.doc(`monthlyStoryJobs/${jobId}`);
      const storyValue = snapshotData(await transaction.get(storyRef));
      if (storyValue === null) throw new MonthlyStoryAudioServiceError("story-missing");
      const story = parseMonthlyStoryPersistedText(storyValue);
      if (story.audioStatus === "ready") return { kind: "existing", story };
      const tombstoneValue = snapshotData(await transaction.get(tombstoneRef));
      if (tombstoneValue !== null && parseMonthlyStoryDeletedTombstone(tombstoneValue).expiresAtMillis > input.nowMillis) {
        throw new MonthlyStoryAudioServiceError("story-deleted");
      }
      const jobValue = snapshotData(await transaction.get(jobRef));
      if (jobValue === null) throw new MonthlyStoryAudioServiceError("persistence-failure");
      let job = parseMonthlyStoryJob(jobValue);
      // Written stories created before audio support were terminalized. Only a matching untouched
      // deterministic story may be migrated into the audio stage.
      if (job.status === "ready" && job.audioTerminal && story.audioStatus === "notRequested" &&
          job.textArtifactHash === story.scriptHash) {
        job = { ...job, status: "textReady", audioTerminal: false, updatedAtMillis: input.nowMillis };
      }
      if ((job.status === "audioLeased") && job.leaseExpiresAtMillis !== null &&
          job.leaseExpiresAtMillis > input.nowMillis) return { kind: "active" };
      if (!["textReady", "audioLeased", "audioVerificationRequired"].includes(job.status)) {
        throw new MonthlyStoryAudioServiceError("attempt-limit");
      }
      if (job.audioAttempts >= input.maximumAttempts) throw new MonthlyStoryAudioServiceError("attempt-limit");
      const attempt = job.audioAttempts + 1;
      const reservationId = `${jobId}_audio_${attempt}`;
      const reservationRef = this.firestore.doc(`monthlyStorySpend/${billingMonth(input.nowMillis)}/reservations/${reservationId}`);
      if ((await transaction.get(reservationRef)).exists) throw new MonthlyStoryAudioServiceError("audio-active");
      const dailyRef = this.firestore.doc(`monthlyStoryDailySpend/${dayKey(input.nowMillis)}`);
      const monthRef = this.firestore.doc(`monthlyStorySpend/${billingMonth(input.nowMillis)}`);
      const daily = snapshotData(await transaction.get(dailyRef)) as Record<string, unknown> | null;
      const monthly = snapshotData(await transaction.get(monthRef)) as Record<string, unknown> | null;
      const dailyCount = count(daily?.audioGenerationCount);
      const monthlyCount = count(monthly?.audioGenerationCount);
      const reserved = count(monthly?.audioReservedMicros);
      const committed = count(monthly?.audioCommittedMicros);
      if (dailyCount >= input.dailyCap) throw new MonthlyStoryAudioServiceError("daily-cap");
      if (monthlyCount >= input.monthlyCap) throw new MonthlyStoryAudioServiceError("monthly-cap");
      if (reserved + committed + input.reservationMicros > input.monthlyBudgetMicros) {
        throw new MonthlyStoryAudioServiceError("budget-denied");
      }
      transaction.set(dailyRef, { ...(daily ?? {}), audioGenerationCount: dailyCount + 1,
        updatedAtMillis: input.nowMillis });
      transaction.set(monthRef, { ...(monthly ?? {}), audioGenerationCount: monthlyCount + 1,
        audioReservedMicros: reserved + input.reservationMicros, audioCommittedMicros: committed,
        updatedAtMillis: input.nowMillis });
      transaction.create(reservationRef, { reservationId, jobId, stage: "audio", attempt,
        status: "reserved", amountMicros: input.reservationMicros, committedMicros: 0,
        createdAtMillis: input.nowMillis, updatedAtMillis: input.nowMillis,
        expiresAtMillis: input.nowMillis + input.leaseDurationMillis });
      transaction.set(jobRef, { ...job, status: "audioLeased", leaseOwner: input.leaseOwner,
        leaseExpiresAtMillis: input.nowMillis + input.leaseDurationMillis, audioAttempts: attempt,
        failureCode: null, nextAttemptAtMillis: null, audioTerminal: false, updatedAtMillis: input.nowMillis });
      transaction.set(storyRef, { ...story, audioStatus: "generating", audioTtsVersion: "pending",
        audioVoiceKey: "pending", audioProviderRequestCount: attempt - 1, audioEstimatedCostMicros: 0,
        audioRetryCount: attempt - 1, audioFailureCode: null });
      return { kind: "acquired", attempt, leaseOwner: input.leaseOwner, reservedMicros: input.reservationMicros };
    });
  }

  async markAudioReady(input: { uid: string; monthKey: string; generationVersion: string; leaseOwner: string;
    object: MonthlyStoryAudioObject; nowMillis: number }): Promise<MonthlyStoryPersistedText> {
    const monthKey = requireMonthKey(input.monthKey);
    const jobId = deterministicMonthlyStoryJobId(input.uid, monthKey, input.generationVersion, OWNER_KEY_VERSION);
    return this.firestore.runTransaction(async (transaction) => {
      const storyRef = this.firestore.doc(MONTHLY_STORY_PATHS.story(input.uid, monthKey));
      const jobRef = this.firestore.doc(`monthlyStoryJobs/${jobId}`);
      const storyValue = snapshotData(await transaction.get(storyRef));
      const jobValue = snapshotData(await transaction.get(jobRef));
      if (storyValue === null || jobValue === null) throw new MonthlyStoryAudioServiceError("persistence-failure");
      const story = parseMonthlyStoryPersistedText(storyValue); const job = parseMonthlyStoryJob(jobValue);
      if (story.audioStatus === "ready" && story.audioHash === input.object.hash) return story;
      if (input.leaseOwner !== "object-reconciliation" &&
          (job.status !== "audioLeased" || job.leaseOwner !== input.leaseOwner)) {
        throw new MonthlyStoryAudioServiceError("persistence-failure");
      }
      const ready: MonthlyStoryPersistedText = { ...story, audioStatus: "ready",
        audioStoragePath: input.object.path, audioFormat: "mp3", audioDurationMillis: input.object.durationMillis,
        audioHash: input.object.hash, audioTtsVersion: input.object.ttsVersion,
        audioVoiceKey: input.object.voiceKey, audioGeneratedAtMillis: input.object.generatedAtMillis,
        audioProviderRequestCount: input.object.providerRequestCount,
        audioEstimatedCostMicros: input.object.estimatedCostMicros,
        audioRetryCount: Math.max(0, input.object.providerRequestCount - 1), audioFailureCode: null };
      transaction.set(storyRef, ready);
      transaction.set(jobRef, { ...job, status: "ready", leaseOwner: null, leaseExpiresAtMillis: null,
        audioArtifactHash: input.object.hash, audioTerminal: true, failureCode: null,
        updatedAtMillis: input.nowMillis });
      const attempt = Math.max(job.audioAttempts, 1);
      const reservationId = `${jobId}_audio_${attempt}`;
      const reservationRef = this.firestore.doc(`monthlyStorySpend/${billingMonth(input.nowMillis)}/reservations/${reservationId}`);
      const reservation = snapshotData(await transaction.get(reservationRef)) as Record<string, unknown> | null;
      if (reservation && reservation.status === "reserved") {
        const monthRef = this.firestore.doc(`monthlyStorySpend/${billingMonth(input.nowMillis)}`);
        const monthly = snapshotData(await transaction.get(monthRef)) as Record<string, unknown> | null;
        const amount = count(reservation.amountMicros); const actual = input.object.estimatedCostMicros;
        if (actual > amount) throw new MonthlyStoryAudioServiceError("budget-denied");
        transaction.set(monthRef, { ...(monthly ?? {}),
          audioReservedMicros: count(monthly?.audioReservedMicros) - amount,
          audioCommittedMicros: count(monthly?.audioCommittedMicros) + actual,
          audioReleasedMicros: count(monthly?.audioReleasedMicros) + amount - actual,
          updatedAtMillis: input.nowMillis });
        transaction.set(reservationRef, { ...reservation, status: "committed", committedMicros: actual,
          updatedAtMillis: input.nowMillis });
      }
      return ready;
    });
  }

  async markAudioFailure(input: { uid: string; monthKey: string; generationVersion: string; leaseOwner: string;
    failureCode: string; transient: boolean; outcomeUncertain: boolean; billableMicros: number;
    nowMillis: number }): Promise<void> {
    const monthKey = requireMonthKey(input.monthKey);
    const jobId = deterministicMonthlyStoryJobId(input.uid, monthKey, input.generationVersion, OWNER_KEY_VERSION);
    await this.firestore.runTransaction(async (transaction) => {
      const storyRef = this.firestore.doc(MONTHLY_STORY_PATHS.story(input.uid, monthKey));
      const jobRef = this.firestore.doc(`monthlyStoryJobs/${jobId}`);
      const storyValue = snapshotData(await transaction.get(storyRef)); const jobValue = snapshotData(await transaction.get(jobRef));
      if (storyValue === null || jobValue === null) throw new MonthlyStoryAudioServiceError("persistence-failure");
      const story = parseMonthlyStoryPersistedText(storyValue); const job = parseMonthlyStoryJob(jobValue);
      if (job.status !== "audioLeased" || job.leaseOwner !== input.leaseOwner) return;
      transaction.set(storyRef, { ...story, audioStatus: "failed", audioTtsVersion: story.audioTtsVersion ?? "failed",
        audioVoiceKey: story.audioVoiceKey ?? "failed", audioProviderRequestCount: job.audioAttempts,
        audioEstimatedCostMicros: input.billableMicros, audioRetryCount: Math.max(0, job.audioAttempts - 1),
        audioFailureCode: input.failureCode });
      transaction.set(jobRef, { ...job, status: input.outcomeUncertain ? "audioVerificationRequired" :
        (input.transient ? "textReady" : "terminalFailure"), leaseOwner: null, leaseExpiresAtMillis: null,
        audioTerminal: !input.transient && !input.outcomeUncertain, failureCode: input.outcomeUncertain ?
          "unknownAudioOutcome" : (input.transient ? "transientProvider" : "providerRejected"),
        updatedAtMillis: input.nowMillis });
      const reservationId = `${jobId}_audio_${job.audioAttempts}`;
      const reservationRef = this.firestore.doc(`monthlyStorySpend/${billingMonth(input.nowMillis)}/reservations/${reservationId}`);
      const reservation = snapshotData(await transaction.get(reservationRef)) as Record<string, unknown> | null;
      if (reservation && reservation.status === "reserved") {
        const monthRef = this.firestore.doc(`monthlyStorySpend/${billingMonth(input.nowMillis)}`);
        const monthly = snapshotData(await transaction.get(monthRef)) as Record<string, unknown> | null;
        const amount = count(reservation.amountMicros);
        transaction.set(monthRef, { ...(monthly ?? {}),
          audioReservedMicros: count(monthly?.audioReservedMicros) - amount,
          audioCommittedMicros: count(monthly?.audioCommittedMicros) + input.billableMicros,
          audioReleasedMicros: count(monthly?.audioReleasedMicros) + amount - input.billableMicros,
          updatedAtMillis: input.nowMillis });
        transaction.set(reservationRef, { ...reservation,
          status: input.billableMicros > 0 ? "committed" : "released", committedMicros: input.billableMicros,
          updatedAtMillis: input.nowMillis });
      }
    });
  }
}

export class InMemoryMonthlyStoryAudioRepository implements MonthlyStoryAudioRepository {
  story: MonthlyStoryPersistedText | null = null;
  tombstoned = false; activeLeaseUntil = 0; attempts = 0; dailyCount = 0; monthlyCount = 0;
  reservedMicros = 0; committedMicros = 0; failMetadata = false;
  loadStory(): Promise<MonthlyStoryPersistedText | null> { return Promise.resolve(this.story ? structuredClone(this.story) : null); }
  hasActiveTombstone(): Promise<boolean> { return Promise.resolve(this.tombstoned); }
  async acquireAudioLease(input: { nowMillis: number; leaseOwner: string; leaseDurationMillis: number;
    maximumAttempts: number; reservationMicros: number; dailyCap: number; monthlyCap: number;
    monthlyBudgetMicros: number }): Promise<AudioLeaseResult> {
    if (!this.story) throw new MonthlyStoryAudioServiceError("story-missing");
    if (this.story.audioStatus === "ready") return { kind: "existing", story: this.story };
    if (this.activeLeaseUntil > input.nowMillis) return { kind: "active" };
    if (this.attempts >= input.maximumAttempts) throw new MonthlyStoryAudioServiceError("attempt-limit");
    if (this.dailyCount >= input.dailyCap) throw new MonthlyStoryAudioServiceError("daily-cap");
    if (this.monthlyCount >= input.monthlyCap) throw new MonthlyStoryAudioServiceError("monthly-cap");
    if (this.reservedMicros + this.committedMicros + input.reservationMicros > input.monthlyBudgetMicros) {
      throw new MonthlyStoryAudioServiceError("budget-denied");
    }
    this.attempts += 1; this.dailyCount += 1; this.monthlyCount += 1;
    this.reservedMicros += input.reservationMicros; this.activeLeaseUntil = input.nowMillis + input.leaseDurationMillis;
    this.story = { ...this.story, audioStatus: "generating", audioTtsVersion: "pending",
      audioVoiceKey: "pending", audioProviderRequestCount: this.attempts - 1, audioEstimatedCostMicros: 0,
      audioRetryCount: this.attempts - 1, audioFailureCode: null };
    return { kind: "acquired", attempt: this.attempts, leaseOwner: input.leaseOwner,
      reservedMicros: input.reservationMicros };
  }
  async markAudioReady(input: { object: MonthlyStoryAudioObject }): Promise<MonthlyStoryPersistedText> {
    if (this.failMetadata || !this.story) throw new MonthlyStoryAudioServiceError("persistence-failure");
    this.reservedMicros = 0; this.committedMicros += input.object.estimatedCostMicros; this.activeLeaseUntil = 0;
    this.story = { ...this.story, audioStatus: "ready", audioStoragePath: input.object.path,
      audioFormat: "mp3", audioDurationMillis: input.object.durationMillis, audioHash: input.object.hash,
      audioTtsVersion: input.object.ttsVersion, audioVoiceKey: input.object.voiceKey,
      audioGeneratedAtMillis: input.object.generatedAtMillis,
      audioProviderRequestCount: input.object.providerRequestCount,
      audioEstimatedCostMicros: input.object.estimatedCostMicros,
      audioRetryCount: Math.max(0, input.object.providerRequestCount - 1), audioFailureCode: null };
    return this.story;
  }
  async markAudioFailure(input: { billableMicros: number; failureCode: string }): Promise<void> {
    if (!this.story) return; this.reservedMicros = 0; this.committedMicros += input.billableMicros;
    this.activeLeaseUntil = 0; this.story = { ...this.story, audioStatus: "failed",
      audioTtsVersion: this.story.audioTtsVersion ?? "failed", audioVoiceKey: this.story.audioVoiceKey ?? "failed",
      audioProviderRequestCount: this.attempts, audioEstimatedCostMicros: input.billableMicros,
      audioRetryCount: Math.max(0, this.attempts - 1), audioFailureCode: input.failureCode };
  }
}
