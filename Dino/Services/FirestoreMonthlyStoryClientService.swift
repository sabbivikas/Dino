import Foundation
import FirebaseFunctions

protocol MonthlyStoryCallableTransport: Sendable {
    func call(_ name: String, data: [String: Any]) async throws -> Any
}

struct FirebaseMonthlyStoryCallableTransport: MonthlyStoryCallableTransport {
    func call(_ name: String, data: [String: Any]) async throws -> Any {
        try await Functions.functions(region: "us-central1").httpsCallable(name).call(data).data
    }
}

@MainActor
final class FirestoreMonthlyStoryClientService: MonthlyStoryClientService {
    private let transport: any MonthlyStoryCallableTransport
    private let timeoutNanoseconds: UInt64
    private var availability: MonthlyStoryFeatureAvailability?
    private var settings = MonthlyStorySettings.disabled
    private var storyCache: [MonthlyStoryMonthKey: MonthlyStoryDocument] = [:]
    private var generationTasks: [MonthlyStoryMonthKey: Task<MonthlyStoryDocument, Error>] = [:]

    init(transport: any MonthlyStoryCallableTransport = FirebaseMonthlyStoryCallableTransport(),
         timeoutSeconds: UInt64 = 30) {
        self.transport = transport
        timeoutNanoseconds = timeoutSeconds * 1_000_000_000
    }

    func loadFeatureAvailability() async throws -> MonthlyStoryFeatureAvailability {
        let data = try await invoke("getMonthlyStoryInternalAvailability", fields: [:])
        let value = MonthlyStoryFeatureAvailability(
            visible: data["visible"] as? Bool == true,
            signalUploadEnabled: data["signalUploadEnabled"] as? Bool == true,
            textGenerationEnabled: data["textGenerationEnabled"] as? Bool == true,
            generationVersion: data["generationVersion"] as? String ?? "",
            signalSchemaVersion: data["signalSchemaVersion"] as? Int ?? 0
        )
        guard value.visible,
              value.generationVersion.range(of: "^[A-Za-z0-9._-]{1,32}$", options: .regularExpression) != nil,
              value.signalSchemaVersion > 0 else {
            throw MonthlyStoryClientError.featureDisabled
        }
        availability = value
        return value
    }

    func loadSettings() async throws -> MonthlyStorySettings {
        let value = try decodeSettings(try await invoke("getMonthlyStoryInternalSettings", fields: [:]))
        settings = value
        return value
    }

    func updateSettings(_ requested: MonthlyStorySettings) async throws -> MonthlyStorySettings {
        let sanitized = requested.sanitizedForWrittenOnlyStage
        let payload: [String: Any] = [
            "enabled": sanitized.enabled,
            "useJournalThemes": sanitized.useJournalThemes,
            "useHealthPatterns": sanitized.useHealthPatterns,
            "audioEnabled": false,
            "timezone": sanitized.timezone,
            "timezoneEffectiveMonth": sanitized.timezoneEffectiveMonth,
            "settingsVersion": sanitized.settingsVersion
        ]
        let value = try decodeSettings(try await invoke(
            "updateMonthlyStoryInternalSettings", fields: ["settings": payload]))
        settings = value
        return value
    }

    func loadAvailableStory() async throws -> MonthlyStoryStoryLoadResult {
        let monthKey = try closedMonthKey(timezone: settings.timezone)
        if let cached = storyCache[monthKey] { return .story(cached) }
        let response = try await invoke("loadMonthlyStoryInternalStory",
                                        fields: ["monthKey": monthKey.rawValue])
        guard let raw = response["story"], !(raw is NSNull) else { return .notFound }
        let story = try decodeStory(raw)
        guard story.monthKey == monthKey else { throw MonthlyStoryClientError.malformedStory }
        storyCache[monthKey] = story
        return story.expiresAt <= Date() ? .expired : .story(story)
    }

    func prepareDeterministicStory(signal: MonthlyStorySignal) async throws -> MonthlyStoryDocument {
        guard signal.isUploadable else { throw MonthlyStoryClientError.invalidSignal }
        if let cached = storyCache[signal.monthKey] { return cached }
        if let existing = generationTasks[signal.monthKey] { return try await existing.value }
        let resolvedAvailability: MonthlyStoryFeatureAvailability
        if let availability {
            resolvedAvailability = availability
        } else {
            resolvedAvailability = try await loadFeatureAvailability()
        }
        guard resolvedAvailability.signalUploadEnabled, resolvedAvailability.textGenerationEnabled,
              resolvedAvailability.signalSchemaVersion == signal.schemaVersion else {
            throw MonthlyStoryClientError.featureDisabled
        }
        let transport = transport
        let timeout = timeoutNanoseconds
        let appVersion = Self.appVersion
        let version = resolvedAvailability.generationVersion
        let task = Task<MonthlyStoryDocument, Error> {
            let signalObject = try Self.jsonObject(signal)
            let raw = try await Self.invoke(transport: transport, timeoutNanoseconds: timeout,
                name: "generateMonthlyStoryInternal", data: ["appVersion": appVersion,
                    "monthKey": signal.monthKey.rawValue, "generationVersion": version,
                    "signal": signalObject])
            guard let story = raw["story"] else { throw MonthlyStoryClientError.generationFailed }
            return try Self.decodeStoryValue(story)
        }
        generationTasks[signal.monthKey] = task
        defer { generationTasks[signal.monthKey] = nil }
        let story = try await task.value
        guard story.monthKey == signal.monthKey else { throw MonthlyStoryClientError.malformedStory }
        storyCache[signal.monthKey] = story
        return story
    }

    func deleteStory(monthKey: MonthlyStoryMonthKey) async throws {
        guard let story = storyCache[monthKey] else { return }
        do {
            _ = try await invoke("deleteMonthlyStoryInternal", fields: [
                "monthKey": monthKey.rawValue, "generationVersion": story.generationVersion
            ])
            storyCache[monthKey] = nil
        } catch {
            throw MonthlyStoryClientError.deletionFailed
        }
    }

    func clearLocalStoryCache(monthKey: MonthlyStoryMonthKey) async { storyCache[monthKey] = nil }

    private func invoke(_ name: String, fields: [String: Any]) async throws -> [String: Any] {
        try await Self.invoke(transport: transport, timeoutNanoseconds: timeoutNanoseconds,
                              name: name, data: fields.merging(["appVersion": Self.appVersion]) { current, _ in current })
    }

    nonisolated private static func invoke(transport: any MonthlyStoryCallableTransport,
                                           timeoutNanoseconds: UInt64,
                                           name: String,
                                           data: [String: Any]) async throws -> [String: Any] {
        try await withThrowingTaskGroup(of: Any.self) { group in
            group.addTask { try await transport.call(name, data: data) }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw MonthlyStoryClientError.networkUnavailable
            }
            guard let result = try await group.next() else { throw MonthlyStoryClientError.networkUnavailable }
            group.cancelAll()
            guard let dictionary = result as? [String: Any] else {
                throw MonthlyStoryClientError.malformedStory
            }
            return dictionary
        }
    }

    private func decodeSettings(_ data: [String: Any]) throws -> MonthlyStorySettings {
        guard let enabled = data["enabled"] as? Bool,
              let journal = data["useJournalThemes"] as? Bool,
              let health = data["useHealthPatterns"] as? Bool,
              data["audioEnabled"] as? Bool == false,
              let timezone = data["timezone"] as? String,
              TimeZone(identifier: timezone) != nil,
              let effective = data["timezoneEffectiveMonth"] as? String,
              let version = data["settingsVersion"] as? Int,
              version == MonthlyStorySettings.currentVersion,
              (try? MonthlyStoryMonthKey(rawValue: effective)) != nil else {
            throw MonthlyStoryClientError.malformedStory
        }
        return MonthlyStorySettings(enabled: enabled, useJournalThemes: journal,
            useHealthPatterns: health, audioEnabled: false, timezone: timezone,
            timezoneEffectiveMonth: effective, settingsVersion: version)
    }

    private func closedMonthKey(timezone: String) throws -> MonthlyStoryMonthKey {
        guard let zone = TimeZone(identifier: timezone) else { throw MonthlyStoryClientError.malformedStory }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        guard let prior = calendar.date(byAdding: .month, value: -1, to: Date()) else {
            throw MonthlyStoryClientError.malformedStory
        }
        let components = calendar.dateComponents([.year, .month], from: prior)
        return try MonthlyStoryMonthKey(rawValue: String(format: "%04d-%02d", components.year!, components.month!))
    }

    private func decodeStory(_ raw: Any) throws -> MonthlyStoryDocument { try Self.decodeStoryValue(raw) }

    nonisolated private static func decodeStoryValue(_ raw: Any) throws -> MonthlyStoryDocument {
        do {
            let data = try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys])
            return try JSONDecoder().decode(MonthlyStoryDocument.self, from: data)
        } catch MonthlyStoryDocumentError.unsupportedSchemaVersion {
            throw MonthlyStoryClientError.unsupportedSchemaVersion
        } catch {
            throw MonthlyStoryClientError.malformedStory
        }
    }

    nonisolated private static func jsonObject(_ signal: MonthlyStorySignal) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(signal))
    }

    nonisolated private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}
