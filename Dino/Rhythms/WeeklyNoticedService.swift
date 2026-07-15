//
//  WeeklyNoticedService.swift
//  Dino
//
//  Orchestrates the weekly "what i noticed" lines: builds the anonymized
//  WeeklyDigest locally, asks generateWeeklyNoticed for dino's prose, and
//  falls back through the chain — gpt letter → delta-aware local templates →
//  rotating sparse copy → nil (truly empty week: the static insight cards
//  render as before). Only buckets and deltas ever travel; raw step counts,
//  sleep hours, and journal text never leave the device. One generation per
//  ISO week, cached locally.
//

import Foundation
import FirebaseFunctions

@MainActor
final class WeeklyNoticedService {
    static let shared = WeeklyNoticedService()
    private init() {}

    struct CachedNoticed: Codable {
        let weekKey: String
        let lines: [String]
        let source: String   // "ai" | "local" | "sparse" | "empty"
    }

    private let cacheKey = "dino.rhythms.noticed"

    static func weekKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let week = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        return String(format: "%04d-W%02d", year, week)
    }

    /// The lines for this week (cached after first computation). Nil means
    /// "nothing to say" — the caller keeps its existing static fallback.
    func linesForThisWeek(dataManager: SharedDataManager = .shared,
                          now: Date = Date(),
                          calendar: Calendar = .current) async -> [String]? {
        let key = Self.weekKey(now: now, calendar: calendar)
        if let cached = load(), cached.weekKey == key {
            return cached.lines.isEmpty ? nil : cached.lines
        }
        let previousLines = load()?.lines ?? []

        let digest = await buildDigest(dataManager: dataManager, now: now, calendar: calendar)
        if digest.isEmpty {
            save(CachedNoticed(weekKey: key, lines: [], source: "empty"))
            return nil
        }
        if digest.isSparse {
            let line = WeeklyDigest.sparseLine(weekIndex: calendar.component(.weekOfYear, from: now))
            save(CachedNoticed(weekKey: key, lines: [line], source: "sparse"))
            return [line]
        }

        if let ai = await generate(digest: digest, lastWeekLines: previousLines),
           !ai.isEmpty, ai != previousLines {
            save(CachedNoticed(weekKey: key, lines: ai, source: "ai"))
            return ai
        }

        let local = WeeklyDigest.localLines(digest: digest)
        save(CachedNoticed(weekKey: key, lines: local, source: "local"))
        return local.isEmpty ? nil : local
    }

    // MARK: - Digest assembly (raw values stay in this process)

    private func buildDigest(dataManager: SharedDataManager,
                             now: Date, calendar: Calendar) async -> WeeklyDigest {
        let moodSamples = dataManager.moodEntries.map {
            MoodSample(date: $0.date, weather: $0.weatherType)
        }
        var practiceDates = dataManager.journalEntries.map { $0.date }
        practiceDates += dataManager.gratitudeNotes.map { $0.createdAt }
        practiceDates += dataManager.breathingSessions.map { $0.date }

        var stepDays: [(date: Date, steps: Double)] = []
        var movementLift = false
        if HealthService.shared.hasRequestedSteps,
           let totals = await HealthService.shared.dailyStepTotals(days: 30, now: now, calendar: calendar) {
            stepDays = totals
            let engine = RhythmsDataAdapter.makeEngine(
                from: dataManager,
                stepsSamples: totals.map { StepsSample(date: $0.date, steps: $0.steps) },
                now: now, calendar: calendar)
            if let corr = engine.movementCorrelation(),
               corr.liftRatio >= StepsSignal.insightLiftThreshold {
                movementLift = true
            }
        }

        var sleepNights: [(date: Date, hours: Double)] = []
        if HealthService.shared.hasRequestedSleep,
           let series = await HealthService.shared.nightlySleepSeries(nights: 30, now: now, calendar: calendar) {
            sleepNights = series
        }

        let streak = dataManager.streakData.currentStreak
        let streakState = streak <= 0 ? "none" : (streak < 3 ? "just starting" : (streak < 7 ? "building" : "strong"))

        return WeeklyDigest.build(
            moodSamples: moodSamples,
            practiceDates: practiceDates,
            stepDays: stepDays,
            sleepNights: sleepNights,
            themeTags: dataManager.themeTags.map { (date: $0.date, theme: $0.theme) },
            journalToggleOn: dataManager.journalThemeLearningEnabled,
            movementLift: movementLift,
            streakState: streakState,
            now: now, calendar: calendar)
    }

    // MARK: - Server generation (buckets and deltas only)

    private func generate(digest: WeeklyDigest, lastWeekLines: [String]) async -> [String]? {
        var payload: [String: Any] = [
            "practicedDelta": digest.practicedDelta?.rawValue ?? "same",
            "daysLogged": digest.daysLogged,
            "streakState": digest.streakState,
            "movementLift": digest.movementLift,
            "themeIsNew": digest.themeIsNew,
            "lastWeekLines": Array(lastWeekLines.prefix(3)),
            "userLocale": AppLanguage.current,
        ]
        if let d = digest.moodDirection { payload["moodDirection"] = d.rawValue }
        if let l = digest.moodLean { payload["moodLean"] = l.rawValue }
        if let m = digest.movementDelta { payload["movementDelta"] = m.rawValue }
        if let s = digest.sleepDirection { payload["sleepDirection"] = s.rawValue }
        if let n = digest.shortNightsThisWeek { payload["shortNights"] = n }
        if let n = digest.solidNightsThisWeek { payload["solidNights"] = n }
        if let t = digest.topTheme { payload["topTheme"] = t }

        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("generateWeeklyNoticed").call(payload)
            guard let data = result.data as? [String: Any],
                  let raw = data["lines"] as? [String] else { return nil }
            let lines = raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { line in
                    !line.isEmpty && line.count <= 180
                        && line == line.lowercased()
                        && !line.contains("-") && !line.contains("\u{2013}") && !line.contains("\u{2014}")
                }
            return (1...3).contains(lines.count) ? lines : nil
        } catch {
            #if DEBUG
            print("🌿 weekly noticed error: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Cache

    private func load() -> CachedNoticed? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(CachedNoticed.self, from: data)
    }

    private func save(_ cached: CachedNoticed) {
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
