//
//  WeeklyCheckInResult.swift
//  Dino
//

import Foundation

struct WeeklyReport: Codable, Equatable {
    let overallScore: Int
    let overallLabel: String
    let overallEmoji: String
    let moodEnergyScore: Int
    let moodEnergyInsight: String
    let anxietyStressScore: Int
    let anxietyStressInsight: String
    let wellbeingScore: Int
    let wellbeingInsight: String
    let weeklyReflection: String
    let trend: String
    let trendNote: String
}

struct WeeklyCheckInResult: Codable, Identifiable, Equatable {
    let id: UUID
    let weekNumber: Int
    let year: Int
    let dateRange: String
    let questions: [String]
    let answers: [Int]
    let report: WeeklyReport
    let completedAt: Date

    init(id: UUID = UUID(),
         weekNumber: Int,
         year: Int,
         dateRange: String,
         questions: [String],
         answers: [Int],
         report: WeeklyReport,
         completedAt: Date = Date()) {
        self.id = id
        self.weekNumber = weekNumber
        self.year = year
        self.dateRange = dateRange
        self.questions = questions
        self.answers = answers
        self.report = report
        self.completedAt = completedAt
    }
}
