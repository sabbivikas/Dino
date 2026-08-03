import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { MonthlyStoryCriticResult, parseMonthlyStoryCriticResult } from "./monthlyStoryCritic";
import { MonthlyStoryModelConfig, MONTHLY_STORY_EVALUATION_MODEL_CONFIG,
  monthlyStoryMaximumRequestCostMicros, monthlyStoryOperationConfig,
  parseMonthlyStoryModelConfig } from "./monthlyStoryModelConfig";
import { buildMonthlyStoryNarrativePlan, monthlyStoryPlanClaimOptions,
  monthlyStoryWordTarget } from "./monthlyStoryNarrativePlan";
import { createMonthlyStoryOpenAIClient, MonthlyStoryOpenAIProvider,
  MonthlyStoryProviderUsage } from "./monthlyStoryOpenAIProvider";
import { buildMonthlyStoryCriticPrompt, buildMonthlyStoryRepairPrompt,
  buildMonthlyStoryWriterPrompt, MonthlyStoryPromptInput, MonthlyStoryPromptKind } from "./monthlyStoryPrompts";
import { MonthlyStoryScriptValidationResult, monthlyStoryValidationCanBeRepaired,
  validateMonthlyStoryScript } from "./monthlyStoryScriptValidator";
import { parseMonthlyStorySignal } from "./monthlyStorySchema";
import { approvedMonthlyStoryEvaluationFixture, isApprovedMonthlyStoryEvaluationFixtureId,
  MonthlyStoryEvaluationFixtureId } from "./monthlyStorySyntheticEvaluationFixtures";
import { MonthlyStoryTextProvider, MonthlyStoryTextProviderRequest, MonthlyStoryWriterOutput,
  parseMonthlyStoryWriterOutput } from "./monthlyStoryTextProvider";

export const MONTHLY_STORY_EVALUATION_MAX_FIXTURES = 8;
export const MONTHLY_STORY_EVALUATION_MAX_REQUESTS = 24;
export const MONTHLY_STORY_EVALUATION_MAX_SPEND_MICROS = 5_000_000;

export type MonthlyStoryEvaluationOptions = {
  live: boolean;
  syntheticOnlyConfirmed: boolean;
  fixtureIds: MonthlyStoryEvaluationFixtureId[];
  maximumRequests: number;
  maximumSpendMicros: number;
};

export type MonthlyStoryEvaluationRubric = {
  evidenceAlignment: number;
  unsupportedDetailAvoidance: number;
  naturalSpokenEnglish: number;
  warmth: number;
  nonClinicalTone: number;
  nonAnalyticalTone: number;
  nonMotivationalTone: number;
  lackOfAppLanguage: number;
  emotionalCoherence: number;
  recommendationWording: number;
  suggestionUsefulness: number;
  repetition: number;
};

export type MonthlyStoryFixtureEvaluation = {
  fixtureId: MonthlyStoryEvaluationFixtureId;
  synthetic: true;
  passed: boolean;
  hardFailureCodes: string[];
  script: string | null;
  wordCount: number;
  estimatedSpokenSeconds: number;
  validation: MonthlyStoryScriptValidationResult | null;
  critic: MonthlyStoryCriticResult | null;
  repaired: boolean;
  secondCriticPassed: boolean;
  rubric: MonthlyStoryEvaluationRubric | null;
  writerCostMicros: number;
  criticCostMicros: number;
  repairCostMicros: number;
  totalCostMicros: number;
  latencyMillis: number;
  requestCount: number;
  failureCode: string | null;
};

export type MonthlyStoryEvaluationReport = {
  label: "SYNTHETIC MONTHLY STORY EVALUATION";
  generatedAt: string;
  configurationVersion: string;
  pricingConfigurationVersion: string;
  writerModel: string;
  criticModel: string;
  maximumRequests: number;
  maximumSpendMicros: number;
  results: MonthlyStoryFixtureEvaluation[];
  aggregate: { passed: number; failed: number; requestCount: number; averageCostMicros: number;
    medianCostMicros: number; maximumCostMicros: number; averageLatencyMillis: number;
    totalSpendMicros: number; projectedTextOnlyCostMicros: { users100: number; users1000: number;
      users2700: number } };
  usage: MonthlyStoryProviderUsage[];
};

export class MonthlyStoryEvaluationSafetyError extends Error {
  constructor(readonly code: "invalid-arguments" | "fixture-not-approved" | "live-confirmation-required" |
    "missing-api-key" | "request-cap" | "spend-ceiling") {
    super(code);
    this.name = "MonthlyStoryEvaluationSafetyError";
  }
}

function parsePositiveInteger(value: string, maximum: number): number {
  if (!/^[1-9]\d*$/.test(value)) throw new MonthlyStoryEvaluationSafetyError("invalid-arguments");
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed > maximum) {
    throw new MonthlyStoryEvaluationSafetyError("invalid-arguments");
  }
  return parsed;
}

function parseSpendMicros(value: string): number {
  if (!/^\d+(?:\.\d{1,6})?$/.test(value)) throw new MonthlyStoryEvaluationSafetyError("invalid-arguments");
  const [whole, fraction = ""] = value.split(".");
  const micros = Number(whole) * 1_000_000 + Number(fraction.padEnd(6, "0"));
  if (!Number.isSafeInteger(micros) || micros < 1 || micros > MONTHLY_STORY_EVALUATION_MAX_SPEND_MICROS) {
    throw new MonthlyStoryEvaluationSafetyError("invalid-arguments");
  }
  return micros;
}

export function parseMonthlyStoryEvaluationArguments(args: readonly string[]): MonthlyStoryEvaluationOptions {
  let live = false;
  let syntheticOnlyConfirmed = false;
  let fixtureIds: MonthlyStoryEvaluationFixtureId[] | null = null;
  let maximumRequests = MONTHLY_STORY_EVALUATION_MAX_REQUESTS;
  let maximumSpendMicros = MONTHLY_STORY_EVALUATION_MAX_SPEND_MICROS;
  const seen = new Set<string>();
  for (const argument of args) {
    const [flag, value] = argument.split("=", 2);
    if (seen.has(flag)) throw new MonthlyStoryEvaluationSafetyError("invalid-arguments");
    seen.add(flag);
    if (argument === "--live") live = true;
    else if (argument === "--confirm-synthetic-only") syntheticOnlyConfirmed = true;
    else if (flag === "--fixtures" && value) {
      const ids = value.split(",");
      if (ids.length < 1 || ids.length > MONTHLY_STORY_EVALUATION_MAX_FIXTURES ||
          new Set(ids).size !== ids.length || ids.some((id) => !isApprovedMonthlyStoryEvaluationFixtureId(id))) {
        throw new MonthlyStoryEvaluationSafetyError("fixture-not-approved");
      }
      fixtureIds = ids as MonthlyStoryEvaluationFixtureId[];
    } else if (flag === "--max-requests" && value) {
      maximumRequests = parsePositiveInteger(value, MONTHLY_STORY_EVALUATION_MAX_REQUESTS);
    } else if (flag === "--max-spend-usd" && value) maximumSpendMicros = parseSpendMicros(value);
    else if (argument !== "--live" && argument !== "--confirm-synthetic-only") {
      throw new MonthlyStoryEvaluationSafetyError("invalid-arguments");
    }
  }
  if (!fixtureIds) throw new MonthlyStoryEvaluationSafetyError("invalid-arguments");
  if (live && !syntheticOnlyConfirmed) {
    throw new MonthlyStoryEvaluationSafetyError("live-confirmation-required");
  }
  return { live, syntheticOnlyConfirmed, fixtureIds, maximumRequests, maximumSpendMicros };
}

export function requireMonthlyStoryEvaluationApiKey(environment: NodeJS.ProcessEnv): string {
  const key = environment.OPENAI_API_KEY;
  if (typeof key !== "string" || key.length < 20 || /\s/.test(key)) {
    throw new MonthlyStoryEvaluationSafetyError("missing-api-key");
  }
  return key;
}

export class MonthlyStoryEvaluationLimits {
  requestCount = 0;
  actualSpendMicros = 0;
  private worstCaseSpendMicros = 0;

  constructor(readonly maximumRequests: number, readonly maximumSpendMicros: number,
    private readonly config: MonthlyStoryModelConfig) {
    if (!Number.isSafeInteger(maximumRequests) || maximumRequests < 1 ||
        maximumRequests > MONTHLY_STORY_EVALUATION_MAX_REQUESTS ||
        !Number.isSafeInteger(maximumSpendMicros) || maximumSpendMicros < 1 ||
        maximumSpendMicros > MONTHLY_STORY_EVALUATION_MAX_SPEND_MICROS) {
      throw new MonthlyStoryEvaluationSafetyError("invalid-arguments");
    }
  }

  beforeRequest(operation: MonthlyStoryPromptKind): void {
    if (this.requestCount >= this.maximumRequests) throw new MonthlyStoryEvaluationSafetyError("request-cap");
    const maximumCost = monthlyStoryMaximumRequestCostMicros(operation, this.config);
    if (this.worstCaseSpendMicros + maximumCost > this.maximumSpendMicros) {
      throw new MonthlyStoryEvaluationSafetyError("spend-ceiling");
    }
    this.requestCount += 1;
    this.worstCaseSpendMicros += maximumCost;
  }

  recordActualCost(costMicros: number): void {
    if (!Number.isSafeInteger(costMicros) || costMicros < 0 ||
        this.actualSpendMicros + costMicros > this.maximumSpendMicros) {
      throw new MonthlyStoryEvaluationSafetyError("spend-ceiling");
    }
    this.actualSpendMicros += costMicros;
  }
}

function promptInput(signalValue: unknown, config: MonthlyStoryModelConfig): {
  signal: ReturnType<typeof parseMonthlyStorySignal>; prompt: MonthlyStoryPromptInput } {
  const signal = parseMonthlyStorySignal(signalValue);
  const plan = buildMonthlyStoryNarrativePlan(signal);
  return { signal, prompt: { plan, allowedClaims: monthlyStoryPlanClaimOptions(plan),
    storyMode: plan.storyMode, wordTarget: monthlyStoryWordTarget(plan),
    language: "en", promptVersion: config.writerPromptVersion } };
}

function requestFor(operation: MonthlyStoryPromptKind, prompt: MonthlyStoryTextProviderRequest["prompt"],
  config: MonthlyStoryModelConfig): MonthlyStoryTextProviderRequest {
  const operationConfig = monthlyStoryOperationConfig(config, operation);
  return { operation, prompt, modelSnapshot: operationConfig.model, promptVersion: operationConfig.promptVersion,
    timeoutMillis: operationConfig.timeoutMillis, maximumInputTokens: operationConfig.inputTokenCap,
    maximumOutputTokens: operationConfig.outputTokenCap };
}

async function generate(provider: MonthlyStoryTextProvider, limits: MonthlyStoryEvaluationLimits,
  request: MonthlyStoryTextProviderRequest): Promise<unknown> {
  limits.beforeRequest(request.operation);
  const output = await provider.generate(request);
  if (typeof output !== "object" || output === null ||
      !Number.isSafeInteger((output as Record<string, unknown>).syntheticCostMicros)) return output;
  limits.recordActualCost((output as Record<string, number>).syntheticCostMicros);
  return output;
}

function retryableMalformed(error: unknown): boolean {
  return error instanceof Error && ["malformed-response", "provider-malformed-response",
    "provider-output-truncated"].includes(error.message);
}

function hasUsableScript(value: unknown): boolean {
  return typeof value === "object" && value !== null && !Array.isArray(value) &&
    typeof (value as Record<string, unknown>).script === "string" &&
    ((value as Record<string, string>).script).trim().length > 0;
}

async function generateWriterWithOneMalformedRetry(provider: MonthlyStoryTextProvider,
  limits: MonthlyStoryEvaluationLimits, request: MonthlyStoryTextProviderRequest):
Promise<MonthlyStoryWriterOutput> {
  for (let attempt = 0; attempt < 2; attempt += 1) {
    let raw: unknown;
    try {
      raw = await generate(provider, limits, request);
    } catch (error) {
      if (attempt === 0 && retryableMalformed(error)) continue;
      throw error;
    }
    try {
      return parseMonthlyStoryWriterOutput(raw);
    } catch (error) {
      if (attempt === 0 && !hasUsableScript(raw) && retryableMalformed(error)) continue;
      throw error;
    }
  }
  throw new Error("provider-malformed-response");
}

async function generateCriticWithOneMalformedRetry(provider: MonthlyStoryTextProvider,
  limits: MonthlyStoryEvaluationLimits, request: MonthlyStoryTextProviderRequest):
Promise<MonthlyStoryCriticResult> {
  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      return parseMonthlyStoryCriticResult(await generate(provider, limits, request));
    } catch (error) {
      if (attempt === 0 && retryableMalformed(error)) continue;
      throw error;
    }
  }
  throw new Error("provider-malformed-response");
}

function validate(output: MonthlyStoryWriterOutput, signal: ReturnType<typeof parseMonthlyStorySignal>,
  prompt: MonthlyStoryPromptInput): MonthlyStoryScriptValidationResult {
  return validateMonthlyStoryScript({ script: output.script, claimedEvidenceIds: output.claimedEvidenceIds,
    claimKeys: output.claimKeys, plan: prompt.plan, availableEvidence: signal.evidence });
}

function rubric(critic: MonthlyStoryCriticResult): MonthlyStoryEvaluationRubric {
  return { evidenceAlignment: critic.scores.evidenceAlignment,
    unsupportedDetailAvoidance: critic.scores.unsupportedCertainty,
    naturalSpokenEnglish: Math.min(critic.scores.naturalness, critic.scores.spokenLanguage),
    warmth: critic.scores.warmth, nonClinicalTone: critic.scores.clinicalTone,
    nonAnalyticalTone: critic.scores.reportTone, nonMotivationalTone: critic.scores.motivationalTone,
    lackOfAppLanguage: critic.scores.reportTone, emotionalCoherence: critic.scores.monthReflection,
    recommendationWording: critic.scores.evidenceAlignment,
    suggestionUsefulness: critic.scores.suggestionUsefulness, repetition: critic.scores.repetition };
}

function hardFailures(validation: MonthlyStoryScriptValidationResult): string[] {
  return [...validation.errors];
}

function failureResult(id: MonthlyStoryEvaluationFixtureId, code: string, startRequestCount: number,
  limits: MonthlyStoryEvaluationLimits, startSpend: number, usage: MonthlyStoryProviderUsage[]):
  MonthlyStoryFixtureEvaluation {
  const stageCost = (stage: MonthlyStoryPromptKind): number => usage.filter((item) =>
    item.requestStage === stage).reduce((sum, item) => sum + item.estimatedCostMicros, 0);
  const observedCost = usage.reduce((sum, item) => sum + item.estimatedCostMicros, 0);
  return { fixtureId: id, synthetic: true, passed: false, hardFailureCodes: [code], script: null,
    wordCount: 0, estimatedSpokenSeconds: 0, validation: null, critic: null, repaired: false,
    secondCriticPassed: false, rubric: null, writerCostMicros: stageCost("writer"),
    criticCostMicros: stageCost("critic"), repairCostMicros: stageCost("repair"),
    totalCostMicros: usage.length > 0 ? observedCost : limits.actualSpendMicros - startSpend,
    latencyMillis: usage.reduce((sum, item) => sum + item.latencyMillis, 0),
    requestCount: limits.requestCount - startRequestCount, failureCode: code };
}

export async function evaluateMonthlyStorySyntheticFixture(id: MonthlyStoryEvaluationFixtureId,
  provider: MonthlyStoryTextProvider, limits: MonthlyStoryEvaluationLimits,
  configValue: unknown = MONTHLY_STORY_EVALUATION_MODEL_CONFIG): Promise<MonthlyStoryFixtureEvaluation> {
  const config = parseMonthlyStoryModelConfig(configValue);
  const startRequestCount = limits.requestCount;
  const startSpend = limits.actualSpendMicros;
  const usageProvider = provider as MonthlyStoryTextProvider & { usageRecords?: () => MonthlyStoryProviderUsage[] };
  const startUsageCount = usageProvider.usageRecords?.().length ?? 0;
  try {
    const prepared = promptInput(approvedMonthlyStoryEvaluationFixture(id), config);
    const writerPrompt = buildMonthlyStoryWriterPrompt(prepared.prompt);
    let output = await generateWriterWithOneMalformedRetry(provider, limits,
      requestFor("writer", writerPrompt, config));
    let validation = validate(output, prepared.signal, prepared.prompt);
    let critic: MonthlyStoryCriticResult | null = null;
    let repaired = false;
    let secondCriticPassed = false;
    let writerCost = output.syntheticCostMicros;
    let criticCost = 0;
    let repairCost = 0;
    const repair = async (criticErrors: readonly string[]): Promise<void> => {
      const repairPrompt = buildMonthlyStoryRepairPrompt({ ...prepared.prompt,
        promptVersion: config.repairPromptVersion }, output.script, validation.errors, criticErrors,
      output.claimedEvidenceIds, output.claimKeys);
      output = parseMonthlyStoryWriterOutput(await generate(provider, limits,
        requestFor("repair", repairPrompt, config)));
      repairCost += output.syntheticCostMicros;
      repaired = true;
      validation = validate(output, prepared.signal, prepared.prompt);
    };
    if (!validation.isValid && monthlyStoryValidationCanBeRepaired(validation)) {
      await repair([]);
    }
    if (validation.isValid) {
      const criticInput = { ...prepared.prompt, promptVersion: config.criticPromptVersion };
      critic = await generateCriticWithOneMalformedRetry(provider, limits,
        requestFor("critic", buildMonthlyStoryCriticPrompt(criticInput, output.script,
          output.claimedEvidenceIds, output.claimKeys), config));
      criticCost += critic.syntheticCostMicros;
      if (critic.decision === "repairable" && !repaired) {
        await repair(critic.reasons);
        if (validation.isValid) {
          const secondCritic = await generateCriticWithOneMalformedRetry(provider, limits,
            requestFor("critic", buildMonthlyStoryCriticPrompt(criticInput, output.script,
              output.claimedEvidenceIds, output.claimKeys), config));
          criticCost += secondCritic.syntheticCostMicros;
          critic = secondCritic;
          secondCriticPassed = secondCritic.decision === "pass";
        }
      } else if (repaired) {
        secondCriticPassed = critic.decision === "pass";
      }
    }
    const failures = hardFailures(validation);
    if (critic?.decision === "reject") failures.push("critic-reject");
    if (repaired && !secondCriticPassed) failures.push("second-critic-not-pass");
    if (!critic) failures.push("deterministic-validation-failed");
    if (validation.warnings.includes("belowPreferredWordRange") &&
        !(prepared.prompt.storyMode === "moodOnly" && critic?.decision === "pass")) {
      failures.push("outsidePreferredWordRange");
    }
    const usage = (usageProvider.usageRecords?.() ?? []).slice(startUsageCount);
    const stageCost = (stage: MonthlyStoryPromptKind): number => usage.filter((item) =>
      item.requestStage === stage).reduce((sum, item) => sum + item.estimatedCostMicros, 0);
    const observedCost = usage.reduce((sum, item) => sum + item.estimatedCostMicros, 0);
    const passed = failures.length === 0 && critic?.decision === "pass";
    return { fixtureId: id, synthetic: true, passed, hardFailureCodes: [...new Set(failures)],
      script: output.script, wordCount: validation.wordCount,
      estimatedSpokenSeconds: Math.round((validation.wordCount / 140) * 60), validation, critic,
      repaired, secondCriticPassed, rubric: critic ? rubric(critic) : null,
      writerCostMicros: usage.length > 0 ? stageCost("writer") : writerCost,
      criticCostMicros: usage.length > 0 ? stageCost("critic") : criticCost,
      repairCostMicros: usage.length > 0 ? stageCost("repair") : repairCost,
      totalCostMicros: usage.length > 0 ? observedCost : limits.actualSpendMicros - startSpend,
      latencyMillis: usage.reduce((sum, item) => sum + item.latencyMillis, 0),
      requestCount: limits.requestCount - startRequestCount, failureCode: passed ? null : failures[0] ?? "failed" };
  } catch (error) {
    const code = error instanceof Error ? error.message : "provider-failure";
    const usage = (usageProvider.usageRecords?.() ?? []).slice(startUsageCount);
    return failureResult(id, code, startRequestCount, limits, startSpend, usage);
  }
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : Math.round((sorted[middle - 1] + sorted[middle]) / 2);
}

export async function runMonthlyStorySyntheticEvaluation(options: MonthlyStoryEvaluationOptions,
  provider: MonthlyStoryTextProvider, configValue: unknown = MONTHLY_STORY_EVALUATION_MODEL_CONFIG):
Promise<MonthlyStoryEvaluationReport> {
  const config = parseMonthlyStoryModelConfig(configValue);
  const limits = new MonthlyStoryEvaluationLimits(options.maximumRequests, options.maximumSpendMicros, config);
  const results: MonthlyStoryFixtureEvaluation[] = [];
  for (const id of options.fixtureIds) {
    if (limits.actualSpendMicros >= options.maximumSpendMicros) break;
    results.push(await evaluateMonthlyStorySyntheticFixture(id, provider, limits, config));
  }
  const costs = results.map((result) => result.totalCostMicros);
  const latencies = results.map((result) => result.latencyMillis);
  const averageCost = costs.length ? Math.round(costs.reduce((sum, value) => sum + value, 0) / costs.length) : 0;
  const usageProvider = provider as MonthlyStoryTextProvider & { usageRecords?: () => MonthlyStoryProviderUsage[] };
  const usage = usageProvider.usageRecords?.() ?? [];
  const observedSpend = usage.length > 0 ? usage.reduce((sum, item) => sum + item.estimatedCostMicros, 0) :
    limits.actualSpendMicros;
  return { label: "SYNTHETIC MONTHLY STORY EVALUATION", generatedAt: new Date().toISOString(),
    configurationVersion: config.configurationVersion,
    pricingConfigurationVersion: config.pricingConfigurationVersion, writerModel: config.writerModel,
    criticModel: config.criticModel, maximumRequests: options.maximumRequests,
    maximumSpendMicros: options.maximumSpendMicros, results,
    aggregate: { passed: results.filter((result) => result.passed).length,
      failed: results.filter((result) => !result.passed).length, requestCount: limits.requestCount,
      averageCostMicros: averageCost, medianCostMicros: median(costs), maximumCostMicros: Math.max(0, ...costs),
      averageLatencyMillis: latencies.length ? Math.round(latencies.reduce((sum, value) => sum + value, 0) /
        latencies.length) : 0, totalSpendMicros: observedSpend,
      projectedTextOnlyCostMicros: { users100: averageCost * 100, users1000: averageCost * 1_000,
        users2700: averageCost * 2_700 } }, usage };
}

export async function writeMonthlyStorySyntheticEvaluationReport(report: MonthlyStoryEvaluationReport,
  directory = path.resolve(__dirname, "../../.local/monthly-story-evaluation")): Promise<void> {
  await mkdir(directory, { recursive: true });
  await writeFile(path.join(directory, "synthetic-evaluation-report.json"),
    `${JSON.stringify(report, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
  for (const result of report.results) {
    if (result.script !== null) await writeFile(path.join(directory, `${result.fixtureId}.synthetic.txt`),
      `SYNTHETIC MONTHLY STORY — ${result.fixtureId}\n\n${result.script}\n`,
      { encoding: "utf8", mode: 0o600 });
  }
}

function preflight(options: MonthlyStoryEvaluationOptions, config: MonthlyStoryModelConfig): string {
  return JSON.stringify({ stage: "monthly-story-synthetic-preflight", writerModel: config.writerModel,
    criticModel: config.criticModel, fixtureCount: options.fixtureIds.length,
    maximumRequests: options.maximumRequests, maximumSpendUSD: options.maximumSpendMicros / 1_000_000,
    allFixturesSynthetic: true, firebaseOrUserDataAccess: false, live: options.live });
}

async function main(): Promise<void> {
  try {
    const options = parseMonthlyStoryEvaluationArguments(process.argv.slice(2));
    const config = parseMonthlyStoryModelConfig(MONTHLY_STORY_EVALUATION_MODEL_CONFIG);
    process.stdout.write(`${preflight(options, config)}\n`);
    if (!options.live) return;
    const apiKey = requireMonthlyStoryEvaluationApiKey(process.env);
    const client = await createMonthlyStoryOpenAIClient(apiKey);
    const provider = new MonthlyStoryOpenAIProvider(client, config);
    const report = await runMonthlyStorySyntheticEvaluation(options, provider, config);
    await writeMonthlyStorySyntheticEvaluationReport(report);
    process.stdout.write(`${JSON.stringify({ stage: "monthly-story-synthetic-complete",
      status: "complete", fixtureCount: report.results.length, passed: report.aggregate.passed,
      failed: report.aggregate.failed, requestCount: report.aggregate.requestCount,
      totalSpendMicros: report.aggregate.totalSpendMicros })}\n`);
  } catch (error) {
    const code = error instanceof Error ? error.message : "evaluation-failed";
    process.stderr.write(`${JSON.stringify({ stage: "monthly-story-synthetic-evaluation", status: "failed",
      errorCode: code })}\n`);
    process.exitCode = 1;
  }
}

if (require.main === module) void main();
