//
//  WeeklyCheckInModels.swift
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
    /// True when the report was generated from the local fallback instead of
    /// the Cloud Function. Optional so older persisted reports still decode.
    var isMock: Bool? = nil
}

struct WeeklyCheckInResult: Codable, Identifiable, Equatable {
    let id: UUID
    let weekNumber: Int
    let year: Int
    let dateRange: String
    let completedAt: Date
    let report: WeeklyReport
}
