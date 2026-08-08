import Foundation

enum MonthlyStoryUnavailableReason: Equatable, Sendable {
    case network
    case notFound
    case expired
    case malformed
    case unsupportedVersion
    case remoteDisabled
}

enum MonthlyStoryViewState: Equatable, Sendable {
    case idle
    case loading
    case settingsDisabled
    /// The closed month has no story yet. This is an invitation, not a problem.
    case noStory
    /// A story was attempted for the closed month and there was not enough of it to write one.
    /// Distinct from `noStory`: nothing the user does on this screen will change it today.
    case insufficientEvidence
    case preparing
    case ready(MonthlyStoryDocument)
    case unavailable(MonthlyStoryUnavailableReason)
    case failed
    case deleted
}

struct MonthlyStoryExperienceSnapshot: Equatable, Sendable {
    let isVisible: Bool
    let settings: MonthlyStorySettings
    let state: MonthlyStoryViewState
    /// The closed month the card is talking about, so states that have no story to name one
    /// (`noStory`, `insufficientEvidence`) can still say which month they mean.
    var targetMonth: MonthlyStoryMonthKey?

    static let hidden = MonthlyStoryExperienceSnapshot(isVisible: false,
                                                       settings: .disabled,
                                                       state: .idle)
}
