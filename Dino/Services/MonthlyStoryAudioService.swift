import Foundation
import SwiftUI
import FirebaseStorage

enum MonthlyStoryAudioClientError: Error, Equatable {
    case disabled, unavailable, malformed, downloadFailed
}

@MainActor
protocol MonthlyStoryAudioService: AnyObject {
    func requestAudio(for story: MonthlyStoryDocument) async throws -> MonthlyStoryDocument
    func playableURL(for story: MonthlyStoryDocument) async throws -> URL
    func clearCache(monthKey: MonthlyStoryMonthKey) async
}

@MainActor
final class FirebaseMonthlyStoryAudioService: MonthlyStoryAudioService {
    private let transport: any MonthlyStoryCallableTransport
    private let storage: Storage
    private let cache: MonthlyStoryAudioCache
    private var requests: [String: Task<MonthlyStoryDocument, Error>] = [:]

    init(transport: any MonthlyStoryCallableTransport = FirebaseMonthlyStoryCallableTransport(),
         storage: Storage = Storage.storage(), cache: MonthlyStoryAudioCache = MonthlyStoryAudioCache()) {
        self.transport = transport; self.storage = storage; self.cache = cache
    }

    func requestAudio(for story: MonthlyStoryDocument) async throws -> MonthlyStoryDocument {
        if story.audioState == .ready { return story }
        if let task = requests[story.id] { return try await task.value }
        let transport = transport
        let task = Task<MonthlyStoryDocument, Error> {
            let raw = try await transport.call("generateMonthlyStoryInternalAudio", data: [
                "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
                "monthKey": story.monthKey.rawValue, "generationVersion": story.generationVersion
            ])
            guard let dictionary = raw as? [String: Any], let storyObject = dictionary["story"] else {
                throw MonthlyStoryAudioClientError.malformed
            }
            return try Self.decode(storyObject)
        }
        requests[story.id] = task
        defer { requests[story.id] = nil }
        return try await task.value
    }

    func playableURL(for story: MonthlyStoryDocument) async throws -> URL {
        guard story.audioState == .ready, let path = story.audioStoragePath,
              path == "monthlyStories/" + path.split(separator: "/").dropFirst().joined(separator: "/"),
              path.hasSuffix("/\(story.generationVersion)/story.mp3") else {
            throw MonthlyStoryAudioClientError.unavailable
        }
        if let cached = await cache.existingURL(for: story) { return cached }
        do {
            let data = try await storage.reference(withPath: path).data(maxSize: 25 * 1024 * 1024)
            return try await cache.store(data, for: story)
        } catch { throw MonthlyStoryAudioClientError.downloadFailed }
    }

    func clearCache(monthKey: MonthlyStoryMonthKey) async { await cache.remove(monthKey: monthKey) }

    nonisolated private static func decode(_ raw: Any) throws -> MonthlyStoryDocument {
        do {
            return try JSONDecoder().decode(MonthlyStoryDocument.self,
                from: JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]))
        } catch { throw MonthlyStoryAudioClientError.malformed }
    }
}

@MainActor
final class InMemoryMonthlyStoryAudioService: MonthlyStoryAudioService {
    var generatedStory: MonthlyStoryDocument?
    var playableFile: URL?
    var error: MonthlyStoryAudioClientError?
    private(set) var generationCount = 0
    private(set) var cacheClearCount = 0
    nonisolated init() {}
    func requestAudio(for story: MonthlyStoryDocument) async throws -> MonthlyStoryDocument {
        generationCount += 1; if let error { throw error }; return generatedStory ?? story
    }
    func playableURL(for story: MonthlyStoryDocument) async throws -> URL {
        if let error { throw error }; guard let playableFile else { throw MonthlyStoryAudioClientError.unavailable }
        return playableFile
    }
    func clearCache(monthKey: MonthlyStoryMonthKey) async { cacheClearCount += 1 }
}

@MainActor private enum MonthlyStoryDefaultAudioService {
    static let shared: any MonthlyStoryAudioService = FirebaseMonthlyStoryAudioService()
}
@MainActor private struct MonthlyStoryAudioServiceKey: EnvironmentKey {
    static let defaultValue: any MonthlyStoryAudioService = MonthlyStoryDefaultAudioService.shared
}
extension EnvironmentValues {
    @MainActor var monthlyStoryAudioService: any MonthlyStoryAudioService {
        get { self[MonthlyStoryAudioServiceKey.self] }
        set { self[MonthlyStoryAudioServiceKey.self] = newValue }
    }
}
