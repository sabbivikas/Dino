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
  isPerEventUrl,
  unwrapImageProxyUrl,
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

// ── isPerEventUrl — the og:image INVERSION fix, half one ──────────────────
//
// The pipeline used to ACCEPT a listing page's og:image (the site's social card
// for the whole calendar — very likely a DIFFERENT event's photo, which is
// exactly the "stock/unrelated photo" this feature forbids) and REJECT a
// per-event page's image. This helper is the gate on the first half.

test("isPerEventUrl: TRUE only for urls that identify ONE event", () => {
  // eventbrite's per-event permalink
  assert.equal(isPerEventUrl(
    "https://www.eventbrite.com/e/gentle-morning-yoga-tickets-1234567890"), true);
  assert.equal(isPerEventUrl(
    "https://eventbrite.com/e/quiet-reading-tickets-999?aff=ebdssbdestsearch"), true);
  // lu.ma — a single meaningful segment IS the event page
  assert.equal(isPerEventUrl("https://lu.ma/quiet-reading-night"), true);
  assert.equal(isPerEventUrl("https://lu.ma/abc123"), true);
  // bibliocommons and every CMS shaped like it: <collection>/<id>
  assert.equal(isPerEventUrl(
    "https://sppl.bibliocommons.com/v2/events/68f0a1b2c3d4e5f600000001"), true);
  assert.equal(isPerEventUrl("https://sppl.org/events/storytime-at-rondo"), true);
  assert.equal(isPerEventUrl("https://stpaul.gov/programs/como-garden-walk"), true);
});

test("isPerEventUrl: FALSE for listing, calendar, search and browse pages", () => {
  assert.equal(isPerEventUrl("https://sppl.org/events"), false);
  assert.equal(isPerEventUrl("https://sppl.org/events/"), false);
  assert.equal(isPerEventUrl("https://sppl.bibliocommons.com/v2/events"), false);
  assert.equal(isPerEventUrl("https://www.eventbrite.com/d/mn--saint-paul/free--events/"), false);
  assert.equal(isPerEventUrl("https://www.eventbrite.com/d/mn--saint-paul/free--events"), false);
  // a bare collection word at the end, whatever the host or depth
  assert.equal(isPerEventUrl("https://stpaul.gov/calendar"), false);
  assert.equal(isPerEventUrl("https://stpaul.gov/parks/programs"), false);
  assert.equal(isPerEventUrl("https://x.org/a/b/c/listings"), false);
  // only query filters — still the same listing page
  assert.equal(isPerEventUrl("https://sppl.org/events?date=2026-08-02&free=1"), false);
  assert.equal(isPerEventUrl("https://sppl.org/?view=calendar"), false);
  assert.equal(isPerEventUrl("https://lu.ma/"), false);
  assert.equal(isPerEventUrl("https://lu.ma/discover/wellness"), false);
});

test("isPerEventUrl: WHEN IN DOUBT, false — a missing photo beats a wrong event's photo", () => {
  // an unrecognised shape is not assumed to be one event
  assert.equal(isPerEventUrl("https://stpaul.gov/como"), false);
  assert.equal(isPerEventUrl("https://example.org/some/deep/unknown/path"), false);
  // eventbrite outside its /e/ permalink shape
  assert.equal(isPerEventUrl("https://www.eventbrite.com/o/saint-paul-library-123"), false);
  // /events/<id>/register is a step PAST the event page, not the event page
  assert.equal(isPerEventUrl("https://sppl.org/events/storytime/register"), false);
  // junk, wrong types, wrong schemes — never throws
  assert.equal(isPerEventUrl(""), false);
  assert.equal(isPerEventUrl("   "), false);
  assert.equal(isPerEventUrl("not a url"), false);
  assert.equal(isPerEventUrl("/events/123"), false);          // relative
  assert.equal(isPerEventUrl("ftp://x.org/events/123"), false);
  assert.equal(isPerEventUrl("https://localhost/events/1"), false);  // no dot in host
  assert.equal(isPerEventUrl(undefined), false);
  assert.equal(isPerEventUrl(null), false);
  assert.equal(isPerEventUrl(42), false);
  assert.equal(isPerEventUrl({ url: "https://lu.ma/x" }), false);
});

// ── unwrapImageProxyUrl — the og:image INVERSION fix, half two ────────────
//
// A genuine per-event image usually arrives through a resizing proxy whose path
// carries no raster extension (`…/_next/image?url=<encoded>`,
// `img.evbuc.com/<encoded>`), so sanitizeImageUrl dropped the REAL photo.
// Unwrap first, then sanitize.

test("unwrapImageProxyUrl decodes an https target out of a proxy query param", () => {
  assert.equal(
    unwrapImageProxyUrl(
      "https://www.eventbrite.com/_next/image?url=https%3A%2F%2Fimg.evbuc.com%2Fimages%2F1%2Foriginal.jpg&w=1200&q=75"),
    "https://img.evbuc.com/images/1/original.jpg");
  // the same shape with the other common param names
  assert.equal(
    unwrapImageProxyUrl("https://proxy.example/i?u=https%3A%2F%2Fcdn.x.org%2Fa.png"),
    "https://cdn.x.org/a.png");
  assert.equal(
    unwrapImageProxyUrl("https://proxy.example/i?src=https%3A%2F%2Fcdn.x.org%2Fb.webp"),
    "https://cdn.x.org/b.webp");
});

test("unwrapImageProxyUrl decodes a target carried AS the path (img.evbuc.com)", () => {
  assert.equal(
    unwrapImageProxyUrl(
      "https://img.evbuc.com/https%3A%2F%2Fcdn.evbuc.com%2Fimages%2F900%2Foriginal.jpg?w=600&auto=format"),
    "https://cdn.evbuc.com/images/900/original.jpg");
});

test("unwrapImageProxyUrl handles DOUBLE encoding", () => {
  assert.equal(
    unwrapImageProxyUrl(
      "https://www.eventbrite.com/_next/image?url=https%253A%252F%252Fimg.evbuc.com%252Fimages%252F2%252Foriginal.jpg"),
    "https://img.evbuc.com/images/2/original.jpg");
});

test("unwrapImageProxyUrl: a MISSING param and a NON-proxy url pass through unchanged", () => {
  // proxy shape, no url param at all — nothing to unwrap
  assert.equal(
    unwrapImageProxyUrl("https://www.eventbrite.com/_next/image?w=1200&q=75"),
    "https://www.eventbrite.com/_next/image?w=1200&q=75");
  // a param that is not an absolute url is NOT treated as a payload
  assert.equal(
    unwrapImageProxyUrl("https://proxy.example/i?url=%2Flocal%2Fa.jpg"),
    "https://proxy.example/i?url=%2Flocal%2Fa.jpg");
  // a plain image url is returned byte-for-byte
  assert.equal(
    unwrapImageProxyUrl("https://cdn.sppl.org/images/storytime.jpg"),
    "https://cdn.sppl.org/images/storytime.jpg");
  // non-strings / empties, never throws
  assert.equal(unwrapImageProxyUrl(""), null);
  assert.equal(unwrapImageProxyUrl("   "), null);
  assert.equal(unwrapImageProxyUrl(undefined), null);
  assert.equal(unwrapImageProxyUrl(null), null);
  assert.equal(unwrapImageProxyUrl(42), null);
  // not parseable as a url → handed back as-is for sanitizeImageUrl to reject
  assert.equal(unwrapImageProxyUrl("not a url"), "not a url");
  assert.equal(sanitizeImageUrl(unwrapImageProxyUrl("not a url")), null);
});

test("UNWRAP THEN SANITIZE: a proxied per-event image now SURVIVES the gate", () => {
  const proxied =
    "https://www.eventbrite.com/_next/image?url=https%3A%2F%2Fimg.evbuc.com%2Fimages%2F1%2Foriginal.jpg&w=1200";
  // the bug: the proxy path has no raster extension, so the gate dropped it
  assert.equal(sanitizeImageUrl(proxied), null);
  // the fix: unwrap first, and the REAL image passes
  assert.equal(
    sanitizeImageUrl(unwrapImageProxyUrl(proxied)),
    "https://img.evbuc.com/images/1/original.jpg");
});

test("UNWRAP is not a bypass: an unwrapped non-https target is still rejected", () => {
  assert.equal(
    sanitizeImageUrl(unwrapImageProxyUrl(
      "https://proxy.example/i?url=http%3A%2F%2Finsecure.example%2Fa.jpg")),
    null);
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
