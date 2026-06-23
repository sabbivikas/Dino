//
//  GratitudeViewModel.swift
//  Dino
//

import SwiftUI
import Combine
import PostHog

@MainActor
class GratitudeViewModel: ObservableObject {
    @Published var showAddSheet: Bool = false
    @Published var newNoteText: String = ""
    @Published var selectedNote: GratitudeNote? = nil
    @Published var showNoteDetail: Bool = false

    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
    }

    var notes: [GratitudeNote] { dataManager.gratitudeNotes }
    var todayCount: Int { dataManager.todayGratitudeCount }
    var totalCount: Int { dataManager.gratitudeNotes.count }
    var dailyGoal: Int { 3 }
    var showCongrats: Bool { totalCount >= 30 }

    var jarFillRatio: Double {
        min(Double(totalCount) / 30.0, 1.0)
    }

    func addNote(tokenType: String = "heart") {
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        dataManager.addGratitudeNote(text, tokenType: tokenType)
        AnalyticsManager.shared.trackGratitudeTokenAdded(type: tokenType)
        let newTotal = dataManager.gratitudeNotes.count
        if [3, 10, 25].contains(newTotal) {
            AnalyticsManager.shared.trackGratitudeMilestone(count: newTotal)
        }
        newNoteText = ""
        showAddSheet = false
    }

    func deleteNote(_ note: GratitudeNote) {
        dataManager.deleteGratitudeNote(note)
    }

    func selectNote(_ note: GratitudeNote) {
        selectedNote = note
        showNoteDetail = true
    }
}
