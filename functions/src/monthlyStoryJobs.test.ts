import { test } from "node:test";
import assert from "node:assert";
import { MonthlyStoryJob, MonthlyStoryJobRepository, MonthlyStoryJobTransaction,
  acquireMonthlyStoryJobLease, completeMonthlyStoryAudio, completeMonthlyStoryText,
  createMonthlyStoryJobIfAbsent, deterministicMonthlyStoryJobId, markMonthlyStoryJobDeleted,
  parseMonthlyStoryJob, recordMonthlyStoryJobFailure, resolveMonthlyStoryAudioVerification } from "./monthlyStoryJobs";

class FakeJobRepository implements MonthlyStoryJobRepository {
  readonly jobs = new Map<string, MonthlyStoryJob>();
  readonly tombstones = new Set<string>();
  private queue: Promise<void> = Promise.resolve();

  runTransaction<T>(operation: (transaction: MonthlyStoryJobTransaction) => Promise<T>): Promise<T> {
    const run = this.queue.then(async () => {
      const working = new Map(Array.from(this.jobs, ([key, value]) => [key, structuredClone(value)]));
      const transaction: MonthlyStoryJobTransaction = {
        get: async (jobId) => working.get(jobId) ?? null,
        create: (job) => {
          if (working.has(job.jobId)) throw new Error("already-exists");
          working.set(job.jobId, structuredClone(job));
        },
        set: (job) => working.set(job.jobId, structuredClone(job)),
        hasActiveTombstone: async (ownerKey, monthKey, generationVersion) =>
          this.tombstones.has(`${ownerKey}/${monthKey}/${generationVersion}`),
      };
      const result = await operation(transaction);
      this.jobs.clear();
      for (const [key, value] of working) this.jobs.set(key, value);
      return result;
    });
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }
}

const input = { uid: "synthetic-user-a", ownerKeyVersion: "owner-v1",
  monthKey: "2026-07", generationVersion: "v1", nowMillis: 100 };
const hash = "a".repeat(64);

async function pendingJob(repository = new FakeJobRepository()): Promise<{ repository: FakeJobRepository; job: MonthlyStoryJob }> {
  const { job } = await createMonthlyStoryJobIfAbsent(repository, input);
  return { repository, job };
}

test("job IDs are deterministic, opaque, and duplicate creation is idempotent", async () => {
  const repository = new FakeJobRepository();
  const first = await createMonthlyStoryJobIfAbsent(repository, input);
  const second = await createMonthlyStoryJobIfAbsent(repository, input);
  assert.equal(first.created, true);
  assert.equal(second.created, false);
  assert.equal(first.job.jobId, second.job.jobId);
  assert.match(first.job.jobId, /^ms_[a-f0-9]{64}$/);
  assert.equal(first.job.jobId.includes(input.uid), false);
  assert.equal(deterministicMonthlyStoryJobId(input.uid, input.monthKey, input.generationVersion,
    input.ownerKeyVersion), first.job.jobId);
});

test("active tombstone prevents regeneration", async () => {
  const repository = new FakeJobRepository();
  const probe = await pendingJob();
  repository.tombstones.add(`${probe.job.ownerKey}/${input.monthKey}/${input.generationVersion}`);
  await assert.rejects(createMonthlyStoryJobIfAbsent(repository, input), /tombstoned/);
});

test("atomic lease permits one concurrent owner and rejects the other", async () => {
  const { repository, job } = await pendingJob();
  const leases = await Promise.allSettled([
    acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text", leaseOwner: "worker-a",
      nowMillis: 101, leaseDurationMillis: 100, maximumAttempts: 2 }),
    acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text", leaseOwner: "worker-b",
      nowMillis: 101, leaseDurationMillis: 100, maximumAttempts: 2 }),
  ]);
  assert.equal(leases.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(leases.filter((result) => result.status === "rejected").length, 1);
});

test("expired lease can be acquired again but attempt maximum is enforced", async () => {
  const { repository, job } = await pendingJob();
  await acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text", leaseOwner: "worker-a",
    nowMillis: 101, leaseDurationMillis: 10, maximumAttempts: 2 });
  const reacquired = await acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text",
    leaseOwner: "worker-b", nowMillis: 112, leaseDurationMillis: 10, maximumAttempts: 2 });
  assert.equal(reacquired.textAttempts, 2);
  await assert.rejects(acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text",
    leaseOwner: "worker-c", nowMillis: 123, leaseDurationMillis: 10, maximumAttempts: 2 }), /attempt-limit/);
});

test("lease ownership ends at the exact expiration instant", async () => {
  const { repository, job } = await pendingJob();
  await acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text", leaseOwner: "worker-a",
    nowMillis: 100, leaseDurationMillis: 50, maximumAttempts: 2 });
  await assert.rejects(completeMonthlyStoryText(repository,
    { jobId: job.jobId, leaseOwner: "worker-a", nowMillis: 150, textArtifactHash: "a".repeat(64) }),
  /wrong-stage/);
});

test("text completion can proceed to audio and terminal audio failure preserves text", async () => {
  const { repository, job } = await pendingJob();
  await acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text", leaseOwner: "worker-a",
    nowMillis: 101, leaseDurationMillis: 100, maximumAttempts: 2 });
  const textReady = await completeMonthlyStoryText(repository,
    { jobId: job.jobId, leaseOwner: "worker-a", nowMillis: 102, textArtifactHash: hash });
  assert.equal(textReady.status, "textReady");
  await acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "audio", leaseOwner: "worker-b",
    nowMillis: 103, leaseDurationMillis: 100, maximumAttempts: 2 });
  const preserved = await recordMonthlyStoryJobFailure(repository, { jobId: job.jobId, stage: "audio",
    leaseOwner: "worker-b", nowMillis: 104, failureCode: "providerRejected" });
  assert.equal(preserved.status, "textReady");
  assert.equal(preserved.textArtifactHash, hash);
  assert.equal(preserved.audioTerminal, true);
  await assert.rejects(acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "audio",
    leaseOwner: "worker-c", nowMillis: 105, leaseDurationMillis: 100, maximumAttempts: 2 }), /terminal-state/);
});

test("audio attempt maximum is enforced after a retriable failure", async () => {
  const { repository, job } = await pendingJob();
  await acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text", leaseOwner: "worker-a",
    nowMillis: 101, leaseDurationMillis: 100, maximumAttempts: 1 });
  await completeMonthlyStoryText(repository,
    { jobId: job.jobId, leaseOwner: "worker-a", nowMillis: 102, textArtifactHash: hash });
  await acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "audio", leaseOwner: "worker-a",
    nowMillis: 103, leaseDurationMillis: 100, maximumAttempts: 1 });
  await recordMonthlyStoryJobFailure(repository, { jobId: job.jobId, stage: "audio",
    leaseOwner: "worker-a", nowMillis: 104, failureCode: "providerTimeout", nextAttemptAtMillis: 200 });
  await assert.rejects(acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "audio",
    leaseOwner: "worker-b", nowMillis: 200, leaseDurationMillis: 100, maximumAttempts: 1 }), /attempt-limit/);
});

test("unknown audio outcome blocks retries until object and hash verification", async () => {
  const { repository, job } = await pendingJob();
  await acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text", leaseOwner: "worker-a",
    nowMillis: 101, leaseDurationMillis: 100, maximumAttempts: 2 });
  await completeMonthlyStoryText(repository,
    { jobId: job.jobId, leaseOwner: "worker-a", nowMillis: 102, textArtifactHash: hash });
  await acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "audio", leaseOwner: "worker-a",
    nowMillis: 103, leaseDurationMillis: 100, maximumAttempts: 2 });
  const blocked = await completeMonthlyStoryAudio(repository, { jobId: job.jobId, leaseOwner: "worker-a",
    nowMillis: 104, audioArtifactHash: "b".repeat(64), objectExists: true, objectHashMatches: false });
  assert.equal(blocked.status, "audioVerificationRequired");
  await assert.rejects(acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "audio",
    leaseOwner: "worker-b", nowMillis: 105, leaseDurationMillis: 100, maximumAttempts: 2 }), /terminal-state/);
  const retryable = await resolveMonthlyStoryAudioVerification(repository,
    { jobId: job.jobId, nowMillis: 106, objectExists: false, objectHashMatches: false });
  assert.equal(retryable.status, "textReady");
});

test("deleted and terminal jobs cannot restart", async () => {
  const { repository, job } = await pendingJob();
  const deleted = await markMonthlyStoryJobDeleted(repository, job.jobId, 101);
  assert.equal(deleted.status, "deleted");
  await assert.rejects(acquireMonthlyStoryJobLease(repository, { jobId: job.jobId, stage: "text",
    leaseOwner: "worker-a", nowMillis: 102, leaseDurationMillis: 100, maximumAttempts: 2 }), /terminal-state/);
});

test("job schema rejects unknown fields", async () => {
  const { job } = await pendingJob();
  assert.deepEqual(parseMonthlyStoryJob(job), job);
  assert.throws(() => parseMonthlyStoryJob({ ...job, rawPrompt: "not accepted" }), /invalid-job/);
});
