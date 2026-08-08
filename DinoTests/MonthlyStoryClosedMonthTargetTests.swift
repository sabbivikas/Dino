import XCTest
@testable import Dino

/// The card targets "the most recent CLOSED month", which is not the same as "last calendar
/// month". A month stays open until its evidence freeze — day 3 of the following month, 04:00
/// local — so for the first three days of every month the two answers differ. The old code
/// subtracted one month from `Date()` and stopped, so on 1-3 August it asked for July, which
/// `buildSignal` then refused with `safetyHold` and the card reported as a generic failure.
final class MonthlyStoryClosedMonthTargetTests: XCTestCase {

    private let chicago = try! MonthlyStoryTimeZone(rawValue: "America/Chicago")

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testMostRecentClosedMonthSkipsAMonthThatHasNotFrozenYet() throws {
        // July 2026 freezes at 2026-08-03 04:00 America/Chicago.
        let cases: [(Date, String, String)] = [
            (at(2026, 8, 1, 12), "2026-06", "1 august: july is still open"),
            (at(2026, 8, 2, 12), "2026-06", "2 august: july is still open"),
            (at(2026, 8, 3, 3), "2026-06", "3 august 03:00: one hour before the freeze"),
            (at(2026, 8, 3, 5), "2026-07", "3 august 05:00: july has just closed"),
            (at(2026, 8, 7, 12), "2026-07", "7 august: the day this was reported"),
            (at(2026, 8, 31, 12), "2026-07", "31 august: still july, august is not over")
        ]

        for (now, expected, note) in cases {
            let resolved = try MonthlyStoryCalendar.mostRecentClosedMonth(timeZone: chicago, now: now)
            XCTAssertEqual(resolved.rawValue, expected, note)
            // Whatever it returns must actually be closed. This is the property that matters;
            // the table above is just the worked example of it.
            XCTAssertTrue(try MonthlyStoryCalendar.boundary(for: resolved, timeZone: chicago).isClosed(at: now),
                          "\(note): resolved \(resolved.rawValue) is not closed")
        }
    }

    func testResolvedMonthIsNeverTheCurrentMonthAndIsAlwaysClosed() throws {
        // Sweep every day of a year at two hours, either side of the 04:00 freeze.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        var checked = 0

        for month in 1...12 {
            for day in [1, 2, 3, 4, 15, 28] {
                for hour in [3, 5] {
                    let now = at(2026, month, day, hour)
                    let resolved = try MonthlyStoryCalendar.mostRecentClosedMonth(timeZone: chicago, now: now)
                    let current = try MonthlyStoryCalendar.monthKey(containing: now, timeZone: chicago)

                    XCTAssertLessThan(resolved, current, "resolved the current or a future month")
                    XCTAssertTrue(try MonthlyStoryCalendar.boundary(for: resolved, timeZone: chicago)
                        .isClosed(at: now), "\(resolved.rawValue) was not closed at \(now)")
                    checked += 1
                }
            }
        }

        XCTAssertEqual(checked, 144)
    }

    func testTheClientAndTheSignalCoordinatorAgreeOnTheMonth() async throws {
        // The lookup and the signal used to compute the month independently. If they ever
        // disagree the server rejects the upload, so pin them together.
        let now = at(2026, 8, 7, 12)
        let settings = MonthlyStorySettings(enabled: true, useJournalThemes: false,
                                            useHealthPatterns: false, audioEnabled: false,
                                            timezone: "America/Chicago",
                                            timezoneEffectiveMonth: "2026-07")

        let expected = try MonthlyStoryCalendar.mostRecentClosedMonth(timeZone: chicago, now: now)
        XCTAssertEqual(expected.rawValue, "2026-07")

        // Eight mood days clears the mood-only floor, so buildSignal returns rather than throwing.
        let data = await StubMonthlyStoryLocalEvidence(
            moodEntries: [1, 4, 8, 12, 16, 20, 24, 29].map {
                MonthlyStoryBuildSignalScenario.mood($0, $0.isMultiple(of: 8) ? .drained : .clear)
            })
        let coordinator = await MonthlyStorySignalCoordinator(dataManager: data,
                                                              journalThemeLearningEnabled: false,
                                                              health: StubMonthlyStoryHealth())
        let signal = try await coordinator.buildSignal(settings: settings, now: now)

        XCTAssertEqual(signal.monthKey, expected,
                       "the signal names a different month than the lookup would request")
    }

    func testMonthKeyDisplayNameNamesTheKeysOwnMonth() throws {
        XCTAssertEqual(try MonthlyStoryMonthKey(rawValue: "2026-07").displayName, "July 2026")
        XCTAssertEqual(try MonthlyStoryMonthKey(rawValue: "2026-12").displayName, "December 2026")
        XCTAssertEqual(try MonthlyStoryMonthKey(rawValue: "2026-01").displayName, "January 2026")
    }
}
