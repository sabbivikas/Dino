import { test } from "node:test";
import assert from "node:assert";
import { MONTHLY_STORY_EVALUATION_MODEL_CONFIG, monthlyStoryEstimatedCostMicros,
  monthlyStoryMaximumRequestCostMicros, monthlyStoryOperationConfig,
  parseMonthlyStoryModelConfig } from "./monthlyStoryModelConfig";

test("model configuration is closed, versioned, and uses the approved writer and critic roles", () => {
  const parsed = parseMonthlyStoryModelConfig(MONTHLY_STORY_EVALUATION_MODEL_CONFIG);
  assert.equal(parsed.configurationVersion, "openai-evaluation-v4");
  assert.equal(parsed.writerModel, "gpt-5.6-terra");
  assert.equal(parsed.criticModel, "gpt-5.6-luna");
  assert.equal(parsed.writerPromptVersion, "writer-v4");
  assert.equal(parsed.criticPromptVersion, "critic-v4");
  assert.equal(parsed.repairPromptVersion, "writer-v4");
  assert.equal(monthlyStoryOperationConfig(parsed, "repair").model, parsed.writerModel);
  assert.equal(monthlyStoryOperationConfig(parsed, "critic").model, parsed.criticModel);
  assert.match(parsed.pricingConfigurationVersion, /^openai-standard-/);
});

test("missing, malformed, partial, unknown, and unsupported model configuration fails closed", () => {
  for (const value of [null, {}, { ...MONTHLY_STORY_EVALUATION_MODEL_CONFIG, writerModel: "unknown" },
    { ...MONTHLY_STORY_EVALUATION_MODEL_CONFIG, extra: true },
    { ...MONTHLY_STORY_EVALUATION_MODEL_CONFIG, writerTimeoutMillis: 0 },
    { ...MONTHLY_STORY_EVALUATION_MODEL_CONFIG, criticOutputTokenCap: 1 },
    { ...MONTHLY_STORY_EVALUATION_MODEL_CONFIG, writerInputCostMicrosPerMillionTokens: -1 }]) {
    assert.throws(() => parseMonthlyStoryModelConfig(value), /invalid-model-config/);
  }
});

test("versioned Terra and Luna pricing uses the verified standard rates", () => {
  const config = MONTHLY_STORY_EVALUATION_MODEL_CONFIG;
  assert.equal(config.pricingConfigurationVersion, "openai-standard-2026-08-02-v2");
  assert.equal(monthlyStoryEstimatedCostMicros(1_000_000, 0, "writer", config), 2_500_000);
  assert.equal(monthlyStoryEstimatedCostMicros(0, 1_000_000, "writer", config), 15_000_000);
  assert.equal(monthlyStoryEstimatedCostMicros(1_000_000, 0, "critic", config), 1_000_000);
  assert.equal(monthlyStoryEstimatedCostMicros(0, 1_000_000, "critic", config), 6_000_000);
  assert.equal(monthlyStoryEstimatedCostMicros(1_000, 500, "writer",
    config), 10_000);
  assert.equal(monthlyStoryEstimatedCostMicros(1_000, 500, "critic",
    config), 4_000);
});

test("cached input is discounted only when explicitly reported and rounding never undercharges", () => {
  const config = MONTHLY_STORY_EVALUATION_MODEL_CONFIG;
  assert.equal(monthlyStoryEstimatedCostMicros(1_000_000, 0, "writer", config, 1_000_000), 250_000);
  assert.equal(monthlyStoryEstimatedCostMicros(1_000_000, 0, "critic", config, 1_000_000), 100_000);
  assert.equal(monthlyStoryEstimatedCostMicros(1_000, 0, "writer", config), 2_500);
  assert.equal(monthlyStoryEstimatedCostMicros(1_000, 0, "writer", config, 250), 1_938);
  assert.equal(monthlyStoryEstimatedCostMicros(1, 0, "writer", config), 3);
  assert.equal(monthlyStoryEstimatedCostMicros(1, 0, "writer", config, 1), 1);
  assert.throws(() => monthlyStoryEstimatedCostMicros(-1, 1, "writer",
    config), /invalid-token-usage/);
  assert.throws(() => monthlyStoryEstimatedCostMicros(1, 1, "writer", config, 2),
    /invalid-token-usage/);
});

test("worst-case single-request reservations reflect the revised output caps", () => {
  const config = MONTHLY_STORY_EVALUATION_MODEL_CONFIG;
  const writer = monthlyStoryMaximumRequestCostMicros("writer", config);
  const critic = monthlyStoryMaximumRequestCostMicros("critic", config);
  const repair = monthlyStoryMaximumRequestCostMicros("repair", config);
  assert.equal(writer, 31_000);
  assert.equal(critic, 9_100);
  assert.equal(repair, 34_750);
});
