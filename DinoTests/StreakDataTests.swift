//
//  StreakDataTests.swift
//  DinoTests
//
//  Deterministic tests for streak day-key formatting, Buddhist-calendar
//  corruption recovery, and the normalization used by the write-back migration.
//

import XCTest
@testable import Dino

final class StreakDataTests: XCTestCase {

    /// Fixed local-noon date for a given Gregorian y/m/d (noon avoids any
    /// midnight/timezone boundary flip on the test machine).
    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = 12
        return cal.date(from: comps)!
    }

    // MARK: - Pinned formatter (Gregorian, independent of device calendar)

    func testDateKeyIsGregorianRegardlessOfDeviceCalendar() {
        let date = noon(2026, 7, 22)
        XCTAssertEqual(StreakData.dateKey(for: date), "2026-07-22")

        // The pinned key stays Gregorian even though a Buddhist-calendar
        // formatter renders the SAME instant with year 2569 (2026 + 543).
        let buddhist = DateFormatter()
        buddhist.calendar = Calendar(identifier: .buddhist)
        buddhist.locale = Locale(identifier: "en_US_POSIX")
        buddhist.dateFormat = "yyyy-MM-dd"
        XCTAssertTrue(buddhist.string(from: date).hasPrefix("2569"),
                      "sanity: Buddhist calendar should render 2569 for a 2026 date")
        XCTAssertTrue(StreakData.dateKey(for: date).hasPrefix("2026"),
                      "pinned formatter must stay Gregorian, not follow the device calendar")
    }

    // MARK: - Recovery correctness (the owner-named case)

    func testBuddhistCorruptedStreakRecoversToConsecutive() {
        let now = noon(2026, 7, 22)
        let corrupted = StreakData(activeDates: ["2569-07-20", "2569-07-21", "2569-07-22"])
        XCTAssertEqual(corrupted.computedCurrentStreak(now: now), 3,
                       "three consecutive Buddhist-corrupted days must recover to a streak of 3")
    }

    func testValidStreakUnaffectedByRecovery() {
        let now = noon(2026, 7, 22)
        let valid = StreakData(activeDates: ["2026-07-20", "2026-07-21", "2026-07-22"])
        XCTAssertEqual(valid.computedCurrentStreak(now: now), 3,
                       "recovery must never harm already-valid data")
    }

    // MARK: - Dedupe

    func testDedupeRecoveredAndValidMergeToOne() {
        let now = noon(2026, 7, 22)
        let normalized = StreakData.normalizedActiveDates(["2569-07-22", "2026-07-22"], now: now)
        XCTAssertEqual(normalized, ["2026-07-22"],
                       "a recovered 2569 key must merge with the equivalent 2026 key")
    }

    // MARK: - Fail-safe (unrecoverable / malformed → dropped, no crash)

    func testUnrecoverableAndMalformedKeysAreDropped() {
        let now = noon(2026, 7, 22)
        let raw: Set<String> = [
            "9999-01-01",   // high, but 9999-543 = 9456 still implausible → drop
            "1999-01-01",   // implausibly low, not high → drop
            "not-a-date",   // malformed → drop
            "2026-13-40",   // out-of-range month/day → drop
            "2026-07-22"    // the one valid key survives
        ]
        let normalized = StreakData.normalizedActiveDates(raw, now: now)
        XCTAssertEqual(normalized, ["2026-07-22"],
                       "only the valid key survives; garbage is dropped, never kept")
    }

    // MARK: - Migration write-back: bounded, plausible-only, idempotent

    func testNormalizationYieldsOnlyPlausibleYearsAndIsIdempotent() {
        let now = noon(2026, 7, 22)
        let mixed: Set<String> = ["2569-07-22", "2026-07-20", "garbage", "1999-01-01"]
        let first = StreakData.normalizedActiveDates(mixed, now: now)
        XCTAssertEqual(first, ["2026-07-22", "2026-07-20"])

        // Every surviving key parses to a plausible Gregorian year.
        for key in first {
            let year = Int(key.split(separator: "-")[0])!
            XCTAssertTrue(year >= 2015 && year <= 2027, "key \(key) has an implausible year")
        }

        // Idempotent: normalizing an already-clean set is a no-op.
        let second = StreakData.normalizedActiveDates(first, now: now)
        XCTAssertEqual(first, second, "normalization must be idempotent")
    }
}
