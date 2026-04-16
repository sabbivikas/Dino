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
}
