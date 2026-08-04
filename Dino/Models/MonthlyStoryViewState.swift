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
    case noStory
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

    static let hidden = MonthlyStoryExperienceSnapshot(isVisible: false,
                                                       settings: .disabled,
                                                       state: .idle)
}
