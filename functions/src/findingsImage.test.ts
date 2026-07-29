// findingsImage.test.ts — pure tests for the REDESIGN additions:
//   • sanitizeImageUrl   — the event's own listing image, https-sanitized
//   • parseCandidates    — imageUrl rides through onto the candidate
//   • buildSearchPrompt  — the agent is told to capture the event's own image
//   • JSON_RETRY_MESSAGE — the re-ask schema carries imageUrl too
//   • tasksRemainingToday — the idle-count helper (5/day cap minus used)
//
// New test FILE (no existing test file is modified).

import test from "node:test";
import assert from "node:assert/strict";
import {
  sanitizeImageUrl,
  tasksRemainingToday,
  parseCandidates,
  buildSearchPrompt,
  JSON_RETRY_MESSAGE,
  MAX_TASKS_PER_DAY,
  IMAGE_URL_MAX,
} from "./starFindings";

const NOW = new Date("2026-07-28T12:00:00-05:00");

// ── sanitizeImageUrl ────────────────────────────────────────────────────────

test("sanitizeImageUrl accepts an https image with a real extension", () => {
  assert.equal(
    sanitizeImageUrl("https://cdn.evbuc.com/images/12345/original.jpg"),
    "https://cdn.evbuc.com/images/12345/original.jpg");
  assert.equal(
    sanitizeImageUrl("https://example.org/event-poster.png"),
    "https://example.org/event-poster.png");
  // extension followed by a query string still counts
  assert.equal(
    sanitizeImageUrl("https://img.host.com/a/b.webp?w=800&h=600"),
    "https://img.host.com/a/b.webp?w=800&h=600");
  // trimming, never baking whitespace in
  assert.equal(
    sanitizeImageUrl("  https://example.org/photo.jpeg "),
    "https://example.org/photo.jpeg");
});

test("sanitizeImageUrl accepts an extension-less path under a plausible media segment", () => {
  assert.equal(
    sanitizeImageUrl("https://images.squarespace-cdn.com/content/v1/abc/def"),
    "https://images.squarespace-cdn.com/content/v1/abc/def");
  assert.equal(
    sanitizeImageUrl("https://host.com/media/9182734"),
    "https://host.com/media/9182734");
});

test("sanitizeImageUrl rejects non-https, data:, and offsite non-image urls", () => {
  assert.equal(sanitizeImageUrl("http://example.org/photo.jpg"), null);   // not https
  assert.equal(sanitizeImageUrl("data:image/png;base64,AAAA"), null);      // data uri
  assert.equal(sanitizeImageUrl("https://example.org/register"), null);    // no image shape
  assert.equal(sanitizeImageUrl("https://example.org/"), null);            // bare host
  assert.equal(sanitizeImageUrl("ftp://example.org/a.jpg"), null);         // wrong scheme
});

test("sanitizeImageUrl rejects garbage, wrong types, over-length, and never throws", () => {
  assert.equal(sanitizeImageUrl(""), null);
  assert.equal(sanitizeImageUrl("   "), null);
  assert.equal(sanitizeImageUrl("not a url"), null);
  assert.equal(sanitizeImageUrl(undefined), null);
  assert.equal(sanitizeImageUrl(null), null);
  assert.equal(sanitizeImageUrl(42), null);
  assert.equal(sanitizeImageUrl({ url: "https://x/y.jpg" }), null);
  assert.equal(sanitizeImageUrl(["https://x/y.jpg"]), null);
  // over the length cap
  const long = "https://example.org/img/" + "a".repeat(IMAGE_URL_MAX) + ".jpg";
  assert.equal(sanitizeImageUrl(long), null);
});

// ── parseCandidates carries imageUrl through ─────────────────────────────────

test("parseCandidates carries a valid event imageUrl through, and nulls a bad one", () => {
  const raw = JSON.stringify([
    { title: "Storytime", date: "sat 10am", venue: "Library",
      url: "https://sppl.org/events/storytime",
      registrationNeeded: false, startISO: null, endISO: null, dateConfidence: "unknown",
      imageUrl: "https://cdn.sppl.org/images/storytime.jpg" },
    { title: "Garden Walk", date: "sun 2pm", venue: "Como",
      url: "https://stpaul.gov/como/walk",
      registrationNeeded: false, startISO: null, endISO: null, dateConfidence: "unknown",
      imageUrl: "http://insecure.example/x.jpg" },   // http → dropped
    { title: "Open Studio", date: "fri", venue: "Studio",
      url: "https://studio.example/open",
      registrationNeeded: false, startISO: null, endISO: null, dateConfidence: "unknown" },
    // no imageUrl → null
  ]);
  const cs = parseCandidates(raw, NOW);
  assert.equal(cs.length, 3);
  assert.equal(cs[0].imageUrl, "https://cdn.sppl.org/images/storytime.jpg");
  assert.equal(cs[1].imageUrl, null);
  assert.equal(cs[2].imageUrl, null);
});

test("parseCandidates also accepts snake_case image_url / image aliases", () => {
  const raw = JSON.stringify([
    { title: "A", url: "https://a.example/a", image_url: "https://a.example/photos/a.png" },
    { title: "B", url: "https://b.example/b", image: "https://b.example/media/b" },
  ]);
  const cs = parseCandidates(raw, NOW);
  assert.equal(cs[0].imageUrl, "https://a.example/photos/a.png");
  assert.equal(cs[1].imageUrl, "https://b.example/media/b");
});

// ── the search prompt asks for the event's own image ─────────────────────────

test("buildSearchPrompt tells the agent to capture the event's own image url", () => {
  const p = buildSearchPrompt();
  assert.match(p, /imageUrl/);
  assert.match(p, /event's OWN photo or/i);
  assert.match(p, /never a stock, logo, avatar, icon, or/i);
  assert.match(p, /set imageUrl to null/i);
  // the schema line itself carries the field
  assert.match(p, /"imageUrl": string\|null/);
});

test("JSON_RETRY_MESSAGE schema carries imageUrl so a re-format keeps it", () => {
  assert.match(JSON_RETRY_MESSAGE, /"imageUrl": string\|null/);
});

// ── tasksRemainingToday ──────────────────────────────────────────────────────

test("tasksRemainingToday subtracts used from the cap and clamps to [0, cap]", () => {
  assert.equal(tasksRemainingToday(0), MAX_TASKS_PER_DAY);
  assert.equal(tasksRemainingToday(1), MAX_TASKS_PER_DAY - 1);
  assert.equal(tasksRemainingToday(MAX_TASKS_PER_DAY), 0);
  assert.equal(tasksRemainingToday(MAX_TASKS_PER_DAY + 3), 0);   // never negative
});

test("tasksRemainingToday treats a bad/negative reading as zero used (generous, not zero-left)", () => {
  assert.equal(tasksRemainingToday(undefined), MAX_TASKS_PER_DAY);
  assert.equal(tasksRemainingToday(null), MAX_TASKS_PER_DAY);
  assert.equal(tasksRemainingToday(NaN), MAX_TASKS_PER_DAY);
  assert.equal(tasksRemainingToday(-4), MAX_TASKS_PER_DAY);
  assert.equal(tasksRemainingToday("nope" as unknown), MAX_TASKS_PER_DAY);
});

test("tasksRemainingToday honors an explicit cap override", () => {
  assert.equal(tasksRemainingToday(2, 10), 8);
  assert.equal(tasksRemainingToday(2, 0), MAX_TASKS_PER_DAY - 2);   // bad cap → default
});
