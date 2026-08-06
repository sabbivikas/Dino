import { MonthlyStoryAudioObject, MonthlyStoryAudioRepository, MonthlyStoryAudioServiceError,
  AudioLeaseResult } from "./monthlyStoryAudioService";
import { FirestoreDocument, FirestoreMonthlyStoryRepository, FirestoreTransaction,
  MonthlyStoryFirestoreDependency, MonthlyStoryPersistedText,
  parseMonthlyStoryPersistedText, snapshotData } from "./monthlyStoryRepository";
import { deterministicMonthlyStoryJobId, parseMonthlyStoryJob } from "./monthlyStoryJobs";
import { MONTHLY_STORY_PATHS, parseMonthlyStoryDeletedTombstone, requireGenerationVersion,
  requireMonthKey } from "./monthlyStorySchema";

const OWNER_KEY_VERSION = "monthly-story-owner-v1";

// The largest timestamp `new Date(...).toISOString()` can render; anything beyond it throws.
const MAXIMUM_DATE_MILLIS = 8_640_000_000_000_000;

function dayKey(millis: number): string { return new Date(millis).toISOString().slice(0, 10); }
function billingMonth(millis: number): string { return new Date(millis).toISOString().slice(0, 7); }
// Day 0 of the current UTC month IS the last day of the previous one, so the UTC Date does the
// rollover arithmetic itself and 2026-01 yields 2025-12 without any string math.
function previousBillingMonth(millis: number): string {
  const current = new Date(millis);
  return new Date(Date.UTC(current.getUTCFullYear(), current.getUTCMonth(), 0)).toISOString().slice(0, 7);
}
// The day the reservation was CREATED, read off the reservation itself, or null when the stored
// value is missing or unusable as a timestamp.
function reservationDayKey(reservation: Record<string, unknown>): string | null {
  const created = Number(reservation.createdAtMillis ?? Number.NaN);
  if (!Number.isSafeInteger(created) || created <= 0 || created > MAXIMUM_DATE_MILLIS) return null;
  return dayKey(created);
}
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

  // A reservation id is created exactly once, in exactly one billing month: the month that was
  // current when `acquireAudioLease` ran. Settlement recomputes the month from its own clock, so a
  // lease taken just before a UTC month boundary would otherwise look for its reservation in the
  // WRONG month doc, find nothing, silently decline to settle, and strand the original month's
  // `audioReservedMicros` forever. So probe: the current billing month first, then the previous one.
  //
  // Probing exactly ONE month back is sufficient because of the FUNCTION TIMEOUT, not because
  // "leases are short". The lease duration is remote-controlled —
  // `Math.max(MONTHLY_STORY_AUDIO_LEASE_MILLIS, control.audioRequestTimeoutSeconds * 1000 + 30_000)`
  // with `audioRequestTimeoutSeconds` bounded only to 0-300 — so the lease itself guarantees
  // nothing. The guarantee is that `generateMonthlyStoryInternalAudio` is declared
  // `timeoutSeconds: 180` (functions/src/index.ts:148), so a lease and its settlement always happen
  // inside ONE invocation and can therefore span at most one month boundary.
  //
  // The probe is keyed on document EXISTENCE, not on status: existence is what LOCATES the
  // reservation (it lives in exactly one month), and status then decides whether it still settles.
  // Keying the probe on status instead would let an already-`committed` reservation sitting in the
  // current month trigger a second lookup in the previous month that could pick up something else.
  private async probeAudioReservation(transaction: FirestoreTransaction, reservationId: string,
    nowMillis: number): Promise<{ month: string; reservationRef: FirestoreDocument;
      reservation: Record<string, unknown> | null }> {
    const candidates = [billingMonth(nowMillis), previousBillingMonth(nowMillis)];
    for (const month of candidates) {
      const reservationRef = this.firestore.doc(`monthlyStorySpend/${month}/reservations/${reservationId}`);
      const snapshot = await transaction.get(reservationRef);
      if (snapshot.exists) {
        return { month, reservationRef,
          reservation: snapshotData(snapshot) as Record<string, unknown> | null };
      }
    }
    // Found in neither month: nothing settles, and the caller only needs a well-formed ref.
    const month = candidates[0];
    return { month, reservation: null,
      reservationRef: this.firestore.doc(`monthlyStorySpend/${month}/reservations/${reservationId}`) };
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
      const attempt = job.audioAttempts;
      // `audioAttempts === 0` means no lease was ever taken, so no reservation exists for this job
      // and there is nothing to settle. The caller that reaches this state is the
      // `leaseOwner: "object-reconciliation"` path (monthlyStoryAudioService.ts:78), which runs when
      // the audio object is already in storage. Fabricating an `_audio_1` id here would either find
      // nothing or, worse, settle a stale reservation belonging to an unrelated attempt. The skip is
      // keyed on the ATTEMPT COUNT, not on the lease owner: reconciliation with `audioAttempts >= 1`
      // (a previous lease that crashed after writing the object) does have a real reservation and
      // must still settle it. Only the settlement block is skipped — the story and job writes below
      // and the returned `ready` value are identical either way.
      // Every read is issued BEFORE the first write below: Firestore rejects a get() that follows a
      // write inside the same transaction, so the reservation and the monthly ledger it settles
      // against have to be loaded while the transaction is still read-only.
      const probe = attempt >= 1 ?
        await this.probeAudioReservation(transaction, `${jobId}_audio_${attempt}`, input.nowMillis) : null;
      const reservation = probe?.reservation ?? null;
      const settles = reservation !== null && reservation.status === "reserved";
      // Address the month doc at the month the reservation actually LIVES in, never at
      // `billingMonth(input.nowMillis)`: a lease that crossed a boundary must credit the month it
      // reserved against, not the month it happened to finish in.
      const monthRef = probe !== null && settles ?
        this.firestore.doc(`monthlyStorySpend/${probe.month}`) : null;
      const monthly = monthRef !== null ?
        snapshotData(await transaction.get(monthRef)) as Record<string, unknown> | null : null;
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
      if (probe !== null && monthRef !== null && reservation && settles) {
        const amount = count(reservation.amountMicros); const actual = input.object.estimatedCostMicros;
        if (actual > amount) throw new MonthlyStoryAudioServiceError("budget-denied");
        transaction.set(monthRef, { ...(monthly ?? {}),
          audioReservedMicros: count(monthly?.audioReservedMicros) - amount,
          audioCommittedMicros: count(monthly?.audioCommittedMicros) + actual,
          audioReleasedMicros: count(monthly?.audioReleasedMicros) + amount - actual,
          updatedAtMillis: input.nowMillis });
        transaction.set(probe.reservationRef, { ...reservation, status: "committed", committedMicros: actual,
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
    // `acquireAudioLease` increments BOTH generation counters (daily and monthly); an attempt that
    // produced nothing and cost nothing has to give both of them back, the same way its micros are
    // released. The guard is deliberately narrow, because a generation counter is a CAP, not an
    // accounting record, and a cap has to hold no matter what: over-counting costs a user an
    // occasional slot on a run that genuinely failed, while under-counting lets the cap admit more
    // generations than it is set to — and that costs money.
    // `outcomeUncertain` means the provider (Hume) may have produced audio and may therefore have
    // billed us, so `billableMicros === 0` alongside it is US NOT KNOWING what was spent, not us
    // knowing that nothing was. Withholding the refund there also keeps the counters consistent with
    // the micros: whenever the provider itself reports an uncertain outcome it reports the call as
    // billable too, so those micros are committed rather than released and the attempt is spent.
    const refundsGenerationCount = input.billableMicros === 0 && !input.outcomeUncertain;
    await this.firestore.runTransaction(async (transaction) => {
      const storyRef = this.firestore.doc(MONTHLY_STORY_PATHS.story(input.uid, monthKey));
      const jobRef = this.firestore.doc(`monthlyStoryJobs/${jobId}`);
      const storyValue = snapshotData(await transaction.get(storyRef)); const jobValue = snapshotData(await transaction.get(jobRef));
      if (storyValue === null || jobValue === null) throw new MonthlyStoryAudioServiceError("persistence-failure");
      const story = parseMonthlyStoryPersistedText(storyValue); const job = parseMonthlyStoryJob(jobValue);
      if (job.status !== "audioLeased" || job.leaseOwner !== input.leaseOwner) return;
      // Every read is issued BEFORE the first write below: Firestore rejects a get() that follows a
      // write inside the same transaction, and the daily doc — untouched by this path until now —
      // has to be read to refund its counter. Order: probe the reservation, then the month doc it
      // lives in, then the daily doc the probe's `createdAtMillis` points at.
      const probe = await this.probeAudioReservation(transaction,
        `${jobId}_audio_${job.audioAttempts}`, input.nowMillis);
      const reservation = probe.reservation;
      const settles = reservation !== null && reservation.status === "reserved";
      // The month the reservation LIVES in, not the month this completion happens to land in.
      const monthRef = settles ? this.firestore.doc(`monthlyStorySpend/${probe.month}`) : null;
      const monthly = monthRef !== null ?
        snapshotData(await transaction.get(monthRef)) as Record<string, unknown> | null : null;
      // Same root cause as the month doc above, one level down: `acquireAudioLease` incremented the
      // daily counter under the day key of the LEASE, so the refund has to land on that same day —
      // `dayKey(input.nowMillis)` is the completion day and drifts off it whenever a lease crosses a
      // UTC midnight. The reservation carries `createdAtMillis`, which is exactly the lease instant.
      // When that value is missing or unusable, SKIP the daily refund rather than throwing away the
      // whole settlement or guessing a day: a generation counter is a CAP, and leaving it
      // over-counted costs a user one slot, while decrementing a day that never incremented would
      // let the cap admit more generations than it is set to — and that costs money.
      const refundDayKey = settles && refundsGenerationCount && reservation !== null ?
        reservationDayKey(reservation) : null;
      const dailyRef = refundDayKey !== null ?
        this.firestore.doc(`monthlyStoryDailySpend/${refundDayKey}`) : null;
      const daily = dailyRef !== null ?
        snapshotData(await transaction.get(dailyRef)) as Record<string, unknown> | null : null;
      transaction.set(storyRef, { ...story, audioStatus: "failed", audioTtsVersion: story.audioTtsVersion ?? "failed",
        audioVoiceKey: story.audioVoiceKey ?? "failed", audioProviderRequestCount: job.audioAttempts,
        audioEstimatedCostMicros: input.billableMicros, audioRetryCount: Math.max(0, job.audioAttempts - 1),
        audioFailureCode: input.failureCode });
      transaction.set(jobRef, { ...job, status: input.outcomeUncertain ? "audioVerificationRequired" :
        (input.transient ? "textReady" : "terminalFailure"), leaseOwner: null, leaseExpiresAtMillis: null,
        audioTerminal: !input.transient && !input.outcomeUncertain, failureCode: input.outcomeUncertain ?
          "unknownAudioOutcome" : (input.transient ? "transientProvider" : "providerRejected"),
        updatedAtMillis: input.nowMillis });
      if (monthRef !== null && reservation && settles) {
        const amount = count(reservation.amountMicros);
        // Both counters are normalized through count(), which fails closed on a corrupt (negative or
        // non-integer) stored value, and the refund clamps at 0 so a counter can never go negative:
        // a stored 0 simply means there is nothing left to give back, and leaving it at 0 keeps the
        // cap on the safe side.
        const monthlyRefund = refundsGenerationCount ?
          { audioGenerationCount: Math.max(0, count(monthly?.audioGenerationCount) - 1) } : {};
        transaction.set(monthRef, { ...(monthly ?? {}), ...monthlyRefund,
          audioReservedMicros: count(monthly?.audioReservedMicros) - amount,
          audioCommittedMicros: count(monthly?.audioCommittedMicros) + input.billableMicros,
          audioReleasedMicros: count(monthly?.audioReleasedMicros) + amount - input.billableMicros,
          updatedAtMillis: input.nowMillis });
        if (refundsGenerationCount && dailyRef !== null) {
          transaction.set(dailyRef, { ...(daily ?? {}),
            audioGenerationCount: Math.max(0, count(daily?.audioGenerationCount) - 1),
            updatedAtMillis: input.nowMillis });
        }
        transaction.set(probe.reservationRef, { ...reservation,
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
