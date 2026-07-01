//
//  BreakSchedulerService.swift
//  Dino
//
//  Break-finder v3 — cal.com style. Generates ALL available 20-min slot
//  candidates (hourly within free calendar blocks: today now+20m→10pm, plus
//  tomorrow 8am–6pm if today has < 3), sends them to suggestBreakSlot, and the
//  function returns a single recommended time. The app shows every slot and
//  highlights the AI's pick; the user chooses.
//
//  PRIVACY: the only free text leaving the device is the user's own message,
//  sent to the cloud function only — never logged, never stored. Event titles
//  are never read or sent.
//

import Foundation
import FirebaseFunctions

struct SlotOption: Identifiable {
    let id = UUID()
    let startDate: Date
    let duration: Int        // minutes (always 20)
    let displayTime: String  // "9:00am"
    let isRecommended: Bool
}

struct BreakSuggestion {
    let acknowledgment: String
    let suggestedActivity: String   // "breathing" | "meditation" | "journaling"
    let reason: String
    let slots: [SlotOption]          // ALL available slots
    let recommendedSlot: SlotOption? // the AI's pick
    let deepLinkAction: String       // "breathe" | "meditation" | "journal"
}

@MainActor
final class BreakSchedulerService {
    static let shared = BreakSchedulerService()
    private init() {}

    private static let buffer: TimeInterval = 20 * 60   // earliest slot ≥ 20 min from now
    private static let slot: TimeInterval = 20 * 60     // each break is 20 min
    private static let maxCandidates = 12

    private static let fbAck = "today sounds heavy"
    private static let fbActivity = "breathing"
    private static let fbReason = "a quiet moment to breathe 🌿"

    // MARK: - Suggest

    /// Builds all candidate slots, asks the function for one recommended time,
    /// and returns the acknowledgment + activity + ALL slots with the AI's pick
    /// flagged. `userMessage` is the user's free text (empty if skipped).
    func suggestBreak(mood: EmotionalWeather,
                      userMessage: String,
                      analysis: RhythmsAnalysis?,
                      calendar: Calendar = .current) async -> BreakSuggestion? {
        let now = Date()
        var candidates = await candidateTimes(for: now, startHour: 8, endHour: 22, calendar: calendar)
        if candidates.count < 3, let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            let tmrw = await candidateTimes(for: tomorrow, startHour: 8, endHour: 18, calendar: calendar)
            candidates = (candidates + tmrw).sorted()
        }
        candidates = Array(candidates.prefix(Self.maxCandidates))

        let payload = buildPayload(mood: mood, userMessage: userMessage, analysis: analysis,
                                   candidates: candidates, calendar: calendar)

        var ack = Self.fbAck, activity = Self.fbActivity, reason = Self.fbReason
        var recommendedTime: String?
        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("suggestBreakSlot").call(payload)
            if let data = result.data as? [String: Any] {
                ack = (data["acknowledgment"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Self.fbAck
                activity = (data["suggestedActivity"] as? String)
                    .flatMap { ["breathing", "meditation", "journaling"].contains($0) ? $0 : nil } ?? Self.fbActivity
                reason = (data["reason"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Self.fbReason
                recommendedTime = (data["recommendedTime"] as? String)?.lowercased()
            }
        } catch {
            #if DEBUG
            print("🌿 break suggestion error: \(error)")
            #endif
            // Surface AI failures in production (no PII — domain + code only) so a
            // bad key / rate limit doesn't silently degrade to the fallback ack.
            let ns = error as NSError
            AnalyticsManager.shared.trackBreakFinderAIFailed(domain: ns.domain, code: ns.code)
        }

        // Recommended = the AI's time if it matches a candidate, else the first slot.
        let recLabel = recommendedTime ?? candidates.first.map { timeLabel($0, calendar) }
        let slots: [SlotOption] = candidates.map { date in
            let label = timeLabel(date, calendar)
            return SlotOption(startDate: date, duration: 20, displayTime: label, isRecommended: label == recLabel)
        }
        let recommendedSlot = slots.first(where: { $0.isRecommended })
        return BreakSuggestion(acknowledgment: ack, suggestedActivity: activity, reason: reason,
                               slots: slots, recommendedSlot: recommendedSlot,
                               deepLinkAction: Self.action(for: activity))
    }

    // MARK: - Candidate generation

    /// Hourly candidate start times within the day's FREE calendar blocks,
    /// clamped to [startHour..endHour] (and ≥ now+20min for today). Each block
    /// contributes its start plus each following top-of-hour while a 20-min slot
    /// still fits.
    private func candidateTimes(for date: Date,
                                startHour: Int,
                                endHour: Int,
                                calendar: Calendar) async -> [Date] {
        let now = Date()
        let startOfDay = calendar.startOfDay(for: date)
        let isToday = calendar.isDate(date, inSameDayAs: now)
        guard let winStart = calendar.date(byAdding: .hour, value: startHour, to: startOfDay),
              let winEnd = calendar.date(byAdding: .hour, value: endHour, to: startOfDay) else { return [] }
        let earliest = isToday ? max(winStart, now.addingTimeInterval(Self.buffer)) : winStart
        guard earliest < winEnd else { return [] }

        let blocks = await CalendarService.shared.findFreeSlots(for: date, calendar: calendar)
            .compactMap { b -> DateInterval? in
                let s = max(b.start, earliest)
                let e = min(b.end, winEnd)
                return s.addingTimeInterval(Self.slot) <= e ? DateInterval(start: s, end: e) : nil
            }

        var times: [Date] = []
        for block in blocks {
            times.append(block.start)
            var hour = topOfNextHour(after: block.start, calendar: calendar)
            while hour.addingTimeInterval(Self.slot) <= block.end {
                if hour > block.start { times.append(hour) }
                guard let next = calendar.date(byAdding: .hour, value: 1, to: hour) else { break }
                hour = next
            }
        }
        var seen = Set<Date>()
        return times.sorted().filter { seen.insert($0).inserted }
    }

    private func topOfNextHour(after date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let top = calendar.date(from: comps) ?? date
        if top > date { return top }
        return calendar.date(byAdding: .hour, value: 1, to: top) ?? date.addingTimeInterval(3600)
    }

    // MARK: - Confirm

    /// Creates the calendar event for the chosen slot and schedules a reminder
    /// 5 min before that deep-links to the suggested activity. True on success.
    func confirmBreak(slot: SlotOption, suggestion: BreakSuggestion) async -> Bool {
        let created = CalendarService.shared.createBreakEvent(
            title: "\(suggestion.suggestedActivity) break with dino 🌿",
            start: slot.startDate,
            duration: TimeInterval(slot.duration * 60),
            notes: suggestion.reason
        )
        guard created else { return false }
        let fireDate = max(slot.startDate.addingTimeInterval(-300), Date().addingTimeInterval(5))
        NotificationManager.shared.scheduleBreakReminder(at: fireDate, action: suggestion.deepLinkAction)
        return true
    }

    // MARK: - Activity → deep-link action

    static func action(for activity: String) -> String {
        switch activity {
        case "meditation": return "meditation"
        case "journaling": return "journal"
        default:           return "breathe"   // breathing
        }
    }

    // MARK: - Payload (anonymized, plus the user's own message)

    private func buildPayload(mood: EmotionalWeather,
                             userMessage: String,
                             analysis: RhythmsAnalysis?,
                             candidates: [Date],
                             calendar: Calendar) -> [String: Any] {
        let now = Date()
        let isAfter7pm = calendar.component(.hour, from: now) >= 19
        var rhythmsContext: [String: Any] = ["available": false]
        if let a = analysis, a.hasEnoughData {
            let slope = a.trajectory.slope
            let practiceHelps = (a.practiceCorrelation?.liftRatio ?? 0) > 1.05
            rhythmsContext = [
                "available": true,
                "recentTrend": slope < -0.05 ? "down" : (slope > 0.05 ? "up" : "flat"),
                "helpfulPractice": practiceHelps ? "journaling" : "none",
            ]
        }
        return [
            "userMessage": String(userMessage.prefix(200)),
            "currentMood": mood.rawValue,
            "freeSlots": candidates.map { timeLabel($0, calendar) },
            "timeOfDay": timeOfDay(now, calendar),
            "dayOfWeek": weekdayName(now, calendar),
            "isAfter7pm": isAfter7pm,
            "rhythmsContext": rhythmsContext,
            "nowTime": timeLabel(now, calendar),
            "userLocale": Locale.current.language.languageCode?.identifier ?? "en",
        ]
    }

    // MARK: - Formatting helpers (local, fixed locale)

    /// "9:00am" — lowercase, local, matches what the function returns.
    func timeLabel(_ date: Date, _ calendar: Calendar) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "h:mma"
        return df.string(from: date).lowercased()
    }

    private func weekdayName(_ date: Date, _ calendar: Calendar) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "EEEE"
        return df.string(from: date).lowercased()
    }

    private func timeOfDay(_ date: Date, _ calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case ..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
}
