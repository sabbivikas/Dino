//
//  BreakSchedulerService.swift
//  Dino
//
//  Orchestrates the break-finder flow: read free calendar slots → ask the
//  suggestBreakSlot cloud function for the best one (anonymized input only) →
//  on confirm, write the calendar event + schedule a meditation reminder.
//
//  PRIVACY: the payload contains ONLY anonymized, structured fields — free-slot
//  TIME LABELS (never event titles), enum mood/time/day strings, and an optional
//  minimal rhythms context. No calendar titles, journal, or mood notes.
//

import Foundation
import FirebaseFunctions

enum TargetDay: String {
    case today, tonight, tomorrow
}

struct BreakSuggestion {
    let slotStart: Date
    let duration: Int        // minutes
    let reason: String
    let isAfter7pm: Bool
    let targetDay: TargetDay
}

@MainActor
final class BreakSchedulerService {
    static let shared = BreakSchedulerService()
    private init() {}

    private static let staticFallbackReason =
        "you have some quiet time coming up — a good moment to breathe 🌿"

    // MARK: - Suggest

    /// Finds free slots for `forDate`, asks the cloud function to pick the best
    /// one, and returns a suggestion. Returns nil if there are no free slots
    /// (the card then never shows). Falls back to the earliest slot if the
    /// function fails.
    func suggestBreak(mood: EmotionalWeather,
                      forDate: Date = Date(),
                      calendar: Calendar = .current) async -> BreakSuggestion? {
        let slots = await CalendarService.shared.findFreeSlots(for: forDate, calendar: calendar)
        guard let firstSlot = slots.first else { return nil }   // no slots → card doesn't show

        let now = Date()
        let isAfter7pm = calendar.isDate(forDate, inSameDayAs: now)
            && calendar.component(.hour, from: now) >= 19
        let targetDay: TargetDay = calendar.isDate(forDate, inSameDayAs: now) ? .today : .tomorrow

        let payload = buildPayload(mood: mood, slots: slots,
                                   forDate: forDate, isAfter7pm: isAfter7pm,
                                   targetDay: targetDay, calendar: calendar)

        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("suggestBreakSlot").call(payload)
            guard let data = result.data as? [String: Any],
                  let slotLabel = data["slot"] as? String else {
                return fallback(firstSlot, isAfter7pm: isAfter7pm, targetDay: targetDay)
            }
            let duration = (data["duration"] as? Int) ?? 20
            let reason = (data["reason"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? Self.staticFallbackReason
            // Resolve the model's slot label back to a real start Date (match by
            // start-time label); fall back to the earliest slot if no match.
            let start = matchSlotStart(label: slotLabel, slots: slots, calendar: calendar)
                ?? firstSlot.start
            return BreakSuggestion(slotStart: start, duration: duration, reason: reason,
                                   isAfter7pm: isAfter7pm, targetDay: targetDay)
        } catch {
            #if DEBUG
            print("🌿 break suggestion error: \(error)")
            #endif
            return fallback(firstSlot, isAfter7pm: isAfter7pm, targetDay: targetDay)
        }
    }

    private func fallback(_ slot: DateInterval, isAfter7pm: Bool, targetDay: TargetDay) -> BreakSuggestion {
        BreakSuggestion(slotStart: slot.start, duration: 20,
                        reason: Self.staticFallbackReason,
                        isAfter7pm: isAfter7pm, targetDay: targetDay)
    }

    // MARK: - Confirm

    /// Creates the calendar event and schedules a meditation reminder 5 minutes
    /// before the slot. Returns true on success.
    func confirmBreak(_ suggestion: BreakSuggestion, targetDay: TargetDay) async -> Bool {
        let created = CalendarService.shared.createBreakEvent(
            title: "🌿 dino break",
            start: suggestion.slotStart,
            duration: TimeInterval(suggestion.duration * 60),
            notes: suggestion.reason
        )
        guard created else { return false }

        // Remind 5 min before — but never in the past.
        let fireDate = max(suggestion.slotStart.addingTimeInterval(-300), Date().addingTimeInterval(5))
        NotificationManager.shared.scheduleBreakReminder(at: fireDate)
        return true
    }

    // MARK: - Payload (anonymized)

    private func buildPayload(mood: EmotionalWeather,
                             slots: [DateInterval],
                             forDate: Date,
                             isAfter7pm: Bool,
                             targetDay: TargetDay,
                             calendar: Calendar) -> [String: Any] {
        let now = Date()
        // Tier 1: no rhythms data on this branch — always minimal/unavailable.
        // When the rhythms feature merges, populate this from RhythmsAnalysis.
        return [
            "freeSlots": slots.prefix(8).map { slotLabel($0, calendar) },
            "currentMood": mood.rawValue,
            "timeOfDay": timeOfDay(now, calendar),
            "dayOfWeek": weekdayName(forDate, calendar),
            "isAfter7pm": isAfter7pm,
            "targetDay": targetDay.rawValue,
            "rhythmsContext": ["available": false],
        ]
    }

    // MARK: - Formatting helpers (local, fixed locale)

    private func slotLabel(_ interval: DateInterval, _ calendar: Calendar) -> String {
        "\(timeLabel(interval.start, calendar))-\(timeLabel(interval.end, calendar))"
    }

    /// "2:30pm" — lowercase, local, matches what the function returns.
    func timeLabel(_ date: Date, _ calendar: Calendar) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "h:mma"
        return df.string(from: date).lowercased()
    }

    private func matchSlotStart(label: String, slots: [DateInterval], calendar: Calendar) -> Date? {
        let target = label.trimmingCharacters(in: .whitespaces).lowercased()
        return slots.first { timeLabel($0.start, calendar) == target }?.start
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
