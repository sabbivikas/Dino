//
//  GrowthViewModel.swift
//  Dino
//

import SwiftUI
import Combine

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

    var levelLabel: String { "level \(currentLevel)" }

    var xpLabel: String { "\(xpInCurrentLevel) / \(xpToNextLevel) xp" }

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
        switch practice {
        case .journal:   addXP(15)
        case .mood:      addXP(10)
        case .gratitude: addXP(5)
        case .breathing: addXP(20)
        }
        updateStreak()
    }

    /// Refresh the published streak from SharedDataManager.
    func updateStreak() {
        currentStreak = dataManager.streakData.currentStreak
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
        let labels = ["m", "t", "w", "t", "f", "s", "s"]
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

    var journalSessionCount: Int   { dataManager.journalEntries.count }
    var moodSessionCount: Int      { dataManager.moodEntries.count }
    var gratitudeSessionCount: Int { dataManager.gratitudeNotes.count }
    var breathingSessionCount: Int { dataManager.breathingSessions.count }

    /// Normalized growth 0...1 — reaches full bloom at ~62 total sessions.
    var growth: Double {
        min(Double(totalSessions) / 62.0, 1.0)
    }

    /// Care 0...1 based on recency of any practice. Happy seed for new users.
    var care: Double {
        if totalSessions == 0 { return 1.0 }
        let d = daysSinceAny
        if d >= Int.max / 2 { return 0.0 }
        return max(0, 1.0 - Double(d) / 14.0)
    }

    // MARK: - Recency

    var daysSinceJournal: Int {
        guard let d = dataManager.journalEntries.first?.date else { return .max }
        return daysSince(d)
    }

    var daysSinceMood: Int {
        guard let d = dataManager.moodEntries.first?.date else { return .max }
        return daysSince(d)
    }

    var daysSinceGratitude: Int {
        guard let d = dataManager.gratitudeNotes.first?.createdAt else { return .max }
        return daysSince(d)
    }

    var daysSinceBreathing: Int {
        guard let d = dataManager.breathingSessions.first?.date else { return .max }
        return daysSince(d)
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

    // MARK: - Phase progressions (smoothstep)

    var sproutP: Double { vmSmoothstep(growth, 0.04, 0.18) }
    var stemP:   Double { vmSmoothstep(growth, 0.22, 0.70) }
    var leafP:   Double { vmSmoothstep(growth, 0.32, 0.78) }
    var budP:    Double { vmSmoothstep(growth, 0.55, 0.82) }
    var bloomP:  Double { vmSmoothstep(growth, 0.78, 1.00) }

    var stageLabel: String {
        if bloomP > 0.5 { return "in full bloom" }
        if budP   > 0.5 { return "forming a bud" }
        if leafP  > 0.5 { return "growing tall" }
        if sproutP > 0.5 { return "a fresh sprout" }
        return "a tiny seed"
    }

    var growthPercent: Int { Int((growth * 100).rounded()) }

    var dayNumber: Int { max(totalSessions, 1) }

    // MARK: - Helpers

    private func daysSince(_ date: Date) -> Int {
        let cal = Calendar.current
        let a = cal.startOfDay(for: date)
        let b = cal.startOfDay(for: Date())
        return max(0, cal.dateComponents([.day], from: a, to: b).day ?? 0)
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
