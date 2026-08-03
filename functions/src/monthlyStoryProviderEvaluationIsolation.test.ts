import { test } from "node:test";
import assert from "node:assert";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { MONTHLY_STORY_APPROVED_EVALUATION_FIXTURE_IDS,
  approvedMonthlyStoryEvaluationFixture } from "./monthlyStorySyntheticEvaluationFixtures";
import { parseMonthlyStorySignal } from "./monthlyStorySchema";
import { buildMonthlyStoryNarrativePlan } from "./monthlyStoryNarrativePlan";

const root = join(__dirname, "..", "..");
const source = (file: string): string => readFileSync(join(root, "functions", "src", file), "utf8");
const productionFiles = ["monthlyStoryModelConfig.ts", "monthlyStoryOpenAIProvider.ts",
  "monthlyStorySyntheticEvaluationFixtures.ts", "monthlyStorySyntheticEvaluation.ts"];

test("Stage 5 remains unreachable and does not alter existing model routes", () => {
  const index = source("index.ts");
  for (const file of productionFiles) assert.equal(index.includes(file.replace(/\.ts$/, "")), false, file);
  const router = source("modelRouter.ts");
  assert.equal(router.includes("monthlyStoryOpenAIProvider"), false);
  assert.equal(router.includes("monthlyStorySyntheticEvaluation"), false);
});

test("only the isolated adapter imports the provider SDK and no Stage 5 module accesses Firebase", () => {
  for (const file of productionFiles) {
    const value = source(file);
    for (const prohibited of ["firebase-admin", "firebase-functions", "firestore()", "getFirestore(",
      "getStorage(", "onCall(", "onSchedule(", "PostHog", "Firecrawl", "TMDB", "EmailJS", "TTS"])
      assert.equal(value.includes(prohibited), false, `${file}:${prohibited}`);
    if (file !== "monthlyStoryOpenAIProvider.ts") {
      assert.equal(value.includes('import("openai")'), false, file);
      assert.equal(value.includes('from "openai"'), false, file);
    }
  }
});

test("provider and runner do not log prompts, scripts, evidence, themes, or recommendations", () => {
  const combined = productionFiles.map(source).join("\n");
  assert.doesNotMatch(combined, /console\.(?:log|info|debug|warn)/);
  assert.doesNotMatch(combined, /logger\./);
  assert.doesNotMatch(combined,
    /(?:console\.(?:log|info|debug|warn)|process\.(?:stdout|stderr)\.write)\([^;\n]*(?:output_text|prompt\.system|\.script|evidence)/);
});

test("approved evaluation fixtures are synthetic, closed, and contain no private payload fields", () => {
  const serialized = JSON.stringify(MONTHLY_STORY_APPROVED_EVALUATION_FIXTURE_IDS.map((id) =>
    approvedMonthlyStoryEvaluationFixture(id)));
  for (const prohibited of ["rawJournal", "journalText", "gratitudeText", "healthSamples", "sleepDuration",
    "stepCount", "recommendationTitle", "deviceId", "uid", "email", "https://", "dino-app-wellness"])
    assert.equal(serialized.toLowerCase().includes(prohibited.toLowerCase()), false, prohibited);
  assert.doesNotMatch(serialized, /\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/i);
  assert.doesNotMatch(serialized, /\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/i);
  for (const id of MONTHLY_STORY_APPROVED_EVALUATION_FIXTURE_IDS) {
    const signal = parseMonthlyStorySignal(approvedMonthlyStoryEvaluationFixture(id));
    assert.doesNotThrow(() => buildMonthlyStoryNarrativePlan(signal), id);
  }
});

test("local evaluation output directory is ignored and no key is embedded", () => {
  const ignore = readFileSync(join(root, ".gitignore"), "utf8");
  assert.equal(ignore.includes(".local/monthly-story-evaluation/"), true);
  const combined = productionFiles.map(source).join("\n");
  assert.doesNotMatch(combined, /sk-[A-Za-z0-9_-]{16,}/);
  assert.equal(combined.includes("OPENAI_API_KEY="), false);
});
