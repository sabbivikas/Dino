import { MonthlyStoryPrompt, MonthlyStoryPromptKind } from "./monthlyStoryPrompts";

export type MonthlyStoryTextProviderRequest = {
  operation: MonthlyStoryPromptKind;
  prompt: MonthlyStoryPrompt;
  modelSnapshot: string;
  promptVersion: string;
  timeoutMillis: number;
  maximumInputTokens: number;
  maximumOutputTokens: number;
};

export interface MonthlyStoryTextProvider {
  generate(request: MonthlyStoryTextProviderRequest): Promise<unknown>;
}

export type MonthlyStoryWriterOutput = {
  script: string;
  claimedEvidenceIds: string[];
  claimKeys: string[];
  syntheticCostMicros: number;
};

export class MonthlyStoryProviderError extends Error {
  constructor(readonly code: "provider-failure" | "provider-timeout" | "malformed-response") {
    super(code);
    this.name = "MonthlyStoryProviderError";
  }
}

function exactRecord(value: unknown, fields: readonly string[]): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new MonthlyStoryProviderError("malformed-response");
  }
  const record = value as Record<string, unknown>;
  if (Object.keys(record).length !== fields.length || Object.keys(record).some((key) => !fields.includes(key))) {
    throw new MonthlyStoryProviderError("malformed-response");
  }
  return record;
}

function tokenArray(value: unknown, maximum: number): string[] {
  if (!Array.isArray(value) || value.length > maximum || value.some((item) =>
    typeof item !== "string" || !/^[A-Za-z0-9._-]{1,64}$/.test(item))) {
    throw new MonthlyStoryProviderError("malformed-response");
  }
  const result = value as string[];
  if (new Set(result).size !== result.length) throw new MonthlyStoryProviderError("malformed-response");
  return [...result];
}

export function parseMonthlyStoryWriterOutput(value: unknown): MonthlyStoryWriterOutput {
  const data = exactRecord(value, ["script", "claimedEvidenceIds", "claimKeys", "syntheticCostMicros"]);
  if (typeof data.script !== "string" || data.script.length < 1 || data.script.length > 12_000 ||
      typeof data.syntheticCostMicros !== "number" || !Number.isSafeInteger(data.syntheticCostMicros) ||
      data.syntheticCostMicros < 0) throw new MonthlyStoryProviderError("malformed-response");
  return { script: data.script, claimedEvidenceIds: tokenArray(data.claimedEvidenceIds, 32),
    claimKeys: tokenArray(data.claimKeys, 32), syntheticCostMicros: data.syntheticCostMicros };
}

export class FakeMonthlyStoryTextProvider implements MonthlyStoryTextProvider {
  readonly calls: MonthlyStoryTextProviderRequest[] = [];
  private readonly responses: Map<MonthlyStoryPromptKind, unknown[]>;

  constructor(responses: Partial<Record<MonthlyStoryPromptKind, unknown | unknown[]>>) {
    this.responses = new Map(Object.entries(responses).map(([kind, value]) =>
      [kind as MonthlyStoryPromptKind, Array.isArray(value) ? [...value] : [value]]));
  }

  async generate(request: MonthlyStoryTextProviderRequest): Promise<unknown> {
    if (request.operation !== request.prompt.kind || request.promptVersion !== request.prompt.version ||
        !/^[A-Za-z0-9._-]{1,64}$/.test(request.modelSnapshot) ||
        !Number.isSafeInteger(request.timeoutMillis) || request.timeoutMillis < 1 ||
        !Number.isSafeInteger(request.maximumInputTokens) || request.maximumInputTokens < 1 ||
        !Number.isSafeInteger(request.maximumOutputTokens) || request.maximumOutputTokens < 1) {
      throw new MonthlyStoryProviderError("malformed-response");
    }
    this.calls.push(structuredClone(request));
    const queue = this.responses.get(request.operation);
    if (!queue || queue.length === 0) throw new MonthlyStoryProviderError("provider-failure");
    return structuredClone(queue.shift());
  }
}

export class FailureMonthlyStoryTextProvider implements MonthlyStoryTextProvider {
  readonly calls: MonthlyStoryTextProviderRequest[] = [];
  async generate(request: MonthlyStoryTextProviderRequest): Promise<unknown> {
    this.calls.push(structuredClone(request));
    throw new MonthlyStoryProviderError("provider-failure");
  }
}

export class MalformedMonthlyStoryTextProvider implements MonthlyStoryTextProvider {
  readonly calls: MonthlyStoryTextProviderRequest[] = [];
  async generate(request: MonthlyStoryTextProviderRequest): Promise<unknown> {
    this.calls.push(structuredClone(request));
    return { unstructured: true };
  }
}

export class TimeoutMonthlyStoryTextProvider implements MonthlyStoryTextProvider {
  readonly calls: MonthlyStoryTextProviderRequest[] = [];
  async generate(request: MonthlyStoryTextProviderRequest): Promise<unknown> {
    this.calls.push(structuredClone(request));
    throw new MonthlyStoryProviderError("provider-timeout");
  }
}
