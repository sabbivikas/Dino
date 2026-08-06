import { test } from "node:test";
import assert from "node:assert";
import { MonthlyStoryBudgetPolicy, MonthlyStoryBudgetRepository, MonthlyStoryBudgetReservation,
  MonthlyStoryBudgetTransaction, MonthlyStoryDailySpend, MonthlyStoryMonthlySpend,
  MonthlyStoryReservationRef,
  commitMonthlyStoryBudget, deterministicMonthlyStoryReservationId,
  markMonthlyStoryProviderCallStarted, reconcileExpiredMonthlyStoryReservations,
  releaseMonthlyStoryBudget, reserveMonthlyStoryBudget } from "./monthlyStoryBudget";

class FakeBudgetRepository implements MonthlyStoryBudgetRepository {
  readonly monthly = new Map<string, MonthlyStoryMonthlySpend>();
  readonly daily = new Map<string, MonthlyStoryDailySpend>();
  readonly reservations = new Map<string, MonthlyStoryBudgetReservation>();
  listExpiredCalls = 0;
  listExpiredThrows = false;
  private queue: Promise<void> = Promise.resolve();

  async listExpiredReservations(input: { nowMillis: number; limit: number }):
  Promise<MonthlyStoryReservationRef[]> {
    this.listExpiredCalls++;
    if (this.listExpiredThrows) throw new Error("9 FAILED_PRECONDITION: index required");
    return Array.from(this.reservations.values())
      .filter((item) => item.status === "reserved" && item.expiresAtMillis <= input.nowMillis)
      .slice(0, input.limit)
      .map(({ reservationId, monthKey, dayKey }) => ({ reservationId, monthKey, dayKey }));
  }

  runTransaction<T>(operation: (transaction: MonthlyStoryBudgetTransaction) => Promise<T>): Promise<T> {
    const run = this.queue.then(async () => {
      const monthly = new Map(Array.from(this.monthly, ([key, value]) => [key, structuredClone(value)]));
      const daily = new Map(Array.from(this.daily, ([key, value]) => [key, structuredClone(value)]));
      const reservations = new Map(Array.from(this.reservations, ([key, value]) => [key, structuredClone(value)]));
      const transaction: MonthlyStoryBudgetTransaction = {
        getMonthlySpend: async (key) => monthly.get(key) ?? null,
        getDailySpend: async (key) => daily.get(key) ?? null,
        getReservation: async (key) => reservations.get(key) ?? null,
        setMonthlySpend: (value) => monthly.set(value.monthKey, structuredClone(value)),
        setDailySpend: (value) => daily.set(value.dayKey, structuredClone(value)),
        createReservation: (value) => {
          if (reservations.has(value.reservationId)) throw new Error("already-exists");
          reservations.set(value.reservationId, structuredClone(value));
        },
        setReservation: (value) => reservations.set(value.reservationId, structuredClone(value)),
      };
      const result = await operation(transaction);
      this.monthly.clear(); this.daily.clear(); this.reservations.clear();
      for (const [key, value] of monthly) this.monthly.set(key, value);
      for (const [key, value] of daily) this.daily.set(key, value);
      for (const [key, value] of reservations) this.reservations.set(key, value);
      return result;
    });
    this.queue = run.then(() => undefined, () => undefined);
    return run;
  }
}

const policy: MonthlyStoryBudgetPolicy = { textGenerationEnabled: true, audioGenerationEnabled: true,
  monthlyBudgetMicros: 1_000, monthlyTextBudgetMicros: 600, monthlyAudioBudgetMicros: 400,
  dailyTextGenerationCap: 2, monthlyTextGenerationCap: 4, dailyAudioGenerationCap: 1,
  monthlyAudioGenerationCap: 2 };
const jobId = `ms_${"a".repeat(64)}`;
const base = { jobId, stage: "text" as const, attempt: 1, monthKey: "2026-07",
  dayKey: "2026-07-05", amountMicros: 200, nowMillis: 100, expiresAtMillis: 200, policy };

test("missing, zero, or disabled budget policy fails closed", async () => {
  const repository = new FakeBudgetRepository();
  await assert.rejects(reserveMonthlyStoryBudget(repository, { ...base, policy: null }), /missing-policy/);
  await assert.rejects(reserveMonthlyStoryBudget(repository,
    { ...base, policy: { ...policy, monthlyBudgetMicros: 0, monthlyTextBudgetMicros: 0,
      monthlyAudioBudgetMicros: 0 } }), /disabled/);
  await assert.rejects(reserveMonthlyStoryBudget(repository,
    { ...base, policy: { ...policy, textGenerationEnabled: false } }), /disabled/);
});

test("reservation is atomic and duplicate retry cannot double-reserve", async () => {
  const repository = new FakeBudgetRepository();
  const attempts = await Promise.all([
    reserveMonthlyStoryBudget(repository, base),
    reserveMonthlyStoryBudget(repository, base),
  ]);
  assert.equal(attempts.filter((item) => item.duplicate).length, 1);
  assert.equal(repository.monthly.get("2026-07")?.reservedMicros, 200);
  assert.equal(repository.daily.get("2026-07-05")?.textGenerationCount, 1);
  assert.equal(repository.reservations.size, 1);
});

test("monthly, stage, and daily caps are enforced", async () => {
  const monthly = new FakeBudgetRepository();
  await reserveMonthlyStoryBudget(monthly, { ...base, amountMicros: 600 });
  await assert.rejects(reserveMonthlyStoryBudget(monthly,
    { ...base, jobId: `ms_${"b".repeat(64)}`, attempt: 1, amountMicros: 1 }), /stage-cap/);

  const daily = new FakeBudgetRepository();
  await reserveMonthlyStoryBudget(daily, base);
  await reserveMonthlyStoryBudget(daily, { ...base, jobId: `ms_${"b".repeat(64)}`, amountMicros: 200 });
  await assert.rejects(reserveMonthlyStoryBudget(daily,
    { ...base, jobId: `ms_${"c".repeat(64)}`, amountMicros: 1 }), /daily-cap/);

  const total = new FakeBudgetRepository();
  await reserveMonthlyStoryBudget(total, { ...base, amountMicros: 600 });
  await reserveMonthlyStoryBudget(total, { ...base, jobId: `ms_${"b".repeat(64)}`,
    stage: "audio", amountMicros: 400 });
  await assert.rejects(reserveMonthlyStoryBudget(total, { ...base, jobId: `ms_${"c".repeat(64)}`,
    attempt: 2, amountMicros: 1 }), /monthly-cap|stage-cap|daily-cap/);

  const audioDaily = new FakeBudgetRepository();
  await reserveMonthlyStoryBudget(audioDaily, { ...base, stage: "audio", amountMicros: 100 });
  await assert.rejects(reserveMonthlyStoryBudget(audioDaily, { ...base, jobId: `ms_${"b".repeat(64)}`,
    stage: "audio", amountMicros: 100 }), /daily-cap/);
});

test("commit records actual cost and releases unused reservation without negatives", async () => {
  const repository = new FakeBudgetRepository();
  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  const committed = await commitMonthlyStoryBudget(repository,
    { reservationId: reservation.reservationId, monthKey: "2026-07", actualMicros: 150, nowMillis: 150 });
  assert.equal(committed.status, "committed");
  const ledger = repository.monthly.get("2026-07")!;
  assert.equal(ledger.reservedMicros, 0);
  assert.equal(ledger.committedMicros, 150);
  assert.equal(ledger.releasedMicros, 50);
  assert.equal(ledger.text.committedMicros, 150);
  assert.ok(ledger.committedMicros <= ledger.ceilingMicros);
});

test("known failure releases budget and unused daily count", async () => {
  const repository = new FakeBudgetRepository();
  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  const released = await releaseMonthlyStoryBudget(repository,
    { reservationId: reservation.reservationId, monthKey: "2026-07", dayKey: "2026-07-05", nowMillis: 150 });
  assert.equal(released.status, "released");
  assert.equal(repository.monthly.get("2026-07")?.reservedMicros, 0);
  assert.equal(repository.daily.get("2026-07-05")?.textGenerationCount, 0);
});

test("reservation cannot mutate a different month or day ledger", async () => {
  const repository = new FakeBudgetRepository();
  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  await assert.rejects(commitMonthlyStoryBudget(repository,
    { reservationId: reservation.reservationId, monthKey: "2026-08", actualMicros: 100, nowMillis: 150 }),
  /ledger-mismatch/);
  await assert.rejects(releaseMonthlyStoryBudget(repository,
    { reservationId: reservation.reservationId, monthKey: "2026-07", dayKey: "2026-07-06", nowMillis: 150 }),
  /ledger-mismatch/);
  assert.equal(repository.monthly.get("2026-07")?.reservedMicros, 200);
  assert.equal(repository.daily.get("2026-07-05")?.textGenerationCount, 1);
});

test("a started provider attempt retains its daily count when reservation is released", async () => {
  const repository = new FakeBudgetRepository();
  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  await markMonthlyStoryProviderCallStarted(repository, reservation.reservationId, 120);
  await releaseMonthlyStoryBudget(repository,
    { reservationId: reservation.reservationId, monthKey: "2026-07", dayKey: "2026-07-05", nowMillis: 150 });
  assert.equal(repository.daily.get("2026-07-05")?.textGenerationCount, 1);
});

test("expired reservations can be reconciled idempotently", async () => {
  const repository = new FakeBudgetRepository();
  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  const inputs = [{ reservationId: reservation.reservationId, monthKey: "2026-07", dayKey: "2026-07-05" }];
  assert.equal(await reconcileExpiredMonthlyStoryReservations(repository, inputs, 201), 1);
  assert.equal(await reconcileExpiredMonthlyStoryReservations(repository, inputs, 202), 0);
});

// ── BUG 1: monthly generation counters must be refunded, exactly like the daily ones ──

test("release refunds the MONTHLY generation count and micros when the provider never started", async () => {
  const repository = new FakeBudgetRepository();
  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  assert.equal(repository.monthly.get("2026-07")?.textGenerationCount, 1);
  await releaseMonthlyStoryBudget(repository,
    { reservationId: reservation.reservationId, monthKey: "2026-07", dayKey: "2026-07-05", nowMillis: 150 });
  const ledger = repository.monthly.get("2026-07")!;
  assert.equal(ledger.textGenerationCount, 0);
  assert.equal(ledger.reservedMicros, 0);
  assert.equal(ledger.releasedMicros, 200);
  assert.equal(ledger.text.reservedMicros, 0);
  assert.equal(ledger.text.releasedMicros, 200);
});

test("a started provider attempt keeps its MONTHLY generation count and only refunds micros", async () => {
  const repository = new FakeBudgetRepository();
  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  await markMonthlyStoryProviderCallStarted(repository, reservation.reservationId, 120);
  await releaseMonthlyStoryBudget(repository,
    { reservationId: reservation.reservationId, monthKey: "2026-07", dayKey: "2026-07-05", nowMillis: 150 });
  const ledger = repository.monthly.get("2026-07")!;
  assert.equal(ledger.textGenerationCount, 1);
  assert.equal(ledger.audioGenerationCount, 0);
  assert.equal(ledger.reservedMicros, 0);
  assert.equal(ledger.releasedMicros, 200);
});

test("audio releases refund the audio monthly count and never touch the text count", async () => {
  const repository = new FakeBudgetRepository();
  const text = await reserveMonthlyStoryBudget(repository, base);
  const audio = await reserveMonthlyStoryBudget(repository,
    { ...base, jobId: `ms_${"b".repeat(64)}`, stage: "audio", amountMicros: 100 });
  assert.equal(repository.monthly.get("2026-07")?.textGenerationCount, 1);
  assert.equal(repository.monthly.get("2026-07")?.audioGenerationCount, 1);

  await releaseMonthlyStoryBudget(repository, { reservationId: audio.reservation.reservationId,
    monthKey: "2026-07", dayKey: "2026-07-05", nowMillis: 150 });
  const afterAudio = repository.monthly.get("2026-07")!;
  assert.equal(afterAudio.audioGenerationCount, 0);
  assert.equal(afterAudio.textGenerationCount, 1, "an audio release must not touch the text count");

  await releaseMonthlyStoryBudget(repository, { reservationId: text.reservation.reservationId,
    monthKey: "2026-07", dayKey: "2026-07-05", nowMillis: 160 });
  const afterText = repository.monthly.get("2026-07")!;
  assert.equal(afterText.textGenerationCount, 0);
  assert.equal(afterText.audioGenerationCount, 0);
  assert.equal(afterText.reservedMicros, 0);
});

test("a corrupt monthly generation count fails closed instead of going negative", async () => {
  const repository = new FakeBudgetRepository();
  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  const ledger = repository.monthly.get("2026-07")!;
  repository.monthly.set("2026-07", { ...ledger, textGenerationCount: 0 });
  await assert.rejects(releaseMonthlyStoryBudget(repository,
    { reservationId: reservation.reservationId, monthKey: "2026-07", dayKey: "2026-07-05", nowMillis: 150 }),
  /ledger-mismatch/);
  assert.equal(repository.monthly.get("2026-07")?.textGenerationCount, 0);
  assert.equal(repository.reservations.get(reservation.reservationId)?.status, "reserved");
});

test("a second release is a no-op and cannot double-refund the monthly count", async () => {
  const repository = new FakeBudgetRepository();
  const { reservation } = await reserveMonthlyStoryBudget(repository, base);
  const release = { reservationId: reservation.reservationId, monthKey: "2026-07",
    dayKey: "2026-07-05", nowMillis: 150 };
  await releaseMonthlyStoryBudget(repository, release);
  const first = structuredClone(repository.monthly.get("2026-07")!);
  await releaseMonthlyStoryBudget(repository, { ...release, nowMillis: 160 });
  const second = repository.monthly.get("2026-07")!;
  assert.equal(second.textGenerationCount, 0);
  assert.equal(second.releasedMicros, first.releasedMicros);
  assert.equal(second.reservedMicros, first.reservedMicros);
  assert.equal(repository.daily.get("2026-07-05")?.textGenerationCount, 0);
});

// ── BUG 2: expired reservations are swept, opportunistically and best-effort ──

test("reconcile self-sweeps expired reservations when no ids are supplied", async () => {
  const repository = new FakeBudgetRepository();
  await reserveMonthlyStoryBudget(repository, base);
  assert.equal(await reconcileExpiredMonthlyStoryReservations(repository, null, 50), 0,
    "an unexpired reservation is not swept");
  assert.equal(await reconcileExpiredMonthlyStoryReservations(repository, null, 201), 1);
  assert.equal(await reconcileExpiredMonthlyStoryReservations(repository, null, 202), 0,
    "self-sweep stays idempotent");
  assert.equal(repository.monthly.get("2026-07")?.reservedMicros, 0);
  assert.equal(repository.monthly.get("2026-07")?.textGenerationCount, 0);
});

test("a reserve that would hit the monthly ceiling succeeds once the expired hold is swept", async () => {
  const repository = new FakeBudgetRepository();
  await reserveMonthlyStoryBudget(repository, { ...base, amountMicros: 600 });
  assert.equal(repository.monthly.get("2026-07")?.reservedMicros, 600);
  // now past the first reservation's expiry: the sweep inside reserve frees its micros
  // and its counts before the ceiling checks run.
  const later = await reserveMonthlyStoryBudget(repository, { ...base, jobId: `ms_${"b".repeat(64)}`,
    amountMicros: 600, nowMillis: 300, expiresAtMillis: 400 });
  assert.equal(later.duplicate, false);
  assert.equal(repository.monthly.get("2026-07")?.reservedMicros, 600);
  assert.equal(repository.monthly.get("2026-07")?.releasedMicros, 600);
  assert.equal(repository.monthly.get("2026-07")?.textGenerationCount, 1);
  assert.equal(repository.daily.get("2026-07-05")?.textGenerationCount, 1);
  assert.ok(repository.listExpiredCalls > 0, "reserve swept opportunistically");
});

test("the reserve sweep is bounded and best-effort", async () => {
  const bounded = new FakeBudgetRepository();
  const limits: number[] = [];
  const inner = bounded.listExpiredReservations.bind(bounded);
  bounded.listExpiredReservations = async (input) => { limits.push(input.limit); return inner(input); };
  await reserveMonthlyStoryBudget(bounded, base);
  assert.deepEqual(limits, [10]);

  // a sweep that throws (e.g. FAILED_PRECONDITION from a missing index) must not
  // fail an otherwise-valid reserve.
  const failing = new FakeBudgetRepository();
  failing.listExpiredThrows = true;
  const reserved = await reserveMonthlyStoryBudget(failing, base);
  assert.equal(reserved.duplicate, false);
  assert.equal(failing.monthly.get("2026-07")?.reservedMicros, 200);
  assert.equal(failing.listExpiredCalls, 1);
});

test("reservation IDs are deterministic per job stage and attempt", () => {
  assert.equal(deterministicMonthlyStoryReservationId(jobId, "text", 1),
    deterministicMonthlyStoryReservationId(jobId, "text", 1));
  assert.notEqual(deterministicMonthlyStoryReservationId(jobId, "text", 1),
    deterministicMonthlyStoryReservationId(jobId, "text", 2));
});
