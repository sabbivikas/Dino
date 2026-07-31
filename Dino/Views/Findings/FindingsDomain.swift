//
//  FindingsDomain.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo — branch-owned pure helper. The redesigned
//  card shows a small pill with the SOURCE DOMAIN of the finding's listing url
//  (e.g. "sppl.org"), so a person can see at a glance where dino found the
//  thing. Pure + deterministic so it is unit-testable with no view.
//
//  English-only demo (owner decision): plain string literals only.
//

import Foundation

enum FindingsDomain {
    /// The bare source domain for the card's pill:
    ///   "https://www.sppl.org/events/hatha" → "sppl.org"
    ///   "http://Como.Park.org/x?a=1"        → "como.park.org"
    ///   "sppl.org/events"                   → "sppl.org"  (scheme optional)
    /// Returns nil when the url has no usable host — the card then simply hides
    /// the pill rather than showing a scheme fragment or garbage.
    static func source(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // URLComponents only fills `host` when a scheme is present; add one when
        // the agent handed us a bare "host/path".
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let host = URLComponents(string: candidate)?.host, !host.isEmpty else { return nil }
        let lower = host.lowercased()
        return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
    }
}

/// The screen's honest copy for the outcomes that are NOT a finding.
///
/// WHY THIS IS SEPARATE FROM `empty`: a `failed` task used to borrow the warm
/// empty-handed line ("came back empty pawed tonight"). That reads as "there
/// was nothing to find", when what actually happened is the star hit its step
/// cap mid-search and the owner was billed for it. The lines below say so
/// plainly, in dino's voice, WITHOUT inviting an immediate retry (every retry
/// is another billed run) and with no error styling and no error haptic.
enum FindingsCopy {
    /// The line for a task-level `failed:*` outcome. `empty` never comes here.
    static func failedLine(outcome: String) -> String {
        switch outcome.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "failed:step_cap":
            return "the star searched as long as it could tonight and ran out of time"
        case "failed:timeout":
            return "the star was out a long while and had to turn back"
        default:
            return "the star could not finish its trip this time"
        }
    }

    /// A send refused because one is already in flight (the server's in-flight
    /// guard). Not an error, and never an invitation to send again.
    static let alreadyRunningLine = "the star is already out looking"
}
