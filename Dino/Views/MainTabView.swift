//
//  MainTabView.swift
//  Dino
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dataManager: SharedDataManager
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
        .accentColor(DinoTheme.sageGreen)
        .onReceive(dataManager.$deepLinkTab) { tab in
            if tab > 0 {
                selectedTab = tab
                dataManager.deepLinkTab = 0
            }
        }
    }
}
