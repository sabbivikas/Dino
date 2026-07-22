//
//  StreakData.swift
//  Dino
//

import Foundation

struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date
    var activeDates: Set<String>  // "yyyy-MM-dd" formatted date strings

    init(currentStreak: Int = 0, longestStreak: Int = 0, lastActiveDate: Date = Date.distantPast, activeDates: Set<String> = []) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
        self.activeDates = activeDates
    }

    // Pinned Gregorian + en_US_POSIX so day keys are always "2026-…" regardless
    // of the device calendar (a Thai/Buddhist device otherwise wrote "2569-…").
    // timeZone is intentionally left unset → stays device-local, matching the
    // existing Calendar.current.startOfDay day-boundary math (LOCAL day).
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Buddhist-key recovery / normalization

    /// Lowest plausible Gregorian year for a stored day key.
    private static let minPlausibleYear = 2015

    /// Non-destructive read-side normalization of a raw activeDates set.
    /// - Valid-year keys ([2015, currentYear+1]) pass through untouched.
    /// - Implausibly HIGH years (> currentYear+1) attempt Buddhist recovery
    ///   (Thai Buddhist = Gregorian + 543, identical month/day): year − 543.
    ///   If the recovered year is plausible, the key is REPLACED; otherwise the
    ///   key is DROPPED (fail-safe — never keep a garbage key).
    /// - Any other implausible / malformed key is DROPPED.
    /// Returns a deduped Set, so a recovered "2569-07-22" merges with an existing
    /// "2026-07-22".
    static func normalizedActiveDates(_ raw: Set<String>, now: Date = Date()) -> Set<String> {
        // currentYear from a pinned Gregorian calendar so a device Buddhist
        // calendar can't skew the plausibility window.
        let gregorian = Calendar(identifier: .gregorian)
        let currentYear = gregorian.component(.year, from: now)
        let maxPlausibleYear = currentYear + 1

        var result = Set<String>()
        for key in raw {
            let parts = key.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 3,
                  parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
                  let year = Int(parts[0]),
                  let month = Int(parts[1]),
                  let day = Int(parts[2]),
                  (1...12).contains(month),
                  (1...31).contains(day) else {
                continue   // malformed shape → drop
            }
            if year >= minPlausibleYear && year <= maxPlausibleYear {
                result.insert(key)   // valid → pass through untouched
            } else if year > maxPlausibleYear {
                // Implausibly high → Buddhist recovery (year − 543, month/day unchanged).
                let recovered = year - 543
                if recovered >= minPlausibleYear && recovered <= maxPlausibleYear {
                    result.insert(String(format: "%04d-%02d-%02d", recovered, month, day))
                }
                // else: unrecoverable → drop
            }
            // year < minPlausibleYear → implausibly low → drop
        }
        return result
    }

    /// Instance view of `activeDates` with corrupted keys recovered/dropped.
    /// Streak-affecting consumers (calendar fill, visit count) read this so they
    /// stay correct even before the one-time write-back migration runs.
    func normalizedActiveDates(now: Date = Date()) -> Set<String> {
        Self.normalizedActiveDates(activeDates, now: now)
    }

    func isActiveDate(_ date: Date, now: Date = Date()) -> Bool {
        normalizedActiveDates(now: now).contains(Self.dateFormatter.string(from: date))
    }

    static func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func date(fromKey key: String) -> Date? {
        dateFormatter.date(from: key)
    }

    // MARK: - Derived streaks (activeDates is the single source of truth)

    /// Length of the consecutive run of active days ending today — or yesterday,
    /// if today hasn't been logged yet. 0 if neither today nor yesterday is active.
    func computedCurrentStreak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let active = Self.normalizedActiveDates(activeDates, now: now)
        let today = calendar.startOfDay(for: now)
        let anchor: Date
        if active.contains(Self.dateKey(for: today)) {
            anchor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  active.contains(Self.dateKey(for: yesterday)) {
            anchor = yesterday   // hasn't logged today yet, but yesterday counts
        } else {
            return 0
        }
        var count = 0
        var day = anchor
        while active.contains(Self.dateKey(for: day)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// Longest consecutive run anywhere in activeDates.
    func computedLongestStreak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Self.normalizedActiveDates(activeDates, now: now)
            .compactMap { Self.date(fromKey: $0) }
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var run = 1
        for i in 1..<days.count {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: days[i - 1]),
               calendar.isDate(nextDay, inSameDayAs: days[i]) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }
}
