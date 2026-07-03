//
//  WorldMoodTests.swift
//  DinoTests
//
//  Deterministic tests for the DINO WORLD data layer's pure functions:
//  aggregate parsing, share/dominant math, and country-code validation.
//

import XCTest
@testable import Dino

final class WorldMoodTests: XCTestCase {

    // 1) Counts parse + derived total.
    func testCountsParse() {
        let c = WorldMoodCounts.parse(["clear": 4, "partlyCloudy": 3, "overwhelmed": 2, "drained": 1, "total": 10])
        XCTAssertEqual(c.clear, 4)
        XCTAssertEqual(c.total, 10)
        // total derived when missing
        let d = WorldMoodCounts.parse(["clear": 2, "drained": 1])
        XCTAssertEqual(d.total, 3)
    }

    // 2) Share math, empty-safe.
    func testShare() {
        let c = WorldMoodCounts.parse(["clear": 3, "drained": 1, "total": 4])
        XCTAssertEqual(c.share(of: .clear), 0.75, accuracy: 1e-9)
        XCTAssertEqual(WorldMoodCounts().share(of: .clear), 0, accuracy: 1e-9)
    }

    // 3) Dominant mood, nil when empty.
    func testDominantMood() {
        let c = WorldMoodCounts.parse(["clear": 1, "overwhelmed": 5, "total": 6])
        XCTAssertEqual(c.dominantMood, .overwhelmed)
        XCTAssertNil(WorldMoodCounts().dominantMood)
    }

    // 4) Full aggregate parse: days, countries, malformed entries skipped.
    func testAggregateParse() {
        let data: [String: Any] = [
            "days": [
                "2026-07-03": [
                    "global": ["clear": 10, "total": 10],
                    "countries": [
                        "US": ["clear": 6, "total": 6],
                        "elsewhere": ["clear": 4, "total": 4],
                        "bad": "not-a-dict",
                    ],
                ],
                "junkKey": ["global": [:]],   // wrong length → skipped
            ],
        ]
        let agg = WorldAggregate.parse(data)
        XCTAssertEqual(agg.days.count, 1)
        let day = agg.bucket(for: "2026-07-03")
        XCTAssertEqual(day?.global.total, 10)
        XCTAssertEqual(day?.countries["US"]?.clear, 6)
        XCTAssertEqual(day?.countries["elsewhere"]?.total, 4)
        XCTAssertNil(day?.countries["bad"])
        XCTAssertEqual(agg.sortedDayKeys, ["2026-07-03"])
    }

    // 5) Country-code validation → "elsewhere" fallback.
    @MainActor func testCountryCodeValidation() {
        XCTAssertEqual(WorldMoodService.countryCode(from: "us"), "US")
        XCTAssertEqual(WorldMoodService.countryCode(from: "JP"), "JP")
        XCTAssertEqual(WorldMoodService.countryCode(from: nil), "elsewhere")
        XCTAssertEqual(WorldMoodService.countryCode(from: "USA"), "elsewhere")
        XCTAssertEqual(WorldMoodService.countryCode(from: "1A"), "elsewhere")
        XCTAssertEqual(WorldMoodService.countryCode(from: ""), "elsewhere")
    }

    // 6) Local-day key formatting.
    @MainActor func testTodayKey() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let d = cal.date(from: DateComponents(timeZone: cal.timeZone, year: 2026, month: 7, day: 3, hour: 23, minute: 50))!
        XCTAssertEqual(WorldMoodService.todayKey(now: d, calendar: cal), "2026-07-03")
    }
}
