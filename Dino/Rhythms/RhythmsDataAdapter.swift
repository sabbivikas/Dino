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
        let themeSamples = data.themeTags.map {
            ThemeSample(date: $0.date, theme: $0.theme)
        }
        return PatternEngine(
            moodSamples: moodSamples,
            practiceDates: practiceDates,
            themeSamples: themeSamples,
            now: now,
            calendar: calendar,
            windowDays: windowDays
        )
    }

    /// Convenience: the full analysis from live data.
    static func currentAnalysis(now: Date = Date()) -> RhythmsAnalysis {
        makeEngine(now: now).analyze()
    }

    /// One mood per recent local day (oldest → newest) for the helix — days
    /// with multiple entries collapse to that day's averages. Gold
    /// "breakthrough" is reserved for a genuinely exceptional day: a clear day
    /// with very high energy AND intensity (≥ 8/10 each). Otherwise color
    /// honestly reflects the day's weather.
    static func recentMoodSequence(from data: SharedDataManager = .shared,
                                   days: Int = 60,
                                   now: Date = Date(),
                                   calendar: Calendar = .current) -> [HelixMood] {
        let today = LocalDay(date: now, calendar: calendar)
        let startDay = today.adding(days: -(days - 1), calendar)
        var byDay: [LocalDay: (scores: [Double], energy: [Int], intensity: [Int])] = [:]
        for entry in data.moodEntries {
            let d = LocalDay(date: entry.date, calendar: calendar)
            guard d >= startDay, d <= today else { continue }
            var cur = byDay[d] ?? (scores: [], energy: [], intensity: [])
            cur.scores.append(PatternEngine.moodScore(entry.weatherType))
            cur.energy.append(entry.energyLevel)
            cur.intensity.append(entry.intensityLevel)
            byDay[d] = cur
        }
        return byDay.keys.sorted().compactMap { day -> HelixMood? in
            guard let v = byDay[day], !v.scores.isEmpty else { return nil }
            let avgScore = v.scores.reduce(0, +) / Double(v.scores.count)
            let weather = weather(forScore: avgScore)
            if weather == .clear, !v.energy.isEmpty, !v.intensity.isEmpty {
                let avgEnergy = Double(v.energy.reduce(0, +)) / Double(v.energy.count)
                let avgIntensity = Double(v.intensity.reduce(0, +)) / Double(v.intensity.count)
                if avgEnergy >= 8, avgIntensity >= 8 { return .breakthrough }
            }
            return HelixMood.from(weather)
        }
    }

    private static func weather(forScore s: Double) -> EmotionalWeather {
        if s >= 3.5 { return .clear }
        if s >= 2.5 { return .partlyCloudy }
        if s >= 1.5 { return .overwhelmed }
        return .drained
    }
}
