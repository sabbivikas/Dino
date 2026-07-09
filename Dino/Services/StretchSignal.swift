//
//  StretchSignal.swift
//  Dino
//
//  Pure logic for the tiered support row: it appears ONLY on a heavy
//  stretch, never on a single isolated heavy log — a tired tuesday is not
//  a crisis. Fully unit-testable; no UI, no storage, no networking.
//

import Foundation

enum StretchSignal {

    static let heavyLogsThreshold = 3      // trigger a: 3+ heavy logs…
    static let heavyWindowDays = 5         // …within 5 days
    static let overwhelmedPairHours: Double = 48   // trigger b: overwhelmed twice within 48h
    static let cooldownDays = 7            // at most once per 7 days

    static let supportLine = "it's been a heavy stretch. support is always close 🌿"

    private static func isHeavy(_ w: EmotionalWeather) -> Bool {
        w == .drained || w == .overwhelmed
    }

    /// True when the support row should appear. Cooldown is checked first;
    /// then ANY of the three triggers fires it.
    static func shouldOffer(moodEntries: [(date: Date, weather: EmotionalWeather)],
                            journalToggleOn: Bool,
                            journalThemesToday: [String],
                            lastShownAt: Date?,
                            now: Date,
                            calendar: Calendar) -> Bool {
        if let last = lastShownAt {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last),
                                               to: calendar.startOfDay(for: now)).day ?? 0
            if days < cooldownDays { return false }
        }

        let heavyToday = moodEntries.contains {
            calendar.isDate($0.date, inSameDayAs: now) && isHeavy($0.weather)
        }

        // a) 3+ heavy logs within the trailing 5 days
        if let windowStart = calendar.date(byAdding: .day, value: -(heavyWindowDays - 1),
                                           to: calendar.startOfDay(for: now)) {
            let heavyInWindow = moodEntries.filter {
                $0.date >= windowStart && $0.date <= now && isHeavy($0.weather)
            }.count
            if heavyInWindow >= heavyLogsThreshold { return true }
        }

        // b) overwhelmed twice within 48 hours (the most recent one still fresh)
        let overwhelmed = moodEntries.filter { $0.weather == .overwhelmed && $0.date <= now }
            .map { $0.date }.sorted(by: >)
        if let newest = overwhelmed.first,
           now.timeIntervalSince(newest) <= overwhelmedPairHours * 3600,
           overwhelmed.dropFirst().contains(where: { newest.timeIntervalSince($0) <= overwhelmedPairHours * 3600 }) {
            return true
        }

        // c) heavy log today + same-day journal theme "self" (toggle-gated)
        if heavyToday, journalToggleOn, journalThemesToday.contains("self") {
            return true
        }

        return false
    }
}

// MARK: - Cooldown storage (UserDefaults — kept out of the pure logic above)

enum SupportRowStore {
    static let key = "dino.support.lastShownDayKey"

    private static func formatter(_ calendar: Calendar) -> DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df
    }

    static func lastShownAt(calendar: Calendar = .current) -> Date? {
        guard let s = UserDefaults.standard.string(forKey: key) else { return nil }
        return formatter(calendar).date(from: s)
    }

    static func recordShown(now: Date = Date(), calendar: Calendar = .current) {
        UserDefaults.standard.set(formatter(calendar).string(from: now), forKey: key)
    }
}
