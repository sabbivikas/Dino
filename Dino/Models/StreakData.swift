//
//  StreakData.swift
//  Dino
//

import Foundation

struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date
    var activeDates: Set<String>  // "yyyy-MM-dd" formatted date strings

    init(currentStreak: Int = 0, longestStreak: Int = 0, lastActiveDate: Date = Date.distantPast, activeDates: Set<String> = []) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
        self.activeDates = activeDates
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func isActiveDate(_ date: Date) -> Bool {
        activeDates.contains(Self.dateFormatter.string(from: date))
    }

    static func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func date(fromKey key: String) -> Date? {
        dateFormatter.date(from: key)
    }

    // MARK: - Derived streaks (activeDates is the single source of truth)

    /// Length of the consecutive run of active days ending today — or yesterday,
    /// if today hasn't been logged yet. 0 if neither today nor yesterday is active.
    func computedCurrentStreak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let anchor: Date
        if activeDates.contains(Self.dateKey(for: today)) {
            anchor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  activeDates.contains(Self.dateKey(for: yesterday)) {
            anchor = yesterday   // hasn't logged today yet, but yesterday counts
        } else {
            return 0
        }
        var count = 0
        var day = anchor
        while activeDates.contains(Self.dateKey(for: day)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// Longest consecutive run anywhere in activeDates.
    func computedLongestStreak(calendar: Calendar = .current) -> Int {
        let days = activeDates
            .compactMap { Self.date(fromKey: $0) }
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var run = 1
        for i in 1..<days.count {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: days[i - 1]),
               calendar.isDate(nextDay, inSameDayAs: days[i]) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }
}
