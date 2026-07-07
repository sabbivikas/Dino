//
//  DailyNudgeScheduler.swift
//  Dino
//
//  Generates today's smart nudge once (cached), then reschedules the daily
//  check-in so its body uses the fresh line. Only the WORDS change — the user's
//  reminder time/schedule is untouched. On failure the reminder keeps its
//  static NudgeLibrary copy. Mirrors RhythmsLetterScheduler's trigger pattern.
//

import Foundation

@MainActor
enum DailyNudgeScheduler {
    private static let lastGenKey = "dino.dailyNudge.lastGenDayKey"

    /// Safe to call on every foreground; generates at most once per local day.
    static func generateIfNeeded(now: Date = Date(), calendar: Calendar = .current) async {
        let nm = NotificationManager.shared
        guard nm.notificationsEnabled, nm.dailyCheckInEnabled else { return }

        let dayKey = DailyNudgeService.todayKey(calendar, now: now)
        guard UserDefaults.standard.string(forKey: lastGenKey) != dayKey else { return }

        let payload = await buildPayload(now: now, calendar: calendar)
        guard let nudge = await DailyNudgeService.generate(payload: payload) else { return }

        DailyNudgeService.cache(nudge, dayKey: dayKey)
        UserDefaults.standard.set(dayKey, forKey: lastGenKey)
        nm.rescheduleAll()   // rebake the check-in body with the fresh nudge
    }

    /// Anonymized context only — no raw text; optional fields only past their gates.
    private static func buildPayload(now: Date, calendar: Calendar) async -> [String: Any] {
        let dm = SharedDataManager.shared
        let lastMood = dm.moodEntries.first?.weatherType.rawValue ?? "unknown"

        let s = dm.streakData.currentStreak
        let streakState = s <= 0 ? "none" : (s < 3 ? "just starting" : (s < 7 ? "building" : "strong"))

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "EEEE"
        let weekday = df.string(from: now).lowercased()

        var payload: [String: Any] = [
            "lastMood": lastMood,
            "streakState": streakState,
            "weekday": weekday,
            "userLocale": Locale.current.language.languageCode?.identifier ?? "en",
        ]

        if let sleep = await HealthService.shared.lastNightSleep() {
            payload["sleepSummary"] = "\(sleep.displayString) of sleep"
        }

        // Relative bucket only — raw step counts never travel off-device.
        if HealthService.shared.hasRequestedSteps,
           let totals = await HealthService.shared.dailyStepTotals(days: 31, now: now, calendar: calendar),
           let bucket = StepsSignal.bucket(today: totals.last?.steps ?? 0,
                                           history: totals.dropLast().map { $0.steps }) {
            payload["movementToday"] = bucket.rawValue
        }

        let analysis = RhythmsDataAdapter.currentAnalysis(now: now)
        if analysis.risk.confident {
            payload["riskLevel"] = analysis.risk.likelyHard ? "harder" : "steady"
        }
        if let ti = analysis.themeInsights, ti.confident,
           let top = ti.frequency.max(by: { $0.value < $1.value })?.key {
            payload["topTheme"] = top
        }
        return payload
    }
}
