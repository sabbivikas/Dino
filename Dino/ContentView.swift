//
//  ContentView.swift
//  Dino
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            if dataManager.isSignedIn && dataManager.onboardingComplete {
                AmbientBackgroundView()
            }

            Group {
                if !dataManager.isSignedIn {
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
            dataManager.deepLinkTab = 2  // mood tab — affirmations live here
        case "streak":
            dataManager.deepLinkTab = 4  // profile tab
        case "focus":
            dataManager.deepLinkTab = 0  // home tab
        default:
            break
        }
    }
}
