import XCTest
@testable import Dino

// MARK: - Test seams
//
// `MonthlyStorySignalCoordinator` used to take `SharedDataManager` and `HealthService` directly.
// Both are `private init()` singletons: `SharedDataManager.shared` is bound to the
// `group.com.vikassabbi.dino` UserDefaults suite and every stored property persists through a
// `didSet`, so seeding it from a test would write to the user's real data; `HealthService.shared`
// wraps `HKHealthStore`, which returns nothing in a simulator test run.
//
// The coordinator now depends on two narrow, read-only protocols covering exactly the members it
// already used — `MonthlyStoryLocalEvidenceProviding` and `MonthlyStoryHealthProviding` — which
// `SharedDataManager` and `HealthService` satisfy as-is. Nothing is written anywhere.

@MainActor
final class StubMonthlyStoryLocalEvidence: MonthlyStoryLocalEvidenceProviding {
    var moodEntries: [MoodEntry]
    var themeTags: [ThemeTag]

    init(moodEntries: [MoodEntry] = [], themeTags: [ThemeTag] = []) {
        self.moodEntries = moodEntries
        self.themeTags = themeTags
    }
}

@MainActor
final class StubMonthlyStoryHealth: MonthlyStoryHealthProviding {
    var hasRequestedSleep: Bool
    var hasRequestedSteps: Bool
    var sleepSeries: [(date: Date, hours: Double)]?
    var stepSeries: [(date: Date, steps: Double)]?

    init(hasRequestedSleep: Bool = false,
         hasRequestedSteps: Bool = false,
         sleepSeries: [(date: Date, hours: Double)]? = nil,
         stepSeries: [(date: Date, steps: Double)]? = nil) {
        self.hasRequestedSleep = hasRequestedSleep
        self.hasRequestedSteps = hasRequestedSteps
        self.sleepSeries = sleepSeries
        self.stepSeries = stepSeries
    }

    func nightlySleepSeries(nights: Int, now: Date, calendar: Calendar) async -> [(date: Date, hours: Double)]? {
        sleepSeries
    }

    func dailyStepTotals(days: Int, now: Date, calendar: Calendar) async -> [(date: Date, steps: Double)]? {
        stepSeries
    }
}

// MARK: - Shared July-2026 scenario

enum MonthlyStoryBuildSignalScenario {
    static let timezone = "America/Chicago"

    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(identifier: timezone)!
        return value
    }

    /// Noon local on a July 2026 day — unambiguous under the local calendar used for bucketing.
    static func july(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: 12))!
    }

    /// 2026-08-06 12:00 local. July's evidence freeze is 2026-08-03 04:00 local, so the month is
    /// closed and `buildSignal` resolves the prior month as `2026-07`.
    static let now = MonthlyStoryBuildSignalScenario.calendar
        .date(from: DateComponents(year: 2026, month: 8, day: 6, hour: 12))!

    static func settings(journal: Bool, health: Bool, audio: Bool) -> MonthlyStorySettings {
        MonthlyStorySettings(enabled: true,
                             useJournalThemes: journal,
                             useHealthPatterns: health,
                             audioEnabled: audio,
                             timezone: timezone,
                             timezoneEffectiveMonth: "2026-07")
    }

    static func mood(_ day: Int, _ weather: EmotionalWeather) -> MoodEntry {
        MoodEntry(date: july(day), weatherType: weather, energyLevel: 3, intensityLevel: 3)
    }

    static func journalTag(_ day: Int, theme: String) -> ThemeTag {
        ThemeTag(date: july(day), theme: theme, source: ThemeTag.sourceJournal)
    }
}

/// Drives `MonthlyStorySignalCoordinator.buildSignal` end to end — evidence construction, the
/// permission declaration, local eligibility — and checks the result against the shape the
/// server's `parseMonthlyStorySignal` requires (functions/src/monthlyStorySchema.ts:312-377).
///
/// Before the interpolation fix this test could not reach any assertion: every evidence ID was a
/// literal such as `"mood-shape-(monthKey.rawValue)"`, and `MonthlyStoryEvidenceID.init(rawValue:)`
/// threw `.invalidEvidenceID` on the `(`.
@MainActor
final class MonthlyStoryBuildSignalEndToEndTests: XCTestCase {

    private typealias Scenario = MonthlyStoryBuildSignalScenario

    // MARK: - Server contract

    /// The evidence-ID rule the server enforces: `/^[a-z0-9._-]+$/`, 8...64, no "..".
    /// See functions/src/monthlyStorySchema.ts:50-61.
    private func assertServerAcceptsEvidenceID(_ id: String,
                                              file: StaticString = #filePath,
                                              line: UInt = #line) {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        XCTAssertTrue(id.unicodeScalars.allSatisfy(allowed.contains),
                      "evidence id \"\(id)\" has characters the server rejects", file: file, line: line)
        XCTAssertTrue((8...64).contains(id.count),
                      "evidence id \"\(id)\" is out of the 8...64 length bound", file: file, line: line)
        XCTAssertFalse(id.contains(".."), "evidence id \"\(id)\" contains \"..\"", file: file, line: line)
    }

    /// Mirrors the structural invariants `parseMonthlyStorySignal` checks, over the signal as it
    /// would actually be serialised for upload.
    private func assertSatisfiesServerSignalContract(_ signal: MonthlyStorySignal,
                                                     file: StaticString = #filePath,
                                                     line: UInt = #line) throws {
        XCTAssertEqual(signal.schemaVersion, 1, "unsupported-signal-schema", file: file, line: line)
        XCTAssertTrue(signal.isStorySafetyEligible, "safety-ineligible", file: file, line: line)
        XCTAssertLessThanOrEqual(signal.evidence.count, 64, "evidence-limit", file: file, line: line)

        for item in signal.evidence { assertServerAcceptsEvidenceID(item.id.rawValue, file: file, line: line) }
        XCTAssertEqual(Set(signal.evidence.map(\.id.rawValue)).count, signal.evidence.count,
                       "duplicate-evidence-id", file: file, line: line)

        // evidence-outside-month
        let prefix = signal.monthKey.rawValue + "-"
        let allDays = signal.usableEvidenceDays + signal.moodEvidenceDays + signal.corroboratingEvidenceDays
            + signal.evidence.flatMap { [$0.startDay, $0.endDay] }
            + [signal.evidenceStartDay, signal.evidenceEndDay]
        for day in allDays {
            XCTAssertTrue(day.rawValue.hasPrefix(prefix), "\(day.rawValue) outside \(prefix)", file: file, line: line)
            XCTAssertTrue(day >= signal.evidenceStartDay && day <= signal.evidenceEndDay,
                          "\(day.rawValue) outside the evidence window", file: file, line: line)
        }
        XCTAssertTrue(Set(signal.moodEvidenceDays).isSubset(of: Set(signal.usableEvidenceDays)),
                      "mood days must be usable days", file: file, line: line)
        XCTAssertTrue(Set(signal.corroboratingEvidenceDays).isSubset(of: Set(signal.usableEvidenceDays)),
                      "corroborating days must be usable days", file: file, line: line)

        // journal-permission-required / health-permission-required
        if !signal.permissions.journalThemesEnabled {
            XCTAssertFalse(signal.evidence.contains { $0.category == .repeatedTheme }, file: file, line: line)
        }
        if !signal.permissions.healthPatternsEnabled {
            XCTAssertFalse(signal.evidence.contains {
                $0.category == .sleepPattern || $0.category == .movementPattern
            }, file: file, line: line)
        }

        // invalid-evidence-source: the server pins these two categories to their source.
        for item in signal.evidence {
            if item.category == .repeatedTheme {
                XCTAssertEqual(item.source, .authorizedJournalTheme, file: file, line: line)
            }
            if item.category == .sleepPattern || item.category == .movementPattern {
                XCTAssertEqual(item.source, .authorizedHealthSummary, file: file, line: line)
            }
            XCTAssertTrue(item.startDay <= item.endDay, "invalid-evidence-range", file: file, line: line)
        }

        // The wire form must survive the strict decoder, which rejects unknown fields.
        let encoded = try JSONEncoder().encode(signal)
        let decoded = try JSONDecoder().decode(MonthlyStorySignal.self, from: encoded)
        XCTAssertEqual(decoded, signal, "signal did not survive an encode/decode round trip",
                       file: file, line: line)
    }

    // MARK: - The end-to-end run

    func testBuildSignalProducesInterpolatedEvidenceIDsAndAnUploadableSignal() async throws {
        let stored = Scenario.settings(journal: true, health: true, audio: true)

        // 5 mood days (>= 4 => .high confidence), mixed shape.
        let data = StubMonthlyStoryLocalEvidence(
            moodEntries: [
                Scenario.mood(2, .clear),
                Scenario.mood(8, .overwhelmed),
                Scenario.mood(14, .partlyCloudy),
                Scenario.mood(20, .drained),
                Scenario.mood(26, .clear)
            ],
            // Two "work" tags in-month => one repeatedTheme(.workPressure) evidence item.
            themeTags: [
                Scenario.journalTag(5, theme: "work"),
                Scenario.journalTag(19, theme: "work")
            ])

        let health = StubMonthlyStoryHealth(
            hasRequestedSleep: true,
            hasRequestedSteps: true,
            sleepSeries: [(Scenario.july(3), 7.0), (Scenario.july(10), 7.0),
                          (Scenario.july(17), 8.0), (Scenario.july(24), 8.0)],
            stepSeries: [(Scenario.july(4), 5_000), (Scenario.july(11), 5_000),
                         (Scenario.july(18), 7_000), (Scenario.july(25), 7_000)])

        let coordinator = MonthlyStorySignalCoordinator(dataManager: data,
                                                        journalThemeLearningEnabled: true,
                                                        health: health)

        let signal = try await coordinator.buildSignal(settings: stored, now: Scenario.now)

        // 1. The evidence IDs are the interpolated values, not the literals.
        let ids = signal.evidence.map(\.id.rawValue)
        XCTAssertEqual(Set(ids), [
            "mood-shape-2026-07",
            "mood-rest-2026-07",
            "journal-workpressure-2026-07",
            "health-sleep-2026-07",
            "health-movement-2026-07"
        ])
        for id in ids {
            XCTAssertFalse(id.contains("("), "\(id) still contains a literal \"(\"")
            XCTAssertFalse(id.contains("monthKey"), "\(id) still contains the un-interpolated expression")
            XCTAssertFalse(id.contains("theme.rawValue"), "\(id) still contains the un-interpolated expression")
        }

        // 2. Month resolution and the categories actually collected.
        XCTAssertEqual(signal.monthKey.rawValue, "2026-07")
        XCTAssertEqual(signal.timeZone.rawValue, Scenario.timezone)
        XCTAssertEqual(signal.evidenceStartDay.rawValue, "2026-07-01")
        XCTAssertEqual(signal.evidenceEndDay.rawValue, "2026-07-31")
        XCTAssertTrue(signal.evidence.contains { $0.category == .repeatedTheme })
        XCTAssertTrue(signal.evidence.contains { $0.category == .sleepPattern })
        XCTAssertTrue(signal.evidence.contains { $0.category == .movementPattern })

        // 3. Uploadable, and eligible on the full (non mood-only) path.
        XCTAssertTrue(signal.isUploadable)
        XCTAssertEqual(signal.eligibility?.code, .eligibleStandard)
        XCTAssertEqual(signal.eligibility?.permitsCauseNarration, true)

        // 4. Permissions round-trip against the stored settings, field for field.
        XCTAssertEqual(signal.permissions.featureEnabled, stored.enabled)
        XCTAssertEqual(signal.permissions.journalThemesEnabled, stored.useJournalThemes)
        XCTAssertEqual(signal.permissions.healthPatternsEnabled, stored.useHealthPatterns)
        XCTAssertEqual(signal.permissions.audioEnabled, stored.audioEnabled)
        XCTAssertEqual(signal.timeZone.rawValue, stored.timezone)
        XCTAssertEqual(signal.permissions, MonthlyStorySignalCoordinator.permissions(for: stored))

        // 5. The whole thing satisfies what parseMonthlyStorySignal requires.
        try assertSatisfiesServerSignalContract(signal)
    }

    /// Every `MonthlyStoryJournalTheme` must yield an evidence ID the validator accepts. The raw
    /// values are camelCase (`workPressure`), which is *outside* the allowed set, so the ID folds
    /// them to lowercase — and the folded forms must stay distinct.
    func testEveryJournalThemeProducesAValidAndDistinctEvidenceID() throws {
        var ids = Set<String>()
        for theme in MonthlyStoryJournalTheme.allCases {
            let raw = "journal-\(theme.rawValue.lowercased())-2026-07"
            assertServerAcceptsEvidenceID(raw)
            XCTAssertNoThrow(try MonthlyStoryEvidenceID(rawValue: raw))
            XCTAssertTrue(ids.insert(raw).inserted, "\(raw) collides with another theme")
        }
        XCTAssertEqual(ids.count, MonthlyStoryJournalTheme.allCases.count)
    }
}
