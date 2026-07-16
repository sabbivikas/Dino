//
//  SiriVoice.swift
//  Dino
//
//  Pure copy + mapping for the siri intents — no AppIntents import, fully
//  unit-testable. Principle: siri is the doorbell, not the dino. capture or
//  open, one warm spoken line, done — no conversation, ever.
//
//  Voice rules: lowercase, no dashes, under ~8 words, and every SPOKEN line
//  carries its warmth in words alone (siri won't speak an emoji).
//

import Foundation

// MARK: - Fuzzy mood matching (owner-approved table 2026-07-09)

enum MoodSynonyms {

    static let table: [(weather: EmotionalWeather, synonyms: [String])] = [
        (.drained, ["drained", "exhausted", "tired", "dead", "done", "empty", "wiped",
                    "wiped out", "burnt out", "burned out", "low", "heavy", "worn out",
                    "spent", "running on empty", "drowsy", "sad"]),   // "sad" added by owner
        (.overwhelmed, ["overwhelmed", "anxious", "stressed", "stressed out", "panicky",
                        "panicked", "too much", "frazzled", "swamped", "drowning",
                        "on edge", "wound up", "nervous", "overloaded", "freaking out"]),
        // owner flag: nervous→overwhelmed is the most aggressive mapping —
        // shipping as approved; revisit if disambiguation data shows regret.
        (.partlyCloudy, ["okay", "ok", "fine", "meh", "so so", "mixed", "cloudy", "gray",
                         "blah", "alright", "up and down", "not sure", "unsure",
                         "average", "in between", "partly cloudy"]),
        (.clear, ["good", "great", "happy", "clear", "sunny", "bright", "light",
                  "wonderful", "calm", "peaceful", "content", "amazing", "lovely", "better"]),
    ]

    /// The donated synonyms for one mood family — fed to the AppEntity's
    /// DisplayRepresentation so "i'm feeling exhausted" matches INLINE in the
    /// trigger phrase, not just at the prompt. (Excludes the canonical label
    /// itself, which the title already covers.)
    static func synonyms(for weather: EmotionalWeather) -> [String] {
        table.first { $0.weather == weather }?.synonyms
            .filter { $0 != weather.label } ?? []
    }

    /// Case/punctuation-insensitive, with soft prefixes ("i'm feeling", "so",
    /// "really"…) stripped. Exact match after normalization; nil → siri asks
    /// once with the four options.
    static func match(_ raw: String) -> EmotionalWeather? {
        // apostrophes vanish (i'm → im); other punctuation becomes space
        var s = raw.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
            .map { $0.isLetter || $0.isWhitespace ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ").joined(separator: " ")

        func lookup(_ value: String) -> EmotionalWeather? {
            table.first { $0.synonyms.contains(value) }?.weather
        }

        // try the whole phrase FIRST — stripping must never eat a synonym
        // that happens to start with a soft prefix ("so so")
        if let hit = lookup(s) { return hit }

        let prefixes = ["i am feeling", "im feeling", "i feel", "feeling", "i am", "im",
                        "really", "very", "so", "kind of", "kinda", "a bit", "a little", "pretty"]
        var stripped = true
        while stripped {
            stripped = false
            for p in prefixes where s.hasPrefix(p + " ") {
                s = String(s.dropFirst(p.count + 1))
                if let hit = lookup(s) { return hit }
                stripped = true
            }
        }
        return nil
    }
}

// MARK: - Spoken replies (owner-approved verbatim 2026-07-09)

enum SiriReplies {

    static let drainedLines = [
        String(localized: "kept. be gentle with yourself."),
        String(localized: "kept. rest is allowed."),
        String(localized: "kept. that took something to say."),
    ]
    static let overwhelmedLines = [
        String(localized: "kept. one breath at a time."),
        String(localized: "kept. you don't have to hold it all."),
        String(localized: "kept. i'm here."),
    ]
    static let partlyCloudyLines = [
        String(localized: "kept. clouds pass."),
        String(localized: "kept. thanks for checking in."),
    ]
    static let clearLines = [
        String(localized: "kept. glad the sky is clear."),
        String(localized: "kept. enjoy the light."),
    ]

    /// Deterministic rotation (log-count modulo) — never repeats twice in a row.
    static func moodLine(for weather: EmotionalWeather, rotation: Int) -> String {
        let lines: [String]
        switch weather {
        case .drained:      lines = drainedLines
        case .overwhelmed:  lines = overwhelmedLines
        case .partlyCloudy: lines = partlyCloudyLines
        case .clear:        lines = clearLines
        }
        return lines[abs(rotation) % lines.count]
    }

    // journal — the 2am whisper is the north star: soft, final, no follow-ups
    static let journalNightLine = "kept. sleep well."
    static let journalDayLine = "kept. it's safe here."   // owner tweak: no self-reference

    /// night = 21:00 through 04:59
    static func isNight(hour: Int) -> Bool {
        hour >= 21 || hour < 5
    }

    static func journalLine(hour: Int) -> String {
        isNight(hour: hour) ? journalNightLine : journalDayLine
    }

    static let gratitudeLines = [
        String(localized: "kept. that's a good one."),
        String(localized: "kept. the jar is a little fuller."),
    ]
    static func gratitudeLine(rotation: Int) -> String {
        gratitudeLines[abs(rotation) % gratitudeLines.count]
    }

    static let disambiguationPrompt =
        "how's the weather inside? clear, partly cloudy, overwhelmed, or drained?"

    /// Soft failure when the captured text is empty — final, never a question.
    static let emptyCaptureLine = "i didn't catch anything to keep."

    /// Next app open after a siri-logged mood.
    static func returnLine(weekday: String) -> String {
        "while you were away, i kept your \(weekday.lowercased()) 🌿"
    }
}

// MARK: - Return moment (storage — kept out of the pure logic above)

enum SiriReturnMoment {
    static let key = "dino.siri.pendingReturnAt"

    @MainActor
    static func stamp(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: key)
    }

    /// Returns the weekday line to show (and clears the stamp) — once only.
    @MainActor
    static func consume(calendar: Calendar = .current) -> String? {
        guard let at = UserDefaults.standard.object(forKey: key) as? Date else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.dateFormat = "EEEE"
        return SiriReplies.returnLine(weekday: df.string(from: at))
    }
}
