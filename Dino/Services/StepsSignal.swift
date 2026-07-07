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
        return median(ofSorted: positive)
    }

    fileprivate static func median(ofSorted values: [Double]) -> Double {
        let mid = values.count / 2
        return values.count % 2 == 0
            ? (values[mid - 1] + values[mid]) / 2
            : values[mid]
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

    // MARK: Sleep bucket (nudge payload — relative to their own nights)

    enum SleepBucket: String {
        case short, typical, solid
    }

    static let sleepShortFactor = 0.85    // short ≤ 0.85× own median night
    static let sleepSolidFactor = 1.1     // solid ≥ 1.1× own median night
    static let minSleepBaselineNights = 5

    /// Nil until ≥ 5 prior nights exist — no bucket, no payload field, silence.
    static func sleepBucket(lastNight: Double, priorNights: [Double]) -> SleepBucket? {
        let positive = priorNights.filter { $0 > 0 }.sorted()
        guard positive.count >= minSleepBaselineNights else { return nil }
        let med = median(ofSorted: positive)
        guard med > 0 else { return nil }
        if lastNight <= sleepShortFactor * med { return .short }
        if lastNight >= sleepSolidFactor * med { return .solid }
        return .typical
    }

    // MARK: Combined body card (sleep + steps merged, ONE read line)

    static var shortNightLine: String { "a short night. be gentle with yourself today 🌿".localized }
    static var lighterSleepLine: String { "lighter sleep than usual. today might feel a little heavier".localized }
    static var sleptWellLine: String { "you slept well. good foundation for today 🌱".localized }
    static var decentRestLine: String { "decent rest last night 🌿".localized }

    /// Priority: today's body state (busiest/quiet) beats last night; a rough
    /// night (very short/short) beats celebration (high steps/solid sleep);
    /// the insight only ever takes an otherwise-neutral line. Nil when both
    /// signals are absent — the card hides entirely.
    static func combinedRead(sleepHours: Double?, stepsRead: StepsRead?, showInsight: Bool) -> String? {
        guard sleepHours != nil || stepsRead != nil else { return nil }
        if stepsRead == .busiest { return StepsRead.busiest.dinoLine }
        if stepsRead == .quiet { return StepsRead.quiet.dinoLine }
        if let h = sleepHours, h < 5 { return shortNightLine }
        if let h = sleepHours, h < 6 { return lighterSleepLine }
        if stepsRead == .high { return StepsRead.high.dinoLine }
        if let h = sleepHours, h >= 7 { return sleptWellLine }
        if showInsight { return insightLine }   // upstream gates: never on quiet/building
        if stepsRead == nil { return decentRestLine }               // sleep-only, 6–7h
        if stepsRead == .building, sleepHours == nil { return StepsRead.building.dinoLine }
        return StepsRead.neutral.dinoLine
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

    /// "7h 12m" / "7h" for the card's top line.
    static func compactSleep(hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}

// MARK: - Body-flavored nudges (gating is pure so every rule is testable)

/// Decides which body-context buckets may ride today's nudge payload. The
/// buckets are the ONLY body data that ever leaves the device — never raw
/// hours or counts — and flavor is rationed so nudges stay mood-driven,
/// never fitness-app nagging.
enum BodyNudge {
    static let weeklyCap = 2          // body-flavored payloads per rolling week
    static let capWindowDays = 7
    static let crisisQuietDays = 7    // crisis marker silences flavor this long
    static let quietStretchDays = 4

    /// True when body fields may be included today: no crisis in the last
    /// week, and fewer than `weeklyCap` flavored payloads in the last week.
    static func allowFlavor(flavorDates: [Date], crisisDate: Date?,
                            now: Date, calendar: Calendar) -> Bool {
        func daysAgo(_ d: Date) -> Int {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: d),
                                    to: calendar.startOfDay(for: now)).day ?? 0
        }
        if let c = crisisDate {
            let days = daysAgo(c)
            if days >= 0 && days < crisisQuietDays { return false }
        }
        let recent = flavorDates.filter { let d = daysAgo($0); return d >= 0 && d < capWindowDays }
        return recent.count < weeklyCap
    }

    /// The payload fields. On a heavy-mood day the ONLY field that survives is
    /// sleepLastNight: short (it makes the nudge gentler) — movement flavor and
    /// the walk offer are structurally impossible, not just prompt-discouraged.
    static func fields(moodIsHeavy: Bool,
                       sleepBucket: StepsSignal.SleepBucket?,
                       movementBucket: StepsSignal.MovementBucket?,
                       quietStretch: Bool) -> [String: String] {
        if moodIsHeavy {
            return sleepBucket == .short ? ["sleepLastNight": "short"] : [:]
        }
        var out: [String: String] = [:]
        if let s = sleepBucket { out["sleepLastNight"] = s.rawValue }
        if let m = movementBucket { out["movementToday"] = m.rawValue }
        if quietStretch { out["movementLately"] = "quiet" }
        return out
    }

    /// A quiet stretch: the last `quietStretchDays` step days all below the
    /// movement threshold vs the window's own median. False without a baseline.
    static func isQuietStretch(dailyTotals: [Double]) -> Bool {
        guard let med = StepsSignal.baseline(history: dailyTotals), med > 0 else { return false }
        let lastN = dailyTotals.suffix(quietStretchDays)
        guard lastN.count >= quietStretchDays else { return false }
        return lastN.allSatisfy { $0 < StepsSignal.movementFactor * med }
    }
}
