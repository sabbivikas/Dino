//
//  WorldRedesignTests.swift
//  DinoTests
//
//  The world redesign's pure parts: voice contract, bar/glow sizing bounds,
//  and the top-5/rest ranking across the three data shapes.
//

import XCTest
@testable import Dino

final class WorldRedesignTests: XCTestCase {

    private func counts(_ total: Int) -> WorldMoodCounts {
        var c = WorldMoodCounts(); c.clear = total; c.total = total; return c
    }

    // MARK: - Voice contract

    func testVoiceObeysTheContract() {
        for s in WorldRedesignVoice.allFixedStrings {
            XCTAssertEqual(s, s.lowercased(), "'\(s)' breaks lowercase")
            for dash in ["-", "\u{2013}", "\u{2014}"] {
                XCTAssertFalse(s.contains(dash), "'\(s)' contains a dash")
            }
        }
    }

    func testNumberSplitMatchesTheKeptConstellationLine() {
        // the split number+suffix must equal the existing full line, so the
        // past-day variants stay in sync
        for total in [1, 7, 42] {
            for isToday in [true, false] {
                let composed = WorldRedesignVoice.totalNumber(total)
                    + WorldRedesignVoice.totalSuffix(total: total, isToday: isToday)
                XCTAssertEqual(composed,
                    WorldConstellationVoice.totalLine(total: total, isToday: isToday))
            }
        }
    }

    func testRowCountPluralAndPastVariants() {
        XCTAssertEqual(WorldRedesignVoice.rowCount(22, isToday: true), "22 tonight")
        XCTAssertEqual(WorldRedesignVoice.rowCount(1, isToday: false), "1 that day")
    }

    func testGallerySublinePlurals() {
        XCTAssertEqual(WorldRedesignVoice.gallerySubline(total: 1, countries: 1),
                       "1 kindness kept, from 1 country")
        XCTAssertEqual(WorldRedesignVoice.gallerySubline(total: 9, countries: 4),
                       "9 kindnesses kept, from 4 countries")
        XCTAssertEqual(WorldRedesignVoice.gallerySubline(total: 3, countries: 1),
                       "3 kindnesses kept, from 1 country")
    }

    // MARK: - Bar + glow sizing

    func testBarFractionBoundsAndFloor() {
        XCTAssertEqual(WorldCountryLayout.barFraction(count: 100, max: 100), 1.0, accuracy: 0.0001)
        XCTAssertEqual(WorldCountryLayout.barFraction(count: 1, max: 100), 0.10, accuracy: 0.0001,
                       "tiny country floored to 10%")
        // sqrt curve: mid count sits above linear so small skies stay present
        XCTAssertGreaterThan(WorldCountryLayout.barFraction(count: 25, max: 100), 0.25)
        // never exceeds 1 even on odd data
        XCTAssertLessThanOrEqual(WorldCountryLayout.barFraction(count: 200, max: 100), 1.0)
    }

    func testBarFractionMonotonic() {
        var last = -1.0
        for c in stride(from: 1, through: 100, by: 1) {
            let f = WorldCountryLayout.barFraction(count: c, max: 100)
            XCTAssertGreaterThanOrEqual(f, last)
            last = f
        }
    }

    func testGlowRadiusStaysCalm() {
        XCTAssertEqual(WorldCountryLayout.glowRadius(count: 100, max: 100), 11, accuracy: 0.001)
        XCTAssertGreaterThan(WorldCountryLayout.glowRadius(count: 1, max: 100), 0)
        XCTAssertLessThanOrEqual(WorldCountryLayout.glowRadius(count: 100, max: 100), 12)
    }

    func testEmptyDayFractionIsFloor() {
        XCTAssertEqual(WorldCountryLayout.barFraction(count: 0, max: 0), 0.10)
    }

    // MARK: - Ranking (top 5 + the quieter lights)

    func testManyCountriesSplitTopFiveAndRest() {
        var m: [String: WorldMoodCounts] = [:]
        for (i, code) in ["JP","US","BR","DE","IN","GB","FR"].enumerated() {
            m[code] = counts(70 - i * 5)
        }
        m["elsewhere"] = counts(3)
        let parts = WorldCountryLayout.split(m)
        XCTAssertEqual(parts.top.map(\.code), ["JP","US","BR","DE","IN"], "top 5 by volume, desc")
        XCTAssertEqual(Set(parts.rest.map(\.code)), Set(["GB","FR","elsewhere"]))
        XCTAssertEqual(parts.rest.last?.code, "elsewhere", "the catch-all folds into the quiet lights")
    }

    func testOneGiantCountryDay() {
        let m: [String: WorldMoodCounts] = ["JP": counts(500), "US": counts(2)]
        let parts = WorldCountryLayout.split(m)
        XCTAssertEqual(parts.top.map(\.code), ["JP","US"])
        XCTAssertTrue(parts.rest.isEmpty, "no expander when everyone fits in the top 5")
        // the giant is full-width, the tiny is floored but present
        XCTAssertEqual(WorldCountryLayout.barFraction(count: 500, max: 500), 1.0, accuracy: 0.0001)
        XCTAssertEqual(WorldCountryLayout.barFraction(count: 2, max: 500), 0.10, accuracy: 0.0001)
    }

    func testSingleCountryDay() {
        let parts = WorldCountryLayout.split(["JP": counts(14)])
        XCTAssertEqual(parts.top.map(\.code), ["JP"])
        XCTAssertTrue(parts.rest.isEmpty)
        XCTAssertEqual(WorldCountryLayout.barFraction(count: 14, max: 14), 1.0, accuracy: 0.0001)
    }
}
