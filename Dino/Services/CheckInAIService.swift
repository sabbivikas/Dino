//
//  CheckInAIService.swift
//  Dino
//

import Foundation

enum CheckInAIError: LocalizedError {
    case missingKey
    case requestFailed(Int)
    case decodeFailed
    case empty

    var errorDescription: String? {
        switch self {
        case .missingKey:      return "ai is offline right now. add an openai key to enable the weekly report."
        case .requestFailed(let code): return "couldn't reach the ai (\(code)). try again in a moment."
        case .decodeFailed:    return "couldn't read the ai response. try again."
        case .empty:           return "no response from ai. try again."
        }
    }
}

@MainActor
final class CheckInAIService {
    static let shared = CheckInAIService()

    // Key is read from LocalSecrets.openAIKey — that file is intended to be
    // edited locally and ignored via `git update-index --skip-worktree`.
    private let apiKey = LocalSecrets.openAIKey

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o"

    func generateReport(
        weekNumber: Int,
        dateRange: String,
        questions: [CheckInQuestion],
        answers: [Int],
        previous: WeeklyCheckInResult?
    ) async throws -> WeeklyReport {
        let key = effectiveKey()
        guard !key.isEmpty else { throw CheckInAIError.missingKey }

        let system = """
        you are dino, a warm, grounded mental-health companion inside a wellness app.
        you write short, gentle, second-person reflections — never clinical, never alarming.
        you NEVER diagnose. you frame everything as a personal reflection, not medical advice.
        respond with a single JSON object that exactly matches the schema requested.
        all string values must be lowercase and in dino's warm, lowercase voice.
        """

        let user = buildUserPrompt(
            weekNumber: weekNumber,
            dateRange: dateRange,
            questions: questions,
            answers: answers,
            previous: previous
        )

        let payload: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "temperature": 0.6,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        req.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw CheckInAIError.empty }
        guard (200..<300).contains(http.statusCode) else {
            throw CheckInAIError.requestFailed(http.statusCode)
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let chat = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = chat.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw CheckInAIError.decodeFailed
        }
        guard let report = try? JSONDecoder().decode(WeeklyReport.self, from: contentData) else {
            throw CheckInAIError.decodeFailed
        }
        return report
    }

    // MARK: - Helpers

    private func effectiveKey() -> String {
        if !apiKey.isEmpty { return apiKey }
        return Self.config("OPENAI_API_KEY", fallback: "")
    }

    private static func config(_ key: String, fallback: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.hasPrefix("$(") else {
            return fallback
        }
        return value
    }

    private func buildUserPrompt(
        weekNumber: Int,
        dateRange: String,
        questions: [CheckInQuestion],
        answers: [Int],
        previous: WeeklyCheckInResult?
    ) -> String {
        var lines: [String] = []
        lines.append("week \(weekNumber), \(dateRange)")
        lines.append("")
        lines.append("answers (option indices map to: 0=not at all, 1=several days, 2=more than half, 3=nearly every day):")
        for (i, q) in questions.enumerated() {
            let raw = answers.indices.contains(i) ? answers[i] : 0
            let opt = AnswerOption(rawValue: raw) ?? .notAtAll
            lines.append("\(i + 1). [\(q.category.rawValue)] \(q.text) — \(opt.label)")
        }

        // Raw subscale sums using the brief's denominators.
        let phqSum = sumFor(.phq9, questions: questions, answers: answers)
        let gadSum = sumFor(.gad7, questions: questions, answers: answers)
        let whoSum = sumFor(.who5, questions: questions, answers: answers)
        let pssSum = sumFor(.pss,  questions: questions, answers: answers)

        lines.append("")
        lines.append("subscale raw scores this week:")
        lines.append("- phq-9 (depression signal): \(phqSum)/27 (higher = more symptoms)")
        lines.append("- gad-7 (anxiety signal): \(gadSum)/21 (higher = more symptoms)")
        lines.append("- who-5 (well-being): \(whoSum)/20 (higher = more well-being)")
        lines.append("- pss (perceived stress): \(pssSum)/16 (higher = more stress)")

        if let prev = previous {
            lines.append("")
            lines.append("previous week (week \(prev.weekNumber)) overall score: \(prev.report.overallScore)/100")
            lines.append("previous trend: \(prev.report.trend)")
        }

        lines.append("")
        lines.append("""
        respond with a JSON object exactly matching this schema (no extra keys):
        {
          "overallScore": int 0-100 (higher = doing better),
          "overallLabel": short lowercase phrase like "doing well" / "holding steady" / "needs care",
          "overallEmoji": single emoji that matches the label,
          "moodEnergyScore": int 0-100,
          "moodEnergyInsight": 2-3 sentence lowercase reflection on mood and energy,
          "anxietyStressScore": int 0-100 (higher = calmer),
          "anxietyStressInsight": 2-3 sentence lowercase reflection on anxiety and stress,
          "wellbeingScore": int 0-100,
          "wellbeingInsight": 2-3 sentence lowercase reflection on overall well-being,
          "weeklyReflection": one warm paragraph (4-6 sentences) reflecting on the week,
          "trend": one of "improved" / "stable" / "needs attention",
          "trendNote": short lowercase sentence explaining the trend
        }
        """)
        return lines.joined(separator: "\n")
    }

    private func sumFor(_ category: CheckInCategory, questions: [CheckInQuestion], answers: [Int]) -> Int {
        var total = 0
        for (i, q) in questions.enumerated() where q.category == category {
            total += answers.indices.contains(i) ? answers[i] : 0
        }
        return total
    }
}
