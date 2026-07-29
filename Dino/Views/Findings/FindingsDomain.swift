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
