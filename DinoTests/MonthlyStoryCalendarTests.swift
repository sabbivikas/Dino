import XCTest
@testable import Dino

final class MonthlyStoryCalendarTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int,
                      timeZone: MonthlyStoryTimeZone) -> Date {
        let calendar = MonthlyStoryCalendar.calendar(timeZone)
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testMonthKeyAndDecemberJanuaryTransition() throws {
        let utc = try MonthlyStoryTimeZone(rawValue: "UTC")
        XCTAssertEqual(try MonthlyStoryCalendar.monthKey(containing: date(2026, 12, 31, 23, timeZone: utc), timeZone: utc).rawValue, "2026-12")
        XCTAssertEqual(try MonthlyStoryCalendar.nextMonth(after: MonthlyStoryMonthKey(rawValue: "2026-12")).rawValue, "2027-01")
    }

    func testLeapYearFebruaryBoundary() throws {
        let utc = try MonthlyStoryTimeZone(rawValue: "UTC")
        let boundary = try MonthlyStoryCalendar.boundary(for: MonthlyStoryMonthKey(rawValue: "2028-02"), timeZone: utc)
        let calendar = MonthlyStoryCalendar.calendar(utc)
        XCTAssertEqual(calendar.component(.day, from: boundary.endExclusive.addingTimeInterval(-1)), 29)
        XCTAssertEqual(try MonthlyStoryCalendar.monthKey(containing: boundary.endExclusive, timeZone: utc).rawValue, "2028-03")
    }

    func testDaylightSavingDoesNotDistortLocalMonthBoundary() throws {
        let zone = try MonthlyStoryTimeZone(rawValue: "America/Chicago")
        let march = try MonthlyStoryCalendar.boundary(for: MonthlyStoryMonthKey(rawValue: "2026-03"), timeZone: zone)
        let calendar = MonthlyStoryCalendar.calendar(zone)
        XCTAssertEqual(calendar.component(.hour, from: march.start), 0)
        XCTAssertEqual(calendar.component(.hour, from: march.endExclusive), 0)
        XCTAssertEqual(calendar.dateComponents([.day], from: march.start, to: march.endExclusive).day, 31)
        XCTAssertNotEqual(march.endExclusive.timeIntervalSince(march.start), 31 * 24 * 60 * 60)
    }

    func testLateSyncDeadlineAndEvidenceFreeze() throws {
        let boundary = try MonthlyStoryCalendar.boundary(for: MonthlyStoryFixtures.month,
                                                        timeZone: MonthlyStoryFixtures.chicago)
        XCTAssertTrue(boundary.acceptsEvidence(receivedAt: boundary.lateSyncDeadline))
        XCTAssertFalse(boundary.acceptsEvidence(receivedAt: boundary.lateSyncDeadline.addingTimeInterval(1)))
        XCTAssertFalse(boundary.isClosed(at: boundary.evidenceFreeze.addingTimeInterval(-1)))
        XCTAssertTrue(boundary.isClosed(at: boundary.evidenceFreeze))
        let calendar = MonthlyStoryCalendar.calendar(MonthlyStoryFixtures.chicago)
        XCTAssertEqual(calendar.component(.day, from: boundary.evidenceFreeze), 3)
        XCTAssertEqual(calendar.component(.hour, from: boundary.evidenceFreeze), 4)
    }

    func testLateArrivingDataBeforeAndAfterFreeze() throws {
        let boundary = try MonthlyStoryCalendar.boundary(for: MonthlyStoryFixtures.month,
                                                        timeZone: MonthlyStoryFixtures.chicago)
        XCTAssertTrue(boundary.acceptsEvidence(receivedAt: boundary.lateSyncDeadline.addingTimeInterval(-1)))
        XCTAssertFalse(boundary.acceptsEvidence(receivedAt: boundary.evidenceFreeze.addingTimeInterval(1)))
    }

    func testTimezoneChangeAppliesBeginningNextMonth() throws {
        let chicago = try MonthlyStoryTimeZone(rawValue: "America/Chicago")
        let tokyo = try MonthlyStoryTimeZone(rawValue: "Asia/Tokyo")
        let july = try MonthlyStoryMonthKey(rawValue: "2026-07")
        let august = try MonthlyStoryMonthKey(rawValue: "2026-08")
        let assignment = try MonthlyStoryCalendar.schedulingTimeZoneChange(from: chicago,
                                                                          to: tokyo,
                                                                          during: july)
        XCTAssertEqual(assignment.timeZone(for: july), chicago)
        XCTAssertEqual(assignment.timeZone(for: august), tokyo)
        XCTAssertEqual(assignment.timeZone(for: try MonthlyStoryMonthKey(rawValue: "2026-09")), tokyo)
    }

    func testAssignedTimezoneIsIndependentFromDeviceTimezone() throws {
        let instant = ISO8601DateFormatter().date(from: "2026-08-01T02:00:00Z")!
        let chicago = try MonthlyStoryTimeZone(rawValue: "America/Chicago")
        let tokyo = try MonthlyStoryTimeZone(rawValue: "Asia/Tokyo")
        XCTAssertEqual(try MonthlyStoryCalendar.monthKey(containing: instant, timeZone: chicago).rawValue, "2026-07")
        XCTAssertEqual(try MonthlyStoryCalendar.monthKey(containing: instant, timeZone: tokyo).rawValue, "2026-08")
    }
}
