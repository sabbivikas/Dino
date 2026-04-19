//
//  MoodEntry.swift
//  Dino
//

import Foundation

enum EmotionalWeather: String, Codable, CaseIterable {
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

    var label: String {
        switch self {
        case .clear: return "clear"
        case .partlyCloudy: return "partly cloudy"
        case .overwhelmed: return "overwhelmed"
        case .drained: return "drained"
        }
    }

    var suggestion: String {
        switch self {
        case .clear:
            return "you're shining today ✨ keep that energy going."
        case .partlyCloudy:
            return "a little mixed — that's okay. take it one step at a time."
        case .overwhelmed:
            return "take a breath. you don't have to carry it all at once."
        case .drained:
            return "rest is healing. be gentle with yourself today."
        }
    }

    var color: String {
        switch self {
        case .clear: return "#F5D98C"          // warm yellow
        case .partlyCloudy: return "#A8D4E6"   // soft blue
        case .overwhelmed: return "#C4B8D4"    // soft purple
        case .drained: return "#C8CDD4"        // soft grey
        }
    }
}

struct MoodEntry: Codable, Identifiable {
    var id: UUID
    var date: Date
    var weatherType: EmotionalWeather
    var energyLevel: Int
    var intensityLevel: Int

    init(id: UUID = UUID(), date: Date = Date(), weatherType: EmotionalWeather, energyLevel: Int, intensityLevel: Int) {
        self.id = id
        self.date = date
        self.weatherType = weatherType
        self.energyLevel = energyLevel
        self.intensityLevel = intensityLevel
    }
}
