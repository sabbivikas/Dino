import Foundation

struct MonthlyStoryMonthBoundary: Equatable, Sendable {
    let monthKey: MonthlyStoryMonthKey
    let timeZone: MonthlyStoryTimeZone
    let start: Date
    let endExclusive: Date
    let lateSyncDeadline: Date
    let evidenceFreeze: Date

    func acceptsEvidence(receivedAt date: Date) -> Bool {
        date <= lateSyncDeadline
    }

    func isClosed(at date: Date) -> Bool {
        date >= evidenceFreeze
    }
}

struct MonthlyStoryTimeZoneAssignment: Equatable, Sendable {
    let current: MonthlyStoryTimeZone
    let pending: MonthlyStoryTimeZone?
    let pendingEffectiveMonth: MonthlyStoryMonthKey?

    init(current: MonthlyStoryTimeZone,
         pending: MonthlyStoryTimeZone? = nil,
         pendingEffectiveMonth: MonthlyStoryMonthKey? = nil) throws {
        guard (pending == nil) == (pendingEffectiveMonth == nil) else {
            throw MonthlyStorySchemaError.invalidMonthBoundary
        }
        self.current = current
        self.pending = pending
        self.pendingEffectiveMonth = pendingEffectiveMonth
    }

    func timeZone(for month: MonthlyStoryMonthKey) -> MonthlyStoryTimeZone {
        guard let pending, let effective = pendingEffectiveMonth, month >= effective else { return current }
        return pending
    }
}

enum MonthlyStoryCalendar {
    static func schedulingTimeZoneChange(from current: MonthlyStoryTimeZone,
                                         to requested: MonthlyStoryTimeZone,
                                         during month: MonthlyStoryMonthKey) throws -> MonthlyStoryTimeZoneAssignment {
        try MonthlyStoryTimeZoneAssignment(current: current,
                                           pending: requested,
                                           pendingEffectiveMonth: nextMonth(after: month))
    }

    static func monthKey(containing date: Date, timeZone: MonthlyStoryTimeZone) throws -> MonthlyStoryMonthKey {
        let components = calendar(timeZone).dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else {
            throw MonthlyStorySchemaError.invalidMonthBoundary
        }
        return try MonthlyStoryMonthKey(rawValue: String(format: "%04d-%02d", year, month))
    }

    static func boundary(for monthKey: MonthlyStoryMonthKey,
                         timeZone: MonthlyStoryTimeZone) throws -> MonthlyStoryMonthBoundary {
        let values = monthKey.rawValue.split(separator: "-").compactMap { Int($0) }
        guard values.count == 2 else { throw MonthlyStorySchemaError.invalidMonthBoundary }
        let calendar = calendar(timeZone)
        guard let start = calendar.date(from: DateComponents(year: values[0], month: values[1], day: 1)),
              let end = calendar.date(byAdding: .month, value: 1, to: start),
              let dayThree = calendar.date(byAdding: .day, value: 2, to: end),
              let freeze = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: dayThree) else {
            throw MonthlyStorySchemaError.invalidMonthBoundary
        }
        return MonthlyStoryMonthBoundary(monthKey: monthKey,
                                         timeZone: timeZone,
                                         start: start,
                                         endExclusive: end,
                                         lateSyncDeadline: end.addingTimeInterval(48 * 60 * 60),
                                         evidenceFreeze: freeze)
    }

    static func nextMonth(after monthKey: MonthlyStoryMonthKey) throws -> MonthlyStoryMonthKey {
        let utc = try MonthlyStoryTimeZone(rawValue: "UTC")
        let boundary = try boundary(for: monthKey, timeZone: utc)
        return try self.monthKey(containing: boundary.endExclusive, timeZone: utc)
    }

    static func day(_ date: Date, in timeZone: MonthlyStoryTimeZone) throws -> MonthlyStoryDay {
        let components = calendar(timeZone).dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            throw MonthlyStorySchemaError.invalidDate
        }
        return try MonthlyStoryDay(rawValue: String(format: "%04d-%02d-%02d", year, month, day))
    }

    static func calendar(_ timeZone: MonthlyStoryTimeZone) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = timeZone.foundation
        return value
    }
}
