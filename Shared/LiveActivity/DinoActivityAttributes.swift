//
//  DinoActivityAttributes.swift
//  Shared (Dino + DinoLiveActivityExtension)
//
//  Single source of truth for ActivityKit attributes used by the main app
//  and the Live Activity widget extension.
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

// MARK: - Rec Parcel Activity (rec delivery F3)

/// The paper parcel on the lock screen: "dino has something for you".
/// Static by design — the parcel never updates, it only appears (announce)
/// and disappears (opened, or the 6h staleDate sweep).
struct RecParcelActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // no dynamic state — the parcel just glows until it is opened
    }

    var deliveryId: String      // the door: dino://rec-reveal/{deliveryId}
    var announcedAt: Date       // announce instant; staleDate = +lifetime

    /// A parcel lives at most 6h after the announcement (owner spec).
    static let lifetime: TimeInterval = 6 * 3600
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
