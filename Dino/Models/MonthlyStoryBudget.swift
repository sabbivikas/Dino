import Foundation

struct MonthlyStoryBudget: Equatable, Sendable {
    let limitMicros: Int64
    private(set) var reservedMicros: Int64
    private(set) var committedMicros: Int64

    init(limitMicros: Int64, reservedMicros: Int64 = 0, committedMicros: Int64 = 0) throws {
        guard limitMicros >= 0, reservedMicros >= 0, committedMicros >= 0,
              reservedMicros + committedMicros <= limitMicros else {
            throw MonthlyStoryGenerationTransitionError.budgetExceeded
        }
        self.limitMicros = limitMicros
        self.reservedMicros = reservedMicros
        self.committedMicros = committedMicros
    }

    var remainingMicros: Int64 { limitMicros - reservedMicros - committedMicros }

    mutating func reserve(_ micros: Int64) throws {
        guard micros >= 0, micros <= remainingMicros else { throw MonthlyStoryGenerationTransitionError.budgetExceeded }
        reservedMicros += micros
    }

    mutating func commit(_ micros: Int64) throws {
        guard micros >= 0, micros <= reservedMicros else { throw MonthlyStoryGenerationTransitionError.budgetExceeded }
        reservedMicros -= micros
        committedMicros += micros
    }

    mutating func release(_ micros: Int64) throws {
        guard micros >= 0, micros <= reservedMicros else { throw MonthlyStoryGenerationTransitionError.budgetExceeded }
        reservedMicros -= micros
    }
}
