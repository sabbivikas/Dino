//
//  GrowthViewModel.swift
//  Dino
//

import SwiftUI
import Combine

// MARK: - File-scope types

enum Practice: String, CaseIterable, Identifiable {
    case journal, mood, gratitude, breathing

    var id: String { rawValue }
    var displayName: String { rawValue }

    var bloomColor: Color {
        switch self {
        case .journal:   return Color(hex: "#F5D98C")  // yellow vine
        case .mood:      return Color(hex: "#E8B4B8")  // warm rose daisy
        case .gratitude: return Color(hex: "#F5C842")  // gold sunflower
        case .breathing: return Color(hex: "#B4A4C8")  // lavender
        }
    }

    // nil = breathing (pushed via NavigationLink instead of tab switch)
    var deepLinkTab: Int? {
        switch self {
        case .journal:   return 1
        case .mood:      return 2
        case .gratitude: return 3
        case .breathing: return nil
        }
    }
}

enum PlantStage: String {
    case seed, sprouting, growing, budding, bloomed
}

enum CareStatus {
    case thriving       // care > 0.7  -> sage green
    case needsAttention // care > 0.4  -> peach/amber
    case wilting        // care <= 0.4 -> red

    var label: String {
        switch self {
        case .thriving:       return "thriving"
        case .needsAttention: return "needs attention"
        case .wilting:        return "wilting"
        }
    }

    var color: Color {
        switch self {
        case .thriving:       return Color(hex: "#7BA872")
        case .needsAttention: return Color(hex: "#D4920A")
        case .wilting:        return Color(hex: "#C85050")
        }
    }

    var note: String {
        switch self {
        case .thriving:       return "keep showing up"
        case .needsAttention: return "dino misses this practice"
        case .wilting:        return "come back before it is too late"
        }
    }
}

struct PlantState: Identifiable {
    let practice: Practice
    let totalSessions: Int
    let daysSinceLastUsed: Int?   // nil = never used
    let currentStreak: Int

    var id: String { practice.rawValue }

    var growth: Double { min(Double(totalSessions) / 62.0, 1.0) }

    var care: Double {
        guard totalSessions > 0, let d = daysSinceLastUsed else { return 0 }
        return max(0, 1.0 - Double(d) / 14.0)
    }

    var stage: PlantStage {
        switch growth {
        case ..<0.06: return .seed
        case ..<0.30: return .sprouting
        case ..<0.55: return .growing
        case ..<0.82: return .budding
        default:      return .bloomed
        }
    }

    var careStatus: CareStatus {
        if care > 0.7 { return .thriving }
        if care > 0.4 { return .needsAttention }
        return .wilting
    }
}

@MainActor
class GrowthViewModel: ObservableObject {
    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
    }

    // MARK: - XP / level (preserved)

    var stats: GrowthStats { dataManager.growthStats }

    var levelLabel: String { "level \(stats.level)" }

    var xpLabel: String { "\(stats.xpInCurrentLevel) / 100 xp" }

    var xpProgress: Double { stats.xpProgress }

    // MARK: - Per-practice data derivation

    var plantStates: [PlantState] {
        Practice.allCases.map { practice in
            let (count, lastUsed) = rawSessionData(for: practice)
            let days = lastUsed.map { daysBetween($0, and: Date()) }
            return PlantState(
                practice: practice,
                totalSessions: count,
                daysSinceLastUsed: days,
                currentStreak: computeStreak(for: practice)
            )
        }
    }

    private func rawSessionData(for practice: Practice) -> (Int, Date?) {
        switch practice {
        case .journal:
            return (dataManager.journalEntries.count,
                    dataManager.journalEntries.first?.date)
        case .mood:
            return (dataManager.moodEntries.count,
                    dataManager.moodEntries.first?.date)
        case .gratitude:
            return (dataManager.gratitudeNotes.count,
                    dataManager.gratitudeNotes.first?.createdAt)
        case .breathing:
            return (dataManager.breathingSessions.count,
                    dataManager.breathingSessions.first?.date)
        }
    }

    private func daysBetween(_ from: Date, and to: Date) -> Int {
        let cal = Calendar.current
        let a = cal.startOfDay(for: from)
        let b = cal.startOfDay(for: to)
        return max(0, cal.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    private func computeStreak(for practice: Practice) -> Int {
        let dates = practiceDates(for: practice)
        guard !dates.isEmpty else { return 0 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let keys = Set(dates.map { cal.startOfDay(for: $0) })

        // Streak must include today or yesterday to be "current"
        var cursor = today
        if !keys.contains(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
                  keys.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while keys.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func practiceDates(for practice: Practice) -> [Date] {
        switch practice {
        case .journal:   return dataManager.journalEntries.map { $0.date }
        case .mood:      return dataManager.moodEntries.map { $0.date }
        case .gratitude: return dataManager.gratitudeNotes.map { $0.createdAt }
        case .breathing: return dataManager.breathingSessions.map { $0.date }
        }
    }

    // MARK: - Weekly bloom log
    // 7 days ending with the current week's Sunday (Mon-Sun), each day -> set
    // of practices done.
    var weeklyBlooms: [(date: Date, dayLabel: String, practices: Set<Practice>)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // weekday where 1=Sunday, so Monday=2. Distance back to Monday:
        let weekday = cal.component(.weekday, from: today)   // 1...7
        let daysBackToMonday = (weekday + 5) % 7             // Sun=6..Sat=5 -> Mon=0
        guard let monday = cal.date(byAdding: .day, value: -daysBackToMonday, to: today) else {
            return []
        }
        let labels = ["m", "t", "w", "t", "f", "s", "s"]
        return (0..<7).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: monday) else { return nil }
            var done: Set<Practice> = []
            for p in Practice.allCases {
                if practiceDates(for: p).contains(where: { cal.isDate($0, inSameDayAs: d) }) {
                    done.insert(p)
                }
            }
            return (d, labels[offset], done)
        }
    }
}
