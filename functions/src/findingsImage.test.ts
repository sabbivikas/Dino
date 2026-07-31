// findingsImage.test.ts — pure tests for the REDESIGN additions:
//   • sanitizeImageUrl   — the image url gate, https-sanitized
//   • extractOgImage     — the POST-SEARCH og:image read (zero agent steps)
//   • parseCandidates    — imageUrl still rides through when volunteered
//   • buildSearchPrompt  — the agent is NO LONGER asked for images at all
//   • tasksRemainingToday — the idle-count helper (5/day cap minus used)
//
// New test FILE (no existing test file is modified).

import test from "node:test";
import assert from "node:assert/strict";
import {
  sanitizeImageUrl,
  extractOgImage,
  tasksRemainingToday,
  parseCandidates,
  buildSearchPrompt,
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

// Collecting imageUrl per candidate was one of the two step sinks that capped
// both production runs — the agent went visual-scrollback hunting for the
// banner beside each listing row. The photo now comes from a server-side
// og:image fetch AFTER the pick, so the prompt must not mention it at all.
test("buildSearchPrompt never asks the agent for an image (the step sink is gone)", () => {
  for (const p of [buildSearchPrompt(), buildSearchPrompt(undefined, true)]) {
    assert.doesNotMatch(p, /imageUrl/);
    assert.doesNotMatch(p, /THE EVENT IMAGE/);
    assert.doesNotMatch(p, /photo or\s+poster/i);
  }
});

// ── extractOgImage (the post-pick photo, at zero agent steps) ──────────────

const PAGE = "https://sppl.org/events/storytime";

test("extractOgImage reads og:image and resolves an absolute url", () => {
  const html = `<html><head><meta property="og:image" content="https://cdn.sppl.org/images/a.jpg">` +
    "</head><body>x</body></html>";
  assert.equal(extractOgImage(html, PAGE), "https://cdn.sppl.org/images/a.jpg");
});

test("extractOgImage resolves protocol-relative and root-relative urls against the page", () => {
  assert.equal(
    extractOgImage('<meta property="og:image" content="//cdn.sppl.org/images/a.jpg">', PAGE),
    "https://cdn.sppl.org/images/a.jpg");
  assert.equal(
    extractOgImage('<meta property="og:image" content="/media/hero.png">', PAGE),
    "https://sppl.org/media/hero.png");
  // a plain relative path resolves against the page's directory
  assert.equal(
    extractOgImage('<meta property="og:image" content="hero.png">', "https://sppl.org/events/"),
    "https://sppl.org/events/hero.png");
});

test("extractOgImage falls back to twitter:image only when there is no og:image", () => {
  const twOnly = '<meta name="twitter:image" content="https://x.org/images/t.jpg">';
  assert.equal(extractOgImage(twOnly, PAGE), "https://x.org/images/t.jpg");
  // og wins even when twitter comes first in the document
  const both = twOnly + '<meta property="og:image" content="https://x.org/images/o.jpg">';
  assert.equal(extractOgImage(both, PAGE), "https://x.org/images/o.jpg");
});

test("extractOgImage takes the FIRST og:image when several are present", () => {
  const html =
    '<meta property="og:image" content="https://x.org/images/1.jpg">' +
    '<meta property="og:image" content="https://x.org/images/2.jpg">';
  assert.equal(extractOgImage(html, PAGE), "https://x.org/images/1.jpg");
});

test("extractOgImage tolerates single quotes, attribute order, and &amp; entities", () => {
  assert.equal(
    extractOgImage("<meta content='https://x.org/images/a.jpg' property='og:image'>", PAGE),
    "https://x.org/images/a.jpg");
  assert.equal(
    extractOgImage('<meta property="og:image" content="https://x.org/i.jpg?a=1&amp;b=2">', PAGE),
    "https://x.org/i.jpg?a=1&b=2");
});

test("extractOgImage returns null for a missing tag, malformed html, and wrong types", () => {
  assert.equal(extractOgImage("<html><head><title>x</title></head></html>", PAGE), null);
  assert.equal(extractOgImage("", PAGE), null);
  assert.equal(extractOgImage("<<<not html", PAGE), null);
  assert.equal(extractOgImage('<meta property="og:image">', PAGE), null);       // no content
  assert.equal(extractOgImage('<meta property="og:image" content="">', PAGE), null);
  assert.equal(extractOgImage('<meta property="og:image" content="not a url">', ""), null);
  assert.equal(extractOgImage(undefined, PAGE), null);
  assert.equal(extractOgImage(null, PAGE), null);
  assert.equal(extractOgImage(42, PAGE), null);
  assert.equal(extractOgImage('<meta property="description" content="https://x/a.jpg">', PAGE), null);
});

test("extractOgImage output is NOT trusted — sanitizeImageUrl is still the gate", () => {
  // http og:image resolves fine here, and is then rejected downstream
  const raw = extractOgImage('<meta property="og:image" content="http://x.org/images/a.jpg">', PAGE);
  assert.equal(raw, "http://x.org/images/a.jpg");
  assert.equal(sanitizeImageUrl(raw), null);
  // …and a real https image survives the round trip
  const ok = extractOgImage('<meta property="og:image" content="//cdn.x.org/images/a.jpg">', PAGE);
  assert.equal(sanitizeImageUrl(ok), "https://cdn.x.org/images/a.jpg");
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
