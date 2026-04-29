//
//  ContentView.swift
//  Dino
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var themeManager = ThemeManager.shared

    @AppStorage("hasSeenLetter") private var hasSeenLetter = false
    @AppStorage("hasPassedAuth") private var hasPassedAuth = false

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
                }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
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
