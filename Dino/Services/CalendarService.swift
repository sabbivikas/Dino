//
//  CalendarService.swift
//  Dino
//
//  EventKit wrapper for the break-finder: finds free pockets in the user's day
//  and writes a gentle break event. Fully isolated — no other feature touches it.
//  Degrades silently if calendar access is denied (returns [] / false, never
//  throws, never shows an error).
//
//  PRIVACY: event titles are never read out of this file. findFreeSlots only
//  returns time gaps (DateIntervals) — the scheduler turns those into anonymized
//  time labels. All day math uses Calendar.current (local), never UTC.
//

import EventKit
import Foundation

@MainActor
final class CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()
    private init() {}

    /// Request calendar access once. Returns true only if we can READ events
    /// (needed to find gaps). Denied / restricted / write-only → false.
    func ensureAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .notDetermined:
            do { return try await store.requestFullAccessToEvents() }
            catch { return false }
        default:
            return false
        }
    }

    /// Coarse calendar access state for UI display (reads status, never requests).
    enum CalendarAccess { case connected, notDetermined, denied }

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:    return .connected
        case .notDetermined: return .notDetermined
        default:             return .denied   // denied / restricted / write-only
        }
    }

    /// Free gaps (no events) of at least `minimumDuration`, in LOCAL time, from
    /// the later of 8am / now (for today) until 10pm. Empty if access denied or
    /// none qualify. Never throws.
    func findFreeSlots(for date: Date,
                       minimumDuration: TimeInterval = 1200,
                       calendar: Calendar = .current) async -> [DateInterval] {
        guard await ensureAccess() else { return [] }

        let startOfDay = calendar.startOfDay(for: date)
        guard let eightAM = calendar.date(byAdding: .hour, value: 8, to: startOfDay),
              let tenPM = calendar.date(byAdding: .hour, value: 22, to: startOfDay) else { return [] }

        let now = Date()
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let windowStart = isToday ? max(eightAM, now) : eightAM
        let windowEnd = tenPM
        guard windowStart < windowEnd else { return [] }

        let predicate = store.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }

        var slots: [DateInterval] = []
        var cursor = windowStart
        for event in events {
            guard let evStart = event.startDate, let evEnd = event.endDate else { continue }
            let gapEnd = min(max(evStart, windowStart), windowEnd)
            if gapEnd > cursor {
                let gap = DateInterval(start: cursor, end: gapEnd)
                if gap.duration >= minimumDuration { slots.append(gap) }
            }
            cursor = max(cursor, min(evEnd, windowEnd))
            if cursor >= windowEnd { break }
        }
        if cursor < windowEnd {
            let tail = DateInterval(start: cursor, end: windowEnd)
            if tail.duration >= minimumDuration { slots.append(tail) }
        }
        return slots.sorted { $0.start < $1.start }
    }

    /// Create a break event in the default calendar. Returns true on success,
    /// false on any failure. Never crashes.
    func createBreakEvent(title: String, start: Date, duration: TimeInterval, notes: String) -> Bool {
        guard let defaultCalendar = store.defaultCalendarForNewEvents else { return false }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(duration)
        event.notes = notes
        event.calendar = defaultCalendar
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
}
