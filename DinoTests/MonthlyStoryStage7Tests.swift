import XCTest
@testable import Dino

@MainActor
final class MonthlyStoryStage7Tests: XCTestCase {
    func testInternalGateHiddenSkipsRemoteService() async {
        let service = InMemoryMonthlyStoryClientService(
            availability: .init(visible: true)
        )

        let snapshot = await resolveMonthlyStoryExperience(
            localGate: .disabled,
            service: service
        )

        XCTAssertFalse(snapshot.isVisible)
        XCTAssertEqual(snapshot.state, .idle)
        XCTAssertEqual(service.availabilityLoadCount, 0)
    }

    func testRemoteVisibilityFalseHidesCardBeforeSettingsOrStoryLoad() async {
        let service = InMemoryMonthlyStoryClientService(
            availability: .init(visible: false)
        )

        let snapshot = await resolveMonthlyStoryExperience(
            localGate: .init(isEnabled: true),
            service: service
        )

        XCTAssertFalse(snapshot.isVisible)
        XCTAssertEqual(service.availabilityLoadCount, 1)
        XCTAssertEqual(service.settingsLoadCount, 0)
        XCTAssertEqual(service.storyLoadCount, 0)
    }

    func testMonthlyStorySettingsDefaultEntirelyOff() {
        let settings = MonthlyStorySettings()

        XCTAssertFalse(settings.enabled)
        XCTAssertFalse(settings.useJournalThemes)
        XCTAssertFalse(settings.useHealthPatterns)
        XCTAssertFalse(settings.audioEnabled)
    }

    func testWrittenOnlySettingsNeverEnableAudio() async throws {
        let service = InMemoryMonthlyStoryClientService(
            availability: .init(visible: true)
        )
        let requested = MonthlyStorySettings(
            enabled: true,
            useJournalThemes: true,
            useHealthPatterns: true,
            audioEnabled: true,
            timezone: "UTC",
            timezoneEffectiveMonth: "2026-07",
            settingsVersion: 1
        )

        _ = try await service.updateSettings(requested)

        XCTAssertTrue(service.settings.enabled)
        XCTAssertTrue(service.settings.useJournalThemes)
        XCTAssertTrue(service.settings.useHealthPatterns)
        XCTAssertFalse(service.settings.audioEnabled)
    }

    func testReadyStoryDecodesAndPreservesParagraphOrder() throws {
        let story = try MonthlyStoryPreviewData.story()

        XCTAssertEqual(story.monthKey.rawValue, "2026-07")
        XCTAssertEqual(story.displayMonth, "July 2026")
        XCTAssertEqual(story.paragraphs.count, 2)
        XCTAssertTrue(story.script.hasPrefix(story.paragraphs[0]))
        XCTAssertLessThan(
            story.script.range(of: story.paragraphs[0])!.lowerBound,
            story.script.range(of: story.paragraphs[1])!.lowerBound
        )
    }

    func testMalformedDocumentIsRejected() throws {
        var object = validStoryObject()
        object["uid"] = "synthetic-user"

        XCTAssertThrowsError(try decodeStory(object))
    }

    func testUnsupportedSchemaVersionIsRejected() throws {
        var object = validStoryObject()
        object["signalSchemaVersion"] = 2

        XCTAssertThrowsError(try decodeStory(object)) { error in
            XCTAssertEqual(
                error as? MonthlyStoryDocumentError,
                .unsupportedSchemaVersion
            )
        }
    }

    func testNoStoryAndPreparingStatesResolveWithoutInternalCodes() async throws {
        let settings = enabledSettings()
        let noStoryService = InMemoryMonthlyStoryClientService(
            availability: .init(visible: true),
            settings: settings,
            storyResult: .notFound
        )
        let preparingService = InMemoryMonthlyStoryClientService(
            availability: .init(visible: true),
            settings: settings,
            storyResult: .preparing
        )

        let noStory = await resolveMonthlyStoryExperience(
            localGate: .init(isEnabled: true),
            service: noStoryService
        )
        let preparing = await resolveMonthlyStoryExperience(
            localGate: .init(isEnabled: true),
            service: preparingService
        )

        XCTAssertEqual(noStory.state, .noStory)
        XCTAssertEqual(preparing.state, .preparing)
    }

    func testDeleteSuccessClearsCacheAndCannotReopenStory() async throws {
        let story = try MonthlyStoryPreviewData.story()
        let service = InMemoryMonthlyStoryClientService(storyResult: .story(story))
        let model = MonthlyStoryReaderModel(story: story, service: service)

        await model.deleteStory()
        await model.deleteStory()

        XCTAssertEqual(model.state, .deleted)
        XCTAssertEqual(service.deleteCount, 1)
        XCTAssertEqual(service.cacheClearCount, 1)
    }

    func testDeleteFailureKeepsStoryVisible() async throws {
        let story = try MonthlyStoryPreviewData.story()
        let service = InMemoryMonthlyStoryClientService(storyResult: .story(story))
        service.deletionError = MonthlyStoryClientError.networkUnavailable
        let model = MonthlyStoryReaderModel(story: story, service: service)

        await model.deleteStory()

        XCTAssertEqual(model.state, .ready(story))
        XCTAssertTrue(model.showsDeletionError)
        XCTAssertEqual(service.deleteCount, 1)
        XCTAssertEqual(service.cacheClearCount, 0)
    }

    func testRemoteDisableWhileReaderOpenPreservesOwnedStory() async throws {
        let story = try MonthlyStoryPreviewData.story()
        let service = InMemoryMonthlyStoryClientService(
            availability: .init(visible: true),
            storyResult: .story(story)
        )
        let model = MonthlyStoryReaderModel(story: story, service: service)
        service.availability = .init(visible: false)

        await model.refreshRemoteAvailability()

        XCTAssertEqual(model.state, .ready(story))
    }

    func testStage7SourceHasNoFirebaseAnalyticsHealthOrAudioIntegration() throws {
        let sources = try stage7ProductionSources()
        let joined = sources.values.joined(separator: "\n")

        for forbidden in [
            "import Firebase",
            "Firestore.",
            "FirebaseFirestore",
            "PostHog",
            "AnalyticsManager",
            "HealthKit",
            "HealthService",
            "AVAudio",
            "AudioPlayer",
            "NotificationCenter",
            "URLSession",
            "https://"
        ] {
            XCTAssertFalse(joined.contains(forbidden), "Stage 7 source contains \(forbidden)")
        }
    }

    func testNoAppLaunchListenerAndProfileIntegrationRemainsGateOwned() throws {
        let root = repositoryRoot()
        let appSource = try String(
            contentsOf: root.appendingPathComponent("Dino/DinoApp.swift"),
            encoding: .utf8
        )
        let profileSource = try String(
            contentsOf: root.appendingPathComponent("Dino/Views/ProfileView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(appSource.contains("MonthlyStory"))
        XCTAssertEqual(profileSource.components(separatedBy: "MonthlyStoryCardHost(").count - 1, 1)
        XCTAssertFalse(profileSource.contains("MonthlyStoryClientService"))
        XCTAssertFalse(profileSource.contains("monthlyStoryInternal"))
    }

    func testAccessibilityAndDynamicTypeSupportArePresent() throws {
        let sources = try stage7ProductionSources()
        let setup = try XCTUnwrap(sources["MonthlyStorySetupView.swift"])
        let card = try XCTUnwrap(sources["MonthlyStoryCard.swift"])
        let reader = try XCTUnwrap(sources["MonthlyStoryView.swift"])

        XCTAssertTrue(setup.contains("accessibilityHint"))
        XCTAssertTrue(setup.contains("coming later"))
        XCTAssertTrue(card.contains("accessibilityLabel"))
        XCTAssertTrue(reader.contains("accessibilityElement(children: .contain)"))
        XCTAssertTrue(reader.contains("accessibilityLabel(\"delete this monthly story\")"))
        XCTAssertTrue(reader.contains("ScrollView"))
        XCTAssertTrue(reader.contains("DinoTheme.serifFont"))
        XCTAssertTrue([setup, card, reader].allSatisfy { $0.contains("minHeight: 44") || $0.contains("height: 44") })
    }

    private func enabledSettings() -> MonthlyStorySettings {
        MonthlyStorySettings(
            enabled: true,
            useJournalThemes: false,
            useHealthPatterns: false,
            audioEnabled: false,
            timezone: "UTC",
            timezoneEffectiveMonth: "2026-07",
            settingsVersion: 1
        )
    }

    private func validStoryObject() -> [String: Any] {
        let paragraphs = [
            "Work seemed to take a lot out of you this month, and home seemed to stay on your mind. Even so, time with your own ideas still mattered, especially when the rest of the month felt crowded and heavy.",
            "There were also quieter moments that gave the month a little room. Rest and breathing did not need to solve anything to be worth keeping close, and you did not need to turn every difficult day into progress.",
            "Next month, try to protect one small stretch of time where work is actually over. Leave room for a personal project without asking it to become productive, and keep one gentle way to slow down nearby for the days that feel full."
        ]
        return [
            "monthKey": "2026-07",
            "generationVersion": "deterministic-v1",
            "signalSchemaVersion": 1,
            "status": "textReady",
            "profile": "standard",
            "compositionMode": "deterministic",
            "compositionVersion": "deterministic-v1",
            "script": paragraphs.joined(separator: "\n\n"),
            "paragraphs": paragraphs,
            "wordCount": 124,
            "usedEvidenceIds": ["synthetic-a", "synthetic-b"],
            "usedClaimKeys": ["workPressure", "missingHome"],
            "usedSuggestionKeys": ["protectPersonalTime"],
            "scriptHash": String(repeating: "a", count: 64),
            "validationVersion": "script-validator-v1",
            "providerRequestCount": 0,
            "providerCostMicros": 0,
            "createdAtMillis": 1_775_203_200_000,
            "finalizedAtMillis": 1_775_203_200_000,
            "expiresAtMillis": 1_806_739_200_000,
            "audioStatus": "notRequested",
            "deletionState": "active",
            "storageCleanup": [
                "state": "notRequired",
                "updatedAtMillis": 1_775_203_200_000
            ]
        ]
    }

    private func decodeStory(_ object: [String: Any]) throws -> MonthlyStoryDocument {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try JSONDecoder().decode(MonthlyStoryDocument.self, from: data)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func stage7ProductionSources() throws -> [String: String] {
        let root = repositoryRoot()
        let paths = [
            "Dino/Models/MonthlyStoryDocument.swift",
            "Dino/Models/MonthlyStorySettings.swift",
            "Dino/Models/MonthlyStoryViewState.swift",
            "Dino/Services/MonthlyStoryClientService.swift",
            "Dino/Services/MonthlyStoryInternalGate.swift",
            "Dino/Views/MonthlyStorySetupView.swift",
            "Dino/Views/MonthlyStoryCard.swift",
            "Dino/Views/MonthlyStoryView.swift"
        ]
        return try Dictionary(uniqueKeysWithValues: paths.map { path in
            let url = root.appendingPathComponent(path)
            return (
                url.lastPathComponent,
                try String(contentsOf: url, encoding: .utf8)
            )
        })
    }
}
