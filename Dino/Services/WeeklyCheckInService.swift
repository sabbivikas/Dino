//
//  WeeklyCheckInService.swift
//  Dino
//
//  NEVER throws. Always returns a WeeklyReport — real one if the
//  `generateWeeklyReport` Firebase Cloud Function succeeds, mock report on
//  any failure path (and the mock is flagged with `isMock: true` so the UI
//  can show an "offline summary" badge).
//

import Foundation
import FirebaseFunctions

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
        let qaPayload: [[String: Any]] = questionsAndAnswers.map { qa in
            ["question": qa.0, "score": qa.1]
        }
        let prevPayload: [[String: Any]] = (previousScores ?? [:]).map { kv in
            ["key": kv.key, "score": kv.value]
        }

        do {
            let functions = Functions.functions(region: "us-central1")
            let callable = functions.httpsCallable("generateWeeklyReport")
            let result = try await callable.call([
                "weekNumber": weekNumber,
                "dateRange": dateRange,
                "questionsAndAnswers": qaPayload,
                "previousScores": prevPayload
            ])

            guard let data = result.data as? [String: Any],
                  let reportDict = data["report"] as? [String: Any] else {
                #if DEBUG
                print("\u{1F995} WeeklyCheckInService: malformed response — falling back to mock")
                #endif
                return mockReport()
            }

            // Round-trip the dictionary through JSONSerialization —> JSONDecoder so
            // we get a real WeeklyReport with full Codable validation.
            let jsonData = try JSONSerialization.data(withJSONObject: reportDict)
            var report = try JSONDecoder().decode(WeeklyReport.self, from: jsonData)
            // Real report from the function — force isMock = nil so the badge
            // doesn't appear even if upstream included a stale key.
            report.isMock = nil
            return report
        } catch {
            #if DEBUG
            print("\u{1F995} WeeklyCheckInService Cloud Function error — falling back to mock: \(error)")
            #endif
            return mockReport()
        }
    }

    private static let systemPrompt = """
    You are Dino, a warm and empathetic mental wellness companion. You analyze weekly mental health check-in responses and generate caring, insightful wellness reports. Your tone is warm, personal, and encouraging \u{2014} never clinical or alarming. Always remind users this is a reflection tool not a diagnosis.
    """

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
            trendNote: "\u{2191} improved from last week",
            isMock: true
        )
    }
}
