import Foundation

enum MonthlyStoryProfile: String, Codable, Equatable, Sendable {
    case rich
    case standard
    case moodOnly
}

enum MonthlyStoryDocumentError: Error, Equatable {
    case malformed
    case unsupportedSchemaVersion
    case unsupportedStatus
}

enum MonthlyStoryAudioStatus: String, Codable, Equatable, Sendable {
    case notRequested, generating, ready, failed, deleted
}

extension MonthlyStoryMonthKey {
    /// "July 2026". Formatted in UTC from the key's own year and month, never from the device
    /// clock, so the label always names the month the key means.
    var displayName: String {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return rawValue }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: 1)) else {
            return rawValue
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }
}

struct MonthlyStoryDocument: Decodable, Equatable, Sendable, Identifiable {
    static let supportedSignalSchemaVersion = 1

    let monthKey: MonthlyStoryMonthKey
    let generationVersion: String
    let compositionVersion: String
    let signalSchemaVersion: Int
    let script: String
    let paragraphs: [String]
    let wordCount: Int
    let profile: MonthlyStoryProfile
    let finalizedAt: Date
    let expiresAt: Date
    let audioStatus: String
    let audioStoragePath: String?
    let audioFormat: String?
    let audioDuration: TimeInterval?
    let audioHash: String?
    let audioTtsVersion: String?
    let audioVoiceKey: String?
    let audioGeneratedAt: Date?
    let audioProviderRequestCount: Int
    let audioEstimatedCostMicros: Int64
    let audioRetryCount: Int
    let audioFailureCode: String?
    let deletionState: String

    var id: String { "\(monthKey.rawValue)/\(generationVersion)" }
    var audioState: MonthlyStoryAudioStatus { MonthlyStoryAudioStatus(rawValue: audioStatus) ?? .failed }

    var displayMonth: String { monthKey.displayName }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case monthKey, generationVersion, compositionVersion, signalSchemaVersion, status, script, paragraphs
        case wordCount, profile, usedEvidenceIds, usedClaimKeys, usedSuggestionKeys, scriptHash
        case createdAtMillis, finalizedAtMillis, expiresAtMillis, audioStatus, deletionState
        case validationVersion, compositionMode, providerRequestCount, providerCostMicros, storageCleanup
        case audioStoragePath, audioFormat, audioDurationMillis, audioHash, audioTtsVersion, audioVoiceKey
        case audioGeneratedAtMillis, audioProviderRequestCount, audioEstimatedCostMicros, audioRetryCount
        case audioFailureCode
    }

    private struct StorageCleanup: Decodable {
        let state: String
        let updatedAtMillis: Int64

        private enum CodingKeys: String, CodingKey, CaseIterable { case state, updatedAtMillis }

        init(from decoder: Decoder) throws {
            try rejectUnknownKeys(decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
            let container = try decoder.container(keyedBy: CodingKeys.self)
            state = try container.decode(String.self, forKey: .state)
            updatedAtMillis = try container.decode(Int64.self, forKey: .updatedAtMillis)
        }
    }

    init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .signalSchemaVersion)
        guard schemaVersion == Self.supportedSignalSchemaVersion else {
            throw MonthlyStoryDocumentError.unsupportedSchemaVersion
        }
        guard try container.decode(String.self, forKey: .status) == "textReady",
              try container.decode(String.self, forKey: .compositionMode) == "deterministic",
              try container.decode(Int.self, forKey: .providerRequestCount) == 0,
              try container.decode(Int64.self, forKey: .providerCostMicros) == 0 else {
            throw MonthlyStoryDocumentError.unsupportedStatus
        }

        let decodedScript = try container.decode(String.self, forKey: .script)
        let decodedParagraphs = try container.decode([String].self, forKey: .paragraphs)
        let decodedWordCount = try container.decode(Int.self, forKey: .wordCount)
        let decodedMonthKey = try container.decode(MonthlyStoryMonthKey.self, forKey: .monthKey)
        let decodedGenerationVersion = try container.decode(String.self, forKey: .generationVersion)
        let decodedCompositionVersion = try container.decode(String.self, forKey: .compositionVersion)
        let createdAtMillis = try container.decode(Int64.self, forKey: .createdAtMillis)
        let finalizedAtMillis = try container.decode(Int64.self, forKey: .finalizedAtMillis)
        let expiresAtMillis = try container.decode(Int64.self, forKey: .expiresAtMillis)
        guard let decodedAudioStatus = MonthlyStoryAudioStatus(rawValue:
                try container.decode(String.self, forKey: .audioStatus)) else {
            throw MonthlyStoryDocumentError.unsupportedStatus
        }
        let decodedDeletionState = try container.decode(String.self, forKey: .deletionState)
        let cleanup = try container.decode(StorageCleanup.self, forKey: .storageCleanup)

        _ = try container.decode([String].self, forKey: .usedEvidenceIds)
        _ = try container.decode([String].self, forKey: .usedClaimKeys)
        _ = try container.decode([String].self, forKey: .usedSuggestionKeys)
        let scriptHash = try container.decode(String.self, forKey: .scriptHash)
        let validationVersion = try container.decode(String.self, forKey: .validationVersion)

        guard !decodedScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !decodedParagraphs.isEmpty,
              decodedParagraphs.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              (80...300).contains(decodedWordCount),
              generationToken(decodedGenerationVersion),
              generationToken(decodedCompositionVersion),
              scriptHash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              !validationVersion.isEmpty,
              createdAtMillis >= 0,
              finalizedAtMillis >= createdAtMillis,
              expiresAtMillis > finalizedAtMillis,
              decodedDeletionState == "active",
              ["notRequired", "pending", "complete"].contains(cleanup.state),
              cleanup.updatedAtMillis == finalizedAtMillis else {
            throw MonthlyStoryDocumentError.malformed
        }

        monthKey = decodedMonthKey
        generationVersion = decodedGenerationVersion
        compositionVersion = decodedCompositionVersion
        signalSchemaVersion = schemaVersion
        script = decodedScript
        paragraphs = decodedParagraphs
        wordCount = decodedWordCount
        profile = try container.decode(MonthlyStoryProfile.self, forKey: .profile)
        finalizedAt = Date(timeIntervalSince1970: TimeInterval(finalizedAtMillis) / 1_000)
        expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtMillis) / 1_000)
        audioStatus = decodedAudioStatus.rawValue
        audioStoragePath = try container.decodeIfPresent(String.self, forKey: .audioStoragePath)
        audioFormat = try container.decodeIfPresent(String.self, forKey: .audioFormat)
        let durationMillis = try container.decodeIfPresent(Int64.self, forKey: .audioDurationMillis)
        audioDuration = durationMillis.map { TimeInterval($0) / 1_000 }
        audioHash = try container.decodeIfPresent(String.self, forKey: .audioHash)
        audioTtsVersion = try container.decodeIfPresent(String.self, forKey: .audioTtsVersion)
        audioVoiceKey = try container.decodeIfPresent(String.self, forKey: .audioVoiceKey)
        let generatedAtMillis = try container.decodeIfPresent(Int64.self, forKey: .audioGeneratedAtMillis)
        audioGeneratedAt = generatedAtMillis.map { Date(timeIntervalSince1970: TimeInterval($0) / 1_000) }
        audioProviderRequestCount = try container.decodeIfPresent(Int.self, forKey: .audioProviderRequestCount) ?? 0
        audioEstimatedCostMicros = try container.decodeIfPresent(Int64.self, forKey: .audioEstimatedCostMicros) ?? 0
        audioRetryCount = try container.decodeIfPresent(Int.self, forKey: .audioRetryCount) ?? 0
        audioFailureCode = try container.decodeIfPresent(String.self, forKey: .audioFailureCode)
        deletionState = decodedDeletionState

        if decodedAudioStatus == .notRequested {
            guard audioStoragePath == nil, audioFormat == nil, audioHash == nil else {
                throw MonthlyStoryDocumentError.malformed
            }
        } else {
            guard audioProviderRequestCount >= 0, audioProviderRequestCount <= 2,
                  audioRetryCount >= 0, audioRetryCount <= 1,
                  audioEstimatedCostMicros >= 0 else { throw MonthlyStoryDocumentError.malformed }
            if decodedAudioStatus == .ready {
                guard audioFormat == "mp3",
                      audioStoragePath.map({ privateAudioStoragePath($0,
                          monthKey: decodedMonthKey.rawValue,
                          generationVersion: decodedGenerationVersion) }) == true,
                      audioHash?.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
                      audioGeneratedAt != nil else { throw MonthlyStoryDocumentError.malformed }
            }
        }
    }
}

private func generationToken(_ value: String) -> Bool {
    value.range(of: "^[A-Za-z0-9._-]{1,32}$", options: .regularExpression) != nil
}

private func privateAudioStoragePath(_ value: String, monthKey: String,
                                     generationVersion: String) -> Bool {
    let components = value.split(separator: "/", omittingEmptySubsequences: false)
    guard components.count == 5,
          components[0] == "monthlyStories",
          String(components[1]).range(of: "^[A-Za-z0-9_-]{1,128}$",
                                      options: .regularExpression) != nil,
          components[2] == Substring(monthKey),
          components[3] == Substring(generationVersion),
          components[4] == "story.mp3" else { return false }
    return true
}
