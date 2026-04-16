//
//  DinoActivityAttributes.swift
//  Dino
//
//  Activity attributes shared between the main app and the Live Activity widget extension.
//

import ActivityKit
import Foundation

// MARK: - Breathing Exercise Activity

struct BreathingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phase: String           // "Inhale", "Exhale", "Hold"
        var secondsRemaining: Int
        var currentCycle: Int
        var totalCycles: Int
        var progress: Double        // 0.0 to 1.0 within current phase
        var isPaused: Bool
    }

    var sessionType: String         // "4-4-4", "4-7-8", etc.
    var totalDurationSeconds: Int
}

// MARK: - Meditation Activity

struct MeditationActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var secondsRemaining: Int
        var calmMessage: String
        var isPaused: Bool
        var progress: Double        // 0.0 to 1.0 of overall session
    }

    var totalDurationSeconds: Int
}

// MARK: - Focus Session Activity

struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var secondsRemaining: Int
        var progress: Double        // 0.0 to 1.0 of overall session
        var isPaused: Bool
        var motivationMessage: String
    }

    var totalDurationSeconds: Int   // default 1500 (25 min)
}
