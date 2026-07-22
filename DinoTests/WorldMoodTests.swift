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

    // 6a) Post-log moment line: percentages, warm copy, quiet-world nil.
    @MainActor func testWorldMomentLine() {
        let bucket = WorldDayBucket.parse([
            "global": ["clear": 58, "partlyCloudy": 20, "overwhelmed": 12, "drained": 10, "total": 100],
            "countries": [:],
        ])
        XCTAssertEqual(WorldMoodService.worldMomentLine(mood: .clear, bucket: bucket),
                       "you and 58% of dinos are clear today ✨")
        XCTAssertEqual(WorldMoodService.worldMomentLine(mood: .overwhelmed, bucket: bucket),
                       "you're not alone. 12% of dinos are under clouds today")
        // no aggregate → nothing (never blocks logging)
        XCTAssertNil(WorldMoodService.worldMomentLine(mood: .clear, bucket: nil))
        // too quiet (< 5 logs) → nothing
        let quiet = WorldDayBucket.parse(["global": ["clear": 2, "total": 2], "countries": [:]])
        XCTAssertNil(WorldMoodService.worldMomentLine(mood: .clear, bucket: quiet))
        // 0% of the logged mood → nothing rather than "0%"
        let none = WorldDayBucket.parse(["global": ["clear": 10, "total": 10], "countries": [:]])
        XCTAssertNil(WorldMoodService.worldMomentLine(mood: .drained, bucket: none))
    }

    // 6) Day key is UTC-Gregorian regardless of device calendar or timezone
    //    (the world-globe calendar fix: write, lookup, and server buckets all
    //    share one UTC clock; device calendars like Buddhist year 2569 must
    //    never leak into keys).
    @MainActor func testTodayKeyIsUTCGregorian() {
        var chicago = Calendar(identifier: .gregorian)
        chicago.timeZone = TimeZone(identifier: "America/Chicago")!
        // 23:50 in Chicago is already the NEXT day in UTC (04:50Z)
        let lateNight = chicago.date(from: DateComponents(timeZone: chicago.timeZone, year: 2026, month: 7, day: 3, hour: 23, minute: 50))!
        XCTAssertEqual(WorldMoodService.todayKey(now: lateNight, calendar: chicago), "2026-07-04")

        // A Buddhist-calendar device (year 2569) still produces Gregorian keys.
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        XCTAssertEqual(WorldMoodService.todayKey(now: lateNight, calendar: buddhist), "2026-07-04")

        // Mid-day UTC stays the same UTC day.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let noon = utc.date(from: DateComponents(timeZone: utc.timeZone, year: 2026, month: 7, day: 3, hour: 12))!
        XCTAssertEqual(WorldMoodService.todayKey(now: noon), "2026-07-03")
    }

    // 7) dayKey → Date parser is the exact inverse of todayKey (Gregorian+UTC).
    @MainActor func testDayKeyParserRoundTrip() {
        let date = WorldMoodService.date(fromDayKey: "2026-07-04")
        XCTAssertNotNil(date)
        XCTAssertEqual(WorldMoodService.todayKey(now: date!), "2026-07-04")
        // UTC midnight exactly
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(date, utc.date(from: DateComponents(timeZone: utc.timeZone, year: 2026, month: 7, day: 4)))
        XCTAssertNil(WorldMoodService.date(fromDayKey: "junk"))
    }
}
