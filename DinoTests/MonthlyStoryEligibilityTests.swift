import XCTest
@testable import Dino

final class MonthlyStoryEligibilityTests: XCTestCase {
    private var afterFreeze: Date {
        let boundary = try! MonthlyStoryCalendar.boundary(for: MonthlyStoryFixtures.month,
                                                         timeZone: MonthlyStoryFixtures.chicago)
        return boundary.evidenceFreeze.addingTimeInterval(60)
    }

    private func context(timeZone: String = "America/Chicago",
                         date: Date? = nil,
                         completed: Bool = false,
                         deleted: Bool = false,
                         validBoundary: Bool = true) -> MonthlyStoryEligibilityContext {
        MonthlyStoryEligibilityContext(storedTimeZoneIdentifier: timeZone,
                                       evaluatedAt: date ?? afterFreeze,
                                       hasCompletedStory: completed,
                                       hasDeletedTombstone: deleted,
                                       hasValidMonthBoundary: validBoundary)
    }

    func testStandardAndMoodOnlyEligibility() {
        let standard = MonthlyStoryEligibility.evaluate(signal: MonthlyStoryFixtures.richMonth, context: context())
        XCTAssertEqual(standard, MonthlyStoryEligibilitySnapshot(code: .eligibleStandard, permitsCauseNarration: true))

        let moodOnly = MonthlyStoryEligibility.evaluate(signal: MonthlyStoryFixtures.moodOnlyMonth, context: context())
        XCTAssertEqual(moodOnly, MonthlyStoryEligibilitySnapshot(code: .eligibleMoodOnly, permitsCauseNarration: false))
    }

    func testTerminalAndSafetyReasons() throws {
        let disabled = try MonthlyStoryFixtures.signal(permissions: MonthlyStoryPermissions(featureEnabled: false,
                                                                                           journalThemesEnabled: false,
                                                                                           healthPatternsEnabled: false,
                                                                                           audioEnabled: false),
                                                       evidence: [])
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: disabled, context: context()).code, .featureDisabled)
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: MonthlyStoryFixtures.sensitiveMonth, context: context()).code, .safetyHold)
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: MonthlyStoryFixtures.richMonth, context: context(completed: true)).code, .alreadyCompleted)
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: MonthlyStoryFixtures.richMonth, context: context(deleted: true)).code, .deletedTombstone)
    }

    func testInvalidBoundaryTimeZoneAndOpenMonthReasons() throws {
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: MonthlyStoryFixtures.richMonth,
                                                        context: context(timeZone: "Not/AZone")).code, .invalidTimezone)
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: MonthlyStoryFixtures.richMonth,
                                                        context: context(validBoundary: false)).code, .invalidMonthBoundary)
        let boundary = try MonthlyStoryCalendar.boundary(for: MonthlyStoryFixtures.month,
                                                        timeZone: MonthlyStoryFixtures.chicago)
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: MonthlyStoryFixtures.richMonth,
                                                        context: context(date: boundary.endExclusive)).code, .monthNotClosed)
    }

    func testInsufficientSpanEvidenceMoodCorroborationAndObservations() throws {
        let short = try MonthlyStoryFixtures.signal(usable: [1, 2, 3, 4, 5, 10],
                                                   moods: [1, 2, 3, 4],
                                                   corroborating: [5, 10],
                                                   evidence: [
                                                    MonthlyStoryFixtures.evidence("short-a", value: .emotionalShape(.mixed, .steady), startDay: MonthlyStoryFixtures.day(1), endDay: MonthlyStoryFixtures.day(10)),
                                                    MonthlyStoryFixtures.evidence("short-b", value: .restorativePractice(.focus), startDay: MonthlyStoryFixtures.day(1), endDay: MonthlyStoryFixtures.day(10))
                                                   ],
                                                   startDay: MonthlyStoryFixtures.day(1),
                                                   endDay: MonthlyStoryFixtures.day(10))
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: short, context: context()).code, .insufficientSpan)

        let fewDays = try MonthlyStoryFixtures.signal(usable: [1, 9, 20, 29], moods: [1, 9, 20, 29], corroborating: [])
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: fewDays, context: context()).code, .insufficientEvidenceDays)

        let fewMoods = try MonthlyStoryFixtures.signal(usable: [1, 5, 9, 14, 20, 29], moods: [1, 9, 29], corroborating: [5, 14])
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: fewMoods, context: context()).code, .insufficientMoodDays)

        let noCorroboration = try MonthlyStoryFixtures.signal(corroborating: [])
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: noCorroboration, context: context()).code, .insufficientCorroboration)

        let weak = try MonthlyStoryFixtures.signal(evidence: [
            MonthlyStoryFixtures.evidence("weak-a", value: .emotionalShape(.mixed, .steady), confidence: .medium),
            MonthlyStoryFixtures.evidence("weak-b", value: .restorativePractice(.focus), confidence: .low)
        ])
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: weak, context: context()).code, .insufficientObservations)
    }

    func testNewUserAndReturningUser() throws {
        let newUser = try MonthlyStoryFixtures.signal(usable: [16, 17, 18, 19, 20, 21],
                                                     moods: [16, 17, 18, 19],
                                                     corroborating: [20, 21],
                                                     evidence: [
                                                        MonthlyStoryFixtures.evidence("new-a", value: .emotionalShape(.mixed, .steady), startDay: MonthlyStoryFixtures.day(16), endDay: MonthlyStoryFixtures.day(21)),
                                                        MonthlyStoryFixtures.evidence("new-b", value: .restorativePractice(.focus), startDay: MonthlyStoryFixtures.day(16), endDay: MonthlyStoryFixtures.day(21))
                                                     ],
                                                     startDay: MonthlyStoryFixtures.day(16),
                                                     endDay: MonthlyStoryFixtures.day(21))
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: newUser, context: context()).code, .insufficientSpan)
        XCTAssertEqual(MonthlyStoryEligibility.evaluate(signal: MonthlyStoryFixtures.richMonth, context: context()).code, .eligibleStandard)
    }
}

private extension MonthlyStoryFixtures {
    static func evidence(_ suffix: String,
                         value: MonthlyStoryEvidenceValue,
                         confidence: MonthlyStoryConfidence = .high,
                         source: MonthlyStoryEvidenceSource = .deterministicCombination,
                         allowed: Bool = true,
                         startDay: MonthlyStoryDay,
                         endDay: MonthlyStoryDay) -> MonthlyStoryEvidence {
        try! MonthlyStoryEvidence(id: MonthlyStoryEvidenceID(rawValue: "evidence-\(suffix)"),
                                  value: value,
                                  confidence: confidence,
                                  startDay: startDay,
                                  endDay: endDay,
                                  source: source,
                                  allowedForNarration: allowed)
    }
}
