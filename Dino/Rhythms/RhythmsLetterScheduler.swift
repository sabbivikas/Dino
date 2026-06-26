//
//  RhythmsLetterScheduler.swift
//  Dino
//
//  Decides, each evening, whether to deliver a rhythms "letter from the forest"
//  for tomorrow — only when the pattern engine is confident tomorrow will be
//  hard. Generates the (anonymized) letter and schedules an ~8pm local
//  notification the night before. At most one letter per predicted hard day.
//

import Foundation

@MainActor
final class RhythmsLetterScheduler {
    static let shared = RhythmsLetterScheduler()
    private init() {}

    private let lastSentKey = "dino.rhythmsLetter.lastSentDayKey"
    private let deliveryHour = 20   // 8pm local

    /// Safe to call repeatedly (app launch / scene active). No-ops unless the
    /// engine has enough data AND is confident tomorrow is likely hard, and at
    /// most once per predicted hard day.
    func evaluateAndScheduleIfNeeded(now: Date = Date(), calendar: Calendar = .current) async {
        let analysis = RhythmsDataAdapter.currentAnalysis(now: now)
        guard analysis.hasEnoughData else { return }            // never fire before the 21-day gate
        let risk = analysis.risk
        guard risk.confident, risk.likelyHard else { return }   // confident hard-day predictions only

        // The predicted hard day is tomorrow; guard one letter per predicted day.
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return }
        let predictedDayKey = RhythmsLetterService.dayKey(for: tomorrow, calendar: calendar)
        if UserDefaults.standard.string(forKey: lastSentKey) == predictedDayKey { return }

        // Deliver tonight at ~8pm local. If 8pm already passed, skip — this is a
        // night-before letter, not a same-day one.
        guard let fireDate = Self.deliveryDate(now: now, calendar: calendar, hour: deliveryHour),
              fireDate > now else { return }

        // Generate now (anonymized summary ONLY) and cache for the predicted day.
        let summary = RhythmsLetterService.summary(
            from: analysis,
            streakState: Self.streakState(from: analysis),
            now: now,
            calendar: calendar
        )
        let content = await RhythmsLetterService.shared.generateLetter(summary: summary)
        await RhythmsLetterService.shared.cache(
            RhythmsLetter(dayKey: predictedDayKey, content: content))

        NotificationManager.shared.scheduleRhythmsLetter(at: fireDate)
        UserDefaults.standard.set(predictedDayKey, forKey: lastSentKey)
    }

    /// Tonight at `hour`:00 local.
    static func deliveryDate(now: Date, calendar: Calendar, hour: Int) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = 0
        return calendar.date(from: comps)
    }

    /// Lightweight streak proxy from the analysis (the engine doesn't model
    /// streaks): trending up → "growing", enough data → "steady", else "none".
    static func streakState(from analysis: RhythmsAnalysis) -> String {
        guard analysis.hasEnoughData else { return "none" }
        if analysis.trajectory.confident && analysis.trajectory.slope > 0.05 { return "growing" }
        return "steady"
    }

    /// Manual test: cache a sample fallback letter and fire the notification in
    /// ~5s. Does NOT call the network. Works in release / TestFlight.
    func scheduleTestLetter() async {
        let key = RhythmsLetterService.dayKey(for: Date(), calendar: .current)
        await RhythmsLetterService.shared.cache(
            RhythmsLetter(dayKey: key, content: RhythmsLetterService.fallbackLetter))
        NotificationManager.shared.scheduleRhythmsLetterTest()
    }

    /// Manual test that exercises the REAL pipeline: builds a sample anonymized
    /// summary, calls the live generateRhythmsLetter cloud function, caches the
    /// result, and fires the notification in ~5s. Works in release / TestFlight.
    func scheduleRealTestLetter() async {
        let summary = RhythmsLetterService.AnonymizedSummary(
            hardWeekday: "monday",
            recentTrend: "down",
            recoveryDays: 2,
            helpfulPractice: "journaling",
            streakState: "steady"
        )
        let letter = await RhythmsLetterService.shared.generateLetter(summary: summary)
        let key = RhythmsLetterService.dayKey(for: Date(), calendar: .current)
        await RhythmsLetterService.shared.cache(
            RhythmsLetter(dayKey: key, content: letter))
        NotificationManager.shared.scheduleRhythmsLetterTest()
    }
}
