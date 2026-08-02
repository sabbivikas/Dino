import Foundation
@testable import Dino

enum MonthlyStoryFixtures {
    static let chicago = try! MonthlyStoryTimeZone(rawValue: "America/Chicago")
    static let month = try! MonthlyStoryMonthKey(rawValue: "2026-07")
    static let start = try! MonthlyStoryDay(rawValue: "2026-07-01")
    static let end = try! MonthlyStoryDay(rawValue: "2026-07-29")

    static let defaultPermissions = MonthlyStoryPermissions(featureEnabled: true,
                                                            journalThemesEnabled: true,
                                                            healthPatternsEnabled: true,
                                                            audioEnabled: false)

    static func day(_ value: Int) -> MonthlyStoryDay {
        try! MonthlyStoryDay(rawValue: String(format: "2026-07-%02d", value))
    }

    static func evidence(_ suffix: String,
                         value: MonthlyStoryEvidenceValue,
                         confidence: MonthlyStoryConfidence = .high,
                         source: MonthlyStoryEvidenceSource = .deterministicCombination,
                         allowed: Bool = true) -> MonthlyStoryEvidence {
        try! MonthlyStoryEvidence(id: MonthlyStoryEvidenceID(rawValue: "evidence-\(suffix)"),
                                  value: value,
                                  confidence: confidence,
                                  startDay: start,
                                  endDay: end,
                                  source: source,
                                  allowedForNarration: allowed)
    }

    static func signal(usable: [Int] = [1, 5, 9, 14, 20, 29],
                       moods: [Int] = [1, 9, 20, 29],
                       corroborating: [Int] = [5, 14],
                       permissions: MonthlyStoryPermissions = defaultPermissions,
                       safetyEligible: Bool = true,
                       evidence: [MonthlyStoryEvidence]? = nil,
                       startDay: MonthlyStoryDay = start,
                       endDay: MonthlyStoryDay = end,
                       timeZone: MonthlyStoryTimeZone = chicago) throws -> MonthlyStorySignal {
        try MonthlyStorySignal(monthKey: month,
                               timeZone: timeZone,
                               evidenceStartDay: startDay,
                               evidenceEndDay: endDay,
                               usableEvidenceDays: usable.map(day),
                               moodEvidenceDays: moods.map(day),
                               corroboratingEvidenceDays: corroborating.map(day),
                               permissions: permissions,
                               isStorySafetyEligible: safetyEligible,
                               evidence: evidence ?? [
                                self.evidence("mood", value: .emotionalShape(.mixed, .brighter), source: .mood),
                                self.evidence("rest", value: .restorativePractice(.breathing), source: .practicePresence)
                               ])
    }

    static var richMonth: MonthlyStorySignal {
        try! signal(evidence: [
            evidence("mood", value: .emotionalShape(.mixed, .brighter), source: .mood),
            evidence("work", value: .repeatedTheme(.workPressure), source: .authorizedJournalTheme),
            evidence("sleep", value: .sleepPattern(.moreRestful), source: .authorizedHealthSummary),
            evidence("move", value: .movementPattern(.steady), source: .authorizedHealthSummary),
            evidence("practice", value: .restorativePractice(.breathing), source: .practicePresence),
            evidence("rec-open", value: .recommendationAction(.opened), source: .recommendationOutcome)
        ])
    }

    static var moodOnlyMonth: MonthlyStorySignal {
        try! signal(usable: [1, 4, 8, 12, 16, 20, 24, 29],
                    moods: [1, 4, 8, 12, 16, 20, 24, 29],
                    corroborating: [],
                    permissions: MonthlyStoryPermissions(featureEnabled: true,
                                                         journalThemesEnabled: false,
                                                         healthPatternsEnabled: false,
                                                         audioEnabled: false),
                    evidence: [
                        evidence("mood-shape", value: .emotionalShape(.variable, .variable), source: .mood),
                        evidence("mood-direction", value: .emotionalShape(.mixed, .brighter), source: .mood)
                    ])
    }

    static var sparseMonth: MonthlyStorySignal {
        try! signal(usable: [1, 29], moods: [1, 29], corroborating: [], evidence: [
            evidence("mood-sparse", value: .emotionalShape(.mixed, .unknown), confidence: .low, source: .mood)
        ])
    }

    static var noJournalPermission: MonthlyStorySignal {
        try! signal(permissions: MonthlyStoryPermissions(featureEnabled: true,
                                                        journalThemesEnabled: false,
                                                        healthPatternsEnabled: true,
                                                        audioEnabled: false))
    }

    static var noHealthPermission: MonthlyStorySignal {
        try! signal(permissions: MonthlyStoryPermissions(featureEnabled: true,
                                                        journalThemesEnabled: true,
                                                        healthPatternsEnabled: false,
                                                        audioEnabled: false))
    }

    static var noJournalOrHealthPermission: MonthlyStorySignal {
        try! signal(permissions: MonthlyStoryPermissions(featureEnabled: true,
                                                        journalThemesEnabled: false,
                                                        healthPatternsEnabled: false,
                                                        audioEnabled: false))
    }

    static var sensitiveMonth: MonthlyStorySignal { try! signal(safetyEligible: false) }

    static var recommendationOpened: MonthlyStoryEvidence {
        evidence("rec-opened", value: .recommendationAction(.opened), source: .recommendationOutcome)
    }

    static var recommendationLeftUnopened: MonthlyStoryEvidence {
        evidence("rec-unopened", value: .recommendationAction(.leftUnopened), source: .recommendationOutcome)
    }

    static var recommendationDeliveredUnknown: MonthlyStoryEvidence {
        evidence("rec-delivered", value: .recommendationAction(.delivered), confidence: .medium, source: .recommendationOutcome)
    }

    static let malformedSchemaJSON = #"{"schemaVersion":"raw text instead of a version"}"#.data(using: .utf8)!
    static let arbitraryStringInjectionJSON = #"{"schemaVersion":1,"rawJournalText":"private words"}"#.data(using: .utf8)!

    static let validScript = """
    this month carried a mixture of demanding stretches and gentler moments. some days felt heavier, while others opened into a little more ease. work may have taken up more space than you wanted, though there were also signs that time set aside for breathing gave you room to settle. you opened something dino sent when the month felt busy, and i hope it offered a small pause. as the next month begins, it may feel good to protect a little quiet time, return to the practices that already felt comfortable, and leave space for people who help life feel less crowded. none of this needs to become a project. you can take what feels useful and leave the rest. i will be here beside you as the next part unfolds.
    """

    static let fabricatedCausalScript = validScript + " this definitely happened because work caused every difficult feeling."
    static let fakeImprovementScript = validScript + " that movie helped you and made you feel better."
    static let clinicalScript = validScript + " you have depression and should see a doctor for medical advice."
    static let reportingScript = validScript + " your data shows you logged several check-ins and your mood decreased."
    static let repeatedScript = validScript + "\n\n" + validScript
    static let overWordLimitScript = Array(repeating: "gentle", count: 301).joined(separator: " ")
}
