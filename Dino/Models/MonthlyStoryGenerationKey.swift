import Foundation

struct MonthlyStoryUIDHash: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) throws {
        let allowed = CharacterSet(charactersIn: "0123456789abcdef")
        guard (16...64).contains(rawValue.count), rawValue.unicodeScalars.allSatisfy(allowed.contains) else {
            throw MonthlyStorySchemaError.invalidUIDHash
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

struct MonthlyStoryGenerationVersion: Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard (1...32).contains(rawValue.count), rawValue.unicodeScalars.allSatisfy(allowed.contains) else {
            throw MonthlyStorySchemaError.invalidGenerationVersion
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

struct MonthlyStoryGenerationKey: Codable, Hashable, CustomStringConvertible, Sendable {
    let uidHash: MonthlyStoryUIDHash
    let monthKey: MonthlyStoryMonthKey
    let generationVersion: MonthlyStoryGenerationVersion

    var description: String { "\(uidHash.rawValue)/\(monthKey.rawValue)/\(generationVersion.rawValue)" }
}

enum MonthlyStoryGenerationPhase: String, Codable, Sendable {
    case ready
    case leased
    case scriptValidated
    case completedText
    case completedWithAudio
    case terminalFailure
    case deleted

    var preventsRegeneration: Bool {
        switch self {
        case .completedText, .completedWithAudio, .terminalFailure, .deleted: true
        case .ready, .leased, .scriptValidated: false
        }
    }
}

enum MonthlyStoryGenerationTransitionError: Error, Equatable {
    case invalidTransition
    case activeLease
    case textAttemptLimit
    case audioAttemptLimit
    case budgetExceeded
}

struct MonthlyStoryGenerationState: Equatable, Sendable {
    static let maximumTextAttempts = 2
    static let maximumAudioAttempts = 2

    let key: MonthlyStoryGenerationKey
    private(set) var phase: MonthlyStoryGenerationPhase = .ready
    private(set) var leaseUntil: Date?
    private(set) var textAttemptCount = 0
    private(set) var audioAttemptCount = 0
    private(set) var reservedBudgetMicros: Int64 = 0
    private(set) var committedBudgetMicros: Int64 = 0

    var canGenerate: Bool { !phase.preventsRegeneration }
    var isDeletedTombstone: Bool { phase == .deleted }

    mutating func acquireLease(until: Date, now: Date) throws {
        guard canGenerate, phase != .scriptValidated else { throw MonthlyStoryGenerationTransitionError.invalidTransition }
        if phase == .leased, let leaseUntil, leaseUntil > now { throw MonthlyStoryGenerationTransitionError.activeLease }
        guard until > now else { throw MonthlyStoryGenerationTransitionError.invalidTransition }
        phase = .leased
        leaseUntil = until
    }

    mutating func reserveBudget(micros: Int64, monthlyLimitMicros: Int64) throws {
        guard canGenerate, micros >= 0, monthlyLimitMicros >= 0,
              reservedBudgetMicros + committedBudgetMicros + micros <= monthlyLimitMicros else {
            throw MonthlyStoryGenerationTransitionError.budgetExceeded
        }
        reservedBudgetMicros += micros
    }

    mutating func recordTextAttempt() throws {
        guard phase == .leased else { throw MonthlyStoryGenerationTransitionError.invalidTransition }
        guard textAttemptCount < Self.maximumTextAttempts else { throw MonthlyStoryGenerationTransitionError.textAttemptLimit }
        textAttemptCount += 1
    }

    mutating func validateScript() throws {
        guard phase == .leased, textAttemptCount > 0 else { throw MonthlyStoryGenerationTransitionError.invalidTransition }
        phase = .scriptValidated
        leaseUntil = nil
    }

    mutating func completeText(committedMicros: Int64) throws {
        guard phase == .scriptValidated else { throw MonthlyStoryGenerationTransitionError.invalidTransition }
        try commit(micros: committedMicros)
        phase = .completedText
    }

    mutating func recordAudioAttempt() throws {
        guard phase == .scriptValidated || phase == .completedText else { throw MonthlyStoryGenerationTransitionError.invalidTransition }
        guard audioAttemptCount < Self.maximumAudioAttempts else { throw MonthlyStoryGenerationTransitionError.audioAttemptLimit }
        audioAttemptCount += 1
    }

    mutating func completeAudio(committedMicros: Int64) throws {
        guard (phase == .scriptValidated || phase == .completedText), audioAttemptCount > 0 else {
            throw MonthlyStoryGenerationTransitionError.invalidTransition
        }
        try commit(micros: committedMicros)
        phase = .completedWithAudio
    }

    mutating func failTerminally() {
        guard !phase.preventsRegeneration else { return }
        phase = .terminalFailure
        leaseUntil = nil
        reservedBudgetMicros = 0
    }

    mutating func markDeleted() {
        phase = .deleted
        leaseUntil = nil
        reservedBudgetMicros = 0
    }

    private mutating func commit(micros: Int64) throws {
        guard micros >= 0, micros <= reservedBudgetMicros else {
            throw MonthlyStoryGenerationTransitionError.budgetExceeded
        }
        reservedBudgetMicros -= micros
        committedBudgetMicros += micros
    }
}
