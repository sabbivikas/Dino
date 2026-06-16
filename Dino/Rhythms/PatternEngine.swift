//
//  PatternEngine.swift
//  Dino
//
//  Local statistics engine for the "rhythms" (Emotional DNA) feature.
//  Pure logic only — no UI, no AI, no networking, and it NEVER reads
//  SharedDataManager (a thin adapter feeds it; see RhythmsDataAdapter).
//
//  Contract (locked):
//   • Mood score is the ONLY signal baselines/trajectory/recovery use:
//       clear=4, partlyCloudy=3, overwhelmed=2, drained=1.
//     energyLevel/intensityLevel (stored 1...10) are SECONDARY — reserved
//     for the risk score's future use, never averaged into the mood score.
//   • All day/time math uses an injected Calendar (default .current) and
//     local startOfDay grouping. NEVER UTC, never the streak string keys.
//     A mood at 11:50pm belongs to that local day; 12:10am to the next.
//   • A day with no mood is ABSENT (skipped), never counted as 0.
//     Multiple same-day entries are averaged into one daily score first.
//   • Confidence gates: a weekday baseline needs ≥ minWeekdayCount (3)
//     instances; the feature only "speaks" at ≥ minDaysToSpeak (21) distinct
//     days of mood data.
//

import Foundation

// MARK: - Local-day key (calendar-local, timezone-safe)

struct LocalDay: Hashable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init(date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year ?? 0
        self.month = c.month ?? 0
        self.day = c.day ?? 0
    }

    private init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    func startOfDay(_ calendar: Calendar) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return calendar.date(from: c) ?? Date.distantPast
    }

    /// 1 = Sunday … 7 = Saturday (Calendar convention).
    func weekday(_ calendar: Calendar) -> Int {
        calendar.component(.weekday, from: startOfDay(calendar))
    }

    func adding(days: Int, _ calendar: Calendar) -> LocalDay {
        let base = startOfDay(calendar)
        let shifted = calendar.date(byAdding: .day, value: days, to: base) ?? base
        return LocalDay(date: shifted, calendar: calendar)
    }

    /// Calendar-day count from self to `other` (positive if other is later).
    func days(until other: LocalDay, _ calendar: Calendar) -> Int {
        let a = startOfDay(calendar)
        let b = other.startOfDay(calendar)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

// MARK: - Inputs (fed by the adapter; tests feed fixtures directly)

struct MoodSample {
    let date: Date
    let weather: EmotionalWeather
}

// MARK: - Outputs

struct WeekdayStat: Equatable {
    let mean: Double
    let count: Int
    let confident: Bool
}

struct Trajectory: Equatable {
    let slope: Double      // mood points per day-index; negative = trending down
    let confident: Bool
}

struct PracticeCorrelation: Equatable {
    let withMoodMean: Double      // mean next-day mood after a practiced day
    let withoutMoodMean: Double   // mean next-day mood after a non-practiced day
    let liftRatio: Double         // withMoodMean / withoutMoodMean
}

struct RiskFactors: Equatable {
    let weekdayGap: Double
    let downwardTrajectory: Double
    let belowBaseline: Double
    let noPracticeToday: Double
}

struct RiskAssessment: Equatable {
    let score: Double          // 0...1
    let confident: Bool
    let likelyHard: Bool       // score >= threshold AND confident
    let factors: RiskFactors
}

struct RhythmsAnalysis {
    let overallBaseline: Double
    let weekdayBaseline: [Int: WeekdayStat]
    let trajectory: Trajectory
    let recoveryTimeDays: Double?
    let practiceCorrelation: PracticeCorrelation?
    let risk: RiskAssessment
    let daysOfDataAvailable: Int
    let hasEnoughData: Bool
}

// MARK: - Engine

struct PatternEngine {

    // Tunable constants (documented in the contract).
    static let moodRange: Double = 3.0          // mood scores span 1...4 → max gap 3
    static let recoveryMargin: Double = 0.5     // a "dip" is baseline − margin
    static let slopeNorm: Double = 1.0          // 1 mood-point/day decline = full downward factor
    static let minWeekdayCount = 3              // weekday baseline confidence
    static let minDaysToSpeak = 21             // 3-week gate before the feature speaks
    static let riskHardThreshold: Double = 0.6  // "likely hard" flag
    static let defaultWindowDays = 90
    static let trajectoryLastN = 3

    var calendar: Calendar
    var now: Date
    var windowDays: Int
    var moodSamples: [MoodSample]
    var practiceDates: [Date]

    init(moodSamples: [MoodSample],
         practiceDates: [Date] = [],
         now: Date = Date(),
         calendar: Calendar = .current,
         windowDays: Int = PatternEngine.defaultWindowDays) {
        self.moodSamples = moodSamples
        self.practiceDates = practiceDates
        self.now = now
        self.calendar = calendar
        self.windowDays = windowDays
    }

    // MARK: Mood score (the single primary signal)

    static func moodScore(_ weather: EmotionalWeather) -> Double {
        switch weather {
        case .clear:        return 4
        case .partlyCloudy: return 3
        case .overwhelmed:  return 2
        case .drained:      return 1
        }
    }

    // MARK: Window

    private var todayDay: LocalDay { LocalDay(date: now, calendar: calendar) }
    private var windowStartDay: LocalDay { todayDay.adding(days: -(windowDays - 1), calendar) }
    private func inWindow(_ d: LocalDay) -> Bool { d >= windowStartDay && d <= todayDay }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }

    // MARK: 1) Daily mood scores (absent days skipped, same-day averaged)

    var dailyMoodScores: [LocalDay: Double] {
        var groups: [LocalDay: [Double]] = [:]
        for s in moodSamples {
            let d = LocalDay(date: s.date, calendar: calendar)
            guard inWindow(d) else { continue }
            groups[d, default: []].append(Self.moodScore(s.weather))
        }
        return groups.mapValues { $0.reduce(0, +) / Double($0.count) }
    }

    var practiceDays: Set<LocalDay> {
        Set(practiceDates
            .map { LocalDay(date: $0, calendar: calendar) }
            .filter { inWindow($0) })
    }

    var daysOfDataAvailable: Int { dailyMoodScores.count }
    var hasEnoughData: Bool { daysOfDataAvailable >= Self.minDaysToSpeak }

    // MARK: 2) Weekday baseline

    func weekdayBaseline() -> [Int: WeekdayStat] {
        var groups: [Int: [Double]] = [:]
        for (day, score) in dailyMoodScores {
            groups[day.weekday(calendar), default: []].append(score)
        }
        var out: [Int: WeekdayStat] = [:]
        for (wd, scores) in groups {
            let mean = scores.reduce(0, +) / Double(scores.count)
            out[wd] = WeekdayStat(mean: mean, count: scores.count,
                                  confident: scores.count >= Self.minWeekdayCount)
        }
        return out
    }

    // MARK: 3) Overall baseline

    var overallBaseline: Double {
        let values = Array(dailyMoodScores.values)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: 4) Trajectory (least-squares slope over last N data-days)

    func trajectory(lastN: Int = PatternEngine.trajectoryLastN) -> Trajectory {
        let dataDays = dailyMoodScores.keys.sorted()              // ascending (oldest→newest)
        let recent = Array(dataDays.suffix(lastN))               // most recent N that have data
        guard recent.count >= 2 else { return Trajectory(slope: 0, confident: false) }
        let ys = recent.map { dailyMoodScores[$0] ?? 0 }
        let n = Double(ys.count)
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0
        for (i, y) in ys.enumerated() {
            let x = Double(i)
            sumX += x; sumY += y; sumXY += x * y; sumX2 += x * x
        }
        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return Trajectory(slope: 0, confident: false) }
        return Trajectory(slope: (n * sumXY - sumX * sumY) / denom, confident: true)
    }

    // MARK: 5) Recovery time (avg calendar days from a dip back to baseline)

    func recoveryTime() -> Double? {
        let baseline = overallBaseline
        let days = dailyMoodScores.keys.sorted()
        guard !days.isEmpty else { return nil }
        var dipStart: LocalDay?
        var diffs: [Int] = []
        for d in days {
            let s = dailyMoodScores[d] ?? 0
            if let start = dipStart {
                if s >= baseline {
                    diffs.append(start.days(until: d, calendar))
                    dipStart = nil
                }
            } else if s < baseline - Self.recoveryMargin {
                dipStart = d
            }
        }
        guard !diffs.isEmpty else { return nil }
        return Double(diffs.reduce(0, +)) / Double(diffs.count)
    }

    // MARK: 6) Practice correlation (next-day mood after practiced vs not)

    func practiceCorrelation() -> PracticeCorrelation? {
        let scores = dailyMoodScores
        let practiced = practiceDays
        var withMood: [Double] = []
        var withoutMood: [Double] = []
        // Universe: days that have a mood AND whose next local day also has a
        // mood (so we compare like-with-like — active days that have a tomorrow).
        for d in scores.keys {
            let next = d.adding(days: 1, calendar)
            guard let nextScore = scores[next] else { continue }
            if practiced.contains(d) { withMood.append(nextScore) }
            else { withoutMood.append(nextScore) }
        }
        guard !withMood.isEmpty, !withoutMood.isEmpty else { return nil }
        let wm = withMood.reduce(0, +) / Double(withMood.count)
        let wo = withoutMood.reduce(0, +) / Double(withoutMood.count)
        guard wo != 0 else { return nil }
        return PracticeCorrelation(withMoodMean: wm, withoutMoodMean: wo, liftRatio: wm / wo)
    }

    // MARK: 7) Tomorrow risk score

    /// Pure weighted sum of the four normalized (0...1) risk factors.
    static func weightedRisk(weekdayGap: Double, downwardTrajectory: Double,
                             belowBaseline: Double, noPracticeToday: Double) -> Double {
        0.4 * weekdayGap + 0.3 * downwardTrajectory + 0.2 * belowBaseline + 0.1 * noPracticeToday
    }

    func tomorrowRisk() -> RiskAssessment {
        let baseline = overallBaseline
        let scores = dailyMoodScores
        let wb = weekdayBaseline()
        let traj = trajectory()
        let tomorrow = todayDay.adding(days: 1, calendar)
        let tomorrowWeekday = tomorrow.weekday(calendar)
        let weekdayStat = wb[tomorrowWeekday]

        let weekdayGap: Double = {
            guard let mean = weekdayStat?.mean else { return 0 }
            return clamp((baseline - mean) / Self.moodRange, 0, 1)
        }()
        let downward = clamp(-traj.slope / Self.slopeNorm, 0, 1)
        let belowBaseline: Double = {
            guard let today = scores[todayDay] else { return 0 }
            return clamp((baseline - today) / Self.moodRange, 0, 1)
        }()
        let noPractice: Double = practiceDays.contains(todayDay) ? 0 : 1

        let score = Self.weightedRisk(weekdayGap: weekdayGap, downwardTrajectory: downward,
                                      belowBaseline: belowBaseline, noPracticeToday: noPractice)
        let confident = hasEnoughData && (weekdayStat?.confident ?? false)
        return RiskAssessment(
            score: score,
            confident: confident,
            likelyHard: confident && score >= Self.riskHardThreshold,
            factors: RiskFactors(weekdayGap: weekdayGap, downwardTrajectory: downward,
                                 belowBaseline: belowBaseline, noPracticeToday: noPractice)
        )
    }

    // MARK: Bundle

    func analyze() -> RhythmsAnalysis {
        RhythmsAnalysis(
            overallBaseline: overallBaseline,
            weekdayBaseline: weekdayBaseline(),
            trajectory: trajectory(),
            recoveryTimeDays: recoveryTime(),
            practiceCorrelation: practiceCorrelation(),
            risk: tomorrowRisk(),
            daysOfDataAvailable: daysOfDataAvailable,
            hasEnoughData: hasEnoughData
        )
    }
}
