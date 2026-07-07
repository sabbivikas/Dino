//
//  GentleRecEngine.swift
//  Dino
//
//  Pure moment-engine gates for dino's gentle recommendations — no UI, no
//  networking, fully unit-testable. A recommendation only fires when EVERY
//  gate clears; silence is the default and scarcity is the feature.
//
//  POLICY: nothing sponsored, ever. No affiliate links, no paid placements,
//  no partnerships. A recommendation exists solely because it might genuinely
//  help someone on a heavy day.
//
//  Privacy: only enum buckets ever leave the device (mood/timeOfDay/theme
//  enums + quiet types). Raw journal text never touches this system — the
//  journal signal is read from the already-extracted ThemeTag enums, and only
//  when the user's journal-learning toggle is on.
//

import Foundation

enum GentleRecEngine {

    static let scarcityDays = 3            // at most one rec every 3 days
    static let ignoreQuietThreshold = 3    // 3 ignores → that type goes quiet
    /// Days the crisis marker silences recommendations — keep equal to
    /// BodyNudge.crisisQuietDays on feature/steps (both branches ride the
    /// same release train; unify to one constant after they merge).
    static let crisisQuietDays = 7
    /// Heavy journal themes — deliberately excludes "health" (often physical
    /// illness, where a content rec can land tone-deaf) and the stressor
    /// themes (work/money/relationships say stressed, not depleted).
    static let heavyThemes: Set<String> = ["sleep", "self"]
    static let allTypes = ["music", "film", "cozy"]

    enum TimeSlot: String {
        case midday    // 11:00–17:00 → cozy
        case evening   // 17:00–23:00 → music / film
    }

    static func timeSlot(hour: Int) -> TimeSlot? {
        if (11..<17).contains(hour) { return .midday }
        if (17..<23).contains(hour) { return .evening }
        return nil
    }

    static func quietTypes(ignoreCounts: [String: Int]) -> [String] {
        allTypes.filter { (ignoreCounts[$0] ?? 0) >= ignoreQuietThreshold }
    }

    struct Offer: Equatable {
        let timeOfDay: String
        let quietTypes: [String]
    }

    /// Nil unless every gate clears. The crisis window is checked FIRST and is
    /// absolute — within it, nothing else matters (marker is local-only, see
    /// CrisisMarker).
    static func shouldOffer(now: Date,
                            calendar: Calendar,
                            lastShownAt: Date?,
                            crisisDate: Date?,
                            heavyMoodToday: Bool,
                            journalToggleOn: Bool,
                            journalThemesToday: [String],
                            ignoreCounts: [String: Int]) -> Offer? {
        func daysAgo(_ d: Date) -> Int {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: d),
                                    to: calendar.startOfDay(for: now)).day ?? 0
        }
        if let c = crisisDate {
            let days = daysAgo(c)
            if days >= 0 && days < crisisQuietDays { return nil }
        }
        guard let slot = timeSlot(hour: calendar.component(.hour, from: now)) else { return nil }
        if let last = lastShownAt, daysAgo(last) < scarcityDays { return nil }
        let journalSignal = journalToggleOn && journalThemesToday.contains { heavyThemes.contains($0) }
        guard heavyMoodToday || journalSignal else { return nil }
        let quiet = quietTypes(ignoreCounts: ignoreCounts)
        guard quiet.count < allTypes.count else { return nil }   // everything quiet → silence
        return Offer(timeOfDay: slot.rawValue, quietTypes: quiet)
    }
}
