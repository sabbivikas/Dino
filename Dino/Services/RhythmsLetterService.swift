//
//  RhythmsLetterService.swift
//  Dino
//
//  Generates the rhythms "letter from the forest" — the night before a day the
//  pattern engine predicts will be hard. Mirrors ForestLetterService exactly:
//  the Firebase Cloud Function proxies OpenAI so the API key never ships in the
//  binary, and a static fallback line keeps the UI from ever being empty.
//
//  PRIVACY (critical): the ONLY thing that leaves the device is an anonymized,
//  structured summary — enum-like fields derived from the engine's analysis.
//  No journal text, gratitude text, mood notes, or any free text is ever sent.
//

import Foundation
import FirebaseFunctions

/// A generated rhythms letter, cached for the predicted-hard local day it
/// belongs to so we generate at most once per predicted day.
struct RhythmsLetter: Codable {
    let dayKey: String   // yyyy-MM-dd of the predicted-hard local day
    let content: String
}

actor RhythmsLetterService {
    static let shared = RhythmsLetterService()
    private init() {}

    private let cacheKey = "dino.rhythmsLetter"

    /// Shown on any failure so the envelope is never empty. Warm, lowercase,
    /// signed like the model output.
    static let fallbackLetter = """
        tomorrow might ask a little more of you, and that's okay. you have met days like this one before and found your way through them. go gently. rest where you can. keep close the small things that steady you.

        the forest
        """

    // MARK: - Anonymized summary (the ONLY data that leaves the device)

    /// Enum-like, non-identifying fields. There is deliberately no field that
    /// can carry free text — the cloud function also rejects unknown keys.
    struct AnonymizedSummary: Equatable {
        let hardWeekday: String     // "monday"…"sunday"
        let recentTrend: String     // "down" | "flat" | "up"
        let recoveryDays: Int       // 0…30
        let helpfulPractice: String // "journaling"|"breathing"|"gratitude"|"movement"|"rest"|"none"
        let streakState: String     // "growing"|"steady"|"fresh"|"broken"|"none"

        /// The exact payload sent to the cloud function — structured fields only.
        var payload: [String: Any] {
            [
                "hardWeekday": hardWeekday,
                "recentTrend": recentTrend,
                "recoveryDays": recoveryDays,
                "helpfulPractice": helpfulPractice,
                "streakState": streakState,
            ]
        }
    }

    /// Pure mapping from the engine's analysis to the anonymized summary.
    /// Touches no raw entries. `streakState` is passed in by the caller (the
    /// engine doesn't model streaks). The risk is computed for *tomorrow*, so
    /// the hard weekday is tomorrow's weekday name.
    nonisolated static func summary(from analysis: RhythmsAnalysis,
                                    streakState: String,
                                    now: Date = Date(),
                                    calendar: Calendar = .current) -> AnonymizedSummary {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        let slope = analysis.trajectory.slope
        let trend: String = slope < -0.05 ? "down" : (slope > 0.05 ? "up" : "flat")

        let recoveryRaw = analysis.recoveryTimeDays.map { Int($0.rounded()) } ?? 0
        let recovery = max(0, min(30, recoveryRaw))

        // The engine tracks a generic next-day practice lift, not which practice.
        // A positive lift → represent it as the most common practice (journaling);
        // otherwise "none". Honest about what we know, never sends specifics.
        let practiceHelps = (analysis.practiceCorrelation?.liftRatio ?? 0) > 1.05
        let practice = practiceHelps ? "journaling" : "none"

        return AnonymizedSummary(
            hardWeekday: weekdayName(for: tomorrow, calendar: calendar),
            recentTrend: trend,
            recoveryDays: recovery,
            helpfulPractice: practice,
            streakState: streakState
        )
    }

    // MARK: - Generation

    /// Calls `generateRhythmsLetter`. On ANY failure returns the fallback line.
    func generateLetter(summary: AnonymizedSummary) async -> String {
        do {
            let functions = Functions.functions(region: "us-central1")
            let callable = functions.httpsCallable("generateRhythmsLetter")
            let result = try await callable.call(summary.payload)
            if let data = result.data as? [String: Any],
               let content = data["content"] as? String,
               !content.isEmpty {
                return content
            }
            return Self.fallbackLetter
        } catch {
            #if DEBUG
            print("\u{1F332} Rhythms letter error: \(error)")
            #endif
            return Self.fallbackLetter
        }
    }

    // MARK: - Cache (one letter per predicted-hard day)

    func cachedLetter(forDayKey dayKey: String) -> RhythmsLetter? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let letter = try? JSONDecoder().decode(RhythmsLetter.self, from: data),
              letter.dayKey == dayKey else { return nil }
        return letter
    }

    /// Most recently cached letter regardless of day (used by the UI when
    /// opening from the notification tap).
    func latestCachedLetter() -> RhythmsLetter? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(RhythmsLetter.self, from: data)
    }

    func cache(_ letter: RhythmsLetter) {
        guard let data = try? JSONEncoder().encode(letter) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    // MARK: - Date helpers (local-timezone correct, fixed locale)

    nonisolated static func weekdayName(for date: Date, calendar: Calendar) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "EEEE"
        return df.string(from: date).lowercased()
    }

    nonisolated static func dayKey(for date: Date, calendar: Calendar) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}
