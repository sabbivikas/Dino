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
    @Published var showAffirmations: Bool = false
    @Published var showGrowth: Bool = false

    private let dataManager: SharedDataManager

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
        currentAffirmationIndex = Int.random(in: 0..<AffirmationsData.all.count)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "good morning"
        case 12..<17: return "good afternoon"
        default: return "good evening"
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
}
