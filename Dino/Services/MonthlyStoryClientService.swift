import Foundation
import SwiftUI
import Combine

struct MonthlyStoryFeatureAvailability: Equatable, Sendable {
    let visible: Bool
    var signalUploadEnabled = false
    var textGenerationEnabled = false
    var generationVersion = ""
    var signalSchemaVersion = 0
}

enum MonthlyStoryStoryLoadResult: Equatable, Sendable {
    case notFound
    case preparing
    case failed
    case deleted
    case expired
    case story(MonthlyStoryDocument)
}

enum MonthlyStoryClientError: Error, Equatable {
    case networkUnavailable
    case malformedStory
    case unsupportedSchemaVersion
    case deletionFailed
    case featureDisabled
    case invalidSignal
    case generationFailed
}

@MainActor
protocol MonthlyStoryClientService: AnyObject {
    func loadFeatureAvailability() async throws -> MonthlyStoryFeatureAvailability
    func loadSettings() async throws -> MonthlyStorySettings
    func updateSettings(_ settings: MonthlyStorySettings) async throws -> MonthlyStorySettings
    func loadAvailableStory() async throws -> MonthlyStoryStoryLoadResult
    func prepareDeterministicStory(signal: MonthlyStorySignal) async throws -> MonthlyStoryDocument
    func deleteStory(monthKey: MonthlyStoryMonthKey) async throws
    func clearLocalStoryCache(monthKey: MonthlyStoryMonthKey) async
}

@MainActor
final class InMemoryMonthlyStoryClientService: MonthlyStoryClientService {
    var availability: MonthlyStoryFeatureAvailability
    var settings: MonthlyStorySettings
    var storyResult: MonthlyStoryStoryLoadResult
    var loadError: MonthlyStoryClientError?
    var updateError: MonthlyStoryClientError?
    var deletionError: MonthlyStoryClientError?

    private(set) var availabilityLoadCount = 0
    private(set) var settingsLoadCount = 0
    private(set) var settingsUpdateCount = 0
    private(set) var storyLoadCount = 0
    private(set) var deleteCount = 0
    private(set) var generationCount = 0
    private(set) var cacheClearCount = 0

    init(availability: MonthlyStoryFeatureAvailability = .init(visible: false),
         settings: MonthlyStorySettings = .disabled,
         storyResult: MonthlyStoryStoryLoadResult = .notFound) {
        self.availability = availability
        self.settings = settings.sanitizedForWrittenOnlyStage
        self.storyResult = storyResult
    }

    func loadFeatureAvailability() async throws -> MonthlyStoryFeatureAvailability {
        availabilityLoadCount += 1
        if let loadError { throw loadError }
        return availability
    }

    func loadSettings() async throws -> MonthlyStorySettings {
        settingsLoadCount += 1
        if let loadError { throw loadError }
        return settings
    }

    func updateSettings(_ settings: MonthlyStorySettings) async throws -> MonthlyStorySettings {
        settingsUpdateCount += 1
        if let updateError { throw updateError }
        let sanitized = settings.sanitizedForWrittenOnlyStage
        self.settings = sanitized
        return sanitized
    }

    func loadAvailableStory() async throws -> MonthlyStoryStoryLoadResult {
        storyLoadCount += 1
        if let loadError { throw loadError }
        return storyResult
    }

    func prepareDeterministicStory(signal: MonthlyStorySignal) async throws -> MonthlyStoryDocument {
        generationCount += 1
        guard availability.signalUploadEnabled, availability.textGenerationEnabled,
              signal.isUploadable else { throw MonthlyStoryClientError.featureDisabled }
        if case .story(let story) = storyResult { return story }
        guard let story = try? MonthlyStoryPreviewData.story() else {
            throw MonthlyStoryClientError.generationFailed
        }
        storyResult = .story(story)
        return story
    }

    func deleteStory(monthKey: MonthlyStoryMonthKey) async throws {
        deleteCount += 1
        if let deletionError { throw deletionError }
        if case .story(let story) = storyResult, story.monthKey != monthKey {
            throw MonthlyStoryClientError.deletionFailed
        }
        storyResult = .deleted
    }

    func clearLocalStoryCache(monthKey: MonthlyStoryMonthKey) async {
        cacheClearCount += 1
    }
}

@MainActor
private enum MonthlyStoryDefaultClientService {
    static let shared: any MonthlyStoryClientService = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-monthlyStoryRemoteVisible"),
           let story = try? MonthlyStoryPreviewData.story() {
            return InMemoryMonthlyStoryClientService(
                availability: .init(visible: true),
                settings: .disabled,
                storyResult: .story(story)
            )
        }
        #endif
        return FirestoreMonthlyStoryClientService()
    }()
}

@MainActor
private struct MonthlyStoryClientServiceKey: EnvironmentKey {
    static let defaultValue: any MonthlyStoryClientService = MonthlyStoryDefaultClientService.shared
}

extension EnvironmentValues {
    @MainActor
    var monthlyStoryClientService: any MonthlyStoryClientService {
        get { self[MonthlyStoryClientServiceKey.self] }
        set { self[MonthlyStoryClientServiceKey.self] = newValue }
    }
}

@MainActor
func resolveMonthlyStoryExperience(localGate: MonthlyStoryInternalGate,
                                   service: any MonthlyStoryClientService) async -> MonthlyStoryExperienceSnapshot {
    guard localGate.isEnabled else { return .hidden }
    do {
        let availability = try await service.loadFeatureAvailability()
        guard localGate.permits(remoteVisible: availability.visible) else { return .hidden }
        let settings = try await service.loadSettings()
        guard settings.enabled else {
            return MonthlyStoryExperienceSnapshot(isVisible: true,
                                                  settings: settings,
                                                  state: .settingsDisabled)
        }
        let state: MonthlyStoryViewState
        switch try await service.loadAvailableStory() {
        case .notFound: state = .noStory
        case .preparing: state = .preparing
        case .failed: state = .failed
        case .deleted: state = .deleted
        case .expired: state = .unavailable(.expired)
        case .story(let story): state = .ready(story)
        }
        return MonthlyStoryExperienceSnapshot(isVisible: true, settings: settings, state: state)
    } catch MonthlyStoryClientError.networkUnavailable {
        return MonthlyStoryExperienceSnapshot(isVisible: true,
                                              settings: .disabled,
                                              state: .unavailable(.network))
    } catch MonthlyStoryClientError.malformedStory {
        return MonthlyStoryExperienceSnapshot(isVisible: true,
                                              settings: .disabled,
                                              state: .unavailable(.malformed))
    } catch MonthlyStoryClientError.unsupportedSchemaVersion {
        return MonthlyStoryExperienceSnapshot(isVisible: true,
                                              settings: .disabled,
                                              state: .unavailable(.unsupportedVersion))
    } catch MonthlyStoryClientError.featureDisabled {
        return .hidden
    } catch {
        return MonthlyStoryExperienceSnapshot(isVisible: true, settings: .disabled, state: .failed)
    }
}

@MainActor
final class MonthlyStoryReaderModel: ObservableObject {
    @Published private(set) var state: MonthlyStoryViewState
    @Published private(set) var isDeleting = false
    @Published var showsDeletionError = false

    private let service: any MonthlyStoryClientService
    private let originalStory: MonthlyStoryDocument

    init(story: MonthlyStoryDocument, service: any MonthlyStoryClientService) {
        originalStory = story
        self.service = service
        state = .ready(story)
    }

    func refreshRemoteAvailability() async {
        do {
            _ = try await service.loadFeatureAvailability()
        } catch {
            // Preserve an already-open, user-owned story. Remote disable only
            // prevents future enrollment, upload, and generation actions.
        }
    }

    func deleteStory() async {
        guard state != .deleted, !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await service.deleteStory(monthKey: originalStory.monthKey)
            await service.clearLocalStoryCache(monthKey: originalStory.monthKey)
            state = .deleted
        } catch {
            state = .ready(originalStory)
            showsDeletionError = true
        }
    }
}

enum MonthlyStoryPreviewData {
    static func story() throws -> MonthlyStoryDocument {
        let paragraph = "july held a mix of demanding days and quieter moments. work seemed to take a lot out of you, while time for your own ideas gave the month a little more room. neither part needs to explain the other."
        let second = "next month, try to keep one small part of the week clear after work. leave a little room for your own projects, and let that time stay simple enough to return to."
        let object: [String: Any] = [
            "monthKey": "2026-07", "generationVersion": "deterministic-v1",
            "compositionVersion": "deterministic-v1", "signalSchemaVersion": 1,
            "status": "textReady", "script": "\(paragraph)\n\n\(second)",
            "paragraphs": [paragraph, second], "wordCount":  ninetyTwo,
            "profile": "standard", "usedEvidenceIds": ["synthetic-evidence-01"],
            "usedClaimKeys": ["workPressure"], "usedSuggestionKeys": ["protectPersonalTime"],
            "scriptHash": String(repeating: "a", count: 64), "createdAtMillis": 1_775_203_200_000,
            "finalizedAtMillis": 1_775_203_200_000, "expiresAtMillis": 1_806_724_800_000,
            "audioStatus": "notRequested", "deletionState": "active",
            "validationVersion": "script-validator-v1", "compositionMode": "deterministic",
            "providerRequestCount": 0, "providerCostMicros": 0,
            "storageCleanup": ["state": "notRequired", "updatedAtMillis": 1_775_203_200_000]
        ]
        return try JSONDecoder().decode(MonthlyStoryDocument.self,
                                        from: JSONSerialization.data(withJSONObject: object))
    }

    private static let ninetyTwo = 92
}
