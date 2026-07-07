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
    private static let bodyFlavorDaysKey = "dino.nudge.bodyFlavorDays"

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

        // Body context: relative buckets ONLY — raw hours and step counts
        // never leave the device. Flavor is capped at 2 payloads per rolling
        // week, and the LOCAL-ONLY crisis marker (UserDefaults, never synced,
        // never in analytics) silences it entirely for 7 days, so nudges stay
        // mood-driven — never fitness-app nagging.
        let moodIsHeavy = lastMood == "overwhelmed" || lastMood == "drained"
        let flavorDates = (UserDefaults.standard.array(forKey: bodyFlavorDaysKey) as? [Date]) ?? []
        if BodyNudge.allowFlavor(flavorDates: flavorDates,
                                 crisisDate: CrisisMarker.lastTriggered(calendar: calendar),
                                 now: now, calendar: calendar) {
            var sleepBucket: StepsSignal.SleepBucket?
            if HealthService.shared.hasRequestedSleep,
               let nights = await HealthService.shared.nightlySleepHours(now: now, calendar: calendar),
               let last = nights.lastNight {
                sleepBucket = StepsSignal.sleepBucket(lastNight: last, priorNights: nights.priorNights)
            }
            var movementBucket: StepsSignal.MovementBucket?
            var quietStretch = false
            if HealthService.shared.hasRequestedSteps,
               let totals = await HealthService.shared.dailyStepTotals(days: 31, now: now, calendar: calendar) {
                movementBucket = StepsSignal.bucket(today: totals.last?.steps ?? 0,
                                                    history: totals.dropLast().map { $0.steps })
                quietStretch = BodyNudge.isQuietStretch(dailyTotals: totals.map { $0.steps })
            }
            let fields = BodyNudge.fields(moodIsHeavy: moodIsHeavy,
                                          sleepBucket: sleepBucket,
                                          movementBucket: movementBucket,
                                          quietStretch: quietStretch)
            if !fields.isEmpty {
                for (k, v) in fields { payload[k] = v }
                UserDefaults.standard.set(Array(flavorDates.suffix(9)) + [now], forKey: bodyFlavorDaysKey)
            }
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
