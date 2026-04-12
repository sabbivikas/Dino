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

    var growthLevel: Int {
        load(GrowthStats.self, key: "growthStats")?.level ?? 1
    }

    var userName: String {
        defaults.string(forKey: "userName") ?? ""
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

    var latestAffirmation: String {
        guard let affirmations = load([SavedAffirmation].self, key: "savedAffirmations"),
              let first = affirmations.first else {
            return "you are enough, exactly as you are."
        }
        return first.text
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
