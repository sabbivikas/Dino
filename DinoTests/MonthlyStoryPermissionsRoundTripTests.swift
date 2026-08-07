import XCTest
@testable import Dino

/// Pins the client/server consent contract for `MonthlyStoryPermissions`.
///
/// The server rejects a signal whose declared permissions (or timeZone) differ from the stored
/// settings document. This duplicates that comparison so a client-side drift fails here rather
/// than as a `signal-invalid` / `settings-mismatch` rejection in production. Mirrors:
///   functions/src/monthlyStoryGenerationService.ts:215-219
///   functions/src/monthlyStorySchema.ts:385-390
/// (both compare featureEnabled, journalThemesEnabled, healthPatternsEnabled, audioEnabled and
/// timeZone against the settings document.)
@MainActor
final class MonthlyStoryPermissionsRoundTripTests: XCTestCase {

    /// The server's equality check, expressed once, over the fields it actually compares.
    /// See functions/src/monthlyStoryGenerationService.ts:215-219.
    private func assertServerAccepts(_ permissions: MonthlyStoryPermissions,
                                     timeZone: String,
                                     for settings: MonthlyStorySettings,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) {
        XCTAssertEqual(permissions.featureEnabled, settings.enabled, "featureEnabled", file: file, line: line)
        XCTAssertEqual(permissions.journalThemesEnabled, settings.useJournalThemes,
                       "journalThemesEnabled", file: file, line: line)
        XCTAssertEqual(permissions.healthPatternsEnabled, settings.useHealthPatterns,
                       "healthPatternsEnabled", file: file, line: line)
        XCTAssertEqual(permissions.audioEnabled, settings.audioEnabled, "audioEnabled", file: file, line: line)
        XCTAssertEqual(timeZone, settings.timezone, "timeZone", file: file, line: line)
    }

    private func settings(enabled: Bool = true,
                          journal: Bool,
                          health: Bool,
                          audio: Bool,
                          timezone: String = "America/Chicago") -> MonthlyStorySettings {
        MonthlyStorySettings(enabled: enabled,
                             useJournalThemes: journal,
                             useHealthPatterns: health,
                             audioEnabled: audio,
                             timezone: timezone,
                             timezoneEffectiveMonth: "2026-07")
    }

    // MARK: - Round-trip over every settings combination

    func testDeclaredPermissionsMatchStoredSettingsForEveryCombination() throws {
        for journal in [true, false] {
            for health in [true, false] {
                for audio in [true, false] {
                    let stored = settings(journal: journal, health: health, audio: audio)
                    let declared = MonthlyStorySignalCoordinator.permissions(for: stored)
                    assertServerAccepts(declared, timeZone: stored.timezone, for: stored)
                }
            }
        }
    }

    /// The live settings document that made every upload fail: audio on, journal on, health on.
    func testAudioEnabledSettingsRoundTripInsteadOfBeingHardcodedOff() {
        let stored = settings(journal: true, health: true, audio: true)
        let declared = MonthlyStorySignalCoordinator.permissions(for: stored)

        XCTAssertTrue(declared.audioEnabled)
        assertServerAccepts(declared, timeZone: stored.timezone, for: stored)
    }

    /// The second guaranteed mismatch: journal themes authorized in settings while the local
    /// theme-learning preference is off. The declaration follows the settings, not the preference.
    func testJournalThemesDeclarationFollowsSettingsNotLocalLearningPreference() {
        let stored = settings(journal: true, health: false, audio: false)
        let declared = MonthlyStorySignalCoordinator.permissions(for: stored)

        XCTAssertTrue(declared.journalThemesEnabled)
        assertServerAccepts(declared, timeZone: stored.timezone, for: stored)
    }

    func testDisabledSettingsDeclareFeatureDisabledRatherThanHardcodedTrue() {
        let stored = settings(enabled: false, journal: false, health: false, audio: false)
        let declared = MonthlyStorySignalCoordinator.permissions(for: stored)

        XCTAssertFalse(declared.featureEnabled)
        assertServerAccepts(declared, timeZone: stored.timezone, for: stored)
    }

    // MARK: - Behavioral half: declaration and evidence collection are independent

    /// With `useJournalThemes` on but theme learning off, no theme evidence exists to collect,
    /// yet the signal still declares `journalThemesEnabled: true`. That combination must be a
    /// valid signal: neither the client model nor `parseMonthlyStorySignal` requires theme
    /// evidence to be present when the permission is granted.
    func testJournalThemesEnabledWithNoThemeEvidenceIsAValidSignal() throws {
        let stored = settings(journal: true, health: false, audio: true)
        let declared = MonthlyStorySignalCoordinator.permissions(for: stored)

        let signal = try MonthlyStoryFixtures.signal(
            usable: [1, 4, 8, 12, 16, 20, 24, 29],
            moods: [1, 4, 8, 12, 16, 20, 24, 29],
            corroborating: [],
            permissions: declared,
            evidence: [
                MonthlyStoryFixtures.evidence("mood-shape",
                                              value: .emotionalShape(.mixed, .brighter),
                                              source: .mood),
                MonthlyStoryFixtures.evidence("mood-rest",
                                              value: .nextMonthSuggestionBasis(.continueRest))
            ])

        XCTAssertTrue(signal.permissions.journalThemesEnabled)
        XCTAssertTrue(signal.permissions.audioEnabled)
        XCTAssertFalse(signal.evidence.contains { $0.category == .repeatedTheme })
        XCTAssertTrue(signal.isUploadable)
        assertServerAccepts(signal.permissions, timeZone: signal.timeZone.rawValue, for: stored)
    }

    /// The reverse must stay impossible: theme evidence without the permission is rejected, so
    /// widening the declaration cannot be "fixed" by widening what is collected.
    func testThemeEvidenceWithoutJournalPermissionRemainsRejected() {
        let stored = settings(journal: false, health: false, audio: false)
        let declared = MonthlyStorySignalCoordinator.permissions(for: stored)
        XCTAssertFalse(declared.journalThemesEnabled)

        XCTAssertThrowsError(try MonthlyStoryFixtures.signal(
            permissions: declared,
            evidence: [
                MonthlyStoryFixtures.evidence("mood",
                                              value: .emotionalShape(.mixed, .brighter),
                                              source: .mood),
                MonthlyStoryFixtures.evidence("work",
                                              value: .repeatedTheme(.workPressure),
                                              source: .authorizedJournalTheme)
            ])) { error in
            XCTAssertEqual(error as? MonthlyStorySchemaError, .inconsistentEvidence)
        }
    }

    /// The evidence-collection gate is what keeps theme evidence absent when learning is off.
    /// It is intentionally *not* part of the permission declaration.
    ///
    /// This was a source-text check — it grepped the coordinator for the `if` line — because
    /// `buildSignal` could not be run at all. It now runs the real thing: journal tags that would
    /// otherwise be collected are supplied, so the gate is the only thing that can keep
    /// `repeatedTheme` evidence out of the signal, while the declaration still says
    /// `journalThemesEnabled: true`. The source assertions are gone: the live run subsumes both,
    /// and the "declaration is not narrowed" half is separately covered by
    /// `testJournalThemesDeclarationFollowsSettingsNotLocalLearningPreference` above.
    func testJournalThemeEvidenceCollectionGateStillRequiresLocalLearning() async throws {
        let stored = settings(journal: true, health: false, audio: true)

        // 8 mood days clears the mood-only eligibility floor without any corroboration, so the
        // absence of theme evidence is the thing under test rather than a reason to bail out.
        let data = StubMonthlyStoryLocalEvidence(
            moodEntries: [1, 4, 8, 12, 16, 20, 24, 29].map {
                MonthlyStoryBuildSignalScenario.mood($0, $0.isMultiple(of: 8) ? .drained : .clear)
            },
            // Journal tags that WOULD be collected if the gate were gone.
            themeTags: [
                MonthlyStoryBuildSignalScenario.journalTag(4, theme: "work"),
                MonthlyStoryBuildSignalScenario.journalTag(16, theme: "work"),
                MonthlyStoryBuildSignalScenario.journalTag(20, theme: "relationships"),
                MonthlyStoryBuildSignalScenario.journalTag(24, theme: "relationships")
            ])

        let coordinator = MonthlyStorySignalCoordinator(dataManager: data,
                                                        journalThemeLearningEnabled: false,
                                                        health: StubMonthlyStoryHealth())

        let signal = try await coordinator.buildSignal(settings: stored,
                                                       now: MonthlyStoryBuildSignalScenario.now)

        XCTAssertTrue(signal.permissions.journalThemesEnabled,
                      "the declared permission must not be narrowed by the local learning preference")
        XCTAssertFalse(signal.evidence.contains { $0.category == .repeatedTheme },
                       "journal theme evidence must stay gated on the local learning preference")
        XCTAssertTrue(signal.corroboratingEvidenceDays.isEmpty)
        XCTAssertTrue(signal.isUploadable)
        XCTAssertEqual(signal.eligibility?.code, .eligibleMoodOnly)
        assertServerAccepts(signal.permissions, timeZone: signal.timeZone.rawValue, for: stored)
    }
}
