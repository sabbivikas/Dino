//
//  RhythmsDataAdapter.swift
//  Dino
//
//  Thin bridge from the app's stored data to the pure PatternEngine. This is
//  the ONLY rhythms code that touches SharedDataManager — the math in
//  PatternEngine stays free of it so it can be unit-tested in isolation.
//
//  Mapping:
//   • mood   ← SharedDataManager.moodEntries   (date + weatherType)
//   • practice signal ← journalEntries.date    (the design's "journaling
//     lifts you 2x" claim; breathing/meditation/focus sessions can be folded
//     in later by appending their dates to `practiceDates`).
//   All grouping happens inside the engine using the injected Calendar.
//

import Foundation

@MainActor
enum RhythmsDataAdapter {

    /// Build a PatternEngine from the live store (no UI, no networking).
    static func makeEngine(from data: SharedDataManager = .shared,
                           now: Date = Date(),
                           calendar: Calendar = .current,
                           windowDays: Int = PatternEngine.defaultWindowDays) -> PatternEngine {
        let moodSamples = data.moodEntries.map {
            MoodSample(date: $0.date, weather: $0.weatherType)
        }
        let practiceDates = data.journalEntries.map { $0.date }
        return PatternEngine(
            moodSamples: moodSamples,
            practiceDates: practiceDates,
            now: now,
            calendar: calendar,
            windowDays: windowDays
        )
    }

    /// Convenience: the full analysis from live data.
    static func currentAnalysis(now: Date = Date()) -> RhythmsAnalysis {
        makeEngine(now: now).analyze()
    }
}
