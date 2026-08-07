import { test } from "node:test";
import assert from "node:assert";
import { MONTHLY_STORY_PHRASE_LIBRARY, MonthlyStoryPhraseSet } from "./monthlyStoryPhraseLibrary";
import { MONTHLY_STORY_ZERO_TOLERANCE_PATTERNS,
  MONTHLY_STORY_ZERO_TOLERANCE_PHRASES } from "./monthlyStoryScriptValidator";

/**
 * The deterministic composer may only emit sentences from MONTHLY_STORY_PHRASE_LIBRARY, and every
 * script it builds is then handed to validateMonthlyStoryScript. Nothing previously stopped the
 * library from containing a sentence the validator bans outright, and one did: the `workPressure`
 * support phrase said "...a clear place in this reflection", which META_COMMENTARY rejects. Because
 * `monthlyStoryGenerationService` treats `validation-failed` as TERMINAL for the deterministic path
 * (there is no repair step outside the written/LLM pipeline), every rich month that named work
 * pressure failed permanently, burning the job and showing the user nothing.
 *
 * These tests close that hole structurally: the library is swept against the validator's own
 * exported ban lists, so the two can never disagree again without a red test.
 */

const MONTHS = ["january", "february", "march", "april", "may", "june",
  "july", "august", "september", "october", "november", "december"] as const;

const SLOTS = ["core", "support", "transition"] as const;

type Hit = { key: string; slot: string; code: string; banned: string; sentence: string };

function scan(sentence: string, key: string, slot: string): Hit[] {
  const hits: Hit[] = [];
  const normalized = sentence.toLowerCase();
  for (const [code, phrases] of Object.entries(MONTHLY_STORY_ZERO_TOLERANCE_PHRASES)) {
    for (const banned of phrases ?? []) {
      if (normalized.includes(banned)) hits.push({ key, slot, code, banned, sentence });
    }
  }
  for (const [code, pattern] of Object.entries(MONTHLY_STORY_ZERO_TOLERANCE_PATTERNS)) {
    if (pattern && pattern.test(sentence)) {
      hits.push({ key, slot, code, banned: String(pattern), sentence });
    }
  }
  return hits;
}

function describe(hits: readonly Hit[]): string {
  return ["", ...hits.map((hit) =>
    `  ${hit.code} in ${hit.key}.${hit.slot}\n` +
    `    banned:  ${hit.banned}\n` +
    `    phrase:  "${hit.sentence}"`)].join("\n");
}

// `{month}` is interpolated at composition time, and at least one ban is month-specific
// ("the shape july takes"), so every phrase is checked against every month name rather than one.
function expansions(raw: string): string[] {
  if (!raw.includes("{month}")) return [raw];
  return MONTHS.map((month) => raw.replace(/\{month\}/g, month));
}

test("no phrase the composer may emit is a phrase the validator bans", () => {
  const hits: Hit[] = [];
  let scanned = 0;

  for (const [key, set] of Object.entries(MONTHLY_STORY_PHRASE_LIBRARY) as
    [string, MonthlyStoryPhraseSet][]) {
    for (const slot of SLOTS) {
      for (const raw of set[slot]) {
        for (const sentence of expansions(raw)) {
          scanned += 1;
          hits.push(...scan(sentence, key, slot));
        }
      }
    }
  }

  assert.equal(hits.length, 0, `phrase library emits validator-banned text:${describe(hits)}\n`);

  // Guards against the sweep silently covering nothing if the library or the exports are renamed.
  assert.ok(scanned > 200, `expected the whole library to be scanned, saw ${scanned} phrases`);
  assert.ok(Object.keys(MONTHLY_STORY_ZERO_TOLERANCE_PHRASES).length >= 15);
  assert.ok(Object.keys(MONTHLY_STORY_ZERO_TOLERANCE_PATTERNS).length >= 5);
});

test("no claim key's phrases collide with a ban once joined into a single beat", () => {
  // The composer emits a beat as core + support + transition run together, so a banned phrase can
  // also appear across a sentence boundary that no single phrase contains.
  const hits: Hit[] = [];

  for (const [key, set] of Object.entries(MONTHLY_STORY_PHRASE_LIBRARY) as
    [string, MonthlyStoryPhraseSet][]) {
    for (const month of MONTHS) {
      const beat = [...set.core, ...set.support, ...set.transition]
        .join(" ").replace(/\{month\}/g, month);
      hits.push(...scan(beat, key, "joined").map((hit) => ({ ...hit, sentence: `…${hit.banned}…` })));
    }
  }

  assert.equal(hits.length, 0, `joined phrase beats emit validator-banned text:${describe(hits)}\n`);
});

test("the workPressure support phrase that shipped broken stays fixed", () => {
  const support = MONTHLY_STORY_PHRASE_LIBRARY.workPressure.support.join(" ").toLowerCase();
  assert.ok(!support.includes("this reflection"),
    "the metaCommentary collision is back in workPressure.support");
  assert.ok(support.includes("worth naming on its own"),
    "the replacement phrase is gone; keep an equivalent that carries the same meaning");
});
