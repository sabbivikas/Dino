//
//  NudgeGeneratorService.swift
//  Dino
//
//  Generates push-notification copy via OpenAI, cached per category for 7 days.
//  NEVER throws — falls back to NudgeLibrary on any failure path.
//

import Foundation

@MainActor
final class NudgeGeneratorService {
    static let shared = NudgeGeneratorService()
    private init() {}

    private let cacheKeyPrefix = "dino.cachedNudges"
    private let cacheExpiryKeyPrefix = "dino.nudgeCacheExpiry"

    /// Returns a nudge for the given category. Uses cache if fresh (≤7 days),
    /// otherwise calls OpenAI and caches the result. NEVER throws — falls back
    /// to NudgeLibrary on any failure path.
    func getNudge(for category: String) async -> String {
        if let cached = getCachedNudges(for: category), !cached.isEmpty {
            return cached.randomElement() ?? fallback(for: category)
        }
        let nudges = await generateNudges(for: category)
        cacheNudges(nudges, for: category)
        return nudges.randomElement() ?? fallback(for: category)
    }

    private func generateNudges(for category: String) async -> [String] {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !apiKey.isEmpty, !apiKey.hasPrefix("$(") else {
            #if DEBUG
            print("[Nudge] no OPENAI_API_KEY — falling back to static library for \(category)")
            #endif
            return NudgeLibrary.fallbacks(for: category)
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return NudgeLibrary.fallbacks(for: category)
        }

        let userPrompt = """
        Generate 5 short push notification messages for a wellness app called Dino.
        Category: \(category)

        Tone: gen z, warm, empathetic, like a caring friend texting you. no corporate language. no em-dashes. lowercase. max 60 characters each. use 1 emoji per message.

        Categories and context:
        - drinkWater: remind user to drink water, time neutral, works any time of day
        - eatSomething: remind user to eat, time neutral, not meal specific
        - dailyCheckIn: ask how user is doing today, invite them to check in
        - streakReminder: encourage user to keep their streak alive
        - windDown: gentle reminder to rest and wind down
        - rest: encourage user to take a real break
        - checkInWithYourself: prompt user to pause and reflect
        - plantDying: user's growth garden plant needs attention
        - plantBlooming: celebrate user's plant blooming
        - plantProgressing: celebrate growth milestone

        Return a JSON object with a 'nudges' array of 5 strings. No markdown, no explanation.
        Example: {"nudges":["message 1","message 2","message 3","message 4","message 5"]}
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": "You generate push notification copy. Return only valid JSON with a 'nudges' array of 5 strings."],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 300
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return NudgeLibrary.fallbacks(for: category)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                #if DEBUG
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[Nudge] OpenAI HTTP \(code) for \(category) — falling back")
                #endif
                return NudgeLibrary.fallbacks(for: category)
            }
            struct ChatResp: Decodable {
                struct Choice: Decodable { struct M: Decodable { let content: String }; let message: M }
                let choices: [Choice]
            }
            guard let chat = try? JSONDecoder().decode(ChatResp.self, from: data),
                  let content = chat.choices.first?.message.content,
                  let contentData = content.data(using: .utf8) else {
                return NudgeLibrary.fallbacks(for: category)
            }

            struct NudgesPayload: Decodable { let nudges: [String] }
            if let payload = try? JSONDecoder().decode(NudgesPayload.self, from: contentData),
               !payload.nudges.isEmpty {
                #if DEBUG
                print("[Nudge] generated \(payload.nudges.count) for \(category)")
                #endif
                return payload.nudges
            }
            return NudgeLibrary.fallbacks(for: category)
        } catch {
            #if DEBUG
            print("[Nudge] network error for \(category): \(error)")
            #endif
            return NudgeLibrary.fallbacks(for: category)
        }
    }

    private func getCachedNudges(for category: String) -> [String]? {
        let expiryKey = "\(cacheExpiryKeyPrefix).\(category)"
        let dataKey = "\(cacheKeyPrefix).\(category)"
        guard let expiry = UserDefaults.standard.object(forKey: expiryKey) as? Date,
              expiry > Date(),
              let data = UserDefaults.standard.data(forKey: dataKey),
              let nudges = try? JSONDecoder().decode([String].self, from: data),
              !nudges.isEmpty else {
            return nil
        }
        return nudges
    }

    private func cacheNudges(_ nudges: [String], for category: String) {
        guard let expiry = Calendar.current.date(byAdding: .day, value: 7, to: Date()) else {
            return
        }
        UserDefaults.standard.set(expiry, forKey: "\(cacheExpiryKeyPrefix).\(category)")
        if let data = try? JSONEncoder().encode(nudges) {
            UserDefaults.standard.set(data, forKey: "\(cacheKeyPrefix).\(category)")
        }
    }

    private func fallback(for category: String) -> String {
        NudgeLibrary.fallbacks(for: category).randomElement() ?? "hey, dino is checking on you 🦕"
    }
}
