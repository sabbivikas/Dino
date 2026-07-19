//
//  BreathingPattern.swift
//  Dino
//

import SwiftUI

/// One step of a breathing cycle. Scale/opacity targets are in the
/// view model's circle space (0.6 rest … 1.15 fullest breath).
struct BreathStep: Equatable {
    enum Kind: String {
        case inhale, hold, exhale
    }

    /// How the circle moves through this step.
    enum Curve: Equatable {
        case gentle        // easeInOut, the default breath
        case lift          // quicker, lighter easeOut for the sigh's top up inhale
        case release       // long decelerating curve for the sigh's big exhale
        case wave          // sinusoidal, zero velocity only at the crests, no seams

        func animation(seconds: Int) -> Animation {
            let d = Double(seconds)
            switch self {
            case .gentle:  return .easeInOut(duration: d)
            case .lift:    return .easeOut(duration: d)
            case .release: return .timingCurve(0.16, 1.0, 0.35, 1.0, duration: d)
            case .wave:    return .timingCurve(0.37, 0.0, 0.63, 1.0, duration: d)
            }
        }
    }

    let kind: Kind
    let label: String        // circle label while the step runs
    let shortLabel: String   // timing row: "in", "top up", "hold", "out", "rest"
    let seconds: Int
    let targetScale: CGFloat
    let targetOpacity: Double
    let curve: Curve
}

struct BreathingPattern: Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    let accentHex: String
    let steps: [BreathStep]
    let closingLine: String
    /// sleepy cloud: the long hold gently pulses opacity so it never feels frozen
    let shimmersOnHold: Bool
    /// steady square: hold countdown ticks in four quarter arcs around the circle
    let quarterTickHolds: Bool
    /// big sigh: the mid ring thins slightly as the breath empties
    let thinsOnExhale: Bool

    var accent: Color { Color(hex: accentHex) }
    var shortName: String { name.hasPrefix("the ") ? String(name.dropFirst(4)) : name }
    var cycleLength: Int { steps.reduce(0) { $0 + $1.seconds } }
    var timingSummary: String { steps.map { String($0.seconds) }.joined(separator: " · ") }

    /// Closest whole number of breaths to the requested length — a session
    /// always ends on a completed cycle, never mid exhale.
    func totalCycles(for requestedSeconds: Int) -> Int {
        guard cycleLength > 0 else { return 1 }
        return max(1, Int((Double(requestedSeconds) / Double(cycleLength)).rounded()))
    }

    func plannedDuration(for requestedSeconds: Int) -> Int {
        totalCycles(for: requestedSeconds) * cycleLength
    }
}

// MARK: - Library

extension BreathingPattern {
    // Accents come from the locked palette: rose, obLavender, sageDeep, world gold.

    static let bigSigh = BreathingPattern(
        id: "big-sigh",
        name: String(localized: "the big sigh"),
        tagline: String(localized: "two sips of air, one long letting go"),
        accentHex: "#E8889A",
        steps: [
            BreathStep(kind: .inhale, label: String(localized: "breathe in"), shortLabel: String(localized: "in"), seconds: 4, targetScale: 0.9, targetOpacity: 0.95, curve: .gentle),
            BreathStep(kind: .inhale, label: String(localized: "a little more"), shortLabel: String(localized: "top up"), seconds: 2, targetScale: 1.15, targetOpacity: 1.0, curve: .lift),
            BreathStep(kind: .exhale, label: String(localized: "let it all out"), shortLabel: String(localized: "out"), seconds: 6, targetScale: 0.6, targetOpacity: 0.85, curve: .release)
        ],
        closingLine: String(localized: "you let it all out. lighter now 🌿"),
        shimmersOnHold: false,
        quarterTickHolds: false,
        thinsOnExhale: true
    )

    static let sleepyCloud = BreathingPattern(
        id: "sleepy-cloud",
        name: String(localized: "the sleepy cloud"),
        tagline: String(localized: "the 4 7 8, for drifting off"),
        accentHex: "#C4B8D4",
        steps: [
            BreathStep(kind: .inhale, label: String(localized: "breathe in"), shortLabel: String(localized: "in"), seconds: 4, targetScale: 1.1, targetOpacity: 1.0, curve: .gentle),
            BreathStep(kind: .hold, label: String(localized: "hold, softly"), shortLabel: String(localized: "hold"), seconds: 7, targetScale: 1.1, targetOpacity: 1.0, curve: .gentle),
            BreathStep(kind: .exhale, label: String(localized: "breathe out"), shortLabel: String(localized: "out"), seconds: 8, targetScale: 0.6, targetOpacity: 0.85, curve: .gentle)
        ],
        closingLine: String(localized: "the night can hold you now 🌙"),
        shimmersOnHold: true,
        quarterTickHolds: false,
        thinsOnExhale: false
    )

    static let steadySquare = BreathingPattern(
        id: "steady-square",
        name: String(localized: "the steady square"),
        tagline: String(localized: "four counts, four sides, steady"),
        accentHex: "#7BA872",
        steps: [
            BreathStep(kind: .inhale, label: String(localized: "breathe in"), shortLabel: String(localized: "in"), seconds: 4, targetScale: 1.1, targetOpacity: 1.0, curve: .gentle),
            BreathStep(kind: .hold, label: String(localized: "hold"), shortLabel: String(localized: "hold"), seconds: 4, targetScale: 1.1, targetOpacity: 1.0, curve: .gentle),
            BreathStep(kind: .exhale, label: String(localized: "breathe out"), shortLabel: String(localized: "out"), seconds: 4, targetScale: 0.6, targetOpacity: 0.85, curve: .gentle),
            BreathStep(kind: .hold, label: String(localized: "rest"), shortLabel: String(localized: "rest"), seconds: 4, targetScale: 0.6, targetOpacity: 0.85, curve: .gentle)
        ],
        closingLine: String(localized: "your heart found its square 💚"),
        shimmersOnHold: false,
        quarterTickHolds: true,
        thinsOnExhale: false
    )

    static let calmCurrent = BreathingPattern(
        id: "calm-current",
        name: String(localized: "the calm current"),
        tagline: String(localized: "no holds, just slow waves"),
        accentHex: "#FFE066",
        steps: [
            BreathStep(kind: .inhale, label: String(localized: "breathe in"), shortLabel: String(localized: "in"), seconds: 5, targetScale: 1.1, targetOpacity: 1.0, curve: .wave),
            BreathStep(kind: .exhale, label: String(localized: "breathe out"), shortLabel: String(localized: "out"), seconds: 5, targetScale: 0.6, targetOpacity: 0.85, curve: .wave)
        ],
        closingLine: String(localized: "steady as the tide 🌊"),
        shimmersOnHold: false,
        quarterTickHolds: false,
        thinsOnExhale: false
    )

    static let library: [BreathingPattern] = [bigSigh, sleepyCloud, steadySquare, calmCurrent]
}
