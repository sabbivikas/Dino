//
//  MoodRefreshTests.swift
//  DinoTests
//
//  Loop 2 — the mood screen refresh. Voice contract + pure logic for the
//  new designed components. Grows as the loop adds strings.
//

import XCTest
@testable import Dino

final class MoodRefreshTests: XCTestCase {

    // MARK: - Voice contract (lowercase, zero dashes, zero emoji)

    func testMoodButtonVoiceObeysTheContract() {
        for s in MoodButtonVoice.allFixedStrings {
            XCTAssertEqual(s, s.lowercased(), "'\(s)' breaks lowercase")
            for dash in ["-", "\u{2013}", "\u{2014}"] {
                XCTAssertFalse(s.contains(dash), "'\(s)' contains a dash")
            }
            XCTAssertTrue(s.allSatisfy { $0.isASCII }, "'\(s)' contains non ascii (emoji ban)")
        }
    }

    // MARK: - Adaptive line mapping

    func testHeavyMoodsGetTheHeavyLine() {
        XCTAssertEqual(MoodButtonVoice.line(for: .overwhelmed), MoodButtonVoice.heavyLine)
        XCTAssertEqual(MoodButtonVoice.line(for: .drained), MoodButtonVoice.heavyLine)
    }

    func testLightMoodsGetTheLightLine() {
        XCTAssertEqual(MoodButtonVoice.line(for: .clear), MoodButtonVoice.lightLine)
        XCTAssertEqual(MoodButtonVoice.line(for: .partlyCloudy), MoodButtonVoice.lightLine)
    }

    // MARK: - Seven skies

    func testWeekSkySeedIsStableAndDistinct() {
        let a = WeekSky.seed(userId: "u1", dayKey: "2026-07-11", mood: .clear)
        XCTAssertEqual(a, WeekSky.seed(userId: "u1", dayKey: "2026-07-11", mood: .clear))
        // any component changing changes the sky
        XCTAssertNotEqual(a, WeekSky.seed(userId: "u2", dayKey: "2026-07-11", mood: .clear))
        XCTAssertNotEqual(a, WeekSky.seed(userId: "u1", dayKey: "2026-07-12", mood: .clear))
        XCTAssertNotEqual(a, WeekSky.seed(userId: "u1", dayKey: "2026-07-11", mood: .drained))
        // and distinct seeds give distinct palettes
        XCTAssertNotEqual(GradientSeed.fingerprint(a),
                          GradientSeed.fingerprint(WeekSky.seed(userId: "u1", dayKey: "2026-07-12", mood: .clear)))
    }

    func testWeekSkyHeavyClassification() {
        XCTAssertTrue(WeekSky.isHeavy(.overwhelmed))
        XCTAssertTrue(WeekSky.isHeavy(.drained))
        XCTAssertFalse(WeekSky.isHeavy(.clear))
        XCTAssertFalse(WeekSky.isHeavy(.partlyCloudy))
    }

    func testWeekSkyDayKeyFormat() {
        var comps = DateComponents(); comps.year = 2026; comps.month = 7; comps.day = 5
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(WeekSky.dayKey(date), "2026-07-05")
    }
}
