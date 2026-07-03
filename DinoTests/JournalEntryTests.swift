//
//  JournalEntryTests.swift
//  DinoTests
//
//  Tests for the entry-date feature: legacy decoding (no createdAt),
//  createdAt round-trip, and display sorting by user-chosen date.
//

import XCTest
@testable import Dino

final class JournalEntryTests: XCTestCase {

    private func entry(id: UUID = UUID(), date: Date, createdAt: Date?) -> JournalEntry {
        JournalEntry(id: id, date: date, audioFileName: "", title: "t",
                     summary: "s", createdAt: createdAt)
    }

    // 1) Legacy docs (no createdAt key) decode with nil → effectiveCreatedAt falls back to date.
    func testLegacyDecodeWithoutCreatedAt() throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","date":\(day.timeIntervalSinceReferenceDate),
         "audioFileName":"","title":"old","summary":"words","moodTag":"reflective",
         "isFavorite":false,"durationSeconds":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JournalEntry.self, from: legacyJSON)
        XCTAssertNil(decoded.createdAt)
        XCTAssertEqual(decoded.effectiveCreatedAt, decoded.date)
    }

    // 2) createdAt survives an encode/decode round-trip.
    func testCreatedAtRoundTrip() throws {
        let written = Date(timeIntervalSince1970: 1_700_000_000)
        let backdated = written.addingTimeInterval(-86_400)
        let original = entry(date: backdated, createdAt: written)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JournalEntry.self, from: data)
        XCTAssertEqual(decoded.createdAt, written)
        XCTAssertEqual(decoded.date, backdated)
        XCTAssertEqual(decoded.effectiveCreatedAt, written)
    }

    // 3) Display sorting: user-chosen date wins over write time.
    func testSortedForDisplayByEntryDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = now.addingTimeInterval(-86_400)
        let lastWeek = now.addingTimeInterval(-7 * 86_400)
        // written TODAY but backdated to last week → must sort below yesterday's
        let backdated = entry(date: lastWeek, createdAt: now)
        let yesterdays = entry(date: yesterday, createdAt: yesterday)
        let todays = entry(date: now, createdAt: now)
        let sorted = JournalEntry.sortedForDisplay([backdated, todays, yesterdays])
        XCTAssertEqual(sorted.map(\.id), [todays.id, yesterdays.id, backdated.id])
    }

    // 4) Same-day ties break by actual write time (newest written first).
    func testSortedForDisplaySameDayTieBreak() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let morning = entry(date: day, createdAt: day.addingTimeInterval(-3_600))
        let evening = entry(date: day, createdAt: day)
        let legacy = entry(date: day, createdAt: nil)   // effectiveCreatedAt == day
        let sorted = JournalEntry.sortedForDisplay([morning, legacy, evening])
        // morning (written earliest) must sort last; evening and legacy have
        // EQUAL keys (legacy falls back to its date == evening's write time),
        // so only their membership up front is guaranteed, not their order.
        XCTAssertEqual(sorted.last?.id, morning.id)
        XCTAssertEqual(Set(sorted.prefix(2).map(\.id)), Set([evening.id, legacy.id]))
    }
}
