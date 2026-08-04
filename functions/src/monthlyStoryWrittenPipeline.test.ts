import { test } from "node:test";
import assert from "node:assert";
import { MonthlyStoryBudgetRepository, MonthlyStoryBudgetReservation, MonthlyStoryBudgetTransaction,
  MonthlyStoryDailySpend, MonthlyStoryMonthlySpend } from "./monthlyStoryBudget";
import { MonthlyStoryControl, SAFE_DISABLED_MONTHLY_STORY_CONTROL } from "./monthlyStoryControl";
import { passingMonthlyStoryCriticResult } from "./monthlyStoryCritic";
import { FakeMonthlyStoryTextProvider, FailureMonthlyStoryTextProvider,
  MalformedMonthlyStoryTextProvider, MonthlyStoryTextProvider, MonthlyStoryTextProviderRequest,
  TimeoutMonthlyStoryTextProvider } from "./monthlyStoryTextProvider";
import { MonthlyStoryPipelineError, runMonthlyStoryCompositionPipeline,
  runMonthlyStoryWrittenPipeline } from "./monthlyStoryWrittenPipeline";
import { MONTHLY_STORY_GOLDENS, SYNTHETIC_RICH_SIGNAL } from "./monthlyStoryWrittenFixtures";

class FakeBudgetRepository implements MonthlyStoryBudgetRepository {
  readonly monthly = new Map<string, MonthlyStoryMonthlySpend>();
  readonly daily = new Map<string, MonthlyStoryDailySpend>();
  readonly reservations = new Map<string, MonthlyStoryBudgetReservation>();
  private queue: Promise<void> = Promise.resolve();

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

const control: MonthlyStoryControl = { ...SAFE_DISABLED_MONTHLY_STORY_CONTROL,
  visible: true, enrollmentEnabled: true, textGenerationEnabled: true, rolloutBasisPoints: 10_000,
  dailyTextGenerationCap: 5, monthlyTextGenerationCap: 100,
  monthlyBudgetMicros: 1_000, monthlyTextBudgetMicros: 1_000,
  monthlyAudioBudgetMicros: 0, maxTextAttempts: 2, generationVersion: "gen-v1", signalSchemaVersion: 1,
  scriptPromptVersion: "writer-v1", criticPromptVersion: "critic-v1", updatedAtMillis: 1 };
const golden = MONTHLY_STORY_GOLDENS[0];
const writer = (script = golden.script, cost = 50) => ({ script,
  claimedEvidenceIds: golden.claimedEvidenceIds, claimKeys: golden.claimKeys, syntheticCostMicros: cost });
const baseInput = (repository: FakeBudgetRepository, provider: MonthlyStoryTextProvider) => ({ control,
  signal: SYNTHETIC_RICH_SIGNAL, provider, budgetRepository: repository,
  jobId: `ms_${"a".repeat(64)}`, attempt: 1, dayKey: "2026-07-28", nowMillis: 100,
  reservationExpiresAtMillis: 1_000, artifactExpiresAtMillis: 2_000, reservedMicros: 200,
  modelSnapshot: "fake-snapshot-v1", language: "en" as const });

test("successful writer and critic produce a text-only artifact and commit synthetic cost", async () => {
  const repository = new FakeBudgetRepository();
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(),
    critic: passingMonthlyStoryCriticResult(20) });
  const result = await runMonthlyStoryWrittenPipeline(baseInput(repository, provider));
  assert.equal(result.artifact.status, "textReady");
  assert.equal(result.artifact.textAttemptCount, 1);
  assert.equal(result.syntheticCommittedMicros, 70);
  assert.equal(result.repaired, false);
  assert.deepEqual(provider.calls.map((call) => call.operation), ["writer", "critic"]);
  assert.equal(repository.reservations.get(result.reservationId)?.status, "committed");
  assert.equal(Object.prototype.hasOwnProperty.call(result.artifact, "audio"), false);
});

test("legacy full-story generation requires the explicit modelEvaluation mode", async () => {
  const repository = new FakeBudgetRepository();
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(),
    critic: passingMonthlyStoryCriticResult(20) });
  const result = await runMonthlyStoryCompositionPipeline({ mode: "modelEvaluation",
    modelEvaluationInput: baseInput(repository, provider) });
  assert.equal(result.mode, "modelEvaluation");
  assert.deepEqual(provider.calls.map((call) => call.operation), ["writer", "critic"]);
});

test("budget is reserved and marked started before the first provider request", async () => {
  const repository = new FakeBudgetRepository();
  const responses = [writer(), passingMonthlyStoryCriticResult(20)];
  const provider: MonthlyStoryTextProvider = { generate: async (_request: MonthlyStoryTextProviderRequest) => {
    const reservation = [...repository.reservations.values()][0];
    assert.equal(reservation?.status, "reserved");
    assert.equal(reservation?.providerCallStartedAtMillis, 100);
    return structuredClone(responses.shift());
  } };
  await runMonthlyStoryWrittenPipeline(baseInput(repository, provider));
});

test("disabled controls, zero rollout, and zero budget fail before provider invocation", async () => {
  for (const disabled of [{ ...control, textGenerationEnabled: false }, { ...control, rolloutBasisPoints: 0 },
    { ...control, monthlyBudgetMicros: 0, monthlyTextBudgetMicros: 0 }]) {
    const repository = new FakeBudgetRepository();
    const provider = new FakeMonthlyStoryTextProvider({ writer: writer() });
    await assert.rejects(runMonthlyStoryWrittenPipeline({ ...baseInput(repository, provider), control: disabled }),
      (error: unknown) => error instanceof MonthlyStoryPipelineError && error.code === "feature-disabled");
    assert.equal(provider.calls.length, 0);
    assert.equal(repository.reservations.size, 0);
  }
});

test("an exhausted synthetic monthly budget fails before provider invocation", async () => {
  const repository = new FakeBudgetRepository();
  repository.monthly.set("2026-07", { monthKey: "2026-07", ceilingMicros: 1_000,
    textCeilingMicros: 1_000, audioCeilingMicros: 0, reservedMicros: 0, committedMicros: 1_000,
    releasedMicros: 0, text: { reservedMicros: 0, committedMicros: 1_000, releasedMicros: 0 },
    audio: { reservedMicros: 0, committedMicros: 0, releasedMicros: 0 }, updatedAtMillis: 1 });
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer() });
  await assert.rejects(runMonthlyStoryWrittenPipeline(baseInput(repository, provider)),
    (error: unknown) => error instanceof MonthlyStoryPipelineError && error.code === "budget-denied");
  assert.equal(provider.calls.length, 0);
});

test("synthetic actual cost cannot exceed the reservation ceiling", async () => {
  const repository = new FakeBudgetRepository();
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(golden.script, 190),
    critic: passingMonthlyStoryCriticResult(20) });
  await assert.rejects(runMonthlyStoryWrittenPipeline(baseInput(repository, provider)),
    (error: unknown) => error instanceof MonthlyStoryPipelineError && error.code === "budget-denied");
  assert.equal([...repository.reservations.values()][0]?.status, "released");
  assert.equal(repository.monthly.get("2026-07")?.committedMicros, 0);
});

test("known provider failure, timeout, and malformed output release the synthetic reservation", async () => {
  for (const provider of [new FailureMonthlyStoryTextProvider(), new TimeoutMonthlyStoryTextProvider(),
    new MalformedMonthlyStoryTextProvider()]) {
    const repository = new FakeBudgetRepository();
    await assert.rejects(runMonthlyStoryWrittenPipeline(baseInput(repository, provider)));
    assert.equal([...repository.reservations.values()][0]?.status, "released");
    assert.equal(repository.monthly.get("2026-07")?.reservedMicros, 0);
  }
});

test("critic rejection is terminal and never fabricates a fallback", async () => {
  const repository = new FakeBudgetRepository();
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(), critic: {
    ...passingMonthlyStoryCriticResult(20), decision: "reject", reasons: ["evidenceMismatch"] } });
  await assert.rejects(runMonthlyStoryWrittenPipeline(baseInput(repository, provider)),
    (error: unknown) => error instanceof MonthlyStoryPipelineError && error.code === "critic-rejected");
  assert.deepEqual(provider.calls.map((call) => call.operation), ["writer", "critic"]);
  assert.equal([...repository.reservations.values()][0]?.status, "released");
});

test("repairable output receives exactly one repair and commits only after validation", async () => {
  const repository = new FakeBudgetRepository();
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(), critic: [
    { ...passingMonthlyStoryCriticResult(20), decision: "repairable", reasons: ["unnatural"] },
    passingMonthlyStoryCriticResult(20),
  ],
  repair: writer(golden.script, 30) });
  const result = await runMonthlyStoryWrittenPipeline(baseInput(repository, provider));
  assert.equal(result.repaired, true);
  assert.equal(result.artifact.textAttemptCount, 2);
  assert.equal(result.syntheticCommittedMicros, 120);
  assert.deepEqual(provider.calls.map((call) => call.operation), ["writer", "critic", "repair", "critic"]);
});

test("a too-short draft gets one completeness repair before critic review", async () => {
  const repository = new FakeBudgetRepository();
  const short = writer("this month felt mixed. next month, try to protect a little more rest.", 20);
  const provider = new FakeMonthlyStoryTextProvider({ writer: short,
    repair: writer(golden.script, 30), critic: passingMonthlyStoryCriticResult(20) });
  const result = await runMonthlyStoryWrittenPipeline(baseInput(repository, provider));
  assert.equal(result.repaired, true);
  assert.equal(result.syntheticCommittedMicros, 70);
  assert.deepEqual(provider.calls.map((call) => call.operation), ["writer", "repair", "critic"]);
});

test("a failed repair is terminal, releases budget, and cannot request another repair", async () => {
  const repository = new FakeBudgetRepository();
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(), critic: {
    ...passingMonthlyStoryCriticResult(20), decision: "repairable", reasons: ["weakSuggestions"] },
  repair: writer("next month, try to rest.", 10) });
  await assert.rejects(runMonthlyStoryWrittenPipeline(baseInput(repository, provider)),
    (error: unknown) => error instanceof MonthlyStoryPipelineError && error.code === "repair-failed");
  assert.equal(provider.calls.length, 3);
  assert.equal([...repository.reservations.values()][0]?.status, "released");
});

test("duplicate generation attempt never calls provider or double-reserves", async () => {
  const repository = new FakeBudgetRepository();
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer(),
    critic: passingMonthlyStoryCriticResult(20) });
  await runMonthlyStoryWrittenPipeline(baseInput(repository, provider));
  await assert.rejects(runMonthlyStoryWrittenPipeline(baseInput(repository, provider)),
    (error: unknown) => error instanceof MonthlyStoryPipelineError && error.code === "duplicate-generation");
  assert.equal(provider.calls.length, 2);
  assert.equal(repository.reservations.size, 1);
  assert.equal(repository.monthly.get("2026-07")?.committedMicros, 70);
});

test("narratively weak input fails before reservation or provider invocation", async () => {
  const repository = new FakeBudgetRepository();
  const provider = new FakeMonthlyStoryTextProvider({ writer: writer() });
  const weak = { ...SYNTHETIC_RICH_SIGNAL, evidence: [
    (SYNTHETIC_RICH_SIGNAL.evidence as Record<string, unknown>[])[0],
    (SYNTHETIC_RICH_SIGNAL.evidence as Record<string, unknown>[]).find((item) =>
      (item.value as Record<string, string>).type === "nextMonthSuggestionBasis"),
  ] };
  await assert.rejects(runMonthlyStoryWrittenPipeline({ ...baseInput(repository, provider), signal: weak }),
    (error: unknown) => error instanceof MonthlyStoryPipelineError && error.code === "insufficient-material");
  assert.equal(provider.calls.length, 0);
  assert.equal(repository.reservations.size, 0);
});
