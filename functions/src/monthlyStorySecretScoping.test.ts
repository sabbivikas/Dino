import { test } from "node:test";
import assert from "node:assert";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const sourceRoot = __dirname.endsWith("lib") ? join(__dirname, "..", "src") : __dirname;
const indexSource = readFileSync(join(sourceRoot, "index.ts"), "utf8");

const monthlyStoryExports = [
  "getMonthlyStoryInternalAvailability",
  "getMonthlyStoryInternalSettings",
  "updateMonthlyStoryInternalSettings",
  "loadMonthlyStoryInternalStory",
  "generateMonthlyStoryInternal",
  "deleteMonthlyStoryInternal",
] as const;

const providerBindings = new Map<string, readonly string[]>([
  ["generateMoodPainting", ["OPENAI_API_KEY"]],
  ["generateForestLetter", ["OPENAI_API_KEY"]],
  ["generateRhythmsLetter", ["OPENAI_API_KEY"]],
  ["suggestBreakSlot", ["OPENAI_API_KEY"]],
  ["extractJournalTheme", ["OPENAI_API_KEY"]],
  ["suggestBreathingSession", ["OPENAI_API_KEY"]],
  ["generateDailyNudge", ["OPENAI_API_KEY"]],
  ["generateWeeklyReport", ["OPENAI_API_KEY"]],
  ["generateWeeklyNoticed", ["OPENAI_API_KEY"]],
  ["refreshRecommendationPool", ["FIRECRAWL_API_KEY", "OPENAI_API_KEY"]],
  ["pickGentleRec", ["OPENAI_API_KEY"]],
  ["moderateLantern", ["OPENAI_API_KEY"]],
  ["nightlyExpeditionWatch", ["OPENAI_API_KEY", "META_MODEL_API_KEY", "FIRECRAWL_API_KEY"]],
  ["generateComfortRecs", ["OPENAI_API_KEY", "TMDB_API_TOKEN"]],
  ["nightlyPreferenceDistill", ["OPENAI_API_KEY"]],
  ["startFindingTask", ["OPENAI_API_KEY"]],
]);

function exportBlock(name: string): string {
  const start = indexSource.indexOf(`export const ${name} =`);
  assert.notEqual(start, -1, name);
  const next = indexSource.indexOf("\nexport const ", start + 1);
  return indexSource.slice(start, next === -1 ? indexSource.length : next);
}

test("monthly-story exports bind no provider secrets and retain their export names", () => {
  for (const name of monthlyStoryExports) {
    const block = exportBlock(name);
    assert.doesNotMatch(block, /secrets\s*:/, name);
    assert.doesNotMatch(block, /OPENAI|META_MODEL|FIRECRAWL|TMDB|HUME|TTS/i, name);
  }
});

test("provider-backed exports retain their exact secret-name bindings", () => {
  for (const [name, secrets] of providerBindings) {
    const block = exportBlock(name);
    const expected = `secrets: [${secrets.map((secret) => `"${secret}"`).join(", ")}]`;
    assert.equal(block.includes(expected), true, `${name}:${expected}`);
  }
});

test("index import registers no global params, reads no secret, and initializes no provider client", () => {
  assert.doesNotMatch(indexSource, /defineSecret|defineString/);
  assert.match(indexSource, /function requiredSecret\(name: RuntimeSecretName\)/);
  const compiledIndex = join(__dirname, "index.js");
  const child = `
    const openAIPath = require.resolve("openai");
    require.cache[openAIPath] = {
      id: openAIPath, filename: openAIPath, loaded: true,
      exports: { __esModule: true, default: class ForbiddenProviderInit {
        constructor() { throw new Error("provider initialized during import"); }
      } }, children: [], paths: []
    };
    for (const name of ["OPENAI_API_KEY", "FIRECRAWL_API_KEY", "TMDB_API_TOKEN",
      "META_MODEL_API_KEY", "META_API_BASE"]) delete process.env[name];
    const loaded = require(${JSON.stringify(compiledIndex)});
    const expected = ${JSON.stringify(monthlyStoryExports)};
    if (!expected.every((name) => typeof loaded[name] === "function")) process.exit(2);
    process.stdout.write("monthly-story-import-ok");
    process.exit(0);
  `;
  const output = execFileSync(process.execPath, ["-e", child], {
    cwd: join(__dirname, ".."), encoding: "utf8", timeout: 10_000,
    env: { PATH: process.env.PATH ?? "" },
  });
  assert.equal(output, "monthly-story-import-ok");
});

test("monthly-story entry point cannot reach provider-evaluation code", () => {
  const monthlyImports = ["monthlyStoryInternalApi", "monthlyStoryRepository"];
  for (const required of monthlyImports) assert.equal(indexSource.includes(`from "./${required}"`), true, required);
  for (const prohibited of ["monthlyStoryOpenAIProvider", "monthlyStoryWrittenPipeline",
    "monthlyStorySyntheticEvaluation", "monthlyStoryTextProvider"]) {
    assert.equal(indexSource.includes(`from "./${prohibited}"`), false, prohibited);
  }
});
