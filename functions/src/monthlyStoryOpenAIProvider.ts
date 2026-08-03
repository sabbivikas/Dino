import { MONTHLY_STORY_CRITIC_REASON_CODES } from "./monthlyStoryCritic";
import { MonthlyStoryModelConfig, monthlyStoryEstimatedCostMicros,
  monthlyStoryOperationConfig, parseMonthlyStoryModelConfig } from "./monthlyStoryModelConfig";
import { MonthlyStoryPromptKind } from "./monthlyStoryPrompts";
import { MonthlyStoryTextProvider, MonthlyStoryTextProviderRequest } from "./monthlyStoryTextProvider";

export type MonthlyStoryOpenAIProviderErrorCode = "provider-timeout" | "provider-refusal" |
  "provider-rate-limit" | "provider-authentication" | "provider-malformed-response" |
  "provider-input-too-large" | "provider-output-truncated" | "provider-token-limit" | "provider-failure";

export class MonthlyStoryOpenAIProviderError extends Error {
  constructor(readonly code: MonthlyStoryOpenAIProviderErrorCode) {
    super(code);
    this.name = "MonthlyStoryOpenAIProviderError";
  }
}

export type MonthlyStoryProviderUsage = {
  requestStage: MonthlyStoryPromptKind;
  modelIdentifier: string;
  inputTokens: number;
  cachedInputTokens: number;
  outputTokens: number;
  reasoningOutputTokens: number;
  billingBasis: "reported-usage" | "reserved-maximum";
  latencyMillis: number;
  estimatedCostMicros: number;
};

type OpenAIResponseLike = {
  status?: string;
  incomplete_details?: { reason?: string } | null;
  output_text?: string;
  output?: unknown[];
  usage?: { input_tokens?: number; output_tokens?: number;
    input_tokens_details?: { cached_tokens?: number } | null;
    output_tokens_details?: { reasoning_tokens?: number } | null } | null;
};

export interface MonthlyStoryOpenAIResponsesClient {
  responses: { create(parameters: Record<string, unknown>, options?: Record<string, unknown>):
    Promise<OpenAIResponseLike> };
}

function exactClaims(prompt: MonthlyStoryTextProviderRequest["prompt"]):
{ evidenceIds: string[]; claimKeys: string[] } {
  const claims = prompt.payload.claims;
  if (!Array.isArray(claims) || claims.length < 1 || claims.length > 32) {
    throw new MonthlyStoryOpenAIProviderError("provider-malformed-response");
  }
  const evidenceIds: string[] = [];
  const claimKeys: string[] = [];
  for (const value of claims) {
    if (typeof value !== "object" || value === null || Array.isArray(value)) {
      throw new MonthlyStoryOpenAIProviderError("provider-malformed-response");
    }
    const claim = value as Record<string, unknown>;
    if (typeof claim.evidenceId !== "string" || typeof claim.key !== "string" ||
        !/^[A-Za-z0-9._-]{1,64}$/.test(claim.evidenceId) || !/^[A-Za-z0-9._-]{1,64}$/.test(claim.key)) {
      throw new MonthlyStoryOpenAIProviderError("provider-malformed-response");
    }
    evidenceIds.push(claim.evidenceId);
    claimKeys.push(claim.key);
  }
  return { evidenceIds: [...new Set(evidenceIds)], claimKeys: [...new Set(claimKeys)] };
}

function writerSchema(request: MonthlyStoryTextProviderRequest): Record<string, unknown> {
  const claims = exactClaims(request.prompt);
  return { type: "object", additionalProperties: false,
    properties: {
      script: { type: "string", minLength: 1, maxLength: 2_400 },
      claimedEvidenceIds: { type: "array", maxItems: claims.evidenceIds.length,
        items: { type: "string", enum: claims.evidenceIds } },
      claimKeys: { type: "array", maxItems: claims.claimKeys.length,
        items: { type: "string", enum: claims.claimKeys } },
    },
    required: ["script", "claimedEvidenceIds", "claimKeys"] };
}

function criticSchema(): Record<string, unknown> {
  const scoreFields = ["naturalness", "evidenceAlignment", "unsupportedCertainty", "repetition",
    "clinicalTone", "motivationalTone", "reportTone", "warmth", "suggestionUsefulness",
    "monthReflection", "spokenLanguage"];
  return { type: "object", additionalProperties: false,
    properties: {
      decision: { type: "string", enum: ["pass", "repairable", "reject"] },
      reasons: { type: "array", items: { type: "string", enum: MONTHLY_STORY_CRITIC_REASON_CODES } },
      scores: { type: "object", additionalProperties: false,
        properties: Object.fromEntries(scoreFields.map((field) =>
          [field, { type: "integer", minimum: 1, maximum: 5 }])), required: scoreFields },
    },
    required: ["decision", "reasons", "scores"] };
}

function containsRefusal(output: unknown): boolean {
  if (!Array.isArray(output)) return false;
  const visit = (value: unknown): boolean => {
    if (Array.isArray(value)) return value.some(visit);
    if (typeof value !== "object" || value === null) return false;
    const record = value as Record<string, unknown>;
    return record.type === "refusal" || Object.values(record).some(visit);
  };
  return output.some(visit);
}

function safeUsage(response: OpenAIResponseLike): { inputTokens: number; cachedInputTokens: number;
  outputTokens: number; reasoningOutputTokens: number } {
  const inputTokens = response.usage?.input_tokens;
  const outputTokens = response.usage?.output_tokens;
  const cachedInputTokens = response.usage?.input_tokens_details?.cached_tokens ?? 0;
  const reasoningOutputTokens = response.usage?.output_tokens_details?.reasoning_tokens ?? 0;
  if (!Number.isSafeInteger(inputTokens) || (inputTokens as number) < 0 ||
      !Number.isSafeInteger(outputTokens) || (outputTokens as number) < 0 ||
      !Number.isSafeInteger(cachedInputTokens) || cachedInputTokens < 0 ||
      cachedInputTokens > (inputTokens as number) || !Number.isSafeInteger(reasoningOutputTokens) ||
      reasoningOutputTokens < 0 || reasoningOutputTokens > (outputTokens as number)) {
    throw new MonthlyStoryOpenAIProviderError("provider-malformed-response");
  }
  return { inputTokens: inputTokens as number, cachedInputTokens, outputTokens: outputTokens as number,
    reasoningOutputTokens };
}

function mappedError(error: unknown): MonthlyStoryOpenAIProviderError {
  if (error instanceof MonthlyStoryOpenAIProviderError) return error;
  if (typeof error === "object" && error !== null) {
    const value = error as Record<string, unknown>;
    const name = String(value.name ?? "").toLowerCase();
    const code = String(value.code ?? "").toLowerCase();
    const status = value.status;
    if (name.includes("timeout") || name === "aborterror" || code === "etimedout") {
      return new MonthlyStoryOpenAIProviderError("provider-timeout");
    }
    if (status === 429 || code === "rate_limit_exceeded") {
      return new MonthlyStoryOpenAIProviderError("provider-rate-limit");
    }
    if (status === 401 || status === 403 || code === "invalid_api_key") {
      return new MonthlyStoryOpenAIProviderError("provider-authentication");
    }
  }
  return new MonthlyStoryOpenAIProviderError("provider-failure");
}

export class MonthlyStoryOpenAIProvider implements MonthlyStoryTextProvider {
  private readonly config: MonthlyStoryModelConfig;
  private readonly usage: MonthlyStoryProviderUsage[] = [];

  constructor(private readonly client: MonthlyStoryOpenAIResponsesClient, configValue: unknown,
    private readonly nowMillis: () => number = Date.now) {
    this.config = parseMonthlyStoryModelConfig(configValue);
  }

  usageRecords(): MonthlyStoryProviderUsage[] {
    return structuredClone(this.usage);
  }

  async generate(request: MonthlyStoryTextProviderRequest): Promise<unknown> {
    const operation = monthlyStoryOperationConfig(this.config, request.operation);
    if (request.operation !== request.prompt.kind || request.modelSnapshot !== operation.model ||
        request.promptVersion !== operation.promptVersion || request.timeoutMillis !== operation.timeoutMillis ||
        request.maximumInputTokens !== operation.inputTokenCap ||
        request.maximumOutputTokens !== operation.outputTokenCap) {
      throw new MonthlyStoryOpenAIProviderError("provider-failure");
    }
    const serializedInput = JSON.stringify({ syntheticMonthlyStoryFixture: true, payload: request.prompt.payload });
    const estimatedInputTokens = Math.ceil((Buffer.byteLength(request.prompt.system, "utf8") +
      Buffer.byteLength(serializedInput, "utf8")) / 3);
    if (estimatedInputTokens > operation.inputTokenCap) {
      throw new MonthlyStoryOpenAIProviderError("provider-input-too-large");
    }
    const startedAt = this.nowMillis();
    try {
      const response = await this.client.responses.create({
        model: operation.model,
        instructions: request.prompt.system,
        input: serializedInput,
        max_output_tokens: operation.outputTokenCap,
        reasoning: { effort: operation.reasoningEffort },
        text: { format: { type: "json_schema", name: `monthly_story_${request.operation}_v2`, strict: true,
          schema: request.operation === "critic" ? criticSchema() : writerSchema(request) } },
        store: false,
      }, { timeout: operation.timeoutMillis, maxRetries: 0 });
      let usage: ReturnType<typeof safeUsage>;
      try {
        usage = safeUsage(response);
      } catch (error) {
        const estimatedCostMicros = monthlyStoryEstimatedCostMicros(operation.inputTokenCap,
          operation.outputTokenCap, request.operation, this.config);
        this.usage.push({ requestStage: request.operation, modelIdentifier: operation.model,
          inputTokens: operation.inputTokenCap, cachedInputTokens: 0, outputTokens: operation.outputTokenCap,
          reasoningOutputTokens: 0, billingBasis: "reserved-maximum",
          latencyMillis: Math.max(0, this.nowMillis() - startedAt), estimatedCostMicros });
        throw error;
      }
      const estimatedCostMicros = monthlyStoryEstimatedCostMicros(usage.inputTokens, usage.outputTokens,
        request.operation, this.config, usage.cachedInputTokens);
      this.usage.push({ requestStage: request.operation, modelIdentifier: operation.model,
        inputTokens: usage.inputTokens, cachedInputTokens: usage.cachedInputTokens,
        outputTokens: usage.outputTokens, reasoningOutputTokens: usage.reasoningOutputTokens,
        billingBasis: "reported-usage", latencyMillis: Math.max(0, this.nowMillis() - startedAt),
        estimatedCostMicros });
      if (containsRefusal(response.output)) {
        throw new MonthlyStoryOpenAIProviderError("provider-refusal");
      }
      if (response.status === "incomplete" || response.incomplete_details?.reason === "max_output_tokens") {
        throw new MonthlyStoryOpenAIProviderError("provider-output-truncated");
      }
      if (response.status !== undefined && response.status !== "completed") {
        throw new MonthlyStoryOpenAIProviderError("provider-malformed-response");
      }
      if (typeof response.output_text !== "string" || response.output_text.length < 2 ||
          response.output_text.length > 20_000) {
        throw new MonthlyStoryOpenAIProviderError(usage.outputTokens >= operation.outputTokenCap ?
          "provider-output-truncated" : "provider-malformed-response");
      }
      if (usage.inputTokens > operation.inputTokenCap || usage.outputTokens > operation.outputTokenCap) {
        throw new MonthlyStoryOpenAIProviderError("provider-token-limit");
      }
      let parsed: unknown;
      try {
        parsed = JSON.parse(response.output_text);
      } catch {
        throw new MonthlyStoryOpenAIProviderError(usage.outputTokens >= operation.outputTokenCap ?
          "provider-output-truncated" : "provider-malformed-response");
      }
      if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
        throw new MonthlyStoryOpenAIProviderError("provider-malformed-response");
      }
      return { ...(parsed as Record<string, unknown>), syntheticCostMicros: estimatedCostMicros };
    } catch (error) {
      throw mappedError(error);
    }
  }
}

export async function createMonthlyStoryOpenAIClient(apiKey: string):
Promise<MonthlyStoryOpenAIResponsesClient> {
  if (typeof apiKey !== "string" || apiKey.length < 20 || /\s/.test(apiKey)) {
    throw new MonthlyStoryOpenAIProviderError("provider-authentication");
  }
  const module = await import("openai");
  return new module.default({ apiKey, maxRetries: 0 }) as unknown as MonthlyStoryOpenAIResponsesClient;
}
