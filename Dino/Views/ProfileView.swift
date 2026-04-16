//
//  ProfileView.swift
//  Dino
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @State private var showAssessment = false
    @State private var showResources = false
    @State private var showSettings = false

    var memberSince: String {
        dataManager.memberSinceDate.formatted(.dateTime.month(.wide).year())
    }

    var initial: String {
        String(dataManager.userName.prefix(1)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar + name
                    VStack(spacing: 14) {
                        Image("DinoMascot")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                        .shadow(color: DinoTheme.sageGreen.opacity(0.3), radius: 12, y: 4)

                        VStack(spacing: 4) {
                            Text(dataManager.userName.isEmpty ? "friend" : dataManager.userName)
                                .font(DinoTheme.titleFont())
                                .foregroundColor(DinoTheme.textPrimary)

                            Text("member since \(memberSince)")
                                .font(DinoTheme.captionFont())
                                .foregroundColor(DinoTheme.textSecondary)
                        }
                    }
                    .padding(.top, 16)

                    // Stats row
                    HStack(spacing: 0) {
                        ProfileStat(value: "\(dataManager.journalEntries.count)", label: "journals")
                        Divider().frame(height: 36)
                        ProfileStat(value: "\(dataManager.moodEntries.count)", label: "moods")
                        Divider().frame(height: 36)
                        ProfileStat(value: "\(dataManager.gratitudeNotes.count)", label: "gratitude")
                    }
                    .padding(.vertical, 18)
                    .dinoCardWhite()
                    .padding(.horizontal, DinoTheme.padding)

                    // Streak
                    NavigationLink {
                        StreakCalendarView().environmentObject(dataManager)
                    } label: {
                        HStack {
                            StreakBadge(streak: dataManager.streakData.currentStreak)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("longest")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)
                                Text("\(dataManager.streakData.longestStreak) days")
                                    .font(DinoTheme.headlineFont())
                                    .foregroundColor(DinoTheme.textPrimary)
                            }
                            Image(systemName: "chevron.right")
                                .font(DinoTheme.captionFont())
                                .foregroundColor(DinoTheme.textSecondary.opacity(0.5))
                        }
                        .padding(DinoTheme.padding)
                        .dinoCardWhite()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DinoTheme.padding)

                    // Navigation links
                    VStack(spacing: 2) {
                        ProfileNavRow(icon: "brain.head.profile", label: "weekly assessment", color: DinoTheme.lavender) {
                            showAssessment = true
                        }
                        ProfileNavRow(icon: "heart.text.square.fill", label: "resources", color: DinoTheme.warmRose) {
                            showResources = true
                        }
                        ProfileNavRow(icon: "gearshape.fill", label: "settings", color: DinoTheme.skyBlue) {
                            showSettings = true
                        }
                    }
                    .padding(.horizontal, DinoTheme.padding)

                    // Crisis button
                    Button(action: { showResources = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(DinoTheme.dinoFont(size: 18))
                            Text("need help now?")
                                .font(DinoTheme.headlineFont())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DinoTheme.warmRose)
                        .cornerRadius(DinoTheme.cornerRadius)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, DinoTheme.padding)
                    .padding(.bottom, 32)
                }
            }
            .background(DinoTheme.background.ignoresSafeArea())
            .navigationTitle("profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAssessment) {
            AssessmentView().environmentObject(dataManager)
        }
        .sheet(isPresented: $showResources) {
            ResourcesView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(dataManager)
        }
    }
}

// MARK: - Profile Stat
struct ProfileStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DinoTheme.titleFont())
                .foregroundColor(DinoTheme.textPrimary)
            Text(label)
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Nav Row
struct ProfileNavRow: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(DinoTheme.dinoFont(size: 18))
                    .foregroundColor(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.12))
                    .cornerRadius(10)

                Text(label)
                    .font(DinoTheme.bodyFont())
                    .foregroundColor(DinoTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(DinoTheme.textSecondary.opacity(0.5))
            }
            .padding(14)
            .background(DinoTheme.cardBackground)
            .cornerRadius(DinoTheme.cornerRadius)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
