import { test } from "node:test";
import assert from "node:assert";
import { breathingCrisisNet } from "./crisisNet";

// SAFETY-CRITICAL (owner gate 2026-07-16): every language must fire on
// realistic crisis input; everyday text must not. Mirrors DinoTests/CrisisNetTests.

test("english regression", () => {
  assert.ok(breathingCrisisNet("i want to die"));
  assert.ok(breathingCrisisNet("I can't do this anymore"));
  assert.ok(breathingCrisisNet("k i l l m y s e l f"));
  assert.ok(breathingCrisisNet("feeling hopeless today"));
});

test("korean fires — spaced, de-spaced, stems", () => {
  assert.ok(breathingCrisisNet("요즘 너무 힘들고 죽고 싶어요"));
  assert.ok(breathingCrisisNet("죽고싶다"));
  assert.ok(breathingCrisisNet("그냥 다 사라지고 싶어"));
  assert.ok(breathingCrisisNet("자해하고 싶은 마음이 들어요"));
  assert.ok(breathingCrisisNet("더 이상 못 살겠어"));
  assert.ok(breathingCrisisNet("살 이유가 없는 것 같아"));
  assert.ok(breathingCrisisNet("죽는 게 낫겠다는 생각이 들어"));
});

test("japanese fires — no spaces, kana + kanji", () => {
  assert.ok(breathingCrisisNet("もうつらい。しにたい"));
  assert.ok(breathingCrisisNet("死にたいと思ってしまう"));
  assert.ok(breathingCrisisNet("消えてしまいたいです"));
  assert.ok(breathingCrisisNet("リスカがやめられない"));
  assert.ok(breathingCrisisNet("生きる意味がないような気がする"));
  assert.ok(breathingCrisisNet("何もかももう無理"));
});

test("spanish fires — accents optional", () => {
  assert.ok(breathingCrisisNet("ya no puedo más, quiero desaparecer"));
  assert.ok(breathingCrisisNet("no quiero vivir"));
  assert.ok(breathingCrisisNet("quiero matarme"));
  assert.ok(breathingCrisisNet("pienso en hacerme dano"));
  assert.ok(breathingCrisisNet("estarian mejor sin mi"));
});

test("vietnamese fires — diacritics + ascii", () => {
  assert.ok(breathingCrisisNet("mình chỉ muốn biến mất"));
  assert.ok(breathingCrisisNet("không muốn sống nữa"));
  assert.ok(breathingCrisisNet("muon chet"));
  assert.ok(breathingCrisisNet("có ý nghĩ tự tử"));
  assert.ok(breathingCrisisNet("mình hay rạch tay"));
});

test("everyday text never fires", () => {
  assert.equal(breathingCrisisNet("i want to sleep early tonight"), false);
  assert.equal(breathingCrisisNet("오늘 날씨가 좋아서 산책했어요"), false);
  assert.equal(breathingCrisisNet("ㅈㅅ"), false);
  assert.equal(breathingCrisisNet("ㅈㅅ 늦었어"), false);
  assert.equal(breathingCrisisNet("今日はいい天気で散歩した"), false);
  assert.equal(breathingCrisisNet("無理しないでね"), false);
  assert.equal(breathingCrisisNet("quiero comer tacos esta noche"), false);
  assert.equal(breathingCrisisNet("hôm nay trời đẹp quá"), false);
  assert.equal(breathingCrisisNet("mua vé tàu tự túc"), false);
  assert.equal(breathingCrisisNet(""), false);
  assert.equal(breathingCrisisNet("   "), false);
});
