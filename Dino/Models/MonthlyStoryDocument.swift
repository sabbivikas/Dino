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
    let deletionState: String

    var id: String { "\(monthKey.rawValue)/\(generationVersion)" }

    var displayMonth: String {
        let parts = monthKey.rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return monthKey.rawValue }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: 1)) else {
            return monthKey.rawValue
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case monthKey, generationVersion, compositionVersion, signalSchemaVersion, status, script, paragraphs
        case wordCount, profile, usedEvidenceIds, usedClaimKeys, usedSuggestionKeys, scriptHash
        case createdAtMillis, finalizedAtMillis, expiresAtMillis, audioStatus, deletionState
        case validationVersion, compositionMode, providerRequestCount, providerCostMicros, storageCleanup
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
        let createdAtMillis = try container.decode(Int64.self, forKey: .createdAtMillis)
        let finalizedAtMillis = try container.decode(Int64.self, forKey: .finalizedAtMillis)
        let expiresAtMillis = try container.decode(Int64.self, forKey: .expiresAtMillis)
        let decodedAudioStatus = try container.decode(String.self, forKey: .audioStatus)
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
              generationToken(try container.decode(String.self, forKey: .generationVersion)),
              generationToken(try container.decode(String.self, forKey: .compositionVersion)),
              scriptHash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              !validationVersion.isEmpty,
              createdAtMillis >= 0,
              finalizedAtMillis >= createdAtMillis,
              expiresAtMillis > finalizedAtMillis,
              decodedAudioStatus == "notRequested",
              decodedDeletionState == "active",
              cleanup.state == "notRequired",
              cleanup.updatedAtMillis == finalizedAtMillis else {
            throw MonthlyStoryDocumentError.malformed
        }

        monthKey = try container.decode(MonthlyStoryMonthKey.self, forKey: .monthKey)
        generationVersion = try container.decode(String.self, forKey: .generationVersion)
        compositionVersion = try container.decode(String.self, forKey: .compositionVersion)
        signalSchemaVersion = schemaVersion
        script = decodedScript
        paragraphs = decodedParagraphs
        wordCount = decodedWordCount
        profile = try container.decode(MonthlyStoryProfile.self, forKey: .profile)
        finalizedAt = Date(timeIntervalSince1970: TimeInterval(finalizedAtMillis) / 1_000)
        expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtMillis) / 1_000)
        audioStatus = decodedAudioStatus
        deletionState = decodedDeletionState
    }
}

private func generationToken(_ value: String) -> Bool {
    value.range(of: "^[A-Za-z0-9._-]{1,32}$", options: .regularExpression) != nil
}
