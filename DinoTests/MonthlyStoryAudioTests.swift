import XCTest
@testable import Dino

@MainActor
final class MonthlyStoryAudioTests: XCTestCase {
    private final class FakeEngine: MonthlyStoryPlaybackEngine {
        var isPlaying = false
        var currentTime: TimeInterval = 0
        var duration: TimeInterval = 100
        func prepareToPlay() {}
        func play() { isPlaying = true }
        func pause() { isPlaying = false }
        func stop() { isPlaying = false; currentTime = 0 }
    }

    func testAudioSettingsRemainExplicitAndDefaultOff() {
        XCTAssertFalse(MonthlyStorySettings().audioEnabled)
        let enabled = MonthlyStorySettings(enabled: true, audioEnabled: true)
        XCTAssertTrue(enabled.sanitized(audioAvailable: true).audioEnabled)
        XCTAssertFalse(enabled.sanitized(audioAvailable: false).audioEnabled)
        XCTAssertFalse(MonthlyStorySettings(enabled: false, audioEnabled: true)
            .sanitized(audioAvailable: true).audioEnabled)
    }

    func testReadyAudioDocumentRequiresPrivateMP3Metadata() throws {
        let story = try audioStory(status: "ready")
        XCTAssertEqual(story.audioState, .ready)
        XCTAssertEqual(story.audioFormat, "mp3")
        XCTAssertTrue(story.audioStoragePath?.hasSuffix("/story.mp3") == true)
        XCTAssertThrowsError(try audioStory(status: "ready", path: "https://public.example/story.mp3"))
    }

    func testPlayerLoadsPlaysPausesSeeksAndReplaysWithoutProviderCalls() async throws {
        let story = try audioStory(status: "ready")
        let service = InMemoryMonthlyStoryAudioService()
        service.playableFile = URL(fileURLWithPath: "/tmp/synthetic-monthly-story.mp3")
        let engine = FakeEngine()
        let player = MonthlyStoryAudioPlayer(story: story, audioOptIn: true, service: service,
                                             engineFactory: { _ in engine })
        try await player.load()
        XCTAssertEqual(player.state, .ready)
        await player.togglePlayback(); XCTAssertEqual(player.state, .playing)
        engine.currentTime = 45
        player.replay()
        XCTAssertEqual(engine.currentTime, 0)
        XCTAssertTrue(engine.isPlaying)
        XCTAssertEqual(player.state, .playing)
        player.pause(); XCTAssertEqual(player.state, .paused)
        player.seek(to: 45); XCTAssertEqual(player.elapsed, 45)
        player.replay(); XCTAssertEqual(engine.currentTime, 0)
        XCTAssertEqual(service.generationCount, 0)
    }

    func testGenerationFailurePreservesWrittenStoryAndDeleteClearsCache() async throws {
        let story = try audioStory(status: "notRequested")
        let audio = InMemoryMonthlyStoryAudioService(); audio.error = .unavailable
        let player = MonthlyStoryAudioPlayer(story: story, audioOptIn: true, service: audio,
                                             engineFactory: { _ in FakeEngine() })
        await player.createAudio()
        XCTAssertEqual(player.state, .failed)
        XCTAssertFalse(player.story.script.isEmpty)
        await audio.clearCache(monthKey: story.monthKey)
        XCTAssertEqual(audio.cacheClearCount, 1)
    }

    func testProtectedCacheStoresSyntheticBytesAndRemovesOnDelete() async throws {
        let story = try audioStory(status: "ready")
        let cache = MonthlyStoryAudioCache()
        let url = try await cache.store(Data("ID3synthetic".utf8), for: story)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let protection = attributes[.protectionKey] as? FileProtectionType
#if targetEnvironment(simulator)
        if let protection { XCTAssertEqual(protection, .complete) }
#else
        XCTAssertEqual(protection, .complete)
#endif
        let storedURL = await cache.existingURL(for: story)
        XCTAssertNotNil(storedURL)
        await cache.remove(monthKey: story.monthKey)
        let removedURL = await cache.existingURL(for: story)
        XCTAssertNil(removedURL)
    }

    private func audioStory(status: String, path: String? =
        "monthlyStories/synthetic-owner/2026-07/deterministic-v1/story.mp3") throws -> MonthlyStoryDocument {
        let paragraph = "a synthetic monthly reflection with enough words to remain safely inside the existing validator profile. "
        var object: [String: Any] = [
            "monthKey": "2026-07", "generationVersion": "deterministic-v1",
            "compositionVersion": "deterministic-v1", "signalSchemaVersion": 1,
            "status": "textReady", "script": String(repeating: paragraph, count: 10),
            "paragraphs": [String(repeating: paragraph, count: 10)], "wordCount": 120,
            "profile": "standard", "usedEvidenceIds": ["synthetic-evidence-01"],
            "usedClaimKeys": ["workPressure"], "usedSuggestionKeys": ["protectPersonalTime"],
            "scriptHash": String(repeating: "a", count: 64), "createdAtMillis": 1_775_203_200_000,
            "finalizedAtMillis": 1_775_203_200_000, "expiresAtMillis": 1_806_724_800_000,
            "audioStatus": status, "deletionState": "active", "validationVersion": "script-validator-v1",
            "compositionMode": "deterministic", "providerRequestCount": 0, "providerCostMicros": 0,
            "storageCleanup": ["state": "notRequired", "updatedAtMillis": 1_775_203_200_000]
        ]
        if status != "notRequested" {
            object.merge(["audioTtsVersion": "hume-v1", "audioVoiceKey": "synthetic-voice",
                "audioProviderRequestCount": 1, "audioEstimatedCostMicros": 100_000,
                "audioRetryCount": 0, "audioFailureCode": NSNull()]) { _, new in new }
        }
        if status == "ready" {
            object.merge(["audioStoragePath": path as Any, "audioFormat": "mp3",
                "audioDurationMillis": 100_000, "audioHash": String(repeating: "b", count: 64),
                "audioGeneratedAtMillis": 1_775_203_200_100]) { _, new in new }
        }
        return try JSONDecoder().decode(MonthlyStoryDocument.self,
                                        from: JSONSerialization.data(withJSONObject: object))
    }
}
