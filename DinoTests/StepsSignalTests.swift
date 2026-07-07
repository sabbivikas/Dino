//
//  StepsSignalTests.swift
//  DinoTests
//
//  Pure-logic coverage for the steps feature: card read rules, garden blend,
//  nudge bucket, movement-mood correlation gates, and the independence of the
//  two Health ask-flags.
//

import XCTest
@testable import Dino

final class StepsSignalTests: XCTestCase {

    // MARK: - Baseline

    func testBaselineNilUnderSevenPositiveDays() {
        XCTAssertNil(StepsSignal.baseline(history: []))
        XCTAssertNil(StepsSignal.baseline(history: [5000, 5000, 5000, 5000, 5000, 5000]))
        // zeros (phone-off days) don't count toward the seven
        XCTAssertNil(StepsSignal.baseline(history: [5000, 5000, 5000, 5000, 5000, 5000, 0, 0]))
    }

    func testBaselineIsMedianOfPositiveDays() {
        let history: [Double] = [1000, 2000, 3000, 4000, 5000, 6000, 7000]
        XCTAssertEqual(StepsSignal.baseline(history: history), 4000)
        // even count → average of middle two; zero excluded
        let even: [Double] = [0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000]
        XCTAssertEqual(StepsSignal.baseline(history: even), 4500)
    }

    // MARK: - Card read rules

    private let steadyMonth: [Double] = Array(repeating: 5000, count: 30)

    func testBuildingWithThinHistory() {
        XCTAssertEqual(StepsSignal.read(today: 4200, history: [5000, 6000]), .building)
    }

    func testBusiestWhenWeekMaxAndAboveMedian() {
        // median 5000; today 8000 beats the prior six days and clears 1.1×
        XCTAssertEqual(StepsSignal.read(today: 8000, history: steadyMonth), .busiest)
    }

    func testFlatWeekGetsNoHollowCrown() {
        // today (5100) IS the week's max but ≤ 1.1× median — neutral, not busiest
        XCTAssertEqual(StepsSignal.read(today: 5100, history: steadyMonth), .neutral)
    }

    func testHighWhenNotWeekMax() {
        // 1.4× median cleared, but a prior day in the week was bigger
        var history = steadyMonth
        history[29] = 9000
        XCTAssertEqual(StepsSignal.read(today: 7500, history: history), .high)
    }

    func testQuietDay() {
        XCTAssertEqual(StepsSignal.read(today: 2000, history: steadyMonth), .quiet)
    }

    func testNeutralDay() {
        XCTAssertEqual(StepsSignal.read(today: 5000, history: steadyMonth), .neutral)
    }

    func testQuietThresholdIsRelativeToOwnMedian() {
        // a low-mobility rhythm: median 800 — 600 steps is a NEUTRAL day for them
        let lowMobility: [Double] = Array(repeating: 800, count: 30)
        XCTAssertEqual(StepsSignal.read(today: 600, history: lowMobility), .neutral)
        XCTAssertEqual(StepsSignal.read(today: 300, history: lowMobility), .quiet)
    }

    // MARK: - Insight gating (tone guardrail)

    private func correlation(lift: Double) -> PracticeCorrelation {
        PracticeCorrelation(withMoodMean: 3.0 * lift, withoutMoodMean: 3.0, liftRatio: lift)
    }

    func testInsightNeverShownOnQuietDay() {
        XCTAssertFalse(StepsSignal.shouldShowInsight(read: .quiet, correlation: correlation(lift: 2.0)))
        XCTAssertFalse(StepsSignal.shouldShowInsight(read: .building, correlation: correlation(lift: 2.0)))
    }

    func testInsightShownOnNeutralOrActiveDaysWithConfidentLift() {
        XCTAssertTrue(StepsSignal.shouldShowInsight(read: .neutral, correlation: correlation(lift: 1.2)))
        XCTAssertTrue(StepsSignal.shouldShowInsight(read: .busiest, correlation: correlation(lift: 1.2)))
        XCTAssertTrue(StepsSignal.shouldShowInsight(read: .high, correlation: correlation(lift: 1.2)))
    }

    func testInsightSuppressedWithoutLiftOrCorrelation() {
        XCTAssertFalse(StepsSignal.shouldShowInsight(read: .neutral, correlation: correlation(lift: 1.05)))
        XCTAssertFalse(StepsSignal.shouldShowInsight(read: .neutral, correlation: nil))
    }

    // MARK: - Garden blend

    func testGardenBonusScalesAndCaps() {
        XCTAssertEqual(StepsSignal.gardenBonus(movementDays: 0), 0)
        XCTAssertEqual(StepsSignal.gardenBonus(movementDays: 10), 2.0, accuracy: 1e-9)
        XCTAssertEqual(StepsSignal.gardenBonus(movementDays: 30), 6.0)   // capped
        XCTAssertEqual(StepsSignal.gardenBonus(movementDays: 90), 6.0)   // still capped
        XCTAssertEqual(StepsSignal.gardenBonus(movementDays: -3), 0)     // never negative
    }

    func testBlendedGrowthNeverPunishesAndNeverExceedsOne() {
        // no data → exactly the practice-only growth
        XCTAssertEqual(StepsSignal.blendedGrowth(totalSessions: 10, movementDays: 0), 10.0 / 62.0, accuracy: 1e-9)
        // movement only ever adds
        XCTAssertGreaterThan(StepsSignal.blendedGrowth(totalSessions: 10, movementDays: 10),
                             StepsSignal.blendedGrowth(totalSessions: 10, movementDays: 0))
        XCTAssertEqual(StepsSignal.blendedGrowth(totalSessions: 62, movementDays: 90), 1.0)
    }

    func testMovementDayCountUsesRelativeRule() {
        // median 5000 → threshold 3000; zeros and 1000s don't count
        var totals: [Double] = Array(repeating: 5000, count: 20)
        totals += [1000, 1000, 0, 0, 3000]
        XCTAssertEqual(StepsSignal.movementDayCount(dailyTotals: totals), 21)   // 20×5000 + the 3000
        // no baseline → no bonus, no penalty
        XCTAssertEqual(StepsSignal.movementDayCount(dailyTotals: [4000, 4000]), 0)
    }

    // MARK: - Nudge bucket (relative only)

    func testBucketRelativeToOwnMedian() {
        XCTAssertEqual(StepsSignal.bucket(today: 2000, history: steadyMonth), .low)
        XCTAssertEqual(StepsSignal.bucket(today: 5000, history: steadyMonth), .typical)
        XCTAssertEqual(StepsSignal.bucket(today: 8000, history: steadyMonth), .high)
        XCTAssertNil(StepsSignal.bucket(today: 8000, history: []))   // no baseline → silent
    }

    // MARK: - Display

    func testFormattedCountGroupsDigits() {
        XCTAssertEqual(StepsSignal.formattedCount(4200, locale: Locale(identifier: "en_US")), "4,200")
        XCTAssertEqual(StepsSignal.formattedCount(0, locale: Locale(identifier: "en_US")), "0")
    }

    // MARK: - Engine movement correlation

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return cal.date(from: comps)!
    }

    /// 24 days: even offsets are movement days (8000 steps, clear mood),
    /// odd offsets are still days (1000 steps, drained mood).
    private func movementFixture(days: Int) -> (moods: [MoodSample], steps: [StepsSample], now: Date) {
        var moods: [MoodSample] = []
        var steps: [StepsSample] = []
        for i in 0..<days {
            let d = cal.date(byAdding: .day, value: i, to: date(2024, 3, 1))!
            moods.append(MoodSample(date: d, weather: i % 2 == 0 ? .clear : .drained))
            steps.append(StepsSample(date: d, steps: i % 2 == 0 ? 8000 : 1000))
        }
        let now = cal.date(byAdding: .day, value: days - 1, to: date(2024, 3, 1, 18))!
        return (moods, steps, now)
    }

    func testMovementCorrelationLift() {
        let fx = movementFixture(days: 24)
        let engine = PatternEngine(moodSamples: fx.moods, stepsSamples: fx.steps,
                                   now: fx.now, calendar: cal)
        let corr = engine.movementCorrelation()
        XCTAssertNotNil(corr)
        XCTAssertEqual(corr?.withMoodMean ?? 0, 4.0, accuracy: 1e-9)
        XCTAssertEqual(corr?.withoutMoodMean ?? 0, 1.0, accuracy: 1e-9)
        XCTAssertEqual(corr?.liftRatio ?? 0, 4.0, accuracy: 1e-9)
    }

    func testMovementCorrelationSilentUnderTwentyOneMoodDays() {
        let fx = movementFixture(days: 18)
        let engine = PatternEngine(moodSamples: fx.moods, stepsSamples: fx.steps,
                                   now: fx.now, calendar: cal)
        XCTAssertNil(engine.movementCorrelation())
    }

    func testMovementCorrelationSilentWithoutSteps() {
        let fx = movementFixture(days: 24)
        let engine = PatternEngine(moodSamples: fx.moods, now: fx.now, calendar: cal)
        XCTAssertNil(engine.movementCorrelation())
    }

    func testMovementCorrelationSilentWithThinCohort() {
        // plenty of mood days, but only 4 movement days — cohort floor unmet
        var fx = movementFixture(days: 24)
        fx.steps = fx.steps.enumerated().map { i, s in
            StepsSample(date: s.date, steps: i < 8 && i % 2 == 0 ? 8000 : 1000)
        }
        let engine = PatternEngine(moodSamples: fx.moods, stepsSamples: fx.steps,
                                   now: fx.now, calendar: cal)
        XCTAssertNil(engine.movementCorrelation())
    }

    func testStepsNeverEnterBaselineOrRisk() {
        // identical moods, wildly different steps → identical baseline + risk
        let fx = movementFixture(days: 24)
        let with = PatternEngine(moodSamples: fx.moods, stepsSamples: fx.steps,
                                 now: fx.now, calendar: cal)
        let without = PatternEngine(moodSamples: fx.moods, now: fx.now, calendar: cal)
        XCTAssertEqual(with.overallBaseline, without.overallBaseline)
        XCTAssertEqual(with.tomorrowRisk(), without.tomorrowRisk())
    }

    // MARK: - Permission flags stay independent

    @MainActor
    func testStepsAskFlagIndependentOfSleepFlag() {
        let ud = UserDefaults.standard
        let sleepKey = "dino.health.sleepRequested"
        let stepsKey = "dino.health.stepsRequested"
        let oldSleep = ud.object(forKey: sleepKey)
        let oldSteps = ud.object(forKey: stepsKey)
        defer {
            ud.set(oldSleep, forKey: sleepKey)
            ud.set(oldSteps, forKey: stepsKey)
        }

        // an existing user who granted sleep long ago has NOT been asked for steps
        ud.set(true, forKey: sleepKey)
        ud.removeObject(forKey: stepsKey)
        XCTAssertTrue(HealthService.shared.hasRequestedSleep)
        XCTAssertFalse(HealthService.shared.hasRequestedSteps)

        // and the reverse never bleeds either
        ud.removeObject(forKey: sleepKey)
        ud.set(true, forKey: stepsKey)
        XCTAssertFalse(HealthService.shared.hasRequestedSleep)
        XCTAssertTrue(HealthService.shared.hasRequestedSteps)
    }
}
