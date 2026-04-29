//
//  WidgetDataProvider.swift
//  DinoLiveActivity
//
//  Read-only data provider for widget extensions. Duplicates necessary model types
//  and data-reading logic since extensions cannot import the main app module.
//

import Foundation

// MARK: - Duplicated Model Types (read-only, for decoding)

private struct StreakDataW: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date
    var activeDates: Set<String>

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func isActiveDate(_ date: Date) -> Bool {
        activeDates.contains(Self.dateFormatter.string(from: date))
    }
}

private struct GrowthStatsW: Codable {
    var level: Int
}

private struct GratitudeNoteW: Codable, Identifiable {
    var id: UUID
    var text: String
    var createdAt: Date
}

private struct SavedAffirmationW: Codable, Identifiable {
    var id: UUID
    var text: String
    var savedAt: Date
}

private struct FocusSessionW: Codable, Identifiable {
    var id: UUID
    var date: Date
    var durationSeconds: Int
    var completed: Bool
}

private enum EmotionalWeatherW: String, Codable {
    case clear
    case partlyCloudy
    case overwhelmed
    case drained

    var emoji: String {
        switch self {
        case .clear: return "☀️"
        case .partlyCloudy: return "🌤"
        case .overwhelmed: return "🌧"
        case .drained: return "🌫"
        }
    }
}

private struct MoodEntryW: Codable, Identifiable {
    var id: UUID
    var date: Date
    var weatherType: EmotionalWeatherW
    var energyLevel: Int
    var intensityLevel: Int
}

// MARK: - Widget Data Provider

struct WidgetDataProvider {
    private let defaults: UserDefaults

    init() {
        self.defaults = UserDefaults(suiteName: "group.com.vikassabbi.dino") ?? UserDefaults.standard
    }

    var currentStreak: Int {
        load(StreakDataW.self, key: "streakData")?.currentStreak ?? 0
    }

    var longestStreak: Int {
        load(StreakDataW.self, key: "streakData")?.longestStreak ?? 0
    }

    /// Array of 7 booleans representing whether the streak was active for each day
    /// of the current week (Sunday...Saturday). True = active that day.
    var weeklyStreakDays: [Bool] {
        guard let data = load(StreakDataW.self, key: "streakData") else {
            return Array(repeating: false, count: 7)
        }
        let calendar = Calendar.current
        let today = Date()
        guard let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else {
            return Array(repeating: false, count: 7)
        }
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return false }
            return data.isActiveDate(day)
        }
    }

    var growthLevel: Int {
        load(GrowthStatsW.self, key: "growthStats")?.level ?? 1
    }

    var userName: String {
        defaults.string(forKey: userKey("userName")) ?? ""
    }

    var todayMoodEmoji: String {
        guard let entries = load([MoodEntryW].self, key: "moodEntries"),
              let today = entries.first(where: { Calendar.current.isDateInToday($0.date) }) else {
            return "🌤"
        }
        return today.weatherType.emoji
    }

    var todayGratitudeCount: Int {
        guard let notes = load([GratitudeNoteW].self, key: "gratitudeNotes") else { return 0 }
        return notes.filter { Calendar.current.isDateInToday($0.createdAt) }.count
    }

    var totalGratitudeCount: Int {
        load([GratitudeNoteW].self, key: "gratitudeNotes")?.count ?? 0
    }

    var todayFocus: String {
        guard let sessions = load([FocusSessionW].self, key: "focusSessions"),
              sessions.first(where: { Calendar.current.isDateInToday($0.date) }) != nil else {
            return ""
        }
        let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.date) }
        let totalMins = todaySessions.reduce(0) { $0 + $1.durationSeconds } / 60
        return "\(totalMins) min focused today"
    }

    var latestAffirmation: String {
        guard let affirmations = load([SavedAffirmationW].self, key: "savedAffirmations"),
              let first = affirmations.first else {
            return "you are enough, exactly as you are."
        }
        return first.text
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: userKey(key)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func userKey(_ key: String) -> String {
        guard let uid = defaults.string(forKey: "currentUserId"), !uid.isEmpty else {
            return key
        }
        return "\(uid)_\(key)"
    }
}
