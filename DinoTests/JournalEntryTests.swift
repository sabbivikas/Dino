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

    // 3a) Cross-year ordering — no same-year assumption anywhere.
    func testSortedAcrossYearBoundary() {
        var c = DateComponents(); c.year = 2025; c.month = 12; c.day = 31; c.hour = 12
        let cal = Calendar(identifier: .gregorian)
        let dec2025 = cal.date(from: c)!
        c.year = 2026; c.month = 1; c.day = 1
        let jan2026 = cal.date(from: c)!
        let older = entry(date: dec2025, createdAt: dec2025)
        let newer = entry(date: jan2026, createdAt: jan2026)
        let sorted = JournalEntry.sortedForDisplay([older, newer])
        XCTAssertEqual(sorted.map(\.id), [newer.id, older.id])
    }

    // 3b) Midnight boundary: 11:50pm sorts below the next day's 12:10am —
    //     pure Date comparison, no day-string involvement.
    func testSortedAcrossMidnightBoundary() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let lateNight = base                                     // 23:50 conceptually
        let earlyNext = base.addingTimeInterval(20 * 60)         // 00:10 next local day
        let a = entry(date: lateNight, createdAt: lateNight)
        let b = entry(date: earlyNext, createdAt: earlyNext)
        XCTAssertEqual(JournalEntry.sortedForDisplay([a, b]).first?.id, b.id)
    }

    // 3c) Sync-shuffle regression: any permutation of the input yields the
    //     IDENTICAL display order — including equal-key legacy entries.
    func testSortIsPermutationInvariantAndTotal() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        // two legacy entries with IDENTICAL date + nil createdAt → only the id
        // tie-break keeps them deterministic
        let twinA = entry(date: day, createdAt: nil)
        let twinB = entry(date: day, createdAt: nil)
        let others = (1...5).map { i in
            entry(date: day.addingTimeInterval(Double(i) * 3_600), createdAt: day)
        }
        let original = others + [twinA, twinB]
        let sortedOnce = JournalEntry.sortedForDisplay(original)
        XCTAssertEqual(JournalEntry.sortedForDisplay(original.reversed()).map(\.id), sortedOnce.map(\.id))
        XCTAssertEqual(JournalEntry.sortedForDisplay(original.shuffled()).map(\.id), sortedOnce.map(\.id))
        XCTAssertEqual(JournalEntry.sortedForDisplay(sortedOnce).map(\.id), sortedOnce.map(\.id))   // idempotent
    }

    // 3d) A (legacy/synced) future-dated entry must not crash and sorts first
    //     honestly until its date passes — the pickers block creating new ones.
    func testFutureDatedEntryDoesNotCrash() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let future = entry(date: now.addingTimeInterval(30 * 86_400), createdAt: now)
        let normal = entry(date: now, createdAt: now)
        let sorted = JournalEntry.sortedForDisplay([normal, future])
        XCTAssertEqual(sorted.first?.id, future.id)
        XCTAssertEqual(sorted.count, 2)
    }

    // 4) Same-day ties break by actual write time (newest written first).
    func testSortedForDisplaySameDayTieBreak() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let morning = entry(date: day, createdAt: day.addingTimeInterval(-3_600))
        let evening = entry(date: day, createdAt: day)
        let legacy = entry(date: day, createdAt: nil)   // effectiveCreatedAt == day
        let sorted = JournalEntry.sortedForDisplay([morning, legacy, evening])
        // morning (written earliest) must sort last; evening and legacy tie on
        // both keys and fall to the deterministic id tie-break.
        XCTAssertEqual(sorted.last?.id, morning.id)
        XCTAssertEqual(Set(sorted.prefix(2).map(\.id)), Set([evening.id, legacy.id]))
        // and that tie is STABLE across permutations (no launch-to-launch flip)
        let reversed = JournalEntry.sortedForDisplay([evening, legacy, morning])
        XCTAssertEqual(reversed.map(\.id), sorted.map(\.id))
    }
}
