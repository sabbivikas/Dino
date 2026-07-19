//
//  WeeklyDigest.swift
//  Dino
//
//  Pure week-over-week delta builder for the rhythms "what i noticed"
//  section — no UI, no networking, fully unit-testable. Everything it emits
//  is a BUCKET or a DELTA (enums and small day counts): raw step counts,
//  sleep hours, and journal text never leave the device. Repetition is
//  structurally impossible downstream because every line is grounded in
//  what changed vs last week, not in slow-moving 90-day statistics.
//

import Foundation

struct WeeklyDigest: Equatable {

    enum Direction: String { case up, steady, down }
    enum Lean: String { case gently, clearly }
    enum CountDelta: String { case more, less, same }

    // mood (trajectory this week vs last)
    var moodDirection: Direction?
    var moodLean: Lean?
    // movement (vs their own step median)
    var movementDaysThisWeek: Int?
    var movementDelta: CountDelta?
    var movementLift: Bool = false        // engine-gated movement-mood correlation
    // sleep (vs their own nightly median)
    var shortNightsThisWeek: Int?
    var solidNightsThisWeek: Int?
    var sleepDirection: Direction?        // fewer short nights than last week = up
    // practices
    var practicedDaysThisWeek: Int = 0
    var practicedDelta: CountDelta?
    // journal themes (toggle-gated at build)
    var topTheme: String?
    var themeIsNew: Bool = false
    // meta
    var streakState: String = "none"
    var daysLogged: Int = 0

    var isSparse: Bool { daysLogged < 3 }
    var isEmpty: Bool {
        daysLogged == 0 && movementDaysThisWeek == nil && shortNightsThisWeek == nil
            && practicedDaysThisWeek == 0
    }
    var hasAnyDelta: Bool {
        (moodDirection ?? .steady) != .steady
            || (movementDelta ?? .same) != .same
            || (sleepDirection ?? .steady) != .steady
            || (practicedDelta ?? .same) != .same
            || (themeIsNew && topTheme != nil)
    }

    // MARK: - Tunables

    static let moodSteadyBand = 0.25       // |Δ week mean| below this = steady
    static let moodClearBand = 0.6         // at or above = "clearly"
    static let minSleepNightsPerWeek = 3   // nights needed before weekly sleep speaks
    static let sparseThreshold = 3         // logged days below this = sparse week

    // MARK: - Build (pure)

    static func build(moodSamples: [MoodSample],
                      practiceDates: [Date],
                      stepDays: [(date: Date, steps: Double)],
                      sleepNights: [(date: Date, hours: Double)],
                      themeTags: [(date: Date, theme: String)],
                      journalToggleOn: Bool,
                      movementLift: Bool,
                      streakState: String,
                      now: Date,
                      calendar: Calendar) -> WeeklyDigest {
        let today = calendar.startOfDay(for: now)
        func offset(_ d: Date) -> Int {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: d), to: today).day ?? Int.max
        }
        func thisWeek(_ d: Date) -> Bool { (0...6).contains(offset(d)) }
        func lastWeek(_ d: Date) -> Bool { (7...13).contains(offset(d)) }

        var digest = WeeklyDigest()
        digest.movementLift = movementLift
        digest.streakState = streakState

        // — mood: daily means per week, then week means —
        func weekMean(_ filter: (Date) -> Bool) -> (mean: Double, days: Int)? {
            var byDay: [LocalDay: [Double]] = [:]
            for s in moodSamples where filter(s.date) {
                byDay[LocalDay(date: s.date, calendar: calendar), default: []]
                    .append(PatternEngine.moodScore(s.weather))
            }
            guard !byDay.isEmpty else { return nil }
            let dailyMeans = byDay.values.map { $0.reduce(0, +) / Double($0.count) }
            return (dailyMeans.reduce(0, +) / Double(dailyMeans.count), byDay.count)
        }
        let thisMood = weekMean(thisWeek)
        let lastMood = weekMean(lastWeek)
        digest.daysLogged = thisMood?.days ?? 0
        if let t = thisMood, let l = lastMood {
            let delta = t.mean - l.mean
            if abs(delta) < moodSteadyBand {
                digest.moodDirection = .steady
            } else {
                digest.moodDirection = delta > 0 ? .up : .down
                digest.moodLean = abs(delta) >= moodClearBand ? .clearly : .gently
            }
        }

        // — movement: vs their own median across the provided span —
        if let median = StepsSignal.baseline(history: stepDays.map { $0.steps }), median > 0 {
            let threshold = StepsSignal.movementFactor * median
            let thisCount = stepDays.filter { thisWeek($0.date) && $0.steps >= threshold }.count
            let lastCount = stepDays.filter { lastWeek($0.date) && $0.steps >= threshold }.count
            digest.movementDaysThisWeek = thisCount
            digest.movementDelta = thisCount == lastCount ? .same : (thisCount > lastCount ? .more : .less)
        }

        // — sleep: short/solid nights vs their own median —
        let positiveNights = sleepNights.map { $0.hours }.filter { $0 > 0 }.sorted()
        if positiveNights.count >= StepsSignal.minSleepBaselineNights {
            let mid = positiveNights.count / 2
            let median = positiveNights.count % 2 == 0
                ? (positiveNights[mid - 1] + positiveNights[mid]) / 2
                : positiveNights[mid]
            let thisNights = sleepNights.filter { thisWeek($0.date) }
            let lastNights = sleepNights.filter { lastWeek($0.date) }
            if thisNights.count >= minSleepNightsPerWeek {
                let shortThis = thisNights.filter { $0.hours <= StepsSignal.sleepShortFactor * median }.count
                digest.shortNightsThisWeek = shortThis
                digest.solidNightsThisWeek = thisNights.filter { $0.hours >= StepsSignal.sleepSolidFactor * median }.count
                if lastNights.count >= minSleepNightsPerWeek {
                    let shortLast = lastNights.filter { $0.hours <= StepsSignal.sleepShortFactor * median }.count
                    digest.sleepDirection = shortThis == shortLast ? .steady : (shortThis < shortLast ? .up : .down)
                }
            }
        }

        // — practices: distinct days per week —
        func practicedDays(_ filter: (Date) -> Bool) -> Int {
            Set(practiceDates.filter(filter).map { LocalDay(date: $0, calendar: calendar) }).count
        }
        let practicedThis = practicedDays(thisWeek)
        let practicedLast = practicedDays(lastWeek)
        digest.practicedDaysThisWeek = practicedThis
        digest.practicedDelta = practicedThis == practicedLast ? .same : (practicedThis > practicedLast ? .more : .less)

        // — themes: enum tags only, and ONLY when the journal toggle is on —
        if journalToggleOn {
            func topTheme(_ filter: (Date) -> Bool) -> String? {
                var counts: [String: Int] = [:]
                for t in themeTags where filter(t.date) && ThemeTag.isValid(t.theme) {
                    counts[t.theme, default: 0] += 1
                }
                return counts.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key
            }
            let top = topTheme(thisWeek)
            digest.topTheme = top
            digest.themeIsNew = top != nil && top != topTheme(lastWeek)
        }

        return digest
    }

    // MARK: - Local delta templates (the offline fix for the repetition bug)

    static let moodUpClearlyLine = String(localized: "this week rose. clearer skies than last week, and that came from you 🌱")
    static let moodUpGentlyLine = String(localized: "a gentle lift this week. a little lighter than the last one")
    static let moodDownClearlyLine = String(localized: "this week asked more of you than last week did. be soft with yourself 🌿")
    static let moodDownGentlyLine = String(localized: "a slightly heavier week than last. nothing to fix, just something i noticed")
    static let moodSteadyLine = String(localized: "a steady week, much like the last. steadiness counts 🌱")
    static let movementMoreLine = String(localized: "more movement in this week than last. your body carried you well 🌿")
    static let movementLessLine = String(localized: "a stiller week for your body than last. rest has its own rhythm too")
    static let movementLiftLine = String(localized: "your brighter days often had a little more movement in them")
    static let sleepUpLine = String(localized: "more rested nights than last week. it shows, gently")
    static let sleepDownLine = String(localized: "sleep ran shorter this week than last. today deserves some extra kindness 🌙")
    static let practiceMoreLine = String(localized: "you showed up for yourself more often this week than last 🌱")

    /// 2–3 delta-grounded lines, priority ordered. Differing deltas cannot
    /// produce identical output because every line is keyed off a delta enum.
    /// A down week never gets the movement-lift reflection (never advice on a
    /// heavy week), and a shrinking practice count gets NO line — never guilt.
    static func localLines(digest: WeeklyDigest) -> [String] {
        guard !digest.isEmpty, !digest.isSparse else { return [] }
        var lines: [String] = []
        switch (digest.moodDirection, digest.moodLean) {
        case (.up, .clearly):   lines.append(moodUpClearlyLine)
        case (.up, _):          lines.append(moodUpGentlyLine)
        case (.down, .clearly): lines.append(moodDownClearlyLine)
        case (.down, _):        lines.append(moodDownGentlyLine)
        case (.steady, _):      lines.append(moodSteadyLine)
        case (nil, _):          break
        }
        if digest.sleepDirection == .down { lines.append(sleepDownLine) }
        if digest.movementDelta == .more { lines.append(movementMoreLine) }
        if digest.movementDelta == .less { lines.append(movementLessLine) }
        if digest.sleepDirection == .up { lines.append(sleepUpLine) }
        if digest.practicedDelta == .more { lines.append(practiceMoreLine) }
        if digest.themeIsNew, let theme = digest.topTheme {
            lines.append(String(localized: "\(theme.localized) has been on your mind more this week. i'm holding it with you"))
        }
        if digest.movementLift, digest.moodDirection != .down, (digest.movementDaysThisWeek ?? 0) > 0 {
            lines.append(movementLiftLine)
        }
        return Array(lines.prefix(3))
    }

    // MARK: - Sparse weeks (honest, rotating — never the same nag twice)

    static let sparseLines = [
        String(localized: "a quiet week in the log. no pressure 🌿"),
        String(localized: "we didn't cross paths much this week. the door is always open 🌱"),
        String(localized: "a few quiet days. dino kept the garden warm for you 🍃"),
        String(localized: "not much written down this week. weeks like that happen, and that's okay"),
    ]

    static func sparseLine(weekIndex: Int) -> String {
        sparseLines[abs(weekIndex) % sparseLines.count]
    }
}
