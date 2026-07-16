//
//  HomeViewModel.swift
//  Dino
//

import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var currentAffirmationIndex: Int = 0
    @Published var showBreathing: Bool = false
    @Published var showMeditation: Bool = false
    @Published var showFocus: Bool = false
    @Published var showAffirmations: Bool = false
    @Published var showGrowth: Bool = false
    @Published var showAssessment: Bool = false
    @Published var showResources: Bool = false
    @Published var showRhythms: Bool = false

    // Track card tap animations
    @Published var tappedCard: String? = nil

    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
        currentAffirmationIndex = Int.random(in: 0..<AffirmationsData.all.count)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "good morning")
        case 12..<17: return String(localized: "good afternoon")
        default: return String(localized: "good evening")
        }
    }

    var todaysFocus: String {
        // Based on the most recent mood. Use `.max(by:)` so we don't depend on
        // whether the array is newest-first or insertion-order.
        if let lastMood = dataManager.moodEntries.max(by: { $0.date < $1.date }) {
            switch lastMood.weatherType {
            case .clear: return String(localized: "Productivity")
            case .partlyCloudy: return String(localized: "Balance")
            case .overwhelmed: return String(localized: "Calm")
            case .drained: return String(localized: "Healing")
            }
        }
        if let firstIntention = dataManager.userIntentions.first {
            return firstIntention.capitalized
        }
        return String(localized: "Wellness")
    }

    var todaysFocusEmoji: String {
        if let lastMood = dataManager.moodEntries.max(by: { $0.date < $1.date }) {
            return lastMood.weatherType.emoji
        }
        return "🌱"
    }

    // Weekly activity tracker: returns 7 days (Sun-Sat) with completion status
    func weeklyActivity() -> [(label: String, isCompleted: Bool, isToday: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) // 1=Sun, 7=Sat
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today

        let labels = calendar.veryShortStandaloneWeekdaySymbols   // Sun-first, locale-aware

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: startOfWeek) ?? startOfWeek
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            let hasMood = dataManager.moodEntries.contains { $0.date >= dayStart && $0.date < dayEnd }
            let hasJournal = dataManager.journalEntries.contains { $0.date >= dayStart && $0.date < dayEnd }
            let hasGratitude = dataManager.gratitudeNotes.contains { $0.createdAt >= dayStart && $0.createdAt < dayEnd }
            let isCompleted = hasMood || hasJournal || hasGratitude
            let isTodayCheck = calendar.isDate(day, inSameDayAs: today)

            return (label: labels[offset], isCompleted: isCompleted, isToday: isTodayCheck)
        }
    }

    var currentAffirmation: String {
        AffirmationsData.all[currentAffirmationIndex % AffirmationsData.all.count]
    }

    func nextAffirmation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentAffirmationIndex = (currentAffirmationIndex + 1) % AffirmationsData.all.count
        }
    }

    func previousAffirmation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentAffirmationIndex = (currentAffirmationIndex - 1 + AffirmationsData.all.count) % AffirmationsData.all.count
        }
    }

    func animateCardTap(_ cardId: String) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            tappedCard = cardId
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                self.tappedCard = nil
            }
        }
    }
}
