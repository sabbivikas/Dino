#!/usr/bin/env node
// Writes the two Firestore documents the monthly story needs for an internal run:
//
//   featureFlags/monthlyStory                 - the control document (fresh updatedAt)
//   monthlyStoryInternalTesters/<uid>         - the tester grant (future expiresAt)
//
// Read-only by default. Nothing is written unless --apply is passed.
//
//   node ops/monthlyStory/apply-monthly-story-config.mjs                 # show current vs desired
//   node ops/monthlyStory/apply-monthly-story-config.mjs --apply         # write both documents
//   node ops/monthlyStory/apply-monthly-story-config.mjs --check         # read back + run the real parsers
//
// Auth comes from `gcloud auth print-access-token`, so whoever runs it needs to be logged in
// against the project already. No service-account key is read or written.

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, "..", "..");

const PROJECT = "dino-app-wellness";
const UID = process.env.MONTHLY_STORY_UID ?? "Enlkbg0saoMqvx24r7ZLsBX8ctp2";
const TESTER_DAYS = Number(process.env.MONTHLY_STORY_TESTER_DAYS ?? 30);

const APPLY = process.argv.includes("--apply");
const CHECK = process.argv.includes("--check");
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

const token = () => execFileSync("gcloud", ["auth", "print-access-token"], { encoding: "utf8" }).trim();
const AUTH = { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" };

// ---- Firestore REST value mapping -------------------------------------------------------------

function toValue(value) {
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) throw new Error(`non-integer control value: ${value}`);
    return { integerValue: String(value) };
  }
  if (typeof value === "string") return { stringValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  throw new Error(`unsupported value: ${String(value)}`);
}

function fromValue(value) {
  if ("integerValue" in value) return Number(value.integerValue);
  return Object.values(value)[0];
}

async function getDocument(path) {
  const response = await fetch(`${BASE}/${path}`, { headers: AUTH });
  if (response.status === 404) return null;
  const body = await response.json();
  if (body.error) throw new Error(`${path}: ${body.error.status} ${body.error.message}`);
  return body;
}

// A PATCH with no updateMask leaves unlisted stored fields in place, and a stray field is exactly
// what makes parseMonthlyStoryControl call the document "malformed". So the mask is the UNION of
// what we are writing and what is already stored: masked-but-absent fields get deleted, which is
// how a leftover key from an older schema is cleaned up rather than silently breaking the parse.
async function writeDocument(path, fields) {
  const existing = await getDocument(path);
  const storedKeys = existing ? Object.keys(existing.fields ?? {}) : [];
  const mask = [...new Set([...Object.keys(fields), ...storedKeys])];
  const query = mask.map((key) => `updateMask.fieldPaths=${encodeURIComponent(key)}`).join("&");
  const response = await fetch(`${BASE}/${path}?${query}`, {
    method: "PATCH",
    headers: AUTH,
    body: JSON.stringify({ fields: Object.fromEntries(
      Object.entries(fields).map(([key, value]) => [key, toValue(value)])) }),
  });
  const body = await response.json();
  if (body.error) throw new Error(`${path}: ${body.error.status} ${body.error.message}`);
  const removed = storedKeys.filter((key) => !(key in fields));
  if (removed.length) console.log(`      removed stale fields: ${removed.join(", ")}`);
  return body;
}

// ---- The two documents ------------------------------------------------------------------------

const control = JSON.parse(readFileSync(join(HERE, "featureFlags-monthlyStory.json"), "utf8"));
delete control._comment;

const now = new Date();
const testerExpires = new Date(now.getTime() + TESTER_DAYS * 24 * 60 * 60 * 1000);

const desiredControl = { ...control, updatedAt: now };
const desiredTester = { enabled: true, updatedAt: now, expiresAt: testerExpires };

// ---- Report -----------------------------------------------------------------------------------

function diff(label, stored, desired) {
  console.log(`\n=== ${label} ===`);
  if (!stored) { console.log("      (document does not exist)"); }
  const storedFields = stored ? Object.fromEntries(
    Object.entries(stored.fields ?? {}).map(([key, value]) => [key, fromValue(value)])) : {};
  for (const key of [...new Set([...Object.keys(storedFields), ...Object.keys(desired)])].sort()) {
    const before = storedFields[key];
    const after = desired[key] instanceof Date ? desired[key].toISOString() : desired[key];
    const same = String(before) === String(after);
    const marker = key in desired ? (same ? "  " : "->") : "DEL";
    if (!same || marker === "DEL") console.log(`  ${marker} ${key.padEnd(36)} ${JSON.stringify(before)}  =>  ${JSON.stringify(after)}`);
  }
}

// ---- Verify: run the REAL server parsers over what is actually stored --------------------------

async function check() {
  const { parseMonthlyStoryControl, monthlyStoryGenerationIsFailClosed,
    monthlyStoryAudioGenerationIsFailClosed } = await import(
    join(REPO, "functions", "lib", "monthlyStoryControl.js"));
  const { parseMonthlyStoryInternalTester } = await import(
    join(REPO, "functions", "lib", "monthlyStoryInternalAccess.js"));

  const nowMillis = Date.now();
  const storedControl = await getDocument("featureFlags/monthlyStory");
  const plain = (document) => document ? Object.fromEntries(Object.entries(document.fields ?? {})
    .map(([key, value]) => [key, "timestampValue" in value ? new Date(value.timestampValue) : fromValue(value)])) : null;

  const parsed = parseMonthlyStoryControl(plain(storedControl), nowMillis);
  console.log(`\ncontrol      accepted=${parsed.accepted} reason=${parsed.reason}`);
  if (parsed.accepted) {
    const ageHours = ((nowMillis - parsed.control.updatedAtMillis) / 3600000).toFixed(1);
    console.log(`             age=${ageHours}h (goes stale at 24h)`);
    console.log(`             textFailClosed=${monthlyStoryGenerationIsFailClosed(parsed.control)}` +
                `  audioFailClosed=${monthlyStoryAudioGenerationIsFailClosed(parsed.control)}`);
  }

  const storedTester = await getDocument(`monthlyStoryInternalTesters/${UID}`);
  const tester = parseMonthlyStoryInternalTester(plain(storedTester), nowMillis);
  console.log(`tester       ${UID} valid=${tester}`);
  if (storedTester) {
    const expires = storedTester.fields?.expiresAt?.timestampValue;
    console.log(`             expiresAt=${expires} (${((Date.parse(expires) - nowMillis) / 86400000).toFixed(1)} days left)`);
  }

  const ok = parsed.accepted && tester && !monthlyStoryGenerationIsFailClosed(parsed.control);
  console.log(`\n${ok ? "OK" : "NOT READY"} - deterministic text path ${ok ? "is" : "is NOT"} unblocked.`);
  process.exitCode = ok ? 0 : 1;
}

// ---- Main ---------------------------------------------------------------------------------------

if (CHECK) {
  await check();
} else {
  diff("featureFlags/monthlyStory", await getDocument("featureFlags/monthlyStory"), desiredControl);
  diff(`monthlyStoryInternalTesters/${UID}`, await getDocument(`monthlyStoryInternalTesters/${UID}`), desiredTester);

  if (!APPLY) {
    console.log("\n(dry run - nothing written. re-run with --apply)");
  } else {
    console.log("\nwriting...");
    await writeDocument("featureFlags/monthlyStory", desiredControl);
    console.log("      featureFlags/monthlyStory written");
    await writeDocument(`monthlyStoryInternalTesters/${UID}`, desiredTester);
    console.log(`      monthlyStoryInternalTesters/${UID} written (expires ${testerExpires.toISOString()})`);
    console.log("\nNOTE: the control document goes stale 24h from now. Re-run --apply before each test day.");
  }
}
