//
//  StepsSignal.swift
//  Dino
//
//  Pure step-count logic — no HealthKit, no UI, fully unit-testable.
//  Every read is relative to the user's OWN trailing baseline (median of
//  their positive step days). There are no absolute standards, goals, or
//  targets anywhere in this file, and a still day can never subtract from
//  anything: the garden bonus is additive-only and floors at zero.
//
//  Tone contract: low-movement days always get neutral-to-kind copy. The
//  correlation insight is never shown on a quiet day — on a low-movement
//  day it would read as pressure, so it only rides along with neutral or
//  active reads.
//

import Foundation

// MARK: - Card read

enum StepsRead: Equatable {
    case building   // < 7 days of their own history — no read yet
    case busiest    // week's max AND meaningfully above their median
    case high       // well above their own median
    case quiet      // well below their own median
    case neutral    // an ordinary day by their own rhythm

    var dinoLine: String {
        switch self {
        case .building: return "still getting to know your rhythm 🌱".localized
        case .busiest:  return "your busiest day this week 🌿".localized
        case .high:     return "a lot of motion in today 🌿".localized
        case .quiet:    return "a quieter body day. rest is okay too 🌱".localized
        case .neutral:  return "moving through the day at your own pace 🍃".localized
        }
    }
}

// MARK: - Signal

enum StepsSignal {

    // Tunables — all thresholds are multiples of the user's own median.
    static let minBaselineDays = 7        // positive days needed before any read
    static let movementFactor = 0.6       // movement day: ≥ 0.6× own median
    static let busiestMargin = 1.1        // "busiest" needs > 1.1× median (no hollow crowns on flat weeks)
    static let highFactor = 1.4           // "a lot of motion": ≥ 1.4× median
    static let quietFactor = 0.5          // "quieter body day": ≤ 0.5× median
    static let bonusPerMovementDay = 0.2  // garden: session-equivalents per movement day
    static let bonusCap = 6.0             // garden: movement can never exceed ~10% of the bloom journey
    static let bloomSessions = 62.0       // mirrors GrowthViewModel's full-bloom constant
    static let insightLiftThreshold = 1.15

    static var insightLine: String {
        "your brighter days often have a little more movement in them".localized
    }

    // MARK: Baseline (their own, nobody else's)

    /// Median of the positive daily totals (zero days are likely phone-off,
    /// not stillness — they don't drag the baseline down). Nil until the user
    /// has ≥ minBaselineDays positive days, so early reads stay humble.
    static func baseline(history: [Double]) -> Double? {
        let positive = history.filter { $0 > 0 }.sorted()
        guard positive.count >= minBaselineDays else { return nil }
        let mid = positive.count / 2
        return positive.count % 2 == 0
            ? (positive[mid - 1] + positive[mid]) / 2
            : positive[mid]
    }

    // MARK: Card read rules (first match wins)

    /// `history` = prior daily totals oldest→newest, EXCLUDING today.
    static func read(today: Double, history: [Double]) -> StepsRead {
        guard let median = baseline(history: history), median > 0 else { return .building }
        let weekPrior = history.suffix(6)   // today + these six = the week
        if today >= (weekPrior.max() ?? 0), today > busiestMargin * median { return .busiest }
        if today >= highFactor * median { return .high }
        if today <= quietFactor * median { return .quiet }
        return .neutral
    }

    /// The insight only speaks when the correlation is confident AND today's
    /// read isn't quiet/building — never "move more" pressure on a rest day.
    static func shouldShowInsight(read: StepsRead, correlation: PracticeCorrelation?) -> Bool {
        guard let c = correlation, c.liftRatio >= insightLiftThreshold else { return false }
        switch read {
        case .busiest, .high, .neutral: return true
        case .quiet, .building:         return false
        }
    }

    // MARK: Garden blend (bonus-only, never negative)

    /// Movement days in a window of daily totals: ≥ 0.6× the window's own
    /// median. Zero until the baseline exists — no data, no bonus, no penalty.
    static func movementDayCount(dailyTotals: [Double]) -> Int {
        guard let median = baseline(history: dailyTotals), median > 0 else { return 0 }
        return dailyTotals.filter { $0 >= movementFactor * median }.count
    }

    /// 0.2 session-equivalents per movement day, hard-capped at 6.0 (~10% of
    /// the 62-session bloom journey). A still day contributes exactly 0.
    static func gardenBonus(movementDays: Int) -> Double {
        min(Double(max(movementDays, 0)) * bonusPerMovementDay, bonusCap)
    }

    static func blendedGrowth(totalSessions: Int, movementDays: Int) -> Double {
        min((Double(totalSessions) + gardenBonus(movementDays: movementDays)) / bloomSessions, 1.0)
    }

    // MARK: Nudge bucket (relative enum only — raw counts never travel)

    enum MovementBucket: String {
        case low, typical, high
    }

    static func bucket(today: Double, history: [Double]) -> MovementBucket? {
        guard let median = baseline(history: history), median > 0 else { return nil }
        if today <= quietFactor * median { return .low }
        if today >= highFactor * median { return .high }
        return .typical
    }

    // MARK: Display

    /// "4,200" — grouped digits for the card's number line.
    static func formattedCount(_ steps: Double, locale: Locale = .current) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = locale
        return f.string(from: NSNumber(value: max(steps, 0))) ?? "\(Int(max(steps, 0)))"
    }
}
