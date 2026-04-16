//
//  MainTabView.swift
//  Dino
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            VoiceJournalView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
                .tag(1)

            EmotionalWeatherView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Mood", systemImage: "cloud.sun.fill")
                }
                .tag(2)

            GratitudeJarView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Jar", systemImage: "gift.fill")
                }
                .tag(3)

            ProfileView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(4)
        }
        .accentColor(DinoTheme.navIconSelected)
        .toolbarBackground(DinoTheme.navBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onReceive(dataManager.$deepLinkTab) { tab in
            if tab > 0 {
                selectedTab = tab
                dataManager.deepLinkTab = 0
            }
        }
        .onAppear { applyTabBarAppearance() }
        .onChange(of: themeManager.currentTheme) { _, _ in applyTabBarAppearance() }
    }

    private func applyTabBarAppearance() {
        let colors = ThemeManager.shared.currentTheme.colors
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        let bgColor = UIColor(colors.navBackground)
        appearance.backgroundColor = bgColor
        // Normal item colors
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(colors.navIconDefault)
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(colors.navIconSelected)
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(colors.navIconDefault)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(colors.navIconSelected)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
