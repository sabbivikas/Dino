import Foundation

struct MonthlyStoryPermissions: Codable, Equatable, Sendable {
    let featureEnabled: Bool
    let journalThemesEnabled: Bool
    let healthPatternsEnabled: Bool
    let audioEnabled: Bool

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case featureEnabled, journalThemesEnabled, healthPatternsEnabled, audioEnabled
    }

    init(featureEnabled: Bool, journalThemesEnabled: Bool, healthPatternsEnabled: Bool, audioEnabled: Bool) {
        self.featureEnabled = featureEnabled
        self.journalThemesEnabled = journalThemesEnabled
        self.healthPatternsEnabled = healthPatternsEnabled
        self.audioEnabled = audioEnabled
    }

    init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(featureEnabled: try c.decode(Bool.self, forKey: .featureEnabled),
                  journalThemesEnabled: try c.decode(Bool.self, forKey: .journalThemesEnabled),
                  healthPatternsEnabled: try c.decode(Bool.self, forKey: .healthPatternsEnabled),
                  audioEnabled: try c.decode(Bool.self, forKey: .audioEnabled))
    }
}

enum MonthlyStoryEligibilityCode: String, Codable, CaseIterable, Sendable {
    case eligibleStandard
    case eligibleMoodOnly
    case featureDisabled
    case insufficientSpan
    case insufficientEvidenceDays
    case insufficientMoodDays
    case insufficientCorroboration
    case insufficientObservations
    case safetyHold
    case monthNotClosed
    case alreadyCompleted
    case deletedTombstone
    case invalidTimezone
    case invalidMonthBoundary

    var isEligible: Bool { self == .eligibleStandard || self == .eligibleMoodOnly }
}

struct MonthlyStoryEligibilitySnapshot: Codable, Equatable, Sendable {
    let code: MonthlyStoryEligibilityCode
    let permitsCauseNarration: Bool

    private enum CodingKeys: String, CodingKey, CaseIterable { case code, permitsCauseNarration }

    init(code: MonthlyStoryEligibilityCode, permitsCauseNarration: Bool) {
        self.code = code
        self.permitsCauseNarration = permitsCauseNarration
    }

    init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(code: try c.decode(MonthlyStoryEligibilityCode.self, forKey: .code),
                  permitsCauseNarration: try c.decode(Bool.self, forKey: .permitsCauseNarration))
    }
}

struct MonthlyStorySafetyDecision: Equatable, Sendable {
    let isStorySafetyEligible: Bool

    static let eligible = MonthlyStorySafetyDecision(isStorySafetyEligible: true)
    static let hold = MonthlyStorySafetyDecision(isStorySafetyEligible: false)
}

struct MonthlyStorySignal: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let maximumEvidenceItems = 64
    static let maximumDaysPerSet = 31

    let schemaVersion: Int
    let monthKey: MonthlyStoryMonthKey
    let timeZone: MonthlyStoryTimeZone
    let evidenceStartDay: MonthlyStoryDay
    let evidenceEndDay: MonthlyStoryDay
    let usableEvidenceDays: [MonthlyStoryDay]
    let moodEvidenceDays: [MonthlyStoryDay]
    let corroboratingEvidenceDays: [MonthlyStoryDay]
    let permissions: MonthlyStoryPermissions
    let isStorySafetyEligible: Bool
    let evidence: [MonthlyStoryEvidence]
    let eligibility: MonthlyStoryEligibilitySnapshot?

    init(schemaVersion: Int = Self.currentSchemaVersion,
         monthKey: MonthlyStoryMonthKey,
         timeZone: MonthlyStoryTimeZone,
         evidenceStartDay: MonthlyStoryDay,
         evidenceEndDay: MonthlyStoryDay,
         usableEvidenceDays: [MonthlyStoryDay],
         moodEvidenceDays: [MonthlyStoryDay],
         corroboratingEvidenceDays: [MonthlyStoryDay],
         permissions: MonthlyStoryPermissions,
         isStorySafetyEligible: Bool,
         evidence: [MonthlyStoryEvidence],
         eligibility: MonthlyStoryEligibilitySnapshot? = nil) throws {
        guard schemaVersion == Self.currentSchemaVersion,
              evidenceStartDay <= evidenceEndDay,
              evidence.count <= Self.maximumEvidenceItems,
              usableEvidenceDays.count <= Self.maximumDaysPerSet,
              moodEvidenceDays.count <= Self.maximumDaysPerSet,
              corroboratingEvidenceDays.count <= Self.maximumDaysPerSet else {
            throw MonthlyStorySchemaError.tooManyValues
        }
        try Self.requireUnique(usableEvidenceDays)
        try Self.requireUnique(moodEvidenceDays)
        try Self.requireUnique(corroboratingEvidenceDays)
        try Self.requireUnique(evidence.map(\.id))
        let monthPrefix = monthKey.rawValue + "-"
        let allDays = usableEvidenceDays + moodEvidenceDays + corroboratingEvidenceDays +
            evidence.flatMap { [$0.startDay, $0.endDay] } + [evidenceStartDay, evidenceEndDay]
        guard allDays.allSatisfy({ $0.rawValue.hasPrefix(monthPrefix) }),
              allDays.allSatisfy({ $0 >= evidenceStartDay && $0 <= evidenceEndDay }),
              Set(moodEvidenceDays).isSubset(of: Set(usableEvidenceDays)),
              Set(corroboratingEvidenceDays).isSubset(of: Set(usableEvidenceDays)),
              permissions.journalThemesEnabled || !evidence.contains(where: { $0.category == .repeatedTheme }),
              permissions.healthPatternsEnabled || !evidence.contains(where: { $0.category == .sleepPattern || $0.category == .movementPattern }) else {
            throw MonthlyStorySchemaError.inconsistentEvidence
        }
        self.schemaVersion = schemaVersion
        self.monthKey = monthKey
        self.timeZone = timeZone
        self.evidenceStartDay = evidenceStartDay
        self.evidenceEndDay = evidenceEndDay
        self.usableEvidenceDays = usableEvidenceDays.sorted()
        self.moodEvidenceDays = moodEvidenceDays.sorted()
        self.corroboratingEvidenceDays = corroboratingEvidenceDays.sorted()
        self.permissions = permissions
        self.isStorySafetyEligible = isStorySafetyEligible
        self.evidence = isStorySafetyEligible ? evidence : []
        self.eligibility = eligibility
    }

    var isUploadable: Bool { permissions.featureEnabled && isStorySafetyEligible }

    private static func requireUnique<T: Hashable>(_ values: [T]) throws {
        guard Set(values).count == values.count else { throw MonthlyStorySchemaError.duplicateValue }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, monthKey, timeZone, evidenceStartDay, evidenceEndDay
        case usableEvidenceDays, moodEvidenceDays, corroboratingEvidenceDays
        case permissions, isStorySafetyEligible, evidence, eligibility
    }

    init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(schemaVersion: c.decode(Int.self, forKey: .schemaVersion),
                      monthKey: c.decode(MonthlyStoryMonthKey.self, forKey: .monthKey),
                      timeZone: c.decode(MonthlyStoryTimeZone.self, forKey: .timeZone),
                      evidenceStartDay: c.decode(MonthlyStoryDay.self, forKey: .evidenceStartDay),
                      evidenceEndDay: c.decode(MonthlyStoryDay.self, forKey: .evidenceEndDay),
                      usableEvidenceDays: c.decode([MonthlyStoryDay].self, forKey: .usableEvidenceDays),
                      moodEvidenceDays: c.decode([MonthlyStoryDay].self, forKey: .moodEvidenceDays),
                      corroboratingEvidenceDays: c.decode([MonthlyStoryDay].self, forKey: .corroboratingEvidenceDays),
                      permissions: c.decode(MonthlyStoryPermissions.self, forKey: .permissions),
                      isStorySafetyEligible: c.decode(Bool.self, forKey: .isStorySafetyEligible),
                      evidence: c.decode([MonthlyStoryEvidence].self, forKey: .evidence),
                      eligibility: c.decodeIfPresent(MonthlyStoryEligibilitySnapshot.self, forKey: .eligibility))
    }
}

enum MonthlyStoryThemeAllowlist {
    static func theme(forExistingTag tag: String) -> MonthlyStoryJournalTheme? {
        switch tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "work", "work_pressure", "workpressure": .workPressure
        case "missing_home", "missinghome", "homesick": .missingHome
        case "family": .family
        case "relationships", "relationship": .relationships
        case "uncertainty": .uncertainty
        case "personal_projects", "personalprojects", "projects": .personalProjects
        case "rest", "sleep": .rest
        case "change": .change
        case "social_connection", "socialconnection": .socialConnection
        default: nil
        }
    }
}
