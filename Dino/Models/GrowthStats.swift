//
//  GrowthStats.swift
//  Dino
//

import Foundation

struct GrowthStats: Codable {
    var level: Int
    var xp: Int
    var sleepHP: Int
    var exerciseStrength: Int
    var socialXP: Int
    var focusPoints: Int

    init(level: Int = 1, xp: Int = 0, sleepHP: Int = 0, exerciseStrength: Int = 0, socialXP: Int = 0, focusPoints: Int = 0) {
        self.level = level
        self.xp = xp
        self.sleepHP = sleepHP
        self.exerciseStrength = exerciseStrength
        self.socialXP = socialXP
        self.focusPoints = focusPoints
    }

    var xpToNextLevel: Int {
        return 100
    }

    var xpProgress: Double {
        return Double(xp % 100) / 100.0
    }

    var xpInCurrentLevel: Int {
        return xp % 100
    }
}
