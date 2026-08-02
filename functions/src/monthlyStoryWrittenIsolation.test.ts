import { test } from "node:test";
import assert from "node:assert";
import { readFileSync } from "fs";
import { join } from "path";
import { MONTHLY_STORY_GOLDENS, MONTHLY_STORY_SYNTHETIC_CORPUS } from "./monthlyStoryWrittenFixtures";

const root = join(__dirname, "..", "..");
const productionFiles = ["monthlyStoryNarrativePlan.ts", "monthlyStoryClaims.ts", "monthlyStoryPrompts.ts",
  "monthlyStoryTextProvider.ts", "monthlyStoryWrittenPipeline.ts", "monthlyStoryScriptValidator.ts",
  "monthlyStoryCritic.ts", "monthlyStoryArtifact.ts"];

test("Stage 4 has no Firebase, provider SDK, network, scheduler, callable, or logging integration", () => {
  const source = productionFiles.map((file) => readFileSync(join(root, "functions", "src", file), "utf8")).join("\n");
  for (const prohibited of ["firebase-admin", "firebase-functions", "from \"openai\"", "from 'openai'",
    "fetch(", "axios", "onCall(", "onSchedule(", "https://", "http://", "PostHog", "Firecrawl",
    "TMDB", "EmailJS", "console.log", "logger."]) assert.equal(source.includes(prohibited), false, prohibited);
  assert.doesNotMatch(source, /process\.env|defineSecret|defineString/);
});

test("Stage 4 is unreachable from the Functions entry point", () => {
  const index = readFileSync(join(root, "functions", "src", "index.ts"), "utf8");
  for (const file of productionFiles) {
    const moduleName = file.replace(/\.ts$/, "");
    assert.equal(index.includes(moduleName), false, moduleName);
  }
});

test("synthetic fixtures contain no raw private fields or real-looking identifiers", () => {
  const serialized = JSON.stringify({ corpus: MONTHLY_STORY_SYNTHETIC_CORPUS, goldens: MONTHLY_STORY_GOLDENS });
  for (const prohibited of ["rawJournal", "gratitudeText", "healthSamples", "sleepDuration",
    "stepCount", "recommendationTitle", "deviceId", "user@example", "https://", "dino-app-wellness"])
    assert.equal(serialized.includes(prohibited), false, prohibited);
  assert.doesNotMatch(serialized, /\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/i);
  assert.doesNotMatch(serialized, /\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/i);
});
