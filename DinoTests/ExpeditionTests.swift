//
//  ExpeditionTests.swift
//  DinoTests
//
//  F1's pure parts: the bucketizers (raw numbers stop at the device edge),
//  on device eligibility (crisis first and absolute), and the two ignore
//  cooloff.
//

import XCTest
@testable import Dino

final class ExpeditionTests: XCTestCase {

    private let suite = "expedition-tests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - Bucketizers (enum out, never a number)

    func testHeavyDayBuckets() {
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(0), "0")
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(1), "1")
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(2), "2to3")
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(3), "2to3")
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(7), "4plus")
    }

    func testSleepBuckets() {
        XCTAssertEqual(ExpeditionSignals.sleepBucket(hours: nil), "none")
        XCTAssertEqual(ExpeditionSignals.sleepBucket(hours: 4.5), "short")
        XCTAssertEqual(ExpeditionSignals.sleepBucket(hours: 7.5), "ok")
        XCTAssertEqual(ExpeditionSignals.sleepBucket(hours: 10.0), "long")
    }

    func testStepsBuckets() {
        XCTAssertEqual(ExpeditionSignals.stepsBucket(steps: nil), "none")
        XCTAssertEqual(ExpeditionSignals.stepsBucket(steps: 1200), "low")
        XCTAssertEqual(ExpeditionSignals.stepsBucket(steps: 5000), "mid")
        XCTAssertEqual(ExpeditionSignals.stepsBucket(steps: 12000), "high")
    }

    func testDaysSinceBuckets() {
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(nil), "14plus")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(0), "0to2")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(2), "0to2")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(5), "3to7")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(10), "8to13")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(30), "14plus")
    }

    func testTrendMatchesTheRecBucketExactly() {
        for n in 0...7 {
            XCTAssertEqual(ExpeditionSignals.moodTrendBucket(heavyDays: n),
                           ComfortRecTrend.bucket(heavyDaysInLastWeek: n))
        }
    }

    // MARK: - Eligibility (crisis first and absolute)

    func testCrisisWindowBlocksEverything() {
        XCTAssertFalse(ExpeditionSignals.isEligible(heavyDays: 5, crisisDate: Date(),
                                                    defaults: defaults))
    }

    func testNoHeavySignalMeansNoCohort() {
        XCTAssertFalse(ExpeditionSignals.isEligible(heavyDays: 0, crisisDate: nil,
                                                    defaults: defaults))
        XCTAssertTrue(ExpeditionSignals.isEligible(heavyDays: 1, crisisDate: nil,
                                                   defaults: defaults))
    }

    func testToggleOffMeansQuiet() {
        defaults.set(false, forKey: ExpeditionSignals.enabledKey)
        XCTAssertFalse(ExpeditionSignals.isEligible(heavyDays: 5, crisisDate: nil,
                                                    defaults: defaults))
    }

    func testTwoIgnoresEarnAThirtyDayCooloff() {
        XCTAssertTrue(ExpeditionSignals.isEligible(heavyDays: 3, crisisDate: nil, defaults: defaults))
        ExpeditionSignals.recordIgnore(defaults: defaults)
        XCTAssertTrue(ExpeditionSignals.isEligible(heavyDays: 3, crisisDate: nil, defaults: defaults),
                      "one ignore is not a signal yet")
        ExpeditionSignals.recordIgnore(defaults: defaults)
        XCTAssertFalse(ExpeditionSignals.isEligible(heavyDays: 3, crisisDate: nil, defaults: defaults),
                       "two ignores → 30 day quiet")
        // and the counter reset so a return is possible after the cooloff
        XCTAssertEqual(defaults.integer(forKey: ExpeditionSignals.ignoreCountKey), 0)
    }
}
