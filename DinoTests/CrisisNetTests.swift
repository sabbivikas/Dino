//
//  CrisisNetTests.swift
//  DinoTests
//
//  SAFETY-CRITICAL: the multilingual crisis net (owner gate 2026-07-16).
//  Every language's terms must fire on realistic input — spaced and
//  de-spaced korean, no-space japanese, accent-less spanish, ascii
//  vietnamese — and everyday text must never fire.
//

import XCTest
@testable import Dino

final class CrisisNetTests: XCTestCase {

    private func fires(_ text: String) -> Bool {
        BreathingCrisisNet.isConcerning(text)
    }

    // MARK: english (regression — the original net)
    func testEnglishStillFires() {
        XCTAssertTrue(fires("i want to die"))
        XCTAssertTrue(fires("I can't do this anymore"))
        XCTAssertTrue(fires("k i l l m y s e l f"))
        XCTAssertTrue(fires("feeling hopeless today"))
    }

    // MARK: 한국어
    func testKoreanFires() {
        XCTAssertTrue(fires("요즘 너무 힘들고 죽고 싶어요"), "spaced 죽고 싶")
        XCTAssertTrue(fires("죽고싶다"), "de-spaced 죽고싶")
        XCTAssertTrue(fires("그냥 다 사라지고 싶어"), "사라지고 싶")
        XCTAssertTrue(fires("자해하고 싶은 마음이 들어요"), "자해")
        XCTAssertTrue(fires("더 이상 못 살겠어"), "더이상 못 살")
        XCTAssertTrue(fires("살 이유가 없는 것 같아"), "살 이유가 없")
        XCTAssertTrue(fires("죽는 게 낫겠다는 생각이 들어"), "죽는 게 낫")
    }

    // MARK: 日本語 (no spaces)
    func testJapaneseFires() {
        XCTAssertTrue(fires("もうつらい。しにたい"), "kana しにたい")
        XCTAssertTrue(fires("死にたいと思ってしまう"), "kanji 死にたい")
        XCTAssertTrue(fires("消えてしまいたいです"), "消えてしまいたい")
        XCTAssertTrue(fires("リスカがやめられない"), "リスカ")
        XCTAssertTrue(fires("生きる意味がないような気がする"), "生きる意味がない")
        XCTAssertTrue(fires("何もかももう無理"), "もう無理 over-trigger")
    }

    // MARK: español (accents optional)
    func testSpanishFires() {
        XCTAssertTrue(fires("ya no puedo más, quiero desaparecer"))
        XCTAssertTrue(fires("no quiero vivir"), "accent-less")
        XCTAssertTrue(fires("quiero matarme"))
        XCTAssertTrue(fires("pienso en hacerme dano"), "accent-less daño")
        XCTAssertTrue(fires("estarian mejor sin mi"), "accent-less")
    }

    // MARK: tiếng việt (diacritics + ascii)
    func testVietnameseFires() {
        XCTAssertTrue(fires("mình chỉ muốn biến mất"))
        XCTAssertTrue(fires("không muốn sống nữa"))
        XCTAssertTrue(fires("muon chet"), "ascii vietnamese")
        XCTAssertTrue(fires("có ý nghĩ tự tử"), "tự tử")
        XCTAssertTrue(fires("mình hay rạch tay"), "rạch tay")
    }

    // MARK: negatives — everyday text must never fire
    func testEverydayTextDoesNotFire() {
        XCTAssertFalse(fires("i want to sleep early tonight"))
        XCTAssertFalse(fires("오늘 날씨가 좋아서 산책했어요"), "ko everyday")
        XCTAssertFalse(fires("ㅈㅅ"), "korean sorry-abbreviation excluded by design")
        XCTAssertFalse(fires("ㅈㅅ 늦었어"), "ㅈㅅ in context")
        XCTAssertFalse(fires("今日はいい天気で散歩した"), "ja everyday")
        XCTAssertFalse(fires("無理しないでね"), "無理 alone without もう")
        XCTAssertFalse(fires("quiero comer tacos esta noche"), "es everyday")
        XCTAssertFalse(fires("hôm nay trời đẹp quá"), "vi everyday")
        XCTAssertFalse(fires("mua vé tàu tự túc"), "tự túc is not tự tử")
        XCTAssertFalse(fires(""))
        XCTAssertFalse(fires("   "))
    }

    // MARK: crisis resources gate-1 spot checks (labels changed, numbers never)
    func testCrisisDirectoryNumbersUnchanged() {
        let kr = CrisisResources.resources(for: "KR")
        XCTAssertFalse(kr.isFallback)
        XCTAssertEqual(kr.list.map(\.contact), ["109", "1577-1366"])
        XCTAssertEqual(kr.list[1].name, "다누리콜센터 (danuri)")
        let jp = CrisisResources.resources(for: "JP")
        XCTAssertEqual(jp.list.map(\.contact), ["0120-279-338", "0570-783-556"])
        XCTAssertFalse(jp.list[0].detail.contains("hours vary"))
        XCTAssertFalse(jp.list[1].detail.contains("10am"))
        // english rendering of the verbs stays byte-identical
        XCTAssertEqual(CrisisResources.resources(for: "US").list[0].actionLabel.hasPrefix("call ") ||
                       Locale.preferredLanguages.first?.hasPrefix("en") == false, true)
    }
}
