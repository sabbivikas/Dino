//
//  MoodViewModel.swift
//  Dino
//

import SwiftUI
import Combine
import PostHog

@MainActor
class MoodViewModel: ObservableObject {
    @Published var selectedWeather: EmotionalWeather? = nil
    @Published var energyLevel: Double = 5
    @Published var intensityLevel: Double = 5
    @Published var saved: Bool = false

    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
    }

    var weeklyEntries: [MoodEntry] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        return dataManager.moodEntries.filter { $0.date >= sevenDaysAgo }
    }

    var last7Days: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: -6 + $0, to: calendar.startOfDay(for: Date()))
        }
    }

    func moodForDay(_ date: Date) -> EmotionalWeather? {
        let calendar = Calendar.current
        return dataManager.moodEntries.first(where: {
            calendar.isDate($0.date, inSameDayAs: date)
        })?.weatherType
    }

    func saveMood() {
        guard let weather = selectedWeather else { return }
        let entry = MoodEntry(
            weatherType: weather,
            energyLevel: Int(energyLevel.rounded()),
            intensityLevel: Int(intensityLevel.rounded())
        )
        dataManager.logMood(entry)
        AnalyticsManager.shared.trackMoodLogged(
            weather: weather.rawValue,
            energy: Int(energyLevel.rounded()),
            intensity: Int(intensityLevel.rounded())
        )
        saved = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.saved = false
            self?.selectedWeather = nil
            self?.energyLevel = 5
            self?.intensityLevel = 5
        }
    }

    var suggestion: String {
        selectedWeather?.suggestion ?? "tap a card to log today's emotional weather."
    }
}
