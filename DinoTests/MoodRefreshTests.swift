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
}
