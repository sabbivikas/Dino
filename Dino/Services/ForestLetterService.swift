//
//  ForestLetterService.swift
//  Dino
//
//  Generates and caches a daily "forest letter" via OpenAI. Falls back to a
//  static line on any failure so the experience never breaks. The letter
//  can be saved into the user's gratitude jar from the ambient screen.
//

import Foundation

struct ForestDailyLetter: Codable {
    let date: String           // yyyy-MM-dd, the local-day the letter belongs to
    let content: String
    var savedToJar: Bool
}

actor ForestLetterService {
    static let shared = ForestLetterService()
    private init() {}

    private let cacheKey = "dino.forestDailyLetter"

    private static let fallbackContent =
        "the water has been here longer than your worries. it does not rush. it does not stop. it simply finds its way. so will you."

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

    /// Calls OpenAI's Chat Completions API. On any error, returns the
    /// fallback line so the UI always has something to render.
    func generateLetter() async -> String {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !apiKey.isEmpty,
              let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return Self.fallbackContent
        }

        let (weekday, monthName) = Self.weekdayAndMonth()
        let systemPrompt = "You are the forest. Write one short daily letter to someone who visits a quiet waterfall to find peace. Connect nature with mental health in a warm poetic way. Write in lowercase. Never use dashes. Keep under 150 words. No greeting or sign off. Just the letter body. Make each day feel completely different."
        let userPrompt = "Write today's forest letter. Today is \(weekday), \(monthName)."

        let body: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 200,
            "temperature": 0.9,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 25

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return Self.fallbackContent
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return Self.fallbackContent
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

    nonisolated private static func weekdayAndMonth() -> (String, String) {
        let wd = DateFormatter()
        wd.dateFormat = "EEEE"
        let mo = DateFormatter()
        mo.dateFormat = "MMMM"
        let now = Date()
        return (wd.string(from: now), mo.string(from: now))
    }
}
