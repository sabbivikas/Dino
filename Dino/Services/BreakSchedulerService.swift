//
//  BreakSchedulerService.swift
//  Dino
//
//  Break-finder v2 — conversational. Reads free calendar slots, sends an
//  anonymized summary PLUS the user's own free-text message to the
//  suggestBreakSlot cloud function, and returns an acknowledgment + suggested
//  activity (breathing / meditation / journaling) + 2-3 slot options. On confirm,
//  writes the calendar event and schedules a reminder that deep-links to the
//  suggested activity.
//
//  PRIVACY: the only free text that leaves the device is the user's own message,
//  sent to the cloud function (→ OpenAI) ONLY. It is never logged on-device and
//  never written to Firestore. Calendar event titles are never read or sent.
//

import Foundation
import FirebaseFunctions

struct SlotOption: Identifiable {
    let id = UUID()
    let startDate: Date
    let duration: Int        // minutes
    let displayTime: String  // "7:30pm"
}

struct BreakSuggestion {
    let acknowledgment: String
    let suggestedActivity: String   // "breathing" | "meditation" | "journaling"
    let reason: String
    let slots: [SlotOption]
    let deepLinkAction: String      // notification action: "breathe" | "meditation" | "journal"
}

@MainActor
final class BreakSchedulerService {
    static let shared = BreakSchedulerService()
    private init() {}

    /// The earliest suggested slot must start at least this far out.
    private static let minimumBuffer: TimeInterval = 20 * 60

    private static let fbAck = "today sounds heavy"
    private static let fbActivity = "breathing"
    private static let fbReason = "a quiet moment to breathe 🌿"

    // MARK: - Suggest

    /// Finds free slots (≥ 20 min from now), then asks the cloud function for an
    /// acknowledgment + activity + slot options. `userMessage` is the user's free
    /// text (empty string if skipped) — sent to the function only. Always returns
    /// a suggestion (the card decides what to show, incl. an empty-slots state).
    func suggestBreak(mood: EmotionalWeather,
                      userMessage: String,
                      analysis: RhythmsAnalysis?,
                      forDate: Date = Date(),
                      calendar: Calendar = .current) async -> BreakSuggestion? {
        // raw free blocks → trim each to ≥ 20 min from now (buffer) → subdivide
        // into discrete candidate start times the AI can choose 2-3 from.
        let earliest = Date().addingTimeInterval(Self.minimumBuffer)
        let blocks = await CalendarService.shared.findFreeSlots(for: forDate, calendar: calendar)
        let buffered = blocks.compactMap { block -> DateInterval? in
            let start = max(block.start, earliest)
            guard start < block.end else { return nil }
            return DateInterval(start: start, end: block.end)
        }
        let candidates = CalendarService.shared.subdivideFreeBlocks(buffered)

        let payload = buildPayload(mood: mood, userMessage: userMessage, analysis: analysis,
                                   candidates: candidates, forDate: forDate, calendar: calendar)

        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("suggestBreakSlot").call(payload)
            guard let data = result.data as? [String: Any] else {
                return fallback(candidates: candidates, calendar: calendar)
            }
            let ack = (data["acknowledgment"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Self.fbAck
            let activity = (data["suggestedActivity"] as? String)
                .flatMap { ["breathing", "meditation", "journaling"].contains($0) ? $0 : nil } ?? Self.fbActivity
            let reason = (data["reason"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? Self.fbReason
            let slotDicts = (data["slots"] as? [[String: Any]]) ?? []
            let slots: [SlotOption] = slotDicts.compactMap { dict in
                guard let time = dict["time"] as? String,
                      let start = candidates.first(where: { timeLabel($0, calendar) == time.lowercased() })
                else { return nil }
                let dur = (dict["duration"] as? Int) ?? 20
                return SlotOption(startDate: start, duration: dur, displayTime: time.lowercased())
            }
            return BreakSuggestion(acknowledgment: ack, suggestedActivity: activity, reason: reason,
                                   slots: slots, deepLinkAction: Self.action(for: activity))
        } catch {
            #if DEBUG
            print("🌿 break suggestion error: \(error)")
            #endif
            return fallback(candidates: candidates, calendar: calendar)
        }
    }

    private func fallback(candidates: [Date], calendar: Calendar) -> BreakSuggestion {
        let slots: [SlotOption] = candidates.first.map {
            [SlotOption(startDate: $0, duration: 20, displayTime: timeLabel($0, calendar))]
        } ?? []
        return BreakSuggestion(acknowledgment: Self.fbAck, suggestedActivity: Self.fbActivity,
                               reason: Self.fbReason, slots: slots,
                               deepLinkAction: Self.action(for: Self.fbActivity))
    }

    // MARK: - Confirm

    /// Creates the calendar event for the chosen slot and schedules a reminder
    /// 5 min before that deep-links to the suggested activity. True on success.
    func confirmBreak(slot: SlotOption, suggestion: BreakSuggestion) async -> Bool {
        let created = CalendarService.shared.createBreakEvent(
            title: "🌿 dino break — \(suggestion.suggestedActivity)",
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

    /// Maps the AI activity to the notification action string DinoApp routes
    /// (breathing → "breathe" → dino://breathe, etc.).
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
                             forDate: Date,
                             calendar: Calendar) -> [String: Any] {
        let now = Date()
        let isAfter7pm = calendar.isDate(forDate, inSameDayAs: now) && calendar.component(.hour, from: now) >= 19
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
            "freeSlots": candidates.prefix(6).map { timeLabel($0, calendar) },
            "timeOfDay": timeOfDay(now, calendar),
            "dayOfWeek": weekdayName(forDate, calendar),
            "isAfter7pm": isAfter7pm,
            "rhythmsContext": rhythmsContext,
        ]
    }

    // MARK: - Formatting helpers (local, fixed locale)

    private func slotLabel(_ interval: DateInterval, _ calendar: Calendar) -> String {
        "\(timeLabel(interval.start, calendar))-\(timeLabel(interval.end, calendar))"
    }

    /// "7:30pm" — lowercase, local, matches what the function returns.
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
