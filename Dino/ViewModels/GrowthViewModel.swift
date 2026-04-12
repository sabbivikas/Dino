//
//  GrowthViewModel.swift
//  Dino
//

import SwiftUI
import Combine

@MainActor
class GrowthViewModel: ObservableObject {
    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
    }

    var stats: GrowthStats { dataManager.growthStats }

    var levelLabel: String { "level \(stats.level)" }

    var xpLabel: String { "\(stats.xpInCurrentLevel) / 100 xp" }

    var xpProgress: Double { stats.xpProgress }

    struct StatItem {
        let emoji: String
        let label: String
        let value: Int
        let color: String
    }

    var statItems: [StatItem] {
        [
            StatItem(emoji: "❤️", label: "sleep hp", value: stats.sleepHP, color: "#E8B4B8"),
            StatItem(emoji: "💪", label: "exercise", value: stats.exerciseStrength, color: "#A8C5A0"),
            StatItem(emoji: "🗣", label: "social", value: stats.socialXP, color: "#C4B8D4"),
            StatItem(emoji: "🎯", label: "focus", value: stats.focusPoints, color: "#A8D4E6"),
        ]
    }

    var dinoEmoji: String {
        switch stats.level {
        case 1...3: return "🥚"
        case 4...7: return "🦕"
        case 8...12: return "🦖"
        default: return "⭐️"
        }
    }
}
