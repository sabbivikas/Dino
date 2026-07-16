//
//  GrowthViewModel.swift
//  Dino
//

import SwiftUI
import Combine
import PostHog

// MARK: - PracticeType

enum PracticeType: String, CaseIterable, Identifiable {
    case journal, mood, gratitude, breathing

    var id: String { rawValue }
    var displayName: String { rawValue }

    var bloomColor: Color {
        switch self {
        case .journal:   return Color(hex: "#F5C842")  // gold
        case .mood:      return Color(hex: "#E8A0A8")  // rose
        case .gratitude: return Color(hex: "#C4A35A")  // warm amber
        case .breathing: return Color(hex: "#A594C4")  // lavender
        }
    }
}

// MARK: - DayBloom

struct DayBloom: Identifiable {
    let id = UUID()
    let date: Date
    let dayLabel: String
    let practices: Set<PracticeType>
}

// MARK: - GrowthStage (discrete, session-driven)

enum GrowthStage: Int, CaseIterable {
    case seed      // 0 sessions
    case cracking  // 1-2
    case sprout    // 3-5
    case seedling  // 6-10
    case growing   // 11-20
    case budding   // 21-35
    case opening   // 36-50
    case bloomed   // 51-62
    case thriving  // 63+

    static func from(sessions: Int) -> GrowthStage {
        switch sessions {
        case ..<1:    return .seed
        case 1...2:   return .cracking
        case 3...5:   return .sprout
        case 6...10:  return .seedling
        case 11...20: return .growing
        case 21...35: return .budding
        case 36...50: return .opening
        case 51...62: return .bloomed
        default:      return .thriving
        }
    }

    /// Inclusive lower bound of sessions required to reach this stage.
    var minSessions: Int {
        switch self {
        case .seed:     return 0
        case .cracking: return 1
        case .sprout:   return 3
        case .seedling: return 6
        case .growing:  return 11
        case .budding:  return 21
        case .opening:  return 36
        case .bloomed:  return 51
        case .thriving: return 63
        }
    }

    var displayName: String {
        switch self {
        case .seed:     return "seed"
        case .cracking: return "cracking"
        case .sprout:   return "sprouting"
        case .seedling: return "seedling"
        case .growing:  return "growing"
        case .budding:  return "budding"
        case .opening:  return "opening"
        case .bloomed:  return "bloomed"
        case .thriving: return "thriving"
        }
    }

    var nextStage: GrowthStage? {
        GrowthStage(rawValue: rawValue + 1)
    }
}

// MARK: - CareState (discrete, days-since-practice driven)

enum CareState {
    case healthy    // 0-2 days
    case tired      // 3-4
    case struggling // 5-7
    case wilting    // 8-10
    case dying      // 11-13
    case dead       // 14+

    static func from(daysSince: Int) -> CareState {
        switch daysSince {
        case ..<3:    return .healthy
        case 3...4:   return .tired
        case 5...7:   return .struggling
        case 8...10:  return .wilting
        case 11...13: return .dying
        default:      return .dead
        }
    }
}

// MARK: - ViewModel

@MainActor
final class GrowthViewModel: ObservableObject {

    // Singleton — the new GrowthView expects `GrowthViewModel.shared`.
    static let shared = GrowthViewModel()

    // Explicit published streak so callers can observe updates without reaching
    // through SharedDataManager every time.
    @Published var currentStreak: Int

    init() {
        self.currentStreak = SharedDataManager.shared.streakData.currentStreak
    }

    // MARK: - XP / Level (persisted via SharedDataManager.growthStats)

    private var dataManager: SharedDataManager { SharedDataManager.shared }

    var currentXP: Int { dataManager.growthStats.xp }

    var currentLevel: Int { dataManager.growthStats.level }

    var xpToNextLevel: Int { dataManager.growthStats.xpToNextLevel }

    var xpInCurrentLevel: Int { dataManager.growthStats.xpInCurrentLevel }

    var xpProgress: Double { dataManager.growthStats.xpProgress }

    var levelLabel: String { String(localized: "level \(currentLevel)") }

    var xpLabel: String { String(localized: "\(xpInCurrentLevel) / \(xpToNextLevel) xp") }

    /// Award XP and handle level-up bookkeeping. Persistence is automatic via
    /// the `growthStats` didSet in SharedDataManager.
    func addXP(_ amount: Int) {
        dataManager.addXP(amount)
        objectWillChange.send()
    }

    /// Force a level bump (used by assessment / milestone flows).
    func levelUp() {
        dataManager.growthStats.level += 1
        objectWillChange.send()
    }

    /// Record a practice activity and award XP appropriate for the type.
    func recordGrowthActivity(_ practice: PracticeType) {
        let previousStage = growthStage
        switch practice {
        case .journal:   addXP(15)
        case .mood:      addXP(10)
        case .gratitude: addXP(5)
        case .breathing: addXP(20)
        }
        let newStage = growthStage
        if newStage != previousStage {
            AnalyticsManager.shared.trackGrowthStageReached(stage: newStage.displayName)
        }
        updateStreak()
    }

    /// Refresh the published streak from SharedDataManager.
    func updateStreak() {
        let previous = currentStreak
        let updated = dataManager.streakData.currentStreak
        currentStreak = updated
        if updated != previous, [7, 14, 30, 60, 100].contains(updated) {
            AnalyticsManager.shared.trackStreakMilestone(days: updated)
        }
    }

    // MARK: - Weekly Bloom Log

    /// 7 days Mon-Sun for the current week, each with the set of practices
    /// the user touched that day.
    var weeklyBlooms: [DayBloom] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)   // 1=Sun ... 7=Sat
        let daysBackToMonday = (weekday + 5) % 7             // Sun=6, Mon=0
        guard let monday = cal.date(byAdding: .day, value: -daysBackToMonday, to: today) else {
            return []
        }
        let symbols = cal.veryShortStandaloneWeekdaySymbols   // Sun-first
        let labels = (0..<7).map { symbols[($0 + 1) % 7].lowercased() }   // Mon-first
        return (0..<7).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: monday) else { return nil }
            var done: Set<PracticeType> = []
            for p in PracticeType.allCases {
                if datesUsed(for: p).contains(where: { cal.isDate($0, inSameDayAs: d) }) {
                    done.insert(p)
                }
            }
            return DayBloom(date: d, dayLabel: labels[offset], practices: done)
        }
    }

    /// Placeholder trigger for callers that want to recompute weekly blooms.
    /// The property is already a computed view of SharedDataManager state, so
    /// all this does is nudge observers.
    func updateWeeklyBlooms() {
        objectWillChange.send()
    }

    // MARK: - Combined practice scalars (sunflower driver)

    var totalSessions: Int {
        journalSessionCount + moodSessionCount + gratitudeSessionCount + breathingSessionCount
    }

    // MARK: - Movement garnish (bonus-only, never negative)

    /// Session-equivalents earned from movement days (0.2 each, capped at 6.0
    /// ≈ 10% of the bloom journey). Refreshed from HealthKit; 0 whenever steps
    /// were never connected or Health has nothing to say — a still week leaves
    /// growth exactly where practices put it.
    @Published private(set) var movementBonus: Double = 0

    func refreshMovementBonus() async {
        guard HealthService.shared.hasRequestedSteps,
              let totals = await HealthService.shared.dailyStepTotals(days: 90) else {
            movementBonus = 0
            return
        }
        let movementDays = StepsSignal.movementDayCount(dailyTotals: totals.map { $0.steps })
        movementBonus = StepsSignal.gardenBonus(movementDays: movementDays)
    }

    /// Practices + movement garnish — the continuous growth driver.
    var effectiveSessions: Double { Double(totalSessions) + movementBonus }

    var journalSessionCount: Int   { dataManager.journalEntries.count }
    var moodSessionCount: Int      { dataManager.moodEntries.count }
    var gratitudeSessionCount: Int { dataManager.gratitudeNotes.count }
    var breathingSessionCount: Int { dataManager.breathingSessions.count }

    /// Normalized growth 0...1 — reaches full bloom at ~62 total sessions
    /// (movement days can garnish this, never shrink it).
    var growth: Double {
        min(effectiveSessions / 62.0, 1.0)
    }

    /// Care 0...1 based on recency of any practice. Happy seed for new users.
    var care: Double {
        if totalSessions == 0 { return 1.0 }
        let d = daysSinceAny
        if d >= Int.max / 2 { return 0.0 }
        return max(0, 1.0 - Double(d) / 14.0)
    }

    // MARK: - Discrete stage + care API

    var growthStage: GrowthStage {
        // Movement can tip a stage boundary (floor of the garnish), never lower one.
        GrowthStage.from(sessions: totalSessions + Int(movementBonus))
    }

    var nextStageName: String? {
        growthStage.nextStage?.displayName
    }

    /// Sessions remaining until the next discrete stage; nil at `.thriving`.
    var sessionsToNextStage: Int? {
        guard let next = growthStage.nextStage else { return nil }
        let need = next.minSessions - totalSessions
        return need > 0 ? need : 1
    }

    var careState: CareState {
        if totalSessions == 0 { return .healthy }
        return CareState.from(daysSince: daysSinceAny)
    }

    // MARK: - Recency

    var daysSinceJournal: Int {
        let dates = dataManager.journalEntries.map { $0.date }
        guard let latest = dates.max() else { return .max }
        return daysSince(latest)
    }

    var daysSinceMood: Int {
        let dates = dataManager.moodEntries.map { $0.date }
        guard let latest = dates.max() else { return .max }
        return daysSince(latest)
    }

    var daysSinceGratitude: Int {
        let dates = dataManager.gratitudeNotes.map { $0.createdAt }
        guard let latest = dates.max() else { return .max }
        return daysSince(latest)
    }

    var daysSinceBreathing: Int {
        let dates = dataManager.breathingSessions.map { $0.date }
        guard let latest = dates.max() else { return .max }
        return daysSince(latest)
    }

    var daysSinceAny: Int {
        let all = [daysSinceJournal, daysSinceMood, daysSinceGratitude, daysSinceBreathing]
        let m = all.min() ?? .max
        return m == .max ? 14 : m
    }

    // MARK: - "Today" flags

    var usedJournalToday: Bool {
        dataManager.journalEntries.contains { Calendar.current.isDateInToday($0.date) }
    }

    var usedMoodToday: Bool {
        dataManager.moodEntries.contains { Calendar.current.isDateInToday($0.date) }
    }

    var usedGratitudeToday: Bool {
        dataManager.gratitudeNotes.contains { Calendar.current.isDateInToday($0.createdAt) }
    }

    var usedBreathingToday: Bool {
        dataManager.breathingSessions.contains { Calendar.current.isDateInToday($0.date) }
    }

    var wateredToday: Bool {
        usedJournalToday || usedMoodToday || usedGratitudeToday || usedBreathingToday
    }

    var lastWateredDaysAgo: Int? {
        let d = daysSinceAny
        guard d > 0, d < 14 else { return nil }
        // daysSinceAny collapses "never used" to 14 — treat it as nil.
        if totalSessions == 0 { return nil }
        return d
    }

    // MARK: - Phase progressions (smoothstep — used as continuous drawing scalars)

    var sproutP: Double { vmSmoothstep(growth, 0.04, 0.18) }
    var stemP:   Double { vmSmoothstep(growth, 0.22, 0.70) }
    var leafP:   Double { vmSmoothstep(growth, 0.32, 0.78) }
    var budP:    Double { vmSmoothstep(growth, 0.55, 0.82) }
    var bloomP:  Double { vmSmoothstep(growth, 0.78, 1.00) }

    /// Legacy stage label retained for back-compat; new code uses `statusMessage`.
    var stageLabel: String { growthStage.displayName }

    var growthPercent: Int { Int((growth * 100).rounded()) }

    var dayNumber: Int { max(totalSessions, 1) }

    /// Status-line message driven by both care and growth. Wilting takes
    /// priority when the plant has been neglected.
    var statusMessage: String {
        switch careState {
        case .tired:      return String(localized: "looking a little thirsty")
        case .struggling: return String(localized: "your sunflower needs attention")
        case .wilting:    return String(localized: "wilting — come back soon")
        case .dying:      return String(localized: "nearly gone — one practice saves it")
        case .dead:       return String(localized: "your sunflower has rested. a new seed waits")
        case .healthy:
            switch growthStage {
            case .seed:     return String(localized: "a seed full of potential")
            case .cracking: return String(localized: "something is stirring underground")
            case .sprout:   return String(localized: "your sunflower just broke through")
            case .seedling: return String(localized: "growing stronger every day")
            case .growing:  return String(localized: "reaching for the light")
            case .budding:  return String(localized: "a bud is forming — keep going")
            case .opening:  return String(localized: "almost there, keep showing up")
            case .bloomed:  return String(localized: "your sunflower is in full bloom")
            case .thriving: return String(localized: "thriving beyond measure")
            }
        }
    }

    // MARK: - Helpers

    private func daysSince(_ date: Date) -> Int {
        let cal = Calendar.current
        let a = cal.startOfDay(for: date)
        let b = cal.startOfDay(for: Date())
        return max(0, cal.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    /// The garden's birthday — the earliest recorded practice across all four
    /// practices. Nil for a garden that hasn't been tended yet. Never resets.
    var firstPracticeDate: Date? {
        PracticeType.allCases
            .flatMap { datesUsed(for: $0) }
            .min()
    }

    private func datesUsed(for practice: PracticeType) -> [Date] {
        switch practice {
        case .journal:   return dataManager.journalEntries.map { $0.date }
        case .mood:      return dataManager.moodEntries.map { $0.date }
        case .gratitude: return dataManager.gratitudeNotes.map { $0.createdAt }
        case .breathing: return dataManager.breathingSessions.map { $0.date }
        }
    }
}

// File-private smoothstep (used only by GrowthViewModel). Suffixed to avoid
// collision with the view-side smoothstep.
private func vmSmoothstep(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let x = max(0, min(1, (t - a) / (b - a)))
    return x * x * (3 - 2 * x)
}
