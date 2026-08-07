import { MonthlyStoryTextArtifact, createMonthlyStoryTextArtifact } from "./monthlyStoryArtifact";
import { MonthlyStoryDeterministicComposerInput, MonthlyStoryDeterministicComposition,
  composeMonthlyStoryDeterministically } from "./monthlyStoryDeterministicComposer";
import { MonthlyStoryBudgetRepository, commitMonthlyStoryBudget, markMonthlyStoryProviderCallStarted,
  monthlyStoryBudgetPolicy, releaseMonthlyStoryBudget, reserveMonthlyStoryBudget } from "./monthlyStoryBudget";
import { MonthlyStoryControl, monthlyStoryGenerationIsFailClosed } from "./monthlyStoryControl";
import { MonthlyStoryCriticResult, parseMonthlyStoryCriticResult } from "./monthlyStoryCritic";
import { buildMonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions,
  monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";
import { MonthlyStoryPromptInput, buildMonthlyStoryCriticPrompt, buildMonthlyStoryRepairPrompt,
  buildMonthlyStoryWriterPrompt } from "./monthlyStoryPrompts";
import { MonthlyStoryScriptValidationResult, monthlyStoryValidationCanBeRepaired,
  validateMonthlyStoryScript } from "./monthlyStoryScriptValidator";
import { MonthlyStorySignal, parseMonthlyStorySignal } from "./monthlyStorySchema";
import { MonthlyStoryTextProvider, MonthlyStoryTextProviderRequest, MonthlyStoryWriterOutput,
  parseMonthlyStoryWriterOutput } from "./monthlyStoryTextProvider";

export const MONTHLY_STORY_WRITTEN_PIPELINE_VERSION = "written-v1";
export const MONTHLY_STORY_DEFAULT_WRITTEN_MODE = "deterministic" as const;
export type MonthlyStoryWrittenMode = "deterministic" | "modelEvaluation";

export type MonthlyStoryWrittenPipelineInput = {
  control: MonthlyStoryControl;
  signal: unknown;
  provider: MonthlyStoryTextProvider;
  budgetRepository: MonthlyStoryBudgetRepository;
  jobId: string;
  attempt: number;
  dayKey: string;
  nowMillis: number;
  reservationExpiresAtMillis: number;
  artifactExpiresAtMillis: number;
  reservedMicros: number;
  modelSnapshot: string;
  language: "en";
};

export type MonthlyStoryWrittenPipelineResult = {
  artifact: MonthlyStoryTextArtifact;
  critic: MonthlyStoryCriticResult;
  repaired: boolean;
  reservationId: string;
  syntheticCommittedMicros: number;
};

export type MonthlyStoryCompositionPipelineInput =
  { mode?: "deterministic"; deterministicInput: MonthlyStoryDeterministicComposerInput } |
  { mode: "modelEvaluation"; modelEvaluationInput: MonthlyStoryWrittenPipelineInput };

export type MonthlyStoryCompositionPipelineResult =
  { mode: "deterministic"; composition: MonthlyStoryDeterministicComposition; providerCallCount: 0;
    estimatedProviderCostMicros: 0 } |
  { mode: "modelEvaluation"; result: MonthlyStoryWrittenPipelineResult };

export type MonthlyStoryPipelineErrorCode = "feature-disabled" | "signal-version-mismatch" |
  "insufficient-material" | "duplicate-generation" | "provider-failure" | "provider-timeout" |
  "malformed-response" | "critic-rejected" | "validation-failed" | "repair-failed" |
  "budget-denied" | "budget-release-failed" | "invalid-pipeline-input";

export class MonthlyStoryPipelineError extends Error {
  constructor(readonly code: MonthlyStoryPipelineErrorCode) {
    super(code);
    this.name = "MonthlyStoryPipelineError";
  }
}

function providerRequest(operation: "writer" | "critic" | "repair",
  prompt: MonthlyStoryTextProviderRequest["prompt"], input: MonthlyStoryWrittenPipelineInput):
  MonthlyStoryTextProviderRequest {
  return { operation, prompt, modelSnapshot: input.modelSnapshot, promptVersion: prompt.version,
    timeoutMillis: 20_000, maximumInputTokens: 4_000, maximumOutputTokens: 1_200 };
}

function promptInput(signal: MonthlyStorySignal, input: MonthlyStoryWrittenPipelineInput): MonthlyStoryPromptInput {
  const plan = buildMonthlyStoryNarrativePlan(signal);
  return { plan, allowedClaims: monthlyStoryPlanClaimOptions(plan), storyMode: plan.storyMode,
    wordTarget: monthlyStoryWordTarget(plan), language: input.language,
    promptVersion: input.control.scriptPromptVersion };
}

function errorCode(error: unknown): MonthlyStoryPipelineErrorCode {
  if (error instanceof MonthlyStoryPipelineError) return error.code;
  if (error instanceof Error) {
    if (error.message === "provider-timeout") return "provider-timeout";
    if (error.message === "malformed-response") return "malformed-response";
    if (error.message === "provider-failure") return "provider-failure";
    if (error.message.includes("budget") || ["disabled", "missing-policy", "monthly-cap", "stage-cap",
      "daily-cap", "invalid-amount", "reservation-conflict", "reservation-missing", "reservation-state",
      "reservation-expired", "ledger-mismatch"].includes(error.message)) {
      return "budget-denied";
    }
    if (error.name === "MonthlyStoryNarrativePlanError" || error.name === "MonthlyStoryValidationError") {
      return "insufficient-material";
    }
  }
  return "provider-failure";
}

function validateOutput(output: MonthlyStoryWriterOutput, signal: MonthlyStorySignal,
  prompt: MonthlyStoryPromptInput): MonthlyStoryScriptValidationResult {
  return validateMonthlyStoryScript({ script: output.script, claimedEvidenceIds: output.claimedEvidenceIds,
    claimKeys: output.claimKeys, plan: prompt.plan, availableEvidence: signal.evidence });
}

export async function runMonthlyStoryWrittenPipeline(input: MonthlyStoryWrittenPipelineInput):
Promise<MonthlyStoryWrittenPipelineResult> {
  if (monthlyStoryGenerationIsFailClosed(input.control) || !input.control.visible ||
      input.control.generationVersion.length === 0 || input.control.scriptPromptVersion.length === 0 ||
      input.control.criticPromptVersion.length === 0) throw new MonthlyStoryPipelineError("feature-disabled");
  if (!Number.isSafeInteger(input.attempt) || input.attempt < 1 || input.attempt > input.control.maxTextAttempts ||
      !Number.isSafeInteger(input.reservedMicros) || input.reservedMicros <= 0 ||
      !/^[A-Za-z0-9._-]{1,64}$/.test(input.modelSnapshot)) {
    throw new MonthlyStoryPipelineError("invalid-pipeline-input");
  }
  let signal: MonthlyStorySignal;
  try {
    signal = parseMonthlyStorySignal(input.signal);
  } catch {
    throw new MonthlyStoryPipelineError("insufficient-material");
  }
  if (signal.schemaVersion !== input.control.signalSchemaVersion || !signal.permissions.featureEnabled) {
    throw new MonthlyStoryPipelineError("signal-version-mismatch");
  }
  let prompt: MonthlyStoryPromptInput;
  try {
    prompt = promptInput(signal, input);
  } catch {
    throw new MonthlyStoryPipelineError("insufficient-material");
  }

  let reservationId: string | null = null;
  let reservationCreated = false;
  try {
    const reserved = await reserveMonthlyStoryBudget(input.budgetRepository, {
      jobId: input.jobId, stage: "text", attempt: input.attempt, monthKey: signal.monthKey,
      dayKey: input.dayKey, amountMicros: input.reservedMicros, nowMillis: input.nowMillis,
      expiresAtMillis: input.reservationExpiresAtMillis, policy: monthlyStoryBudgetPolicy(input.control),
    });
    reservationId = reserved.reservation.reservationId;
    if (reserved.duplicate) throw new MonthlyStoryPipelineError("duplicate-generation");
    reservationCreated = true;
    await markMonthlyStoryProviderCallStarted(input.budgetRepository,
      { reservationId, monthKey: signal.monthKey }, input.nowMillis);

    const writerPrompt = buildMonthlyStoryWriterPrompt(prompt);
    let output = parseMonthlyStoryWriterOutput(await input.provider.generate(
      providerRequest("writer", writerPrompt, input)));
    let validation = validateOutput(output, signal, prompt);
    let repaired = false;
    let totalCost = output.syntheticCostMicros;
    const repair = async (criticErrors: readonly string[]): Promise<void> => {
      const repairPrompt = buildMonthlyStoryRepairPrompt(prompt, output.script,
        validation.errors, criticErrors, output.claimedEvidenceIds, output.claimKeys);
      output = parseMonthlyStoryWriterOutput(await input.provider.generate(
        providerRequest("repair", repairPrompt, input)));
      totalCost += output.syntheticCostMicros;
      validation = validateOutput(output, signal, prompt);
      repaired = true;
      if (!validation.isValid) throw new MonthlyStoryPipelineError("repair-failed");
    };

    if (!validation.isValid) {
      if (!monthlyStoryValidationCanBeRepaired(validation)) {
        throw new MonthlyStoryPipelineError("validation-failed");
      }
      await repair([]);
    }

    const criticInput = { ...prompt, promptVersion: input.control.criticPromptVersion };
    let critic = parseMonthlyStoryCriticResult(await input.provider.generate(
      providerRequest("critic", buildMonthlyStoryCriticPrompt(criticInput, output.script,
        output.claimedEvidenceIds, output.claimKeys), input)));
    totalCost += critic.syntheticCostMicros;
    if (critic.decision === "reject") throw new MonthlyStoryPipelineError("critic-rejected");
    if (critic.decision === "repairable") {
      if (repaired) throw new MonthlyStoryPipelineError("repair-failed");
      await repair(critic.reasons);
      critic = parseMonthlyStoryCriticResult(await input.provider.generate(
        providerRequest("critic", buildMonthlyStoryCriticPrompt(criticInput, output.script,
          output.claimedEvidenceIds, output.claimKeys), input)));
      totalCost += critic.syntheticCostMicros;
      if (critic.decision !== "pass") {
        throw new MonthlyStoryPipelineError(critic.decision === "reject" ?
          "critic-rejected" : "repair-failed");
      }
    }
    const artifact = createMonthlyStoryTextArtifact({ monthKey: signal.monthKey,
      generationVersion: input.control.generationVersion, promptVersion: input.control.scriptPromptVersion,
      criticVersion: input.control.criticPromptVersion, language: input.language, script: output.script,
      usedEvidenceIds: output.claimedEvidenceIds, textAttemptCount: repaired ? 2 : 1, validation,
      createdAtMillis: input.nowMillis, expiresAtMillis: input.artifactExpiresAtMillis });
    const committed = await commitMonthlyStoryBudget(input.budgetRepository, { reservationId,
      monthKey: signal.monthKey, actualMicros: totalCost, nowMillis: input.nowMillis });
    return { artifact, critic, repaired, reservationId, syntheticCommittedMicros: committed.committedMicros };
  } catch (error) {
    const code = errorCode(error);
    if (reservationCreated && reservationId) {
      try {
        await releaseMonthlyStoryBudget(input.budgetRepository, { reservationId, monthKey: signal.monthKey,
          dayKey: input.dayKey, nowMillis: input.nowMillis });
      } catch {
        throw new MonthlyStoryPipelineError("budget-release-failed");
      }
    }
    throw new MonthlyStoryPipelineError(code);
  }
}

export async function runMonthlyStoryCompositionPipeline(input: MonthlyStoryCompositionPipelineInput):
Promise<MonthlyStoryCompositionPipelineResult> {
  if (input.mode !== "modelEvaluation") {
    return { mode: MONTHLY_STORY_DEFAULT_WRITTEN_MODE,
      composition: composeMonthlyStoryDeterministically(input.deterministicInput),
      providerCallCount: 0, estimatedProviderCostMicros: 0 };
  }
  return { mode: input.mode, result: await runMonthlyStoryWrittenPipeline(input.modelEvaluationInput) };
}
