import Foundation

enum MonthlyStoryOpeningStyle: String, Codable, CaseIterable, Sendable {
    case gentleReflection
    case quietWelcome
}

enum MonthlyStoryClosingStyle: String, Codable, CaseIterable, Sendable {
    case warmAndOpen
    case simpleCompanionship
}

enum MonthlyStoryNarrativeSectionKind: String, Codable, CaseIterable, Sendable {
    case overallMonth
    case whatWasHard
    case whatHelped
    case recommendationReflection
    case nextMonthSuggestion
}

struct MonthlyStoryNarrativeSection: Codable, Equatable, Sendable {
    let kind: MonthlyStoryNarrativeSectionKind
    let evidenceIDs: [MonthlyStoryEvidenceID]

    private enum CodingKeys: String, CodingKey, CaseIterable { case kind, evidenceIDs }

    init(kind: MonthlyStoryNarrativeSectionKind, evidenceIDs: [MonthlyStoryEvidenceID]) throws {
        guard !evidenceIDs.isEmpty, evidenceIDs.count <= 8, Set(evidenceIDs).count == evidenceIDs.count else {
            throw MonthlyStorySchemaError.invalidNarrativePlan
        }
        self.kind = kind
        self.evidenceIDs = evidenceIDs
    }

    init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(kind: c.decode(MonthlyStoryNarrativeSectionKind.self, forKey: .kind),
                      evidenceIDs: c.decode([MonthlyStoryEvidenceID].self, forKey: .evidenceIDs))
    }
}

struct MonthlyStoryNarrativePlan: Codable, Equatable, Sendable {
    let opening: MonthlyStoryOpeningStyle
    let overallMonth: MonthlyStoryNarrativeSection
    let whatWasHard: MonthlyStoryNarrativeSection?
    let whatHelped: MonthlyStoryNarrativeSection?
    let recommendationReflection: MonthlyStoryNarrativeSection?
    let nextMonthSuggestions: [MonthlyStoryNarrativeSection]
    let closing: MonthlyStoryClosingStyle
    let usedEvidenceIDs: [MonthlyStoryEvidenceID]
    let maximumWordTarget: Int

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case opening, overallMonth, whatWasHard, whatHelped, recommendationReflection
        case nextMonthSuggestions, closing, usedEvidenceIDs, maximumWordTarget
    }

    init(opening: MonthlyStoryOpeningStyle,
         overallMonth: MonthlyStoryNarrativeSection,
         whatWasHard: MonthlyStoryNarrativeSection? = nil,
         whatHelped: MonthlyStoryNarrativeSection? = nil,
         recommendationReflection: MonthlyStoryNarrativeSection? = nil,
         nextMonthSuggestions: [MonthlyStoryNarrativeSection],
         closing: MonthlyStoryClosingStyle,
         usedEvidenceIDs: [MonthlyStoryEvidenceID],
         maximumWordTarget: Int = 300) throws {
        let sections = [overallMonth, whatWasHard, whatHelped, recommendationReflection].compactMap { $0 } + nextMonthSuggestions
        guard overallMonth.kind == .overallMonth,
              whatWasHard?.kind == .whatWasHard || whatWasHard == nil,
              whatHelped?.kind == .whatHelped || whatHelped == nil,
              recommendationReflection?.kind == .recommendationReflection || recommendationReflection == nil,
              nextMonthSuggestions.count <= 3,
              nextMonthSuggestions.allSatisfy({ $0.kind == .nextMonthSuggestion }),
              (80...300).contains(maximumWordTarget),
              !usedEvidenceIDs.isEmpty,
              usedEvidenceIDs.count <= 32,
              Set(usedEvidenceIDs).count == usedEvidenceIDs.count,
              Set(sections.flatMap(\.evidenceIDs)).isSubset(of: Set(usedEvidenceIDs)) else {
            throw MonthlyStorySchemaError.invalidNarrativePlan
        }
        self.opening = opening
        self.overallMonth = overallMonth
        self.whatWasHard = whatWasHard
        self.whatHelped = whatHelped
        self.recommendationReflection = recommendationReflection
        self.nextMonthSuggestions = nextMonthSuggestions
        self.closing = closing
        self.usedEvidenceIDs = usedEvidenceIDs
        self.maximumWordTarget = maximumWordTarget
    }

    init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(opening: c.decode(MonthlyStoryOpeningStyle.self, forKey: .opening),
                      overallMonth: c.decode(MonthlyStoryNarrativeSection.self, forKey: .overallMonth),
                      whatWasHard: c.decodeIfPresent(MonthlyStoryNarrativeSection.self, forKey: .whatWasHard),
                      whatHelped: c.decodeIfPresent(MonthlyStoryNarrativeSection.self, forKey: .whatHelped),
                      recommendationReflection: c.decodeIfPresent(MonthlyStoryNarrativeSection.self, forKey: .recommendationReflection),
                      nextMonthSuggestions: c.decode([MonthlyStoryNarrativeSection].self, forKey: .nextMonthSuggestions),
                      closing: c.decode(MonthlyStoryClosingStyle.self, forKey: .closing),
                      usedEvidenceIDs: c.decode([MonthlyStoryEvidenceID].self, forKey: .usedEvidenceIDs),
                      maximumWordTarget: c.decode(Int.self, forKey: .maximumWordTarget))
    }
}
