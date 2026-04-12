//
//  StreakData.swift
//  Dino
//

import Foundation

struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date

    init(currentStreak: Int = 0, longestStreak: Int = 0, lastActiveDate: Date = Date.distantPast) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
    }
}
