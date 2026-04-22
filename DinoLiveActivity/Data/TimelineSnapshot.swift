//
//  TimelineSnapshot.swift
//  DinoLiveActivity
//
//  Value types for TimelineEntry payloads used by the Mood, Streak, and
//  Breathing widgets. Keeping these in one file makes the timeline shape
//  of every widget easy to diff at a glance.
//

import Foundation
import WidgetKit

// MARK: - Time-of-day

/// Drives the mood widget scene split. Morning 6–12, Day 12–20, Night 20–6.
enum DinoTimeOfDay {
    case morning
    case day
    case night

    static func from(date: Date) -> DinoTimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 20 || hour < 6 { return .night }
        if hour < 12 { return .morning }
        return .day
    }
}

// MARK: - Mood widget

struct MoodSnapshot: TimelineEntry {
    let date: Date
    let timeOfDay: DinoTimeOfDay
    /// Keyframe 0–5 — scene-level pseudo-animation (sun rotation, cloud drift).
    let sceneAnimPhase: Int
    /// Current mood emoji if user has already logged today — used as a small cue.
    let lastMoodEmoji: String
}

// MARK: - Streak widget

struct StreakSnapshot: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let longestStreak: Int
    let weeklyDays: [Bool]
    /// 0.0 → 1.0 position around the flame-flicker keyframe cycle.
    let flickerPhase: Double
}

// MARK: - Breathing widget

struct BreathingSnapshot: TimelineEntry {
    let date: Date
    /// Scale multiplier for the bloom shape — walks through [0.92, 0.96, 1.00, 1.04, 1.08, 1.04].
    let breathPhase: Double
}
