import Foundation

enum MonthlyStorySignalCoordinatorError: Error, Equatable {
    case settingsDisabled
    case safetyHold
    case monthUnavailable
    case insufficientEvidence
}

protocol MonthlyStoryLocalSafetyProviding: Sendable {
    func decision(for monthKey: MonthlyStoryMonthKey) async -> MonthlyStorySafetyDecision
}

struct MonthlyStoryEligibleSafetyProvider: MonthlyStoryLocalSafetyProviding {
    func decision(for monthKey: MonthlyStoryMonthKey) async -> MonthlyStorySafetyDecision { .eligible }
}

/// The two local collections `buildSignal` reads, and nothing else.
///
/// `SharedDataManager` is a `private init()` singleton bound to the `group.com.vikassabbi.dino`
/// UserDefaults suite, and every stored property persists through a `didSet`. A test that
/// populated it would write to the user's real data, so the coordinator depends on this
/// read-only surface instead of the singleton itself. `SharedDataManager` conforms as-is.
@MainActor
protocol MonthlyStoryLocalEvidenceProviding {
    var moodEntries: [MoodEntry] { get }
    var themeTags: [ThemeTag] { get }
}

extension SharedDataManager: MonthlyStoryLocalEvidenceProviding {}

/// The Health reads `buildSignal` performs, and nothing else.
///
/// `HealthService` is a concrete `private init()` singleton wrapping `HKHealthStore`, so the
/// sleep/movement evidence branches are otherwise unreachable from a test. `HealthService`
/// conforms as-is (its default argument values still satisfy these requirements).
@MainActor
protocol MonthlyStoryHealthProviding {
    var hasRequestedSleep: Bool { get }
    var hasRequestedSteps: Bool { get }
    func nightlySleepSeries(nights: Int, now: Date, calendar: Calendar) async -> [(date: Date, hours: Double)]?
    func dailyStepTotals(days: Int, now: Date, calendar: Calendar) async -> [(date: Date, steps: Double)]?
}

extension HealthService: MonthlyStoryHealthProviding {}

@MainActor
final class MonthlyStorySignalCoordinator {
    private let dataManager: any MonthlyStoryLocalEvidenceProviding
    private let journalThemeLearningEnabled: Bool
    private let health: any MonthlyStoryHealthProviding
    private let safety: any MonthlyStoryLocalSafetyProviding

    init(dataManager: any MonthlyStoryLocalEvidenceProviding,
         journalThemeLearningEnabled: Bool,
         health: (any MonthlyStoryHealthProviding)? = nil,
         safety: any MonthlyStoryLocalSafetyProviding = MonthlyStoryEligibleSafetyProvider()) {
        self.dataManager = dataManager
        self.journalThemeLearningEnabled = journalThemeLearningEnabled
        self.health = health ?? HealthService.shared
        self.safety = safety
    }

    func buildSignal(settings: MonthlyStorySettings, now: Date = Date()) async throws -> MonthlyStorySignal {
        guard settings.enabled else { throw MonthlyStorySignalCoordinatorError.settingsDisabled }
        let timeZone = try MonthlyStoryTimeZone(rawValue: settings.timezone)
        var calendar = MonthlyStoryCalendar.calendar(timeZone)
        guard let prior = calendar.date(byAdding: .month, value: -1, to: now) else {
            throw MonthlyStorySignalCoordinatorError.monthUnavailable
        }
        let parts = calendar.dateComponents([.year, .month], from: prior)
        let monthKey = try MonthlyStoryMonthKey(rawValue: String(format: "%04d-%02d", parts.year!, parts.month!))
        let boundary = try MonthlyStoryCalendar.boundary(for: monthKey, timeZone: timeZone)
        guard boundary.isClosed(at: now), (await safety.decision(for: monthKey)).isStorySafetyEligible else {
            throw MonthlyStorySignalCoordinatorError.safetyHold
        }
        calendar.timeZone = timeZone.foundation
        let inMonth: (Date) -> Bool = { $0 >= boundary.start && $0 < boundary.endExclusive }
        let day: (Date) -> MonthlyStoryDay? = { date in
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return try? MonthlyStoryDay(rawValue: String(format: "%04d-%02d-%02d",
                components.year!, components.month!, components.day!))
        }

        let moods = dataManager.moodEntries.filter { inMonth($0.date) }
        let moodDays = Array(Set(moods.compactMap { day($0.date) })).sorted()
        var usableDays = Set(moodDays)
        var corroboratingDays = Set<MonthlyStoryDay>()
        var evidence: [MonthlyStoryEvidence] = []

        if !moods.isEmpty, let first = day(boundary.start),
           let lastDate = calendar.date(byAdding: .day, value: -1, to: boundary.endExclusive), let last = day(lastDate) {
            let heavy = moods.filter { $0.weatherType == .overwhelmed || $0.weatherType == .drained }.count
            let shape: MonthlyStoryMoodShape = heavy * 3 >= moods.count * 2 ? .mostlyHeavy :
                (heavy * 3 <= moods.count ? .mostlyBright : .mixed)
            let midpoint = boundary.start.addingTimeInterval(boundary.endExclusive.timeIntervalSince(boundary.start) / 2)
            let before = moods.filter { $0.date < midpoint }
            let after = moods.filter { $0.date >= midpoint }
            let heavyShare: ([MoodEntry]) -> Double = { values in
                guard !values.isEmpty else { return 0 }
                return Double(values.filter { $0.weatherType == .overwhelmed || $0.weatherType == .drained }.count) /
                    Double(values.count)
            }
            let delta = heavyShare(after) - heavyShare(before)
            let direction: MonthlyStoryMoodDirection = delta > 0.2 ? .heavier : delta < -0.2 ? .brighter : .steady
            evidence.append(try MonthlyStoryEvidence(id: .init(rawValue: "mood-shape-\(monthKey.rawValue)"),
                value: .emotionalShape(shape, direction), confidence: moodDays.count >= 4 ? .high : .medium,
                startDay: first, endDay: last, source: .mood, allowedForNarration: true))
            evidence.append(try MonthlyStoryEvidence(id: .init(rawValue: "mood-rest-\(monthKey.rawValue)"),
                value: .nextMonthSuggestionBasis(.continueRest), confidence: moodDays.count >= 4 ? .high : .medium,
                startDay: first, endDay: last, source: .deterministicCombination, allowedForNarration: true))
        }

        if settings.useJournalThemes && journalThemeLearningEnabled {
            let tags = dataManager.themeTags.filter { inMonth($0.date) && $0.source == ThemeTag.sourceJournal }
            let grouped = Dictionary(grouping: tags.compactMap { tag -> (MonthlyStoryJournalTheme, MonthlyStoryDay)? in
                guard let theme = MonthlyStoryThemeAllowlist.theme(forExistingTag: tag.theme), let value = day(tag.date)
                else { return nil }
                return (theme, value)
            }, by: { $0.0 })
            for (theme, values) in grouped where values.count >= 2 {
                let days = values.map(\.1).sorted(); usableDays.formUnion(days); corroboratingDays.formUnion(days)
                // `theme.rawValue` is camelCase (e.g. "workPressure"); MonthlyStoryEvidenceID and the
                // server's evidenceId(/^[a-z0-9._-]+$/, functions/src/monthlyStorySchema.ts:56-60) both
                // allow lowercase only, so the token must be folded. The lowercased forms stay unique
                // across every MonthlyStoryJournalTheme case.
                evidence.append(try MonthlyStoryEvidence(id: .init(rawValue: "journal-\(theme.rawValue.lowercased())-\(monthKey.rawValue)"),
                    value: .repeatedTheme(theme), confidence: .high, startDay: days.first!, endDay: days.last!,
                    source: .authorizedJournalTheme, allowedForNarration: true))
            }
        }

        if settings.useHealthPatterns {
            if health.hasRequestedSleep,
               let series = await health.nightlySleepSeries(nights: 62, now: now, calendar: calendar) {
                let values = series.filter { inMonth($0.date) }
                let days = values.compactMap { day($0.date) }
                if values.count >= 4, let bucket = Self.bucket(values.map(\.hours), restful: true) {
                    usableDays.formUnion(days); corroboratingDays.formUnion(days)
                    evidence.append(try MonthlyStoryEvidence(id: .init(rawValue: "health-sleep-\(monthKey.rawValue)"),
                        value: .sleepPattern(bucket), confidence: .high, startDay: days.min()!, endDay: days.max()!,
                        source: .authorizedHealthSummary, allowedForNarration: true))
                }
            }
            if health.hasRequestedSteps,
               let series = await health.dailyStepTotals(days: 62, now: now, calendar: calendar) {
                let values = series.filter { inMonth($0.date) && $0.steps > 0 }
                let days = values.compactMap { day($0.date) }
                if values.count >= 4, let bucket = Self.movementBucket(values.map(\.steps)) {
                    usableDays.formUnion(days); corroboratingDays.formUnion(days)
                    evidence.append(try MonthlyStoryEvidence(id: .init(rawValue: "health-movement-\(monthKey.rawValue)"),
                        value: .movementPattern(bucket), confidence: .high, startDay: days.min()!, endDay: days.max()!,
                        source: .authorizedHealthSummary, allowedForNarration: true))
                }
            }
        }

        guard let first = day(boundary.start),
              let finalDate = calendar.date(byAdding: .day, value: -1, to: boundary.endExclusive), let last = day(finalDate)
        else { throw MonthlyStorySignalCoordinatorError.monthUnavailable }
        let permissions = Self.permissions(for: settings)
        let draft = try MonthlyStorySignal(monthKey: monthKey, timeZone: timeZone,
            evidenceStartDay: first, evidenceEndDay: last, usableEvidenceDays: usableDays.sorted(),
            moodEvidenceDays: moodDays, corroboratingEvidenceDays: corroboratingDays.sorted(),
            permissions: permissions, isStorySafetyEligible: true, evidence: evidence)
        let eligibility = MonthlyStoryEligibility.evaluate(signal: draft,
            context: .init(storedTimeZoneIdentifier: settings.timezone, evaluatedAt: now))
        guard eligibility.code == .eligibleStandard || eligibility.code == .eligibleMoodOnly else {
            throw MonthlyStorySignalCoordinatorError.insufficientEvidence
        }
        return try MonthlyStorySignal(monthKey: monthKey, timeZone: timeZone,
            evidenceStartDay: first, evidenceEndDay: last, usableEvidenceDays: usableDays.sorted(),
            moodEvidenceDays: moodDays, corroboratingEvidenceDays: corroboratingDays.sorted(),
            permissions: permissions, isStorySafetyEligible: true, evidence: evidence, eligibility: eligibility)
    }

    /// Declares what the *stored* settings authorize, field for field.
    ///
    /// The server treats this as a consent-integrity guarantee and rejects any signal whose
    /// permissions (or timeZone) differ from the stored settings document — see
    /// functions/src/monthlyStoryGenerationService.ts:215-219 and
    /// functions/src/monthlyStorySchema.ts:385-390. So every field here must mirror the settings
    /// exactly and must never be narrowed by a local collection preference: whether evidence is
    /// actually gathered (e.g. journal theme learning) is a separate, client-side question and is
    /// gated where the evidence is collected, not here.
    static func permissions(for settings: MonthlyStorySettings) -> MonthlyStoryPermissions {
        MonthlyStoryPermissions(featureEnabled: settings.enabled,
                                journalThemesEnabled: settings.useJournalThemes,
                                healthPatternsEnabled: settings.useHealthPatterns,
                                audioEnabled: settings.audioEnabled)
    }

    private static func bucket(_ values: [Double], restful: Bool) -> MonthlyStorySleepBucket? {
        guard values.count >= 4 else { return nil }
        let midpoint = values.count / 2
        let first = values.prefix(midpoint).reduce(0, +) / Double(midpoint)
        let second = values.suffix(from: midpoint).reduce(0, +) / Double(values.count - midpoint)
        guard first > 0 else { return .variable }
        let ratio = second / first
        if ratio > 1.1 { return .moreRestful }
        if ratio < 0.9 { return .lessRestful }
        let average = values.reduce(0, +) / Double(values.count)
        let deviation = values.reduce(0) { $0 + abs($1 - average) } / Double(values.count)
        return deviation / average > 0.25 ? .variable : .steady
    }

    private static func movementBucket(_ values: [Double]) -> MonthlyStoryMovementBucket? {
        guard values.count >= 4 else { return nil }
        let midpoint = values.count / 2
        let first = values.prefix(midpoint).reduce(0, +) / Double(midpoint)
        let second = values.suffix(from: midpoint).reduce(0, +) / Double(values.count - midpoint)
        guard first > 0 else { return .variable }
        let ratio = second / first
        if ratio > 1.15 { return .moreActive }
        if ratio < 0.85 { return .lessActive }
        let average = values.reduce(0, +) / Double(values.count)
        let deviation = values.reduce(0) { $0 + abs($1 - average) } / Double(values.count)
        return deviation / average > 0.35 ? .variable : .steady
    }
}
