//
//  PatternEngineTests.swift
//  DinoTests
//
//  Test-first verification of the rhythms PatternEngine. Every expected
//  value is hand-calculated in the comments and asserted to tolerance.
//  A fixed-timezone gregorian calendar is injected so results are
//  deterministic regardless of the machine running the tests.
//

import XCTest
@testable import Dino

final class PatternEngineTests: XCTestCase {

    // Fixed calendar (UTC-6) so local-day grouping is deterministic.
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: -6 * 3600) ?? .gmt
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(timeZone: cal.timeZone, year: y, month: m, day: d,
                                      hour: h, minute: min)) ?? Date.distantPast
    }

    private func sample(_ y: Int, _ m: Int, _ d: Int, _ w: EmotionalWeather, _ h: Int = 12) -> MoodSample {
        MoodSample(date: date(y, m, d, h), weather: w)
    }

    private func engine(_ samples: [MoodSample], practices: [Date] = [],
                        now: Date, window: Int = 120) -> PatternEngine {
        PatternEngine(moodSamples: samples, practiceDates: practices,
                      now: now, calendar: cal, windowDays: window)
    }

    private let tol = 1e-9

    // MARK: - 1) Mood score mapping

    func testMoodScoreMapping() {
        XCTAssertEqual(PatternEngine.moodScore(.clear), 4, accuracy: tol)
        XCTAssertEqual(PatternEngine.moodScore(.partlyCloudy), 3, accuracy: tol)
        XCTAssertEqual(PatternEngine.moodScore(.overwhelmed), 2, accuracy: tol)
        XCTAssertEqual(PatternEngine.moodScore(.drained), 1, accuracy: tol)
    }

    // MARK: - 2) Weekday baseline + confidence

    func testWeekdayBaselineMeanCountConfidence() {
        // 10 Mondays (2024-01-01 is a Monday), each one overwhelmed (=2).
        // + 2 Tuesdays, each clear (=4).
        let monday = date(2024, 1, 1)
        var samples: [MoodSample] = []
        for i in 0..<10 {
            let d = cal.date(byAdding: .day, value: 7 * i, to: monday) ?? monday
            samples.append(MoodSample(date: d, weather: .overwhelmed))
        }
        samples.append(sample(2024, 1, 2, .clear))   // Tuesday
        samples.append(sample(2024, 1, 9, .clear))   // Tuesday

        let wb = engine(samples, now: date(2024, 3, 4, 18)).weekdayBaseline()
        // Calendar: Sunday=1 … Monday=2, Tuesday=3.
        XCTAssertEqual(wb[2]?.mean ?? -1, 2.0, accuracy: tol)
        XCTAssertEqual(wb[2]?.count, 10)
        XCTAssertEqual(wb[2]?.confident, true)         // 10 >= 3
        XCTAssertEqual(wb[3]?.mean ?? -1, 4.0, accuracy: tol)
        XCTAssertEqual(wb[3]?.count, 2)
        XCTAssertEqual(wb[3]?.confident, false)        // 2 < 3
    }

    // MARK: - 3) Missing days are skipped, never counted as 0

    func testMissingDaysAreSkippedNotZero() {
        // Day1 clear(4), Day2 ABSENT, Day3 clear(4).
        // Correct baseline = (4+4)/2 = 4.0.  Wrong (counting 0) = (4+0+4)/3 = 2.667.
        let samples = [sample(2024, 2, 5, .clear), sample(2024, 2, 7, .clear)]
        let e = engine(samples, now: date(2024, 2, 7, 18))
        XCTAssertEqual(e.dailyMoodScores.count, 2)
        XCTAssertEqual(e.overallBaseline, 4.0, accuracy: tol)
    }

    // MARK: - 4) Multiple same-day entries averaged into one day

    func testMultipleSameDayEntriesAveraged() {
        // Same day: clear(4) + overwhelmed(2) → daily score (4+2)/2 = 3.0.
        let samples = [sample(2024, 2, 5, .clear, 9), sample(2024, 2, 5, .overwhelmed, 21)]
        let e = engine(samples, now: date(2024, 2, 5, 23))
        let key = LocalDay(date: date(2024, 2, 5), calendar: cal)
        XCTAssertEqual(e.dailyMoodScores.count, 1)
        XCTAssertEqual(e.dailyMoodScores[key] ?? -1, 3.0, accuracy: tol)
    }

    // MARK: - 5) Trajectory slope

    func testTrajectoryDownwardSlope() {
        // 3 consecutive days: 4, 3, 2 (oldest→newest). x=0,1,2.
        // slope = (3*7 - 3*9)/(3*5 - 9) = -6/6 = -1.0.
        let samples = [sample(2024, 2, 5, .clear),
                       sample(2024, 2, 6, .partlyCloudy),
                       sample(2024, 2, 7, .overwhelmed)]
        let t = engine(samples, now: date(2024, 2, 7, 18)).trajectory()
        XCTAssertEqual(t.slope, -1.0, accuracy: tol)
        XCTAssertTrue(t.confident)
    }

    func testTrajectoryFlatSlope() {
        let samples = [sample(2024, 2, 5, .partlyCloudy),
                       sample(2024, 2, 6, .partlyCloudy),
                       sample(2024, 2, 7, .partlyCloudy)]
        let t = engine(samples, now: date(2024, 2, 7, 18)).trajectory()
        XCTAssertEqual(t.slope, 0.0, accuracy: tol)
    }

    func testTrajectorySinglePointIsZeroLowConfidence() {
        let t = engine([sample(2024, 2, 7, .clear)], now: date(2024, 2, 7, 18)).trajectory()
        XCTAssertEqual(t.slope, 0.0, accuracy: tol)
        XCTAssertFalse(t.confident)
    }

    // MARK: - 6) Overall baseline

    func testOverallBaseline() {
        // 4, 2, 3 → mean 3.0
        let samples = [sample(2024, 2, 5, .clear),
                       sample(2024, 2, 6, .overwhelmed),
                       sample(2024, 2, 7, .partlyCloudy)]
        XCTAssertEqual(engine(samples, now: date(2024, 2, 7, 18)).overallBaseline, 3.0, accuracy: tol)
    }

    // MARK: - 7) Practice correlation

    func testPracticeCorrelationLift() {
        // Days d0..d3: overwhelmed(2), clear(4), overwhelmed(2), clear(4).
        // Practiced d0 and d2. Universe = d0,d1,d2 (d3's next has no mood).
        //  d0 practiced → next d1 = 4   → withMood
        //  d1 not       → next d2 = 2   → withoutMood
        //  d2 practiced → next d3 = 4   → withMood
        // withMood mean = 4, withoutMood mean = 2, lift = 2.0.
        let samples = [sample(2024, 2, 5, .overwhelmed),
                       sample(2024, 2, 6, .clear),
                       sample(2024, 2, 7, .overwhelmed),
                       sample(2024, 2, 8, .clear)]
        let practices = [date(2024, 2, 5), date(2024, 2, 7)]
        let c = engine(samples, practices: practices, now: date(2024, 2, 8, 18)).practiceCorrelation()
        XCTAssertEqual(c?.withMoodMean ?? -1, 4.0, accuracy: tol)
        XCTAssertEqual(c?.withoutMoodMean ?? -1, 2.0, accuracy: tol)
        XCTAssertEqual(c?.liftRatio ?? -1, 2.0, accuracy: tol)
    }

    func testPracticeCorrelationNilWhenNoPractices() {
        let samples = [sample(2024, 2, 5, .clear), sample(2024, 2, 6, .clear)]
        XCTAssertNil(engine(samples, now: date(2024, 2, 6, 18)).practiceCorrelation())
    }

    // MARK: - 8) Recovery time

    func testRecoveryTimeKnownCycle() {
        // 5 consecutive: 4,4,4,1,4. baseline = 17/5 = 3.4; dip threshold 2.9.
        // Day4 (=1) is a dip; Day5 (=4) >= 3.4 → recovery in 1 calendar day.
        let samples = [sample(2024, 2, 5, .clear),
                       sample(2024, 2, 6, .clear),
                       sample(2024, 2, 7, .clear),
                       sample(2024, 2, 8, .drained),
                       sample(2024, 2, 9, .clear)]
        let r = engine(samples, now: date(2024, 2, 9, 18)).recoveryTime()
        XCTAssertEqual(r ?? -1, 1.0, accuracy: tol)
    }

    func testRecoveryTimeNilWhenNoDip() {
        let samples = [sample(2024, 2, 5, .clear), sample(2024, 2, 6, .clear), sample(2024, 2, 7, .clear)]
        XCTAssertNil(engine(samples, now: date(2024, 2, 7, 18)).recoveryTime())
    }

    // MARK: - 9) Risk weighted sum + 0.6 boundary

    func testWeightedRiskMath() {
        XCTAssertEqual(PatternEngine.weightedRisk(weekdayGap: 1, downwardTrajectory: 1,
                                                  belowBaseline: 1, noPracticeToday: 1), 1.0, accuracy: tol)
        XCTAssertEqual(PatternEngine.weightedRisk(weekdayGap: 1, downwardTrajectory: 0,
                                                  belowBaseline: 0, noPracticeToday: 0), 0.4, accuracy: tol)
        // boundary: 0.4 + 0.2 = 0.6 exactly → "likely hard" (>= 0.6)
        let atBoundary = PatternEngine.weightedRisk(weekdayGap: 1, downwardTrajectory: 0,
                                                    belowBaseline: 1, noPracticeToday: 0)
        XCTAssertEqual(atBoundary, 0.6, accuracy: tol)
        XCTAssertTrue(atBoundary >= PatternEngine.riskHardThreshold)
        // just below: 0.4 + 0.2*0.99 = 0.598 → not hard
        let belowBoundary = PatternEngine.weightedRisk(weekdayGap: 1, downwardTrajectory: 0,
                                                       belowBaseline: 0.99, noPracticeToday: 0)
        XCTAssertEqual(belowBoundary, 0.598, accuracy: tol)
        XCTAssertFalse(belowBoundary >= PatternEngine.riskHardThreshold)
    }

    func testRiskWeekdayGapNormalizationIntegration() {
        // overall baseline 3.0; tomorrow = Thursday with weekday baseline mean 2.0
        //  → weekdayGap = (3.0 - 2.0)/3 = 0.3333…
        // 3 Thursdays @2 (Dec 14/21/28 2023) + 3 Fridays @4 (Dec 15/22/29).
        // overall = (2+4+2+4+2+4)/6 = 3.0.  now = Wed 2024-01-03 → tomorrow Thu.
        let samples = [sample(2023, 12, 14, .overwhelmed), sample(2023, 12, 15, .clear),
                       sample(2023, 12, 21, .overwhelmed), sample(2023, 12, 22, .clear),
                       sample(2023, 12, 28, .overwhelmed), sample(2023, 12, 29, .clear)]
        let risk = engine(samples, now: date(2024, 1, 3, 12)).tomorrowRisk()
        XCTAssertEqual(risk.factors.weekdayGap, 1.0 / 3.0, accuracy: 1e-9)
        // Only 6 days of data (< 21) → not confident, regardless of score.
        XCTAssertFalse(risk.confident)
        XCTAssertFalse(risk.likelyHard)
    }

    // MARK: - 10) Timezone / local-day boundary

    func testLocalDayBoundaryGrouping() {
        // 11:50pm Mon and 12:10am Tue (local) must be different local days
        // (and different weekdays). 2024-01-01 is Monday.
        let s1 = MoodSample(date: date(2024, 1, 1, 23, 50), weather: .clear)
        let s2 = MoodSample(date: date(2024, 1, 2, 0, 10), weather: .overwhelmed)
        let e = engine([s1, s2], now: date(2024, 1, 2, 12))
        XCTAssertEqual(e.dailyMoodScores.count, 2)
        let weekdays = Set(e.dailyMoodScores.keys.map { $0.weekday(cal) })
        XCTAssertEqual(weekdays, Set([2, 3]))   // Monday=2, Tuesday=3
    }

    // MARK: - 11) Confidence gate (≥ 21 distinct days to speak)

    func testConfidenceGate() {
        let base = date(2024, 1, 1)
        func daysOfData(_ count: Int) -> PatternEngine {
            var samples: [MoodSample] = []
            for i in 0..<count {
                let d = cal.date(byAdding: .day, value: i, to: base) ?? base
                samples.append(MoodSample(date: d, weather: .partlyCloudy))
            }
            let now = cal.date(byAdding: .day, value: count, to: base) ?? base
            return engine(samples, now: now)
        }
        XCTAssertFalse(daysOfData(20).hasEnoughData)
        XCTAssertEqual(daysOfData(20).daysOfDataAvailable, 20)
        XCTAssertTrue(daysOfData(21).hasEnoughData)
        XCTAssertEqual(daysOfData(21).daysOfDataAvailable, 21)
    }

    // MARK: - 12) Sample analysis (prints for eyeball sanity check)

    func testPrintSampleAnalysis() {
        // 28 days, gentle downward drift with a mid dip and some practices.
        let base = date(2024, 1, 1)
        var samples: [MoodSample] = []
        var practices: [Date] = []
        let pattern: [EmotionalWeather] = [.clear, .partlyCloudy, .overwhelmed, .partlyCloudy]
        for i in 0..<28 {
            let d = cal.date(byAdding: .day, value: i, to: base) ?? base
            samples.append(MoodSample(date: d, weather: pattern[i % pattern.count]))
            if i % 3 == 0 { practices.append(d) }
        }
        let now = cal.date(byAdding: .day, value: 28, to: base) ?? base
        let a = engine(samples, practices: practices, now: now).analyze()
        print("""
        ── Sample RhythmsAnalysis ──
        daysOfData: \(a.daysOfDataAvailable)  hasEnoughData: \(a.hasEnoughData)
        overallBaseline: \(a.overallBaseline)
        weekdayBaseline: \(a.weekdayBaseline.sorted { $0.key < $1.key }.map { "wd\($0.key)=\(String(format: "%.2f", $0.value.mean))x\($0.value.count)\($0.value.confident ? "✓" : "?")" })
        trajectory slope: \(a.trajectory.slope) confident: \(a.trajectory.confident)
        recoveryTimeDays: \(String(describing: a.recoveryTimeDays))
        practiceCorrelation: \(String(describing: a.practiceCorrelation))
        risk: score=\(String(format: "%.3f", a.risk.score)) confident=\(a.risk.confident) likelyHard=\(a.risk.likelyHard)
          factors=\(a.risk.factors)
        """)
        XCTAssertEqual(a.daysOfDataAvailable, 28)
    }
}
