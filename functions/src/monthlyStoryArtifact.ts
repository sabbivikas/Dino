import { createHash } from "crypto";
import { MonthlyStoryScriptValidationResult } from "./monthlyStoryScriptValidator";
import { requireGenerationVersion, requireMonthKey } from "./monthlyStorySchema";

export type MonthlyStoryTextArtifact = {
  monthKey: string;
  generationVersion: string;
  promptVersion: string;
  criticVersion: string;
  language: "en";
  script: string;
  wordCount: number;
  usedEvidenceIds: string[];
  scriptHash: string;
  status: "textReady";
  textAttemptCount: number;
  validation: { isValid: true; errors: [] };
  createdAtMillis: number;
  expiresAtMillis: number;
};

function version(value: string): string {
  if (!/^[A-Za-z0-9._-]{1,32}$/.test(value)) throw new Error("invalid-artifact-version");
  return value;
}

export function monthlyStoryScriptHash(script: string): string {
  return createHash("sha256").update(script, "utf8").digest("hex");
}

export function createMonthlyStoryTextArtifact(input: { monthKey: string; generationVersion: string;
  promptVersion: string; criticVersion: string; language: "en"; script: string;
  usedEvidenceIds: string[]; textAttemptCount: number; validation: MonthlyStoryScriptValidationResult;
  createdAtMillis: number; expiresAtMillis: number }): MonthlyStoryTextArtifact {
  if (!input.validation.isValid || input.validation.errors.length !== 0 ||
      input.validation.wordCount < 220 || input.validation.wordCount > 290 ||
      !Number.isSafeInteger(input.textAttemptCount) || input.textAttemptCount < 1 || input.textAttemptCount > 2 ||
      !Number.isSafeInteger(input.createdAtMillis) || !Number.isSafeInteger(input.expiresAtMillis) ||
      input.createdAtMillis < 0 || input.expiresAtMillis <= input.createdAtMillis ||
      input.usedEvidenceIds.length < 1 || input.usedEvidenceIds.length > 32 ||
      new Set(input.usedEvidenceIds).size !== input.usedEvidenceIds.length ||
      input.usedEvidenceIds.some((id) => !/^[a-z0-9._-]{8,64}$/.test(id))) {
    throw new Error("invalid-text-artifact");
  }
  return {
    monthKey: requireMonthKey(input.monthKey), generationVersion: requireGenerationVersion(input.generationVersion),
    promptVersion: version(input.promptVersion), criticVersion: version(input.criticVersion), language: input.language,
    script: input.script, wordCount: input.validation.wordCount, usedEvidenceIds: [...input.usedEvidenceIds],
    scriptHash: monthlyStoryScriptHash(input.script), status: "textReady", textAttemptCount: input.textAttemptCount,
    validation: { isValid: true, errors: [] }, createdAtMillis: input.createdAtMillis,
    expiresAtMillis: input.expiresAtMillis,
  };
}
