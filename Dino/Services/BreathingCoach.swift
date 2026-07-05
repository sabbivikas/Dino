//
//  BreathingCoach.swift
//  Dino
//
//  Pure logic for the adaptive breathing coach: feeling chips, the client
//  crisis keyword net, the deterministic fallback matcher, cache key
//  hashing, and the crisis resources. No networking, no UI — everything
//  here is unit-testable and works fully offline.
//

import SwiftUI
import CryptoKit

// MARK: - Feeling chips

enum BreathingFeeling: String, CaseIterable, Identifiable {
    case anxious, cantSleep, overwhelmed, cantFocus, panicky, restless, stressed, sad

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anxious: return "anxious"
        case .cantSleep: return "can't sleep"
        case .overwhelmed: return "overwhelmed"
        case .cantFocus: return "can't focus"
        case .panicky: return "panicky"
        case .restless: return "restless"
        case .stressed: return "stressed"
        case .sad: return "sad"
        }
    }

    /// Deterministic pattern + minutes for this chip (the client matcher).
    var mapping: (pattern: BreathingPattern, minutes: Int) {
        switch self {
        case .panicky:     return (.steadySquare, 3)
        case .cantSleep:   return (.sleepyCloud, 8)
        case .overwhelmed: return (.bigSigh, 3)
        case .sad:         return (.bigSigh, 3)
        case .anxious:     return (.bigSigh, 5)
        case .stressed:    return (.bigSigh, 5)
        case .cantFocus:   return (.calmCurrent, 5)
        case .restless:    return (.calmCurrent, 5)
        }
    }

    /// Multi-select priority: acute physiological need outranks ambient state.
    var priority: Int {
        switch self {
        case .panicky: return 0
        case .cantSleep: return 1
        case .overwhelmed: return 2
        case .sad: return 3
        case .anxious: return 4
        case .stressed: return 5
        case .cantFocus: return 6
        case .restless: return 7
        }
    }

    /// Chip accent = the accent of the pattern it routes to.
    var accent: Color { mapping.pattern.accent }
}

// MARK: - Recommendation

struct BreathingRecommendation: Equatable, Codable {
    let patternID: String     // BreathingPattern.id ("big-sigh" …)
    let minutes: Int
    let reason: String
    let concern: Bool
    let fromAI: Bool

    var pattern: BreathingPattern {
        BreathingPattern.library.first { $0.id == patternID } ?? .bigSigh
    }

    /// Concern can be raised, never lowered.
    func raisingConcern(_ flag: Bool) -> BreathingRecommendation {
        BreathingRecommendation(patternID: patternID, minutes: minutes,
                                reason: reason, concern: concern || flag, fromAI: fromAI)
    }
}

enum BreathingCoach {

    static let allowedMinutes = [1, 3, 5, 8, 10]
    static let fallbackReason = "a steady breath for a heavy moment 🌿"

    /// Coach wire format ("bigSigh") → library pattern. nil for anything else.
    static func pattern(forCoachID id: String) -> BreathingPattern? {
        switch id {
        case "bigSigh": return .bigSigh
        case "sleepyCloud": return .sleepyCloud
        case "steadySquare": return .steadySquare
        case "calmCurrent": return .calmCurrent
        default: return nil
        }
    }

    /// Nearest allowed duration; ties round down (gentler).
    static func clampMinutes(_ raw: Int) -> Int {
        allowedMinutes.min {
            (abs($0 - raw), $0) < (abs($1 - raw), $1)
        } ?? 5
    }

    /// Deterministic local recommendation — the whole flow when there's no
    /// free text, and the fallback when the API errors, times out, or caps.
    static func localRecommendation(chips: [BreathingFeeling], text: String) -> BreathingRecommendation {
        let concern = BreathingCrisisNet.isConcerning(text)

        if let lead = chips.min(by: { $0.priority < $1.priority }) {
            let (pattern, minutes) = lead.mapping
            return BreathingRecommendation(patternID: pattern.id, minutes: minutes,
                                           reason: localReason(for: lead),
                                           concern: concern, fromAI: false)
        }

        // free text only — lightweight keyword routing (mirrors the prompt map)
        let t = normalize(text)
        let route: (BreathingPattern, Int, String)
        if contains(t, ["sleep", "insomnia", "awake", "3am", "wind down", "bed"]) {
            route = (.sleepyCloud, 8, "let's slow everything down for sleep 🌙")
        } else if contains(t, ["panic", "racing", "heart", "attack", "shaking"]) {
            route = (.steadySquare, 3, "four steady sides to hold on to 💚")
        } else if contains(t, ["focus", "scattered", "foggy", "distracted", "concentrate"]) {
            route = (.calmCurrent, 5, "slow waves to gather your attention 🌊")
        } else if contains(t, ["overwhelmed", "too much", "heavy", "crying", "drained", "exhausted"]) {
            route = (.bigSigh, 3, "two sips of air, one long letting go 🌿")
        } else {
            route = (.bigSigh, 5, "a steady breath to soften the day 🌿")
        }
        return BreathingRecommendation(patternID: route.0.id, minutes: route.1,
                                       reason: route.2, concern: concern, fromAI: false)
    }

    private static func localReason(for chip: BreathingFeeling) -> String {
        switch chip {
        case .panicky:     return "four steady sides to hold on to 💚"
        case .cantSleep:   return "let's slow everything down for sleep 🌙"
        case .overwhelmed: return "two sips of air, one long letting go 🌿"
        case .sad:         return "a long soft exhale for a heavy heart 🌿"
        case .anxious:     return "the big sigh settles an anxious body 🌿"
        case .stressed:    return "let the exhale carry some of it away 🌿"
        case .cantFocus:   return "slow waves to gather your attention 🌊"
        case .restless:    return "steady water for restless energy 🌊"
        }
    }

    // MARK: Cache key (hashed — raw feeling text never touches disk)

    static func cacheKeyHash(chips: [BreathingFeeling], text: String, dayKey: String) -> String {
        let normalizedChips = chips.map(\.rawValue).sorted().joined(separator: ",")
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let raw = "\(dayKey)|\(normalizedChips)|\(normalizedText)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Text helpers

    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
        let mapped = lowered.map { ch -> Character in
            if ch.isLetter || ch.isNumber { return ch }
            return " "
        }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }

    private static func contains(_ normalized: String, _ needles: [String]) -> Bool {
        let padded = " " + normalized + " "
        return needles.contains { padded.contains(" " + $0 + " ") || normalized.contains($0 + " ") || normalized.hasSuffix($0) }
    }
}

// MARK: - Crisis keyword net (client detector #1 of 3)

/// SAFETY NET, not a guarantee. Tuned to over-trigger, never under-trigger,
/// and it can only RAISE concern — no code path anywhere downgrades a
/// detected signal. Keys on FIRST-PERSON self-harm phrases, not bare verbs:
/// "this deadline is killing me" must not trip it; "i want to kill myself"
/// must. Runs fully on-device before any network call, so the crisis UI
/// renders even with zero connectivity. Keep the phrase list in sync with
/// the server net in functions/src/index.ts.
enum BreathingCrisisNet {

    /// Multi-word phrases matched against normalized text (and a de-spaced
    /// variant to catch "k i l l m y s e l f" style obfuscation).
    static let phrases: [String] = [
        "kill myself", "killing myself", "killed myself",
        "end my life", "ending my life", "end it all", "ending it all",
        "want to die", "wanna die", "want to be dead",
        "wish i was dead", "wish i were dead",
        "better off dead", "better off without me",
        "self harm", "harm myself", "harming myself",
        "hurt myself", "hurting myself",
        "cut myself", "cutting myself",
        "no reason to live", "nothing to live for",
        "dont want to be here anymore", "dont want to be alive", "dont want to live",
        "cant go on", "cannot go on", "cant do this anymore",
        "want to disappear", "want to give up", "giving up on life", "ready to give up",
        "no point anymore", "no point in anything", "no point in living",
    ]

    /// Single words that are unambiguous on their own in a feelings box.
    static let words: Set<String> = ["suicide", "suicidal", "hopeless", "worthless", "kms"]

    static func isConcerning(_ text: String) -> Bool {
        let normalized = BreathingCoach.normalize(text)
        guard !normalized.isEmpty else { return false }

        let tokens = Set(normalized.split(separator: " ").map(String.init))
        if !words.isDisjoint(with: tokens) { return true }

        let padded = " " + normalized + " "
        if phrases.contains(where: { padded.contains(" " + $0 + " ") }) { return true }

        // de-spaced pass catches letter-spaced obfuscation
        let despaced = normalized.replacingOccurrences(of: " ", with: "")
        let despacedCore = ["killmyself", "endmylife", "wanttodie", "selfharm",
                            "hurtmyself", "cutmyself", "suicide", "suicidal"]
        return despacedCore.contains { despaced.contains($0) }
    }
}

// MARK: - Crisis resources (data, swappable by locale later)

/// TODO: locale-aware international resources are a REQUIRED fast-follow —
/// 988 and 741741 are US-only. The list is data so a locale table can
/// replace it without touching the crisis UI.
struct CrisisResource: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let actions: [(label: String, url: String)]

    static let usDefaults: [CrisisResource] = [
        CrisisResource(
            id: "lifeline-988",
            title: "call or text 988",
            subtitle: "suicide and crisis lifeline, free, any time",
            actions: [("call", "tel:988"), ("text", "sms:988")]
        ),
        CrisisResource(
            id: "crisis-text-line",
            title: "text HOME to 741741",
            subtitle: "crisis text line, a real human answers",
            actions: [("text", "sms:741741&body=HOME")]
        ),
    ]
}

enum BreathingCrisisCopy {
    static let heading = "it sounds like you're carrying something really heavy right now. you don't have to hold it alone."
    static let listeners = "people who care are ready to listen, any hour:"
    static let breathOffer = "and when you're ready, a gentle breath is here. no pressure. it will wait for you."
}
