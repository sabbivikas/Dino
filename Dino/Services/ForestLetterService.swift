//
//  ForestLetterService.swift
//  Dino
//
//  Generates and caches a daily "forest letter" via OpenAI. Falls back to a
//  static line on any failure so the experience never breaks. The letter
//  can be saved into the user's gratitude jar from the ambient screen.
//

import Foundation
import FirebaseFunctions

struct ForestDailyLetter: Codable {
    let date: String           // yyyy-MM-dd, the local-day the letter belongs to
    let content: String
    var savedToJar: Bool
}

actor ForestLetterService {
    static let shared = ForestLetterService()
    private init() {}

    private let cacheKey = "dino.forestDailyLetter"

    private static let fallbackLetter = """
        the water has been here longer than your worries. it does not rush. it does not stop. it simply finds its way. so will you.
        """

    // MARK: - Public API

    /// Returns today's letter, using the cache when available.
    /// Calls the model once per local day; subsequent calls hit the cache.
    func getTodaysLetter() async -> ForestDailyLetter {
        let today = Self.todayString()
        if let cached = loadCached(), cached.date == today {
            return cached
        }
        let content = await generateLetter()
        let letter = ForestDailyLetter(date: today, content: content, savedToJar: false)
        saveCached(letter)
        return letter
    }

    /// Calls the `generateForestLetter` Firebase Cloud Function, which proxies
    /// the OpenAI Chat Completions request so the API key never ships in the
    /// app binary. On any failure, returns the fallback line so the UI is
    /// never empty.
    func generateLetter() async -> String {
        do {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            let weekday = weekdayFormatter.string(from: Date())

            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMMM"
            let monthName = monthFormatter.string(from: Date())

            let functions = Functions.functions(region: "us-central1")
            let callable = functions.httpsCallable("generateForestLetter")
            let result = try await callable.call([
                "weekday": weekday,
                "monthName": monthName
            ])

            if let data = result.data as? [String: Any],
               let content = data["content"] as? String,
               !content.isEmpty {
                return content
            }
            return Self.fallbackLetter
        } catch {
            #if DEBUG
            print("\u{1F33F} Forest letter error: \(error)")
            #endif
            return Self.fallbackLetter
        }
    }

    /// Inserts the letter into the gratitude jar (as a leaf-typed note) and
    /// flips the cached letter's `savedToJar` flag so it persists across
    /// app launches.
    func saveToGratitudeJar(_ letter: ForestDailyLetter) async {
        let payload = "from the forest: " + letter.content
        await MainActor.run {
            let note = GratitudeNote(
                id: UUID(),
                text: payload,
                createdAt: Date(),
                tokenType: "leaf"
            )
            SharedDataManager.shared.gratitudeNotes.insert(note, at: 0)
        }
        var updated = letter
        updated.savedToJar = true
        saveCached(updated)
    }

    // MARK: - Cache

    private func loadCached() -> ForestDailyLetter? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(ForestDailyLetter.self, from: data)
    }

    private func saveCached(_ letter: ForestDailyLetter) {
        guard let data = try? JSONEncoder().encode(letter) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    // MARK: - Date helpers

    nonisolated private static func todayString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: Date())
    }

}
