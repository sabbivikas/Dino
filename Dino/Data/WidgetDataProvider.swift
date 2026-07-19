//
//  WidgetDataProvider.swift
//  Dino
//

import Foundation

/// Read-only struct for widget extensions — reads from shared App Group UserDefaults
struct WidgetDataProvider {
    private let defaults: UserDefaults

    init() {
        self.defaults = UserDefaults(suiteName: "group.com.vikassabbi.dino") ?? UserDefaults.standard
    }

    var currentStreak: Int {
        load(StreakData.self, key: "streakData")?.currentStreak ?? 0
    }

    var longestStreak: Int {
        load(StreakData.self, key: "streakData")?.longestStreak ?? 0
    }

    /// Array of 7 booleans representing whether the streak was active for each day
    /// of the current week (Sunday...Saturday). True = active that day.
    var weeklyStreakDays: [Bool] {
        guard let data = load(StreakData.self, key: "streakData") else {
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
        load(GrowthStats.self, key: "growthStats")?.level ?? 1
    }

    var userName: String {
        defaults.string(forKey: userKey("userName")) ?? ""
    }

    var todayMoodEmoji: String {
        guard let entries = load([MoodEntry].self, key: "moodEntries"),
              let today = entries.first(where: { Calendar.current.isDateInToday($0.date) }) else {
            return "🌤"
        }
        return today.weatherType.emoji
    }

    var todayGratitudeCount: Int {
        guard let notes = load([GratitudeNote].self, key: "gratitudeNotes") else { return 0 }
        return notes.filter { Calendar.current.isDateInToday($0.createdAt) }.count
    }

    var todayFocus: String {
        // Focus sessions don't have a "goal" text — return empty string if none today.
        // The widget uses this to show whether the user has focused today.
        guard let sessions = load([FocusSession].self, key: "focusSessions"),
              sessions.first(where: { Calendar.current.isDateInToday($0.date) }) != nil else {
            return ""
        }
        let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.date) }
        let totalMins = todaySessions.reduce(0) { $0 + $1.durationSeconds } / 60
        return String(localized: "\(totalMins) min focused today")
    }

    var totalGratitudeCount: Int {
        load([GratitudeNote].self, key: "gratitudeNotes")?.count ?? 0
    }

    var latestAffirmation: String {
        guard let affirmations = load([SavedAffirmation].self, key: "savedAffirmations"),
              let latest = affirmations.max(by: { $0.savedAt < $1.savedAt }) else {
            return String(localized: "you are enough, exactly as you are.")
        }
        return latest.text
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
