import { test } from "node:test";
import assert from "node:assert";
import { readFileSync, readdirSync } from "fs";
import { join } from "path";

const sourceRoot = __dirname.endsWith("lib") ? join(__dirname, "..", "src") : __dirname;
const read = (name: string): string => readFileSync(join(sourceRoot, name), "utf8");

test("Stage 6 persistence is reachable only through the approved Stage 8 internal API", () => {
  const index = read("index.ts");
  for (const symbol of ["runMonthlyStoryGenerationInternal"]) {
    assert.equal(index.includes(symbol), false);
  }
  for (const symbol of ["createMonthlyStoryInternalApi", "FirestoreMonthlyStoryRepository",
    "getMonthlyStoryInternalAvailability", "getMonthlyStoryInternalSettings",
    "updateMonthlyStoryInternalSettings", "loadMonthlyStoryInternalStory",
    "generateMonthlyStoryInternal", "deleteMonthlyStoryInternal"]) {
    assert.equal(index.includes(symbol), true, symbol);
  }
});

test("Stage 6 persistence modules contain no provider, network, SDK initialization, or logging", () => {
  const combined = [read("monthlyStoryRepository.ts"), read("monthlyStoryGenerationService.ts")].join("\n");
  for (const prohibited of ["from \"openai\"", "firebase-admin", "initializeApp(", "getFirestore(",
    "fetch(", "axios", "https://", "OPENAI_API_KEY", "HUME_API_KEY", "monthlyStoryHumeProvider",
    "console.log", "logger.", "posthog"]) {
    assert.equal(combined.toLowerCase().includes(prohibited.toLowerCase()), false, prohibited);
  }
  assert.match(combined, /providerRequestCount: 0/);
  assert.match(combined, /providerCostMicros: 0/);
});

test("only the restricted Stage 8 internal API imports the Stage 6 generation service", () => {
  const importers = readdirSync(sourceRoot).filter((name) => name.endsWith(".ts") && !name.endsWith(".test.ts"))
    .filter((name) => !["monthlyStoryGenerationService.ts"].includes(name))
    .filter((name) => read(name).includes("monthlyStoryGenerationService"));
  assert.deepEqual(importers, ["monthlyStoryInternalApi.ts"]);
});

test("repository bodies prohibit direct owner and private-source fields", () => {
  const source = read("monthlyStoryRepository.ts");
  for (const field of ["rawJournal", "gratitudeText", "emailAddress", "deviceId", "recommendationTitle",
    "healthSample", "rawPrompt", "providerResponse"]) assert.equal(source.includes(field), false, field);
  assert.match(source, /ownerKey/);
  assert.equal(source.includes("uid: string;\n  monthKey"), false);
});
