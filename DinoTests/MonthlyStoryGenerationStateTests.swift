import XCTest
@testable import Dino

final class MonthlyStoryGenerationStateTests: XCTestCase {
    private func key() throws -> MonthlyStoryGenerationKey {
        MonthlyStoryGenerationKey(uidHash: try MonthlyStoryUIDHash(rawValue: "0123456789abcdef0123456789abcdef"),
                                  monthKey: try MonthlyStoryMonthKey(rawValue: "2026-07"),
                                  generationVersion: try MonthlyStoryGenerationVersion(rawValue: "v1"))
    }

    func testGenerationKeyContainsHashMonthAndVersionOnly() throws {
        XCTAssertEqual(try key().description, "0123456789abcdef0123456789abcdef/2026-07/v1")
        XCTAssertThrowsError(try MonthlyStoryUIDHash(rawValue: "real-user-id"))
        XCTAssertThrowsError(try MonthlyStoryGenerationVersion(rawValue: "unsafe/version"))
    }

    func testHappyPathAndOneCompletionPerKey() throws {
        var state = MonthlyStoryGenerationState(key: try key())
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try state.acquireLease(until: now.addingTimeInterval(300), now: now)
        try state.reserveBudget(micros: 100, monthlyLimitMicros: 1_000)
        try state.recordTextAttempt()
        try state.validateScript()
        try state.completeText(committedMicros: 80)
        XCTAssertEqual(state.phase, .completedText)
        XCTAssertFalse(state.canGenerate)
        XCTAssertThrowsError(try state.acquireLease(until: now.addingTimeInterval(600), now: now))
    }

    func testActiveAndExpiredLeaseBehavior() throws {
        var state = MonthlyStoryGenerationState(key: try key())
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try state.acquireLease(until: now.addingTimeInterval(60), now: now)
        XCTAssertThrowsError(try state.acquireLease(until: now.addingTimeInterval(120), now: now)) { error in
            XCTAssertEqual(error as? MonthlyStoryGenerationTransitionError, .activeLease)
        }
        try state.acquireLease(until: now.addingTimeInterval(180), now: now.addingTimeInterval(61))
    }

    func testAttemptAndBudgetCaps() throws {
        var state = MonthlyStoryGenerationState(key: try key())
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try state.acquireLease(until: now.addingTimeInterval(60), now: now)
        try state.recordTextAttempt()
        try state.recordTextAttempt()
        XCTAssertThrowsError(try state.recordTextAttempt()) { error in
            XCTAssertEqual(error as? MonthlyStoryGenerationTransitionError, .textAttemptLimit)
        }
        XCTAssertThrowsError(try state.reserveBudget(micros: 101, monthlyLimitMicros: 100))

        var budget = try MonthlyStoryBudget(limitMicros: 100)
        try budget.reserve(80)
        try budget.commit(50)
        try budget.release(30)
        XCTAssertEqual(budget.committedMicros, 50)
        XCTAssertEqual(budget.remainingMicros, 50)
        XCTAssertThrowsError(try budget.reserve(51))
    }

    func testTextSurvivesAudioFailureAndAudioAttemptsAreBounded() throws {
        var state = MonthlyStoryGenerationState(key: try key())
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try state.acquireLease(until: now.addingTimeInterval(60), now: now)
        try state.reserveBudget(micros: 200, monthlyLimitMicros: 500)
        try state.recordTextAttempt()
        try state.validateScript()
        try state.completeText(committedMicros: 80)
        try state.recordAudioAttempt()
        try state.recordAudioAttempt()
        XCTAssertThrowsError(try state.recordAudioAttempt())
        XCTAssertEqual(state.phase, .completedText)
    }

    func testDeletedTombstoneAndTerminalFailurePreventRegeneration() throws {
        var deleted = MonthlyStoryGenerationState(key: try key())
        deleted.markDeleted()
        XCTAssertTrue(deleted.isDeletedTombstone)
        XCTAssertFalse(deleted.canGenerate)

        var failed = MonthlyStoryGenerationState(key: try key())
        failed.failTerminally()
        XCTAssertEqual(failed.phase, .terminalFailure)
        XCTAssertFalse(failed.canGenerate)
    }
}
