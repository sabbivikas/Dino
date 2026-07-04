//
//  ThemeExtractionService.swift
//  Dino
//
//  Opt-in journal theme extraction (DinoMind). Sends the entry text to the
//  extractJournalTheme cloud function ONLY when the user has enabled
//  "let dino learn from your journal". The text leaves the device solely for
//  this one classification call — never logged or stored — and only the enum
//  theme is kept as a ThemeTag.
//

import Foundation
import FirebaseFunctions

@MainActor
enum ThemeExtractionService {
    /// Returns a valid theme string, or nil for none / empty / failure.
    static func extractTheme(from text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("extractJournalTheme")
                .call(["text": String(trimmed.prefix(1000))])
            if let data = result.data as? [String: Any],
               let theme = data["theme"] as? String,
               ThemeTag.isValid(theme) {
                return theme
            }
        } catch {
            #if DEBUG
            print("🧠 theme extraction error: \(error)")
            #endif
            let ns = error as NSError
            AnalyticsManager.shared.trackThemeExtractionFailed(domain: ns.domain, code: ns.code)
        }
        return nil
    }
}
