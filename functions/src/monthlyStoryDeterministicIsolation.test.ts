import assert from "node:assert";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { MONTHLY_STORY_CLAIM_KEYS, MONTHLY_STORY_FORBIDDEN_CLAIM_EXAMPLES } from
  "./monthlyStoryClaims";
import { monthlyStoryPhraseSet } from "./monthlyStoryPhraseLibrary";

const root = join(__dirname, "..", "..");
const deterministicFiles = ["monthlyStoryPhraseLibrary.ts", "monthlyStoryDeterministicComposer.ts"];
const source = (file: string): string => readFileSync(join(root, "functions", "src", file), "utf8");

test("every closed claim has auditable deterministic variants and excludes forbidden mappings", () => {
  for (const key of MONTHLY_STORY_CLAIM_KEYS) {
    const set = monthlyStoryPhraseSet(key);
    assert.ok(set.core.length >= 2, `${key}:core`);
    assert.ok(set.support.length >= 2, `${key}:support`);
    const combined = [...set.core, ...set.support, ...set.transition].join(" ").toLowerCase();
    for (const forbidden of MONTHLY_STORY_FORBIDDEN_CLAIM_EXAMPLES[
      key as keyof typeof MONTHLY_STORY_FORBIDDEN_CLAIM_EXAMPLES] ?? []) {
      assert.equal(combined.includes(forbidden.toLowerCase()), false, `${key}:${forbidden}`);
    }
  }
});

test("deterministic writer is unreachable from index and has no provider, network, Firebase, or logging code", () => {
  const index = source("index.ts");
  for (const file of deterministicFiles) assert.equal(index.includes(file.replace(/\.ts$/, "")), false, file);
  const combined = deterministicFiles.map(source).join("\n");
  for (const prohibited of ["from \"openai\"", "import(\"openai\")", "fetch(", "axios", "https://",
    "http://", "firebase-admin", "firebase-functions", "getFirestore(", "getStorage(", "onCall(",
    "onSchedule(", "defineSecret", "defineString", "process.env", "console.log", "logger."]) {
    assert.equal(combined.includes(prohibited), false, prohibited);
  }
});

test("deterministic writer contains no secrets, provider models, raw private fields, or UID logging", () => {
  const combined = deterministicFiles.map(source).join("\n");
  assert.doesNotMatch(combined, /sk-[A-Za-z0-9_-]{16,}/);
  for (const prohibited of ["gpt-", "OPENAI_API_KEY", "journalText", "gratitudeText", "healthSamples",
    "recommendationTitle", "email", "deviceId", "console.", "logger."]) {
    assert.equal(combined.includes(prohibited), false, prohibited);
  }
});
