//
//  LanternCeremonyMachine.swift
//  Dino
//
//  Pure phase machine + copy + geometry math for the lantern arrival
//  ceremony — no UI, no networking, fully unit-testable. Timings match the
//  design handoff exactly. The 950ms beat after "log this feeling" is
//  sacred: nothing moves, nothing rewards — the pause is the design.
//
//  House accessibility rule (wider than the design): TAP ANYWHERE ADVANCES
//  every phase, so the ceremony is fully skippable.
//

import Foundation

enum CeremonyPhase: Equatable, CaseIterable {
    case beat, hush, drift, hover, open, keep, kept, lift, after
}

struct LanternCeremonyMachine: Equatable {
    private(set) var phase: CeremonyPhase = .beat

    /// Timer-driven phases and their exact design durations (seconds).
    /// hover and open wait for the person; after is terminal.
    static func timerDuration(for phase: CeremonyPhase) -> TimeInterval? {
        switch phase {
        case .beat:  return 0.95
        case .hush:  return 2.6
        case .drift: return 5.2
        case .keep:  return 1.7
        case .kept:  return 2.6
        case .lift:  return 2.8
        case .hover, .open, .after: return nil
        }
    }

    /// The open card's unfold animation length (the phase itself waits for
    /// the keep tap).
    static let openUnfold: TimeInterval = 0.7

    mutating func timerFired() {
        switch phase {
        case .beat:  phase = .hush
        case .hush:  phase = .drift
        case .drift: phase = .hover
        case .keep:  phase = .kept
        case .kept:  phase = .lift
        case .lift:  phase = .after
        case .hover, .open, .after: break
        }
    }

    /// Tap anywhere — always advances (fully skippable).
    mutating func tapped() {
        switch phase {
        case .beat, .hush, .drift: phase = .hover
        case .open:                phase = .keep
        case .hover:               phase = .open
        case .keep, .kept, .lift:  phase = .after
        case .after:               break
        }
    }

    /// The keep button (only meaningful on the open card).
    mutating func keepTapped() {
        if phase == .open { phase = .keep }
    }

    var isNightish: Bool {
        phase != .beat && phase != .after
    }
}

// MARK: - Easing (design helpers, verbatim)

enum CeremonyEase {
    static func seg(_ t: Double, _ a: Double, _ b: Double) -> Double {
        min(max((t - a) / (b - a), 0), 1)
    }
    static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
    static func easeOut(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }
    static func lerp(_ a: Double, _ b: Double, _ k: Double) -> Double {
        a + (b - a) * k
    }
}

// MARK: - Lantern flight geometry (design-space 390×844; dt in ms)

struct CeremonyLanternFrame: Equatable {
    var x: Double = 195
    var y: Double = -120
    var scale: Double = 1
    var rotationDegrees: Double = 0
    var visible: Bool = false
    var glowAlpha: Double = 0
    var glowRadius: Double = 90
    var night: Double = 0
    var jarGlow: Double = 0
}

enum CeremonyLayout {

    /// The exact per-phase formulas from the handoff. `dt` is milliseconds
    /// since the phase began. Reduce Motion callers should crossfade between
    /// the END states of each phase instead of animating these.
    static func frame(phase: CeremonyPhase, dt: Double) -> CeremonyLanternFrame {
        var f = CeremonyLanternFrame()
        switch phase {
        case .beat:
            f.night = 0
        case .hush:
            f.night = CeremonyEase.easeInOut(CeremonyEase.seg(dt, 0, 2600))
        case .drift:
            f.night = 1
            let k = CeremonyEase.easeOut(CeremonyEase.seg(dt, 0, 5200))
            f.y = CeremonyEase.lerp(-120, 268, k)
            f.x = 195 + sin(dt / 830) * (26 * (1 - k * 0.55))
            f.rotationDegrees = sin(dt / 830 + 0.6) * 5 * (1 - k * 0.4)
            f.visible = true
            f.glowAlpha = k * 0.9
            f.glowRadius = 90 + k * 60
        case .hover:
            f.night = 1
            f.y = 268 + sin(dt / 1100) * 7
            f.x = 195 + sin(dt / 1500) * 4
            f.rotationDegrees = sin(dt / 1400) * 2.5
            f.visible = true
            f.glowAlpha = 1
            f.glowRadius = 160
        case .open:
            f.night = 1
            let k = CeremonyEase.easeInOut(CeremonyEase.seg(dt, 0, 700))
            f.y = CeremonyEase.lerp(268, 118, k)
            f.x = 195
            f.scale = CeremonyEase.lerp(1, 0.62, k)
            f.visible = true
            f.glowAlpha = CeremonyEase.lerp(1, 0.6, k)
            f.glowRadius = CeremonyEase.lerp(160, 100, k)
        case .keep:
            f.night = 1
            let k = CeremonyEase.easeInOut(CeremonyEase.seg(dt, 0, 1600))
            f.y = CeremonyEase.lerp(118, 470, k)
            f.x = 195
            f.scale = CeremonyEase.lerp(0.62, 0.42, k)
            f.visible = true
            f.glowAlpha = CeremonyEase.lerp(0.6, 0.35, k)
            f.glowRadius = CeremonyEase.lerp(100, 70, k)
            f.jarGlow = CeremonyEase.seg(dt, 400, 1600) * 0.9
        case .kept:
            f.night = 1
            f.y = 470 + sin(dt / 1300) * 3
            f.x = 195
            f.scale = 0.42
            f.visible = true
            f.glowAlpha = 0.35
            f.glowRadius = 70
            f.jarGlow = 0.9 + sin(dt / 900) * 0.08
        case .lift:
            let k = CeremonyEase.easeInOut(CeremonyEase.seg(dt, 0, 2800))
            f.night = 1 - k
            f.y = 470
            f.x = 195
            f.scale = 0.42
            f.visible = k < 0.5
            f.glowAlpha = 0.35 * (1 - k)
            f.glowRadius = 70
            f.jarGlow = 0.9 * (1 - k)
        case .after:
            f.night = 0
        }
        return f
    }
}

// MARK: - Ceremony copy (owner-approved verbatim; lowercase, zero dashes)

enum CeremonyStrings {
    static let loggedLine = String(localized: "logged 🌱")
    static let hoverTitle = String(localized: "it drifted a long way")
    static let hoverSub = String(localized: "someone far away left it for you")
    static let tapToOpen = String(localized: "tap to open")
    static let keepButton = String(localized: "keep it close 🌱")
    static let reportLink = String(localized: "report this lantern")
    static let keptCaption = String(localized: "kept in your jar · warm things stay")
    static let jarStackLine = String(localized: "tonight's lantern is in your jar")
    static let voHush = String(localized: "the evening is arriving early")
    static let voDrift = String(localized: "something is drifting in")

    static func kicker(countryName: String?) -> String {
        guard let countryName, !countryName.isEmpty else { return "from a dino far away" }
        return "from a dino in \(countryName)"
    }

    /// "4,000 miles · just for you" — km for metric locales, warm fallback
    /// when the distance is unknowable.
    static func distanceLine(kilometers: Double?, metric: Bool) -> String {
        guard let km = kilometers, km > 0 else { return "a long way · just for you" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if metric {
            let rounded = (km / 100).rounded() * 100
            let n = formatter.string(from: NSNumber(value: rounded)) ?? "\(Int(rounded))"
            return "\(n) km · just for you"
        } else {
            let miles = km * 0.621371
            let rounded = (miles / 100).rounded() * 100
            let n = formatter.string(from: NSNumber(value: rounded)) ?? "\(Int(rounded))"
            return "\(n) miles · just for you"
        }
    }

    static var allFixedStrings: [String] {
        [loggedLine, hoverTitle, hoverSub, tapToOpen, keepButton, reportLink,
         keptCaption, jarStackLine, voHush, voDrift,
         kicker(countryName: nil), kicker(countryName: "japan"),
         distanceLine(kilometers: nil, metric: false),
         distanceLine(kilometers: 6400, metric: false),
         distanceLine(kilometers: 6400, metric: true)]
    }
}

// MARK: - Country distance (great-circle over the world anchors)

enum CeremonyDistance {
    /// Great-circle km between two country codes via countryAnchors.json
    /// centroids (first anchor per country). Nil when either is unknown —
    /// callers fall back to the warm line.
    static func kilometers(from: String, to: String) -> Double? {
        guard let a = anchor(for: from), let b = anchor(for: to) else { return nil }
        return haversineKm(lat1: a.0, lon1: a.1, lat2: b.0, lon2: b.1)
    }

    static func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

    private static var anchors: [String: (Double, Double)] = {
        guard let url = Bundle.main.url(forResource: "countryAnchors", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [[Double]]] else { return [:] }
        var out: [String: (Double, Double)] = [:]
        for (code, list) in raw where list.first?.count == 2 {
            out[code] = (list[0][0], list[0][1])
        }
        return out
    }()

    private static func anchor(for code: String) -> (Double, Double)? {
        anchors[code.uppercased()]
    }
}

// MARK: - Post-log stack planner (the priority contract, testable)

enum PostLogStack {
    enum Element: Equatable { case ceremony, siriReturn, supportRow, shareRow, comfortSlip }

    /// The ceremony headlines when a lantern is available; every existing row
    /// keeps its order after it. Support still beats the comfort slip — a
    /// heavy stretch day shows the support row AFTER the ceremony completes,
    /// never buried.
    static func plan(lanternAvailable: Bool,
                     siriReturn: Bool,
                     supportEligible: Bool,
                     shareEligible: Bool,
                     recAvailable: Bool) -> [Element] {
        var out: [Element] = []
        if lanternAvailable { out.append(.ceremony) }
        if siriReturn { out.append(.siriReturn) }
        if supportEligible { out.append(.supportRow) }
        if shareEligible { out.append(.shareRow) }
        if recAvailable && !supportEligible { out.append(.comfortSlip) }
        return out
    }
}
