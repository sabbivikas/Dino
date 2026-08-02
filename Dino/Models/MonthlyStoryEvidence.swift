import Foundation

enum MonthlyStorySchemaError: Error, Equatable {
    case invalidMonthKey
    case invalidTimeZone
    case invalidDate
    case invalidMonthBoundary
    case invalidEvidenceID
    case invalidGenerationVersion
    case invalidUIDHash
    case tooManyValues
    case duplicateValue
    case inconsistentEvidence
    case unknownField(String)
    case invalidNarrativePlan
}

struct MonthlyStoryMonthKey: Codable, Hashable, Comparable, Sendable {
    let rawValue: String

    init(rawValue: String) throws {
        let parts = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts[0].count == 4,
              parts[1].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              (2000...2200).contains(year),
              (1...12).contains(month) else {
            throw MonthlyStorySchemaError.invalidMonthKey
        }
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        try self.init(rawValue: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct MonthlyStoryTimeZone: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) throws {
        guard rawValue.count <= 64,
              (rawValue == "UTC" || TimeZone.knownTimeZoneIdentifiers.contains(rawValue)),
              TimeZone(identifier: rawValue) != nil else {
            throw MonthlyStorySchemaError.invalidTimeZone
        }
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        try self.init(rawValue: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var foundation: TimeZone { TimeZone(identifier: rawValue)! }
}

struct MonthlyStoryDay: Codable, Hashable, Comparable, Sendable {
    let rawValue: String

    init(rawValue: String) throws {
        let pieces = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard pieces.count == 3,
              pieces[0].count == 4,
              pieces[1].count == 2,
              pieces[2].count == 2,
              let year = Int(pieces[0]),
              let month = Int(pieces[1]),
              let day = Int(pieces[2]) else {
            throw MonthlyStorySchemaError.invalidDate
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else {
            throw MonthlyStorySchemaError.invalidDate
        }
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        try self.init(rawValue: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct MonthlyStoryEvidenceID: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        guard (8...64).contains(rawValue.count),
              rawValue.unicodeScalars.allSatisfy(allowed.contains),
              !rawValue.contains("..") else {
            throw MonthlyStorySchemaError.invalidEvidenceID
        }
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        try self.init(rawValue: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum MonthlyStoryEvidenceCategory: String, Codable, CaseIterable, Sendable {
    case emotionalShape
    case repeatedTheme
    case sleepPattern
    case movementPattern
    case restorativePractice
    case recommendationAction
    case nextMonthSuggestionBasis
}

enum MonthlyStoryEvidenceSource: String, Codable, CaseIterable, Sendable {
    case mood
    case authorizedJournalTheme
    case authorizedHealthSummary
    case practicePresence
    case recommendationOutcome
    case deterministicCombination
}

enum MonthlyStoryConfidence: String, Codable, CaseIterable, Comparable, Sendable {
    case low
    case medium
    case high

    private var rank: Int {
        switch self { case .low: 0; case .medium: 1; case .high: 2 }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

enum MonthlyStoryMoodShape: String, Codable, CaseIterable, Sendable {
    case mostlyBright
    case mostlyHeavy
    case mixed
    case steady
    case variable
}

enum MonthlyStoryMoodDirection: String, Codable, CaseIterable, Sendable {
    case brighter
    case heavier
    case steady
    case variable
    case unknown
}

enum MonthlyStoryJournalTheme: String, Codable, CaseIterable, Sendable {
    case workPressure
    case missingHome
    case family
    case relationships
    case uncertainty
    case personalProjects
    case rest
    case change
    case socialConnection
}

enum MonthlyStorySleepBucket: String, Codable, CaseIterable, Sendable {
    case moreRestful
    case lessRestful
    case variable
    case steady
}

enum MonthlyStoryMovementBucket: String, Codable, CaseIterable, Sendable {
    case moreActive
    case lessActive
    case variable
    case steady
}

enum MonthlyStoryPracticeKind: String, Codable, CaseIterable, Sendable {
    case meditation
    case breathing
    case focus
}

enum MonthlyStoryRecommendationAction: String, Codable, CaseIterable, Sendable {
    case delivered
    case opened
    case kept
    case leftUnopened
}

enum MonthlyStorySuggestionBasis: String, Codable, CaseIterable, Sendable {
    case continueRest
    case protectPersonalTime
    case seekConnection
    case continueHelpfulPractice
    case makeSpaceForProjects
}

enum MonthlyStoryEvidenceValue: Codable, Equatable, Sendable {
    case emotionalShape(MonthlyStoryMoodShape, MonthlyStoryMoodDirection)
    case repeatedTheme(MonthlyStoryJournalTheme)
    case sleepPattern(MonthlyStorySleepBucket)
    case movementPattern(MonthlyStoryMovementBucket)
    case restorativePractice(MonthlyStoryPracticeKind)
    case recommendationAction(MonthlyStoryRecommendationAction)
    case nextMonthSuggestionBasis(MonthlyStorySuggestionBasis)

    var category: MonthlyStoryEvidenceCategory {
        switch self {
        case .emotionalShape: .emotionalShape
        case .repeatedTheme: .repeatedTheme
        case .sleepPattern: .sleepPattern
        case .movementPattern: .movementPattern
        case .restorativePractice: .restorativePractice
        case .recommendationAction: .recommendationAction
        case .nextMonthSuggestionBasis: .nextMonthSuggestionBasis
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable { case type, moodShape, moodDirection, theme, sleep, movement, practice, recommendation, suggestion }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MonthlyStoryEvidenceCategory.self, forKey: .type)
        switch type {
        case .emotionalShape:
            try rejectUnknownKeys(decoder, allowed: [CodingKeys.type.stringValue, CodingKeys.moodShape.stringValue, CodingKeys.moodDirection.stringValue])
            self = .emotionalShape(try container.decode(MonthlyStoryMoodShape.self, forKey: .moodShape),
                                   try container.decode(MonthlyStoryMoodDirection.self, forKey: .moodDirection))
        case .repeatedTheme:
            try rejectUnknownKeys(decoder, allowed: [CodingKeys.type.stringValue, CodingKeys.theme.stringValue])
            self = .repeatedTheme(try container.decode(MonthlyStoryJournalTheme.self, forKey: .theme))
        case .sleepPattern:
            try rejectUnknownKeys(decoder, allowed: [CodingKeys.type.stringValue, CodingKeys.sleep.stringValue])
            self = .sleepPattern(try container.decode(MonthlyStorySleepBucket.self, forKey: .sleep))
        case .movementPattern:
            try rejectUnknownKeys(decoder, allowed: [CodingKeys.type.stringValue, CodingKeys.movement.stringValue])
            self = .movementPattern(try container.decode(MonthlyStoryMovementBucket.self, forKey: .movement))
        case .restorativePractice:
            try rejectUnknownKeys(decoder, allowed: [CodingKeys.type.stringValue, CodingKeys.practice.stringValue])
            self = .restorativePractice(try container.decode(MonthlyStoryPracticeKind.self, forKey: .practice))
        case .recommendationAction:
            try rejectUnknownKeys(decoder, allowed: [CodingKeys.type.stringValue, CodingKeys.recommendation.stringValue])
            self = .recommendationAction(try container.decode(MonthlyStoryRecommendationAction.self, forKey: .recommendation))
        case .nextMonthSuggestionBasis:
            try rejectUnknownKeys(decoder, allowed: [CodingKeys.type.stringValue, CodingKeys.suggestion.stringValue])
            self = .nextMonthSuggestionBasis(try container.decode(MonthlyStorySuggestionBasis.self, forKey: .suggestion))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(category, forKey: .type)
        switch self {
        case let .emotionalShape(shape, direction):
            try container.encode(shape, forKey: .moodShape)
            try container.encode(direction, forKey: .moodDirection)
        case let .repeatedTheme(value): try container.encode(value, forKey: .theme)
        case let .sleepPattern(value): try container.encode(value, forKey: .sleep)
        case let .movementPattern(value): try container.encode(value, forKey: .movement)
        case let .restorativePractice(value): try container.encode(value, forKey: .practice)
        case let .recommendationAction(value): try container.encode(value, forKey: .recommendation)
        case let .nextMonthSuggestionBasis(value): try container.encode(value, forKey: .suggestion)
        }
    }
}

struct MonthlyStoryEvidence: Codable, Equatable, Sendable {
    let id: MonthlyStoryEvidenceID
    let value: MonthlyStoryEvidenceValue
    let confidence: MonthlyStoryConfidence
    let startDay: MonthlyStoryDay
    let endDay: MonthlyStoryDay
    let source: MonthlyStoryEvidenceSource
    let allowedForNarration: Bool

    var category: MonthlyStoryEvidenceCategory { value.category }

    init(id: MonthlyStoryEvidenceID,
         value: MonthlyStoryEvidenceValue,
         confidence: MonthlyStoryConfidence,
         startDay: MonthlyStoryDay,
         endDay: MonthlyStoryDay,
         source: MonthlyStoryEvidenceSource,
         allowedForNarration: Bool) throws {
        guard startDay <= endDay else { throw MonthlyStorySchemaError.inconsistentEvidence }
        self.id = id
        self.value = value
        self.confidence = confidence
        self.startDay = startDay
        self.endDay = endDay
        self.source = source
        self.allowedForNarration = allowedForNarration
    }

    private enum CodingKeys: String, CodingKey, CaseIterable { case id, value, confidence, startDay, endDay, source, allowedForNarration }

    init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: c.decode(MonthlyStoryEvidenceID.self, forKey: .id),
                      value: c.decode(MonthlyStoryEvidenceValue.self, forKey: .value),
                      confidence: c.decode(MonthlyStoryConfidence.self, forKey: .confidence),
                      startDay: c.decode(MonthlyStoryDay.self, forKey: .startDay),
                      endDay: c.decode(MonthlyStoryDay.self, forKey: .endDay),
                      source: c.decode(MonthlyStoryEvidenceSource.self, forKey: .source),
                      allowedForNarration: c.decode(Bool.self, forKey: .allowedForNarration))
    }
}

private struct AnyMonthlyStoryCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

func rejectUnknownKeys(_ decoder: Decoder, allowed: Set<String>) throws {
    let keys = try decoder.container(keyedBy: AnyMonthlyStoryCodingKey.self).allKeys.map(\.stringValue)
    if let unknown = keys.first(where: { !allowed.contains($0) }) {
        throw MonthlyStorySchemaError.unknownField(unknown)
    }
}
