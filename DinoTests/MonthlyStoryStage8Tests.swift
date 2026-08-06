import XCTest
@testable import Dino

actor MonthlyStoryFakeCallableTransport: MonthlyStoryCallableTransport {
    private var responses: [String: Any]
    private(set) var calls: [(String, [String: Any])] = []

    init(responses: [String: Any]) { self.responses = responses }

    func call(_ name: String, data: [String: Any]) async throws -> Any {
        calls.append((name, data))
        guard let response = responses[name] else { throw MonthlyStoryClientError.networkUnavailable }
        if let error = response as? MonthlyStoryClientError { throw error }
        return response
    }

    func count(_ name: String) -> Int { calls.filter { $0.0 == name }.count }
    func payloads() -> [[String: Any]] { calls.map(\.1) }
}

@MainActor
final class MonthlyStoryStage8Tests: XCTestCase {
    func testProductionCallableContractUsesUSCentral1AndApprovedNames() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let client = try String(contentsOf: root.appendingPathComponent(
            "Dino/Services/FirestoreMonthlyStoryClientService.swift"))
        let audio = try String(contentsOf: root.appendingPathComponent(
            "Dino/Services/MonthlyStoryAudioService.swift"))

        XCTAssertTrue(client.contains("Functions.functions(region: \"us-central1\")"))
        for name in [
            "getMonthlyStoryInternalAvailability",
            "getMonthlyStoryInternalSettings",
            "updateMonthlyStoryInternalSettings",
            "loadMonthlyStoryInternalStory",
            "generateMonthlyStoryInternal",
            "deleteMonthlyStoryInternal",
            "generateMonthlyStoryInternalAudio"
        ] {
            XCTAssertTrue((client + audio).contains(name), "missing callable: \(name)")
        }
        XCTAssertFalse((client + audio).contains("useEmulator"))
    }

    func testFirebaseServiceIsLazyAndServerAvailabilityControlsVisibility() async throws {
        let transport = MonthlyStoryFakeCallableTransport(responses: [
            "getMonthlyStoryInternalAvailability": availability(),
            "getMonthlyStoryInternalSettings": settings(enabled: false)
        ])
        let service = FirestoreMonthlyStoryClientService(transport: transport)
        let initialAvailabilityCalls = await transport.count("getMonthlyStoryInternalAvailability")
        XCTAssertEqual(initialAvailabilityCalls, 0)

        let snapshot = await resolveMonthlyStoryExperience(localGate: .init(isEnabled: true), service: service)
        XCTAssertTrue(snapshot.isVisible)
        XCTAssertEqual(snapshot.state, .settingsDisabled)
        let availabilityCalls = await transport.count("getMonthlyStoryInternalAvailability")
        let settingsCalls = await transport.count("getMonthlyStoryInternalSettings")
        let storyCalls = await transport.count("loadMonthlyStoryInternalStory")
        XCTAssertEqual(availabilityCalls, 1)
        XCTAssertEqual(settingsCalls, 1)
        XCTAssertEqual(storyCalls, 0)
    }

    func testRemoteDenialCannotBeBypassedByTheLocalGate() async {
        let transport = MonthlyStoryFakeCallableTransport(responses: [
            "getMonthlyStoryInternalAvailability": MonthlyStoryClientError.featureDisabled
        ])
        let service = FirestoreMonthlyStoryClientService(transport: transport)
        let snapshot = await resolveMonthlyStoryExperience(localGate: .init(isEnabled: true), service: service)
        XCTAssertFalse(snapshot.isVisible)
        let settingsCalls = await transport.count("getMonthlyStoryInternalSettings")
        XCTAssertEqual(settingsCalls, 0)
    }

    func testDisabledLocalGateMakesNoBackendRequest() async {
        let transport = MonthlyStoryFakeCallableTransport(responses: [:])
        let service = FirestoreMonthlyStoryClientService(transport: transport)
        let snapshot = await resolveMonthlyStoryExperience(localGate: .disabled, service: service)
        XCTAssertFalse(snapshot.isVisible)
        let payloadCount = await transport.payloads().count
        XCTAssertEqual(payloadCount, 0)
    }

    func testSettingsRemainWrittenOnlyAndPayloadContainsNoUID() async throws {
        let transport = MonthlyStoryFakeCallableTransport(responses: [
            "updateMonthlyStoryInternalSettings": settings(enabled: true, journal: true, health: true)
        ])
        let service = FirestoreMonthlyStoryClientService(transport: transport)
        let saved = try await service.updateSettings(.init(enabled: true, useJournalThemes: true,
            useHealthPatterns: true, audioEnabled: true, timezone: "UTC",
            timezoneEffectiveMonth: "2026-07"))
        XCTAssertTrue(saved.enabled && saved.useJournalThemes && saved.useHealthPatterns)
        XCTAssertFalse(saved.audioEnabled)
        let payloads = await transport.payloads()
        let payload = try XCTUnwrap(payloads.first)
        XCTAssertNil(payload["uid"])
        XCTAssertEqual((payload["settings"] as? [String: Any])?["audioEnabled"] as? Bool, false)
    }

    func testExistingStoryLoadsAndDeleteIsServerBackedAndIdempotent() async throws {
        let story = storyObject()
        let transport = MonthlyStoryFakeCallableTransport(responses: [
            "loadMonthlyStoryInternalStory": ["story": story],
            "deleteMonthlyStoryInternal": ["deleted": true]
        ])
        let service = FirestoreMonthlyStoryClientService(transport: transport)
        guard case .story(let loaded) = try await service.loadAvailableStory() else {
            return XCTFail("expected story")
        }
        try await service.deleteStory(monthKey: loaded.monthKey)
        try await service.deleteStory(monthKey: loaded.monthKey)
        let deleteCalls = await transport.count("deleteMonthlyStoryInternal")
        let payloads = await transport.payloads()
        XCTAssertEqual(deleteCalls, 1)
        XCTAssertNil(payloads.last?["uid"])
    }

    func testDeterministicGenerationUsesOneCallableAndNoProviderOrAudioFields() async throws {
        let transport = MonthlyStoryFakeCallableTransport(responses: [
            "getMonthlyStoryInternalAvailability": availability(),
            "generateMonthlyStoryInternal": ["story": storyObject(), "reused": false]
        ])
        let service = FirestoreMonthlyStoryClientService(transport: transport)
        _ = try await service.loadFeatureAvailability()
        let story = try await service.prepareDeterministicStory(signal: MonthlyStoryFixtures.richMonth)
        XCTAssertEqual(story.audioStatus, "notRequested")
        let generationCalls = await transport.count("generateMonthlyStoryInternal")
        let payloads = await transport.payloads()
        XCTAssertEqual(generationCalls, 1)
        let payload = try XCTUnwrap(payloads.last)
        XCTAssertNil(payload["uid"])
        XCTAssertNil(payload["script"])
        let signal = try XCTUnwrap(payload["signal"] as? [String: Any])
        XCTAssertNil(signal["uid"])
        XCTAssertNil(signal["journalText"])
        XCTAssertNil(signal["healthSamples"])
        let evidence = try XCTUnwrap(signal["evidence"] as? [[String: Any]])
        let firstValue = try XCTUnwrap(evidence.first?["value"] as? [String: Any])
        XCTAssertEqual(firstValue["type"] as? String, "emotionalShape")
    }

    func testInvalidOrDisabledSignalStopsBeforeGenerationCall() async {
        let transport = MonthlyStoryFakeCallableTransport(responses: [
            "getMonthlyStoryInternalAvailability": availability(signalUpload: false)
        ])
        let service = FirestoreMonthlyStoryClientService(transport: transport)
        _ = try? await service.loadFeatureAvailability()
        do {
            _ = try await service.prepareDeterministicStory(signal: MonthlyStoryFixtures.richMonth)
            XCTFail("expected feature-disabled")
        } catch { XCTAssertEqual(error as? MonthlyStoryClientError, .featureDisabled) }
        let generationCalls = await transport.count("generateMonthlyStoryInternal")
        XCTAssertEqual(generationCalls, 0)
    }

    func testStage8SourcesHaveNoAnalyticsProviderTTSOrAppLaunchIntegration() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let paths = ["Dino/Services/FirestoreMonthlyStoryClientService.swift",
                     "Dino/Services/MonthlyStorySignalCoordinator.swift"]
        let source = try paths.map { try String(contentsOf: root.appendingPathComponent($0)) }.joined()
        for forbidden in ["PostHog", "AnalyticsManager", "OpenAI", "AVAudio", "TTS", "TextToSpeech"] {
            XCTAssertFalse(source.contains(forbidden))
        }
        let app = try String(contentsOf: root.appendingPathComponent("Dino/DinoApp.swift"))
        XCTAssertFalse(app.contains("MonthlyStory"))
    }

    private func availability(signalUpload: Bool = true) -> [String: Any] {
        ["visible": true, "enrollmentEnabled": true, "signalUploadEnabled": signalUpload,
         "textGenerationEnabled": true, "generationVersion": "deterministic-v1", "signalSchemaVersion": 1]
    }

    private func settings(enabled: Bool, journal: Bool = false, health: Bool = false) -> [String: Any] {
        ["enabled": enabled, "useJournalThemes": journal, "useHealthPatterns": health,
         "audioEnabled": false, "timezone": "UTC", "timezoneEffectiveMonth": "2026-07",
         "settingsVersion": 1]
    }

    private func storyObject() -> [String: Any] {
        let paragraphs = [
            "July carried a mix of demanding days and quieter moments. Work seemed to take a lot out of you, while time for your own ideas still mattered when the rest of the month felt crowded.",
            "There were also pauses that gave the month a little room. Rest did not need to solve anything to be worth keeping close, and every difficult day did not need to become progress.",
            "Next month, try to protect a small stretch where work is actually over. Leave room for a personal project without asking it to become productive, and keep one gentle way to slow down nearby."
        ]
        return ["monthKey": "2026-07", "generationVersion": "deterministic-v1",
            "compositionVersion": "deterministic-v1", "signalSchemaVersion": 1, "status": "textReady",
            "script": paragraphs.joined(separator: "\n\n"), "paragraphs": paragraphs, "wordCount": 101,
            "profile": "standard", "usedEvidenceIds": ["synthetic-evidence"],
            "usedClaimKeys": ["workPressure"], "usedSuggestionKeys": ["protectPersonalTime"],
            "scriptHash": String(repeating: "a", count: 64), "createdAtMillis": 1_775_203_200_000,
            "finalizedAtMillis": 1_775_203_200_000, "expiresAtMillis": 1_806_739_200_000,
            "audioStatus": "notRequested", "deletionState": "active",
            "validationVersion": "script-validator-v1", "compositionMode": "deterministic",
            "providerRequestCount": 0, "providerCostMicros": 0,
            "storageCleanup": ["state": "notRequired", "updatedAtMillis": 1_775_203_200_000]]
    }
}
