//
//  ThemeTag.swift
//  Dino
//
//  A structured "theme" extracted ONCE by GPT at write time (from a break-finder
//  message, or — opt-in — a journal entry) and stored locally forever. The raw
//  user text is NEVER stored here; only the enum-like theme, the day, a mood
//  snapshot, and the source. PatternEngine crunches these locally, statistically.
//

import Foundation

struct ThemeTag: Codable, Identifiable {
    var id: UUID
    var date: Date
    var theme: String     // one of ThemeTag.validThemes (never "none" — not stored)
    var mood: String      // EmotionalWeather.rawValue snapshot at tag time (may be "")
    var source: String    // "breakfinder" | "journal"

    init(id: UUID = UUID(),
         date: Date = Date(),
         theme: String,
         mood: String = "",
         source: String) {
        self.id = id
        self.date = date
        self.theme = theme
        self.mood = mood
        self.source = source
    }

    /// The six life-area themes. "none" is intentionally excluded — an unclear
    /// or absent theme is simply not recorded.
    static let validThemes: Set<String> = [
        "work", "sleep", "relationships", "health", "money", "self"
    ]
    static func isValid(_ theme: String) -> Bool { validThemes.contains(theme) }

    static let sourceBreakFinder = "breakfinder"
    static let sourceJournal = "journal"
}
