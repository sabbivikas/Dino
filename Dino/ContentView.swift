//
//  ContentView.swift
//  Dino
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var paintingService = MoodPaintingService.shared

    @AppStorage("hasSeenLetter") private var hasSeenLetter = false
    @AppStorage("hasPassedAuth") private var hasPassedAuth = false

    @State private var showMonthlyPaintingGenerator = false

    var body: some View {
        ZStack {
            if dataManager.onboardingComplete {
                AmbientBackgroundView()
            }

            Group {
                if !hasSeenLetter {
                    LetterView {
                        withAnimation { hasSeenLetter = true }
                    }
                } else if !hasPassedAuth {
                    SignInView()
                } else if !dataManager.onboardingComplete {
                    OnboardingView()
                } else {
                    MainTabView()
                        .onAppear { checkMonthlyPaintingTrigger() }
                }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .dinoOpenURL)) { note in
            if let url = note.object as? URL {
                handleDeepLink(url)
                DinoPendingDeepLink.url = nil
            }
        }
        .onAppear {
            if let url = DinoPendingDeepLink.url {
                handleDeepLink(url)
                DinoPendingDeepLink.url = nil
            }
        }
        .fullScreenCover(isPresented: $showMonthlyPaintingGenerator) {
            MoodPaintingGeneratorView(
                month: Date(),
                moods: moodsForCurrentMonth()
            )
        }
    }

    private func checkMonthlyPaintingTrigger() {
        let cal = Calendar.current
        let today = Date()
        guard let range = cal.range(of: .day, in: .month, for: today) else { return }
        let isLastDay = cal.component(.day, from: today) == range.upperBound - 1
        guard isLastDay else { return }
        guard !paintingService.hasPainting(for: today) else { return }
        showMonthlyPaintingGenerator = true
    }

    private func moodsForCurrentMonth() -> [MoodEntry] {
        let cal = Calendar.current
        let now = Date()
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)
        return dataManager.moodEntries.filter {
            cal.component(.month, from: $0.date) == m &&
            cal.component(.year, from: $0.date) == y
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "dino" else { return }
        switch url.host {
        case "mood":
            dataManager.deepLinkTab = 2
        case "journal":
            dataManager.deepLinkTab = 1
        case "gratitude":
            dataManager.deepLinkTab = 3
        case "breathe":
            dataManager.deepLinkTab = 0
            dataManager.showBreathingFromDeepLink = true
        case "affirmation":
            dataManager.deepLinkTab = 2
        case "streak":
            dataManager.deepLinkTab = 4
        case "focus":
            dataManager.deepLinkTab = 0
            dataManager.showFocusFromDeepLink = true
        default:
            break
        }
    }
}
