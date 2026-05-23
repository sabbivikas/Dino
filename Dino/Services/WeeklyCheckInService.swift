//
//  WeeklyCheckInService.swift
//  Dino
//
//  NEVER throws. Always returns a WeeklyReport — real one if OpenAI succeeds,
//  mock report on any failure path.
//

import Foundation

@MainActor
final class WeeklyCheckInService {
    static let shared = WeeklyCheckInService()
    private init() {}

    func generateReport(
        weekNumber: Int,
        year: Int,
        dateRange: String,
        questionsAndAnswers: [(String, Int)],
        previousScores: [String: Int]? = nil
    ) async -> WeeklyReport {
        guard let apiKey = readAPIKey(), !apiKey.isEmpty else {
            #if DEBUG
            print("\u{1F995} WeeklyCheckInService: no OPENAI_API_KEY in Info.plist \u{2014} returning mock")
            #endif
            return mockReport()
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return mockReport()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userPrompt = buildPrompt(
            weekNumber: weekNumber,
            dateRange: dateRange,
            questionsAndAnswers: questionsAndAnswers,
            previousScores: previousScores
        )
        let body: [String: Any] = [
            "model": "gpt-4o",
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return mockReport()
        }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                #if DEBUG
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("\u{1F995} WeeklyCheckInService: HTTP \(code) \u{2014} falling back to mock")
                #endif
                return mockReport()
            }
            return decodeReport(from: data) ?? mockReport()
        } catch {
            #if DEBUG
            print("\u{1F995} WeeklyCheckInService: network error \(error.localizedDescription) \u{2014} falling back to mock")
            #endif
            return mockReport()
        }
    }

    private func readAPIKey() -> String? {
        guard let v = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !v.isEmpty, !v.hasPrefix("$(") else { return nil }
        return v
    }

    private static let systemPrompt = """
    You are Dino, a warm and empathetic mental wellness companion. You analyze weekly mental health check-in responses and generate caring, insightful wellness reports. Your tone is warm, personal, and encouraging \u{2014} never clinical or alarming. Always remind users this is a reflection tool not a diagnosis.
    """

    private func buildPrompt(
        weekNumber: Int,
        dateRange: String,
        questionsAndAnswers: [(String, Int)],
        previousScores: [String: Int]?
    ) -> String {
        var lines: [String] = []
        lines.append("A user completed their weekly mental health check-in (Week \(weekNumber), \(dateRange)). Here are their responses:")
        lines.append("")
        let labels = ["not at all", "several days", "more than half the days", "nearly every day"]
        for (i, qa) in questionsAndAnswers.enumerated() {
            let answerIdx = max(0, min(3, qa.1))
            lines.append("Q\(i + 1): \(qa.0)")
            lines.append("A: \(labels[answerIdx]) (\(answerIdx)/3)")
        }
        lines.append("")
        if let prev = previousScores, !prev.isEmpty {
            lines.append("Previous week scores: \(prev)")
        } else {
            lines.append("Previous week scores: none (first check-in)")
        }
        lines.append("")
        lines.append("""
        Return JSON with this exact shape:
        {
          "overallScore": number 0-100,
          "overallLabel": string,
          "overallEmoji": string,
          "moodEnergyScore": number 0-100,
          "moodEnergyInsight": string (2-3 warm sentences),
          "anxietyStressScore": number 0-100,
          "anxietyStressInsight": string (2-3 warm sentences),
          "wellbeingScore": number 0-100,
          "wellbeingInsight": string (2-3 warm sentences),
          "weeklyReflection": string (3-4 sentences),
          "trend": "improved" | "stable" | "needs attention",
          "trendNote": string (one short line)
        }
        """)
        return lines.joined(separator: "\n")
    }

    private func decodeReport(from data: Data) -> WeeklyReport? {
        struct ChatResp: Decodable {
            struct Choice: Decodable {
                struct M: Decodable { let content: String }
                let message: M
            }
            let choices: [Choice]
        }
        guard let chat = try? JSONDecoder().decode(ChatResp.self, from: data),
              let content = chat.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(WeeklyReport.self, from: contentData)
    }

    private func mockReport() -> WeeklyReport {
        WeeklyReport(
            overallScore: 72,
            overallLabel: "doing well this week",
            overallEmoji: "\u{1F33F}",
            moodEnergyScore: 82,
            moodEnergyInsight: "your energy levels were mostly stable this week. mornings seemed to be your strongest time.",
            anxietyStressScore: 64,
            anxietyStressInsight: "a couple of tense moments this week, but you handled them well.",
            wellbeingScore: 78,
            wellbeingInsight: "you showed up for yourself in small ways. that counts.",
            weeklyReflection: "hey you \u{2014} this week felt a little lighter than last, and that's worth sitting with. you noticed when things got heavy and reached for tools that work for you. that's not nothing.",
            trend: "improved",
            trendNote: "\u{2191} improved from last week"
        )
    }
}
