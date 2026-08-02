import Foundation

struct MonthlyStoryEligibilityContext: Equatable, Sendable {
    let storedTimeZoneIdentifier: String
    let evaluatedAt: Date
    let hasCompletedStory: Bool
    let hasDeletedTombstone: Bool
    let hasValidMonthBoundary: Bool

    init(storedTimeZoneIdentifier: String,
         evaluatedAt: Date,
         hasCompletedStory: Bool = false,
         hasDeletedTombstone: Bool = false,
         hasValidMonthBoundary: Bool = true) {
        self.storedTimeZoneIdentifier = storedTimeZoneIdentifier
        self.evaluatedAt = evaluatedAt
        self.hasCompletedStory = hasCompletedStory
        self.hasDeletedTombstone = hasDeletedTombstone
        self.hasValidMonthBoundary = hasValidMonthBoundary
    }
}

enum MonthlyStoryEligibility {
    static func evaluate(signal: MonthlyStorySignal,
                         context: MonthlyStoryEligibilityContext) -> MonthlyStoryEligibilitySnapshot {
        guard signal.permissions.featureEnabled else { return result(.featureDisabled) }
        guard signal.isStorySafetyEligible else { return result(.safetyHold) }
        guard !context.hasDeletedTombstone else { return result(.deletedTombstone) }
        guard !context.hasCompletedStory else { return result(.alreadyCompleted) }
        guard let storedTimeZone = try? MonthlyStoryTimeZone(rawValue: context.storedTimeZoneIdentifier),
              storedTimeZone == signal.timeZone else {
            return result(.invalidTimezone)
        }
        guard context.hasValidMonthBoundary else { return result(.invalidMonthBoundary) }
        guard let boundary = try? MonthlyStoryCalendar.boundary(for: signal.monthKey, timeZone: storedTimeZone),
              signal.evidenceStartDay.rawValue.hasPrefix(signal.monthKey.rawValue + "-"),
              signal.evidenceEndDay.rawValue.hasPrefix(signal.monthKey.rawValue + "-") else {
            return result(.invalidMonthBoundary)
        }
        guard boundary.isClosed(at: context.evaluatedAt) else { return result(.monthNotClosed) }

        let calendar = MonthlyStoryCalendar.calendar(storedTimeZone)
        guard let start = date(signal.evidenceStartDay, calendar: calendar),
              let end = date(signal.evidenceEndDay, calendar: calendar),
              let span = calendar.dateComponents([.day], from: start, to: end).day,
              span >= 14 else {
            return result(.insufficientSpan)
        }

        let highConfidenceObservations = signal.evidence.filter {
            $0.allowedForNarration && $0.confidence == .high
        }.count
        let moodDays = signal.moodEvidenceDays.count

        if signal.usableEvidenceDays.count >= 6,
           moodDays >= 4,
           signal.corroboratingEvidenceDays.count >= 2 {
            guard highConfidenceObservations >= 2 else { return result(.insufficientObservations) }
            return result(.eligibleStandard, permitsCauseNarration: true)
        }
        if moodDays >= 8 {
            guard highConfidenceObservations >= 2 else { return result(.insufficientObservations) }
            return result(.eligibleMoodOnly, permitsCauseNarration: false)
        }
        guard signal.usableEvidenceDays.count >= 6 else { return result(.insufficientEvidenceDays) }
        guard moodDays >= 4 else { return result(.insufficientMoodDays) }
        return result(.insufficientCorroboration)
    }

    private static func result(_ code: MonthlyStoryEligibilityCode,
                               permitsCauseNarration: Bool = false) -> MonthlyStoryEligibilitySnapshot {
        MonthlyStoryEligibilitySnapshot(code: code, permitsCauseNarration: permitsCauseNarration)
    }

    private static func date(_ day: MonthlyStoryDay, calendar: Calendar) -> Date? {
        let values = day.rawValue.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: values[0], month: values[1], day: values[2], hour: 12))
    }
}
