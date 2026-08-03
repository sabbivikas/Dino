import { MonthlyStoryPromptKind } from "./monthlyStoryPrompts";

export const MONTHLY_STORY_SUPPORTED_OPENAI_MODELS = [
  "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna",
] as const;
export type MonthlyStoryOpenAIModel = typeof MONTHLY_STORY_SUPPORTED_OPENAI_MODELS[number];
export type MonthlyStoryReasoningEffort = "none" | "low" | "medium" | "high";

export type MonthlyStoryModelConfig = {
  configurationVersion: string;
  writerModel: MonthlyStoryOpenAIModel;
  criticModel: MonthlyStoryOpenAIModel;
  writerTimeoutMillis: number;
  criticTimeoutMillis: number;
  repairTimeoutMillis: number;
  writerInputTokenCap: number;
  writerOutputTokenCap: number;
  criticInputTokenCap: number;
  criticOutputTokenCap: number;
  repairInputTokenCap: number;
  repairOutputTokenCap: number;
  writerReasoningEffort: MonthlyStoryReasoningEffort;
  criticReasoningEffort: MonthlyStoryReasoningEffort;
  repairReasoningEffort: MonthlyStoryReasoningEffort;
  writerPromptVersion: string;
  criticPromptVersion: string;
  repairPromptVersion: string;
  pricingConfigurationVersion: string;
  writerInputCostMicrosPerMillionTokens: number;
  writerCachedInputCostMicrosPerMillionTokens: number;
  writerOutputCostMicrosPerMillionTokens: number;
  criticInputCostMicrosPerMillionTokens: number;
  criticCachedInputCostMicrosPerMillionTokens: number;
  criticOutputCostMicrosPerMillionTokens: number;
};

export const MONTHLY_STORY_EVALUATION_MODEL_CONFIG: MonthlyStoryModelConfig = Object.freeze({
  configurationVersion: "openai-evaluation-v4",
  writerModel: "gpt-5.6-terra",
  criticModel: "gpt-5.6-luna",
  writerTimeoutMillis: 30_000,
  criticTimeoutMillis: 20_000,
  repairTimeoutMillis: 30_000,
  writerInputTokenCap: 4_000,
  writerOutputTokenCap: 1_400,
  criticInputTokenCap: 5_500,
  criticOutputTokenCap: 600,
  repairInputTokenCap: 5_500,
  repairOutputTokenCap: 1_400,
  writerReasoningEffort: "low",
  criticReasoningEffort: "low",
  repairReasoningEffort: "low",
  writerPromptVersion: "writer-v4",
  criticPromptVersion: "critic-v4",
  repairPromptVersion: "writer-v4",
  pricingConfigurationVersion: "openai-standard-2026-08-02-v2",
  writerInputCostMicrosPerMillionTokens: 2_500_000,
  writerCachedInputCostMicrosPerMillionTokens: 250_000,
  writerOutputCostMicrosPerMillionTokens: 15_000_000,
  criticInputCostMicrosPerMillionTokens: 1_000_000,
  criticCachedInputCostMicrosPerMillionTokens: 100_000,
  criticOutputCostMicrosPerMillionTokens: 6_000_000,
});

const FIELDS: readonly (keyof MonthlyStoryModelConfig)[] = [
  "configurationVersion", "writerModel", "criticModel", "writerTimeoutMillis", "criticTimeoutMillis",
  "repairTimeoutMillis", "writerInputTokenCap", "writerOutputTokenCap", "criticInputTokenCap",
  "criticOutputTokenCap", "repairInputTokenCap", "repairOutputTokenCap", "writerReasoningEffort",
  "criticReasoningEffort", "repairReasoningEffort", "writerPromptVersion", "criticPromptVersion",
  "repairPromptVersion", "pricingConfigurationVersion", "writerInputCostMicrosPerMillionTokens",
  "writerCachedInputCostMicrosPerMillionTokens", "writerOutputCostMicrosPerMillionTokens",
  "criticInputCostMicrosPerMillionTokens", "criticCachedInputCostMicrosPerMillionTokens",
  "criticOutputCostMicrosPerMillionTokens",
];

function isToken(value: unknown, maximum = 64): value is string {
  return typeof value === "string" && new RegExp(`^[A-Za-z0-9._-]{1,${maximum}}$`).test(value);
}

export function parseMonthlyStoryModelConfig(value: unknown): MonthlyStoryModelConfig {
  if (typeof value !== "object" || value === null || Array.isArray(value)) throw new Error("invalid-model-config");
  const data = value as Record<string, unknown>;
  if (Object.keys(data).length !== FIELDS.length || Object.keys(data).some((key) =>
    !FIELDS.includes(key as keyof MonthlyStoryModelConfig))) throw new Error("invalid-model-config");
  if (!isToken(data.configurationVersion) || !isToken(data.writerPromptVersion, 32) ||
      !isToken(data.criticPromptVersion, 32) || !isToken(data.repairPromptVersion, 32) ||
      !isToken(data.pricingConfigurationVersion) ||
      !(MONTHLY_STORY_SUPPORTED_OPENAI_MODELS as readonly unknown[]).includes(data.writerModel) ||
      !(MONTHLY_STORY_SUPPORTED_OPENAI_MODELS as readonly unknown[]).includes(data.criticModel)) {
    throw new Error("invalid-model-config");
  }
  const timeoutFields = ["writerTimeoutMillis", "criticTimeoutMillis", "repairTimeoutMillis"] as const;
  const tokenFields = ["writerInputTokenCap", "writerOutputTokenCap", "criticInputTokenCap",
    "criticOutputTokenCap", "repairInputTokenCap", "repairOutputTokenCap"] as const;
  const priceFields = ["writerInputCostMicrosPerMillionTokens", "writerOutputCostMicrosPerMillionTokens",
    "writerCachedInputCostMicrosPerMillionTokens", "criticInputCostMicrosPerMillionTokens",
    "criticCachedInputCostMicrosPerMillionTokens", "criticOutputCostMicrosPerMillionTokens"] as const;
  if (timeoutFields.some((field) => !Number.isSafeInteger(data[field]) || (data[field] as number) < 1_000 ||
      (data[field] as number) > 120_000) || tokenFields.some((field) => !Number.isSafeInteger(data[field]) ||
      (data[field] as number) < 64 || (data[field] as number) > 50_000) ||
      priceFields.some((field) => !Number.isSafeInteger(data[field]) || (data[field] as number) < 0 ||
      (data[field] as number) > 500_000_000)) throw new Error("invalid-model-config");
  const efforts = [data.writerReasoningEffort, data.criticReasoningEffort, data.repairReasoningEffort];
  if (efforts.some((effort) => !["none", "low", "medium", "high"].includes(String(effort)))) {
    throw new Error("invalid-model-config");
  }
  return structuredClone(data) as MonthlyStoryModelConfig;
}

export type MonthlyStoryOperationConfig = { model: MonthlyStoryOpenAIModel; timeoutMillis: number;
  inputTokenCap: number; outputTokenCap: number; reasoningEffort: MonthlyStoryReasoningEffort;
  promptVersion: string; inputCostMicrosPerMillionTokens: number;
  cachedInputCostMicrosPerMillionTokens: number; outputCostMicrosPerMillionTokens: number };

export function monthlyStoryOperationConfig(configValue: unknown,
  operation: MonthlyStoryPromptKind): MonthlyStoryOperationConfig {
  const config = parseMonthlyStoryModelConfig(configValue);
  if (operation === "critic") return { model: config.criticModel, timeoutMillis: config.criticTimeoutMillis,
    inputTokenCap: config.criticInputTokenCap, outputTokenCap: config.criticOutputTokenCap,
    reasoningEffort: config.criticReasoningEffort, promptVersion: config.criticPromptVersion,
    inputCostMicrosPerMillionTokens: config.criticInputCostMicrosPerMillionTokens,
    cachedInputCostMicrosPerMillionTokens: config.criticCachedInputCostMicrosPerMillionTokens,
    outputCostMicrosPerMillionTokens: config.criticOutputCostMicrosPerMillionTokens };
  if (operation === "repair") return { model: config.writerModel, timeoutMillis: config.repairTimeoutMillis,
    inputTokenCap: config.repairInputTokenCap, outputTokenCap: config.repairOutputTokenCap,
    reasoningEffort: config.repairReasoningEffort, promptVersion: config.repairPromptVersion,
    inputCostMicrosPerMillionTokens: config.writerInputCostMicrosPerMillionTokens,
    cachedInputCostMicrosPerMillionTokens: config.writerCachedInputCostMicrosPerMillionTokens,
    outputCostMicrosPerMillionTokens: config.writerOutputCostMicrosPerMillionTokens };
  return { model: config.writerModel, timeoutMillis: config.writerTimeoutMillis,
    inputTokenCap: config.writerInputTokenCap, outputTokenCap: config.writerOutputTokenCap,
    reasoningEffort: config.writerReasoningEffort, promptVersion: config.writerPromptVersion,
    inputCostMicrosPerMillionTokens: config.writerInputCostMicrosPerMillionTokens,
    cachedInputCostMicrosPerMillionTokens: config.writerCachedInputCostMicrosPerMillionTokens,
    outputCostMicrosPerMillionTokens: config.writerOutputCostMicrosPerMillionTokens };
}

export function monthlyStoryEstimatedCostMicros(inputTokens: number, outputTokens: number,
  operation: MonthlyStoryPromptKind, configValue: unknown, cachedInputTokens = 0): number {
  if (!Number.isSafeInteger(inputTokens) || inputTokens < 0 || !Number.isSafeInteger(outputTokens) ||
      outputTokens < 0 || !Number.isSafeInteger(cachedInputTokens) || cachedInputTokens < 0 ||
      cachedInputTokens > inputTokens) throw new Error("invalid-token-usage");
  const config = monthlyStoryOperationConfig(configValue, operation);
  const uncachedInputTokens = inputTokens - cachedInputTokens;
  const numerator = uncachedInputTokens * config.inputCostMicrosPerMillionTokens +
    cachedInputTokens * config.cachedInputCostMicrosPerMillionTokens +
    outputTokens * config.outputCostMicrosPerMillionTokens;
  if (!Number.isSafeInteger(numerator)) throw new Error("cost-overflow");
  return Math.ceil(numerator / 1_000_000);
}

export function monthlyStoryMaximumRequestCostMicros(operation: MonthlyStoryPromptKind,
  configValue: unknown): number {
  const config = monthlyStoryOperationConfig(configValue, operation);
  return monthlyStoryEstimatedCostMicros(config.inputTokenCap, config.outputTokenCap, operation, configValue);
}
