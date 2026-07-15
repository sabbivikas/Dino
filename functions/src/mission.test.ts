import { test } from "node:test";
import assert from "node:assert";
import { validateGift, validateGiftWithReason, TRUSTED_SOURCES, trustedSourcesFor } from "./mission";

const URL = "https://example.org/a-small-poem";
const good = {
  title: "A Small Poem About Morning",
  source: "Example Poetry",
  excerpt: "the light came back today, the way it always does, quietly and without asking for thanks",
  url: URL,
  whyOneLine: "It Felt Like A Soft — Morning",
};

test("happy path: lowercased, dash stripped, kept", () => {
  const g = validateGift(good, [URL]);
  assert.ok(g);
  assert.equal(g!.title, "a small poem about morning");
  assert.equal(g!.whyOneLine, "it felt like a soft morning");
});

test("invented url never survives", () => {
  assert.equal(validateGift(good, ["https://other.org/x"]), null);
});

test("http url never survives", () => {
  assert.equal(validateGift({ ...good, url: "http://example.org/a" }, ["http://example.org/a"]), null);
});

test("clinical or distressing content dies quietly", () => {
  assert.equal(validateGift({ ...good, excerpt: "a poem about grief and loss" }, [URL]), null);
  assert.equal(validateGift({ ...good, title: "good news about cancer research" }, [URL]), null);
});

test("long excerpt dies (copyright: 40 words max)", () => {
  const long = Array(45).fill("word").join(" ");
  assert.equal(validateGift({ ...good, excerpt: long }, [URL]), null);
});

test("unknown fields die", () => {
  assert.equal(validateGift({ ...good, extra: "x" }, [URL]), null);
});

test("missing fields die", () => {
  assert.equal(validateGift({ ...good, source: "" }, [URL]), null);
});

test("gentleness rejections are FINAL (reason gentle, no fallback)", () => {
  const v = validateGiftWithReason({ ...good, excerpt: "a poem about grief" }, [URL]);
  assert.equal(v.gift, null);
  assert.equal(v.reason, "gentle");
});

test("shape rejections may fall back (reason shape)", () => {
  const v = validateGiftWithReason({ ...good, url: "https://invented.org/x" }, [URL]);
  assert.equal(v.gift, null);
  assert.equal(v.reason, "shape");
});

test("every needKind has a trusted source home", () => {
  for (const kind of ["rest", "beauty", "hope", "wonder", "connection"]) {
    assert.ok((TRUSTED_SOURCES[kind] ?? []).length >= 3, `${kind} needs sources`);
  }
});

test("rotation puts unused sources first, drops nothing", () => {
  const rotated = trustedSourcesFor("hope", ["goodnewsnetwork.org", "positive.news"]);
  assert.deepEqual(rotated, [
    "reasonstobecheerful.world", "happyeconews.com",
    "goodnewsnetwork.org", "positive.news",
  ]);
  assert.equal(rotated.length, TRUSTED_SOURCES.hope.length);
});

test("unknown needKind falls back to hope's pool", () => {
  assert.deepEqual(trustedSourcesFor("nonsense", []), TRUSTED_SOURCES.hope);
});
