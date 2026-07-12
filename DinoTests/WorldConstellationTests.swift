//
//  WorldConstellationTests.swift
//  DinoTests
//
//  The constellation's pure parts: voice contract, presence curve bounds,
//  glow caps and floors, deterministic tilt and shuffle.
//

import XCTest
@testable import Dino

final class WorldConstellationTests: XCTestCase {

    // MARK: - Voice contract (lowercase, zero dashes)

    func testVoiceObeysTheContract() {
        for s in WorldConstellationVoice.allFixedStrings {
            XCTAssertEqual(s, s.lowercased(), "'\(s)' breaks lowercase")
            for dash in ["-", "\u{2013}", "\u{2014}"] {
                XCTAssertFalse(s.contains(dash), "'\(s)' contains a dash")
            }
        }
    }

    func testVoicePluralsAndPastVariants() {
        XCTAssertEqual(WorldConstellationVoice.totalLine(total: 1, isToday: true), "1 feeling shared today")
        XCTAssertEqual(WorldConstellationVoice.totalLine(total: 42, isToday: true), "42 feelings shared today")
        XCTAssertEqual(WorldConstellationVoice.totalLine(total: 1, isToday: false), "1 feeling shared this day")
        XCTAssertEqual(WorldConstellationVoice.totalLine(total: 42, isToday: false), "42 feelings shared this day")
        XCTAssertEqual(WorldConstellationVoice.subLine(countries: 1), "across 1 country, under one sky \u{1F30D}")
        XCTAssertEqual(WorldConstellationVoice.subLine(countries: 8), "across 8 countries, under one sky \u{1F30D}")
        XCTAssertEqual(WorldConstellationVoice.bubbleLine(count: 1, isToday: true), "1 dino under this sky tonight")
        XCTAssertEqual(WorldConstellationVoice.bubbleLine(count: 50, isToday: true), "50 dinos under this sky tonight")
        XCTAssertEqual(WorldConstellationVoice.bubbleLine(count: 1, isToday: false), "1 dino was under this sky")
        XCTAssertEqual(WorldConstellationVoice.bubbleLine(count: 50, isToday: false), "50 dinos were under this sky")
    }

    // MARK: - Presence curve

    func testPresenceBoundsAndMonotonicity() {
        XCTAssertEqual(WorldConstellationMath.presence(count: 3, minCount: 3, maxCount: 50), 0)
        XCTAssertEqual(WorldConstellationMath.presence(count: 50, minCount: 3, maxCount: 50), 1)
        var last = -1.0
        for c in stride(from: 3, through: 50, by: 1) {
            let p = WorldConstellationMath.presence(count: c, minCount: 3, maxCount: 50)
            XCTAssertGreaterThanOrEqual(p, 0); XCTAssertLessThanOrEqual(p, 1)
            XCTAssertGreaterThan(p, last, "presence must rise with count")
            last = p
        }
        // sqrt curve: the middle count sits ABOVE linear — small skies stay present
        XCTAssertGreaterThan(WorldConstellationMath.presence(count: 26, minCount: 3, maxCount: 50), 0.5)
    }

    func testFlatDaySitsMid() {
        XCTAssertEqual(WorldConstellationMath.presence(count: 14, minCount: 14, maxCount: 14), 0.5)
        XCTAssertEqual(WorldConstellationMath.fontSize(0.5), 20.5)
    }

    func testFontAndGlowCapsAndFloors() {
        XCTAssertEqual(WorldConstellationMath.fontSize(0), 13)   // floor: clearly present
        XCTAssertEqual(WorldConstellationMath.fontSize(1), 28)   // cap: never blinding
        XCTAssertEqual(WorldConstellationMath.glowOpacity(0), 0.18, accuracy: 0.0001)
        XCTAssertEqual(WorldConstellationMath.glowOpacity(1), 0.55, accuracy: 0.0001)
        XCTAssertEqual(WorldConstellationMath.glowRadius(0), 3)
        XCTAssertEqual(WorldConstellationMath.glowRadius(1), 10)
    }

    // MARK: - Tilt + breathing determinism

    func testTiltBoundedAlternatingDeterministic() {
        for i in 0..<40 {
            let t = WorldConstellationMath.tilt(index: i)
            XCTAssertLessThanOrEqual(abs(t), 1.2)
            XCTAssertGreaterThanOrEqual(abs(t), 0.5)
            XCTAssertEqual(t > 0, i.isMultiple(of: 2), "sign alternates by index")
            XCTAssertEqual(t, WorldConstellationMath.tilt(index: i), "deterministic")
        }
    }

    func testBreatheCyclesInsideTheCalmWindow() {
        for i in 0..<40 {
            let c = WorldConstellationMath.breatheCycle(index: i)
            XCTAssertGreaterThanOrEqual(c, 3.0)
            XCTAssertLessThanOrEqual(c, 4.5)
        }
    }

    // MARK: - Stable shuffle

    func testShuffleIsStableWithinADayAndShiftsAcrossDays() {
        let codes = ["JP", "US", "BR", "DE", "IN", "GB", "AU", "FR", "elsewhere"]
        let a1 = WorldConstellationMath.shuffled(codes: codes, dayKey: "2026-07-12")
        let a2 = WorldConstellationMath.shuffled(codes: codes.shuffled(), dayKey: "2026-07-12")
        XCTAssertEqual(a1, a2, "same day → same sky, regardless of input order")
        XCTAssertEqual(Set(a1), Set(codes), "a permutation, nothing lost")
        let b = WorldConstellationMath.shuffled(codes: codes, dayKey: "2026-07-13")
        XCTAssertNotEqual(a1, b, "tomorrow's sky drifts")
    }

    func testShuffleHandlesTinySkies() {
        XCTAssertEqual(WorldConstellationMath.shuffled(codes: ["JP"], dayKey: "2026-07-12"), ["JP"])
        XCTAssertEqual(WorldConstellationMath.shuffled(codes: [], dayKey: "2026-07-12"), [])
    }
}