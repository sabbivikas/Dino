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
    // Observed so the whole tree re-renders when the user changes the iOS text
    // size — DinoTheme's fonts read the Dynamic Type category on each render.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                } else if !hasPassedAuth || authQA {
                    SignInView()
                } else if !dataManager.onboardingComplete || onboardingQA {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .dinoOpenURL)) { note in
            if let url = note.object as? URL {
                AnalyticsManager.shared.trackNotificationTapped(type: url.host ?? "unknown")
                handleDeepLink(url)
                DinoPendingDeepLink.url = nil
            }
        }
        .onAppear {
            if let url = DinoPendingDeepLink.url {
                AnalyticsManager.shared.trackNotificationTapped(type: url.host ?? "unknown")
                handleDeepLink(url)
                DinoPendingDeepLink.url = nil
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { dataManager.showRhythmsLetterFromDeepLink },
            set: { dataManager.showRhythmsLetterFromDeepLink = $0 }
        )) {
            RhythmsLetterView(onDismiss: { dataManager.showRhythmsLetterFromDeepLink = false })
        }
        .fullScreenCover(isPresented: Binding(
            get: { dataManager.showAmbientFromDeepLink },
            set: { dataManager.showAmbientFromDeepLink = $0 }
        )) {
            AmbientSoundsView()
        }
    }

    private var authQA: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-authQA")
        #else
        return false
        #endif
    }

    // QA-only: force the onboarding flow on an already-onboarded install
    // (screenshot verification of localized onboarding, DEBUG builds only).
    private var onboardingQA: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-onboardingQA")
        #else
        return false
        #endif
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "dino" else { return }
        AnalyticsManager.shared.trackDeepLinkOpened(screen: url.host ?? "unknown")
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
        case "ambient":
            // Ambient sounds present as a full-screen cover on top of
            // whatever tab is active — no tab change required.
            dataManager.showAmbientFromDeepLink = true
        case "rhythmsletter":
            // The night-before rhythms letter opens the envelope UI over
            // whatever tab is active.
            dataManager.showRhythmsLetterFromDeepLink = true
        case "meditation":
            // Break-finder reminder opens meditation over the home tab.
            dataManager.deepLinkTab = 0
            dataManager.showMeditationFromDeepLink = true
        default:
            break
        }
    }
}
