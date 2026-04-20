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

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // MARK: - Header: avatar + name + XP
                    VStack(spacing: 16) {
                        // Avatar with pulsing glow ring
                        ProfileAvatarGlow()
                            .padding(.top, 20)

                        VStack(spacing: 5) {
                            Text(dataManager.userName.isEmpty ? "friend" : dataManager.userName)
                                .font(DinoTheme.dinoDisplayFont(size: 24))
                                .foregroundColor(DinoTheme.textPrimary)

                            Text("member since \(memberSince)")
                                .font(DinoTheme.dinoLabelFont(size: 13))
                                .foregroundColor(DinoTheme.textSecondary)
                        }

                        // XP progress bar
                        ProfileXPBar(
                            level: dataManager.growthStats.level,
                            xpProgress: dataManager.growthStats.xpProgress,
                            xpInLevel: dataManager.growthStats.xpInCurrentLevel,
                            xpToNext: dataManager.growthStats.xpToNextLevel
                        )
                        .padding(.horizontal, DinoTheme.padding)
                    }

                    // MARK: - Stats row
                    HStack(spacing: 0) {
                        ProfileStat(emoji: "🎙️", value: "\(dataManager.journalEntries.count)", label: "journals")
                        ProfileStatDivider()
                        ProfileStat(emoji: "🌤️", value: "\(dataManager.moodEntries.count)", label: "moods")
                        ProfileStatDivider()
                        ProfileStat(emoji: "🌱", value: "\(dataManager.gratitudeNotes.count)", label: "gratitude")
                    }
                    .padding(.vertical, 20)
                    .dsCardLarge()
                    .padding(.horizontal, DinoTheme.padding)

                    // MARK: - Streak card
                    NavigationLink {
                        StreakCalendarView().environmentObject(dataManager)
                    } label: {
                        HStack(spacing: 14) {
                            ProfileStreakFlame(streak: dataManager.streakData.currentStreak)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("longest")
                                    .font(DinoTheme.dinoLabelFont(size: 12))
                                    .foregroundColor(DinoTheme.textSecondary)
                                Text("\(dataManager.streakData.longestStreak) days")
                                    .font(DinoTheme.headlineFont())
                                    .foregroundColor(DinoTheme.textPrimary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DinoTheme.textSecondary.opacity(0.4))
                        }
                        .padding(DinoTheme.padding)
                        .dsCardLarge()
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, DinoTheme.padding)

                    // MARK: - Menu items
                    VStack(spacing: 4) {
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

                    // MARK: - Crisis button
                    ProfileCrisisButton { showResources = true }
                        .padding(.horizontal, DinoTheme.padding)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.clear)
            .navigationTitle("")
            .navigationBarHidden(true)
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

// MARK: - Avatar with Pulsing Glow Ring

private struct ProfileAvatarGlow: View {
    @State private var glowPulsing = false

    var body: some View {
        ZStack {
            // Pulsing glow ring
            Circle()
                .strokeBorder(DinoTheme.accent.opacity(glowPulsing ? 0.6 : 0.3), lineWidth: 3)
                .frame(width: 104, height: 104)
                .scaleEffect(glowPulsing ? 1.06 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: glowPulsing
                )

            // Soft outer glow
            Circle()
                .fill(DinoTheme.accent.opacity(glowPulsing ? 0.12 : 0.05))
                .frame(width: 112, height: 112)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: glowPulsing
                )

            Image("DinoMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(Circle())
                .shadow(color: DinoTheme.accent.opacity(0.25), radius: 12, y: 4)
        }
        .onAppear { glowPulsing = true }
    }
}

// MARK: - XP Progress Bar

private struct ProfileXPBar: View {
    let level: Int
    let xpProgress: Double
    let xpInLevel: Int
    let xpToNext: Int

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            // Level labels
            HStack {
                Text("lv. \(level)")
                    .font(DinoTheme.dinoLabelFont(size: 12))
                    .foregroundColor(DinoTheme.accent)
                Spacer()
                Text("\(xpInLevel)/\(xpToNext) xp")
                    .font(DinoTheme.numericFont(size: 12))
                    .foregroundColor(DinoTheme.textSecondary)
                Spacer()
                Text("lv. \(level + 1)")
                    .font(DinoTheme.dinoLabelFont(size: 12))
                    .foregroundColor(DinoTheme.textSecondary)
            }

            // Progress track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DinoTheme.accent.opacity(0.12))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(DinoTheme.accent)
                        .frame(width: max(8, geo.size.width * animatedProgress), height: 8)
                        .shadow(color: DinoTheme.accent.opacity(0.3), radius: 4, y: 1)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = xpProgress
            }
        }
        .onChange(of: xpProgress) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Profile Stat

struct ProfileStat: View {
    let emoji: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 20))

            Text(value)
                .font(DinoTheme.numericFont(size: 28))
                .foregroundColor(DinoTheme.textPrimary)

            Text(label)
                .font(DinoTheme.dinoLabelFont(size: 12))
                .foregroundColor(DinoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat Divider

private struct ProfileStatDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(DinoTheme.accent.opacity(0.15))
            .frame(width: 1, height: 44)
    }
}

// MARK: - Streak Flame (animated)

private struct ProfileStreakFlame: View {
    let streak: Int
    @State private var flameScale: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Flame with orange glow
            ZStack {
                // Warm glow behind flame
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .blur(radius: 6)

                Text("🔥")
                    .font(.system(size: 32))
                    .scaleEffect(flameScale ? 1.08 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: flameScale
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(streak) day\(streak == 1 ? "" : "s")")
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(DinoTheme.textPrimary)

                Text("current streak")
                    .font(DinoTheme.dinoLabelFont(size: 11))
                    .foregroundColor(DinoTheme.textSecondary)
            }
        }
        .onAppear { flameScale = true }
    }
}

// MARK: - Profile Nav Row

struct ProfileNavRow: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var chevronOffset: CGFloat = 0

    var body: some View {
        Button(action: {
            // Chevron slide animation on tap
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                chevronOffset = 4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    chevronOffset = 0
                }
            }
            action()
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(DinoTheme.accent.opacity(0.12))
                    )

                Text(label)
                    .font(DinoTheme.bodyFont())
                    .foregroundColor(DinoTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DinoTheme.textSecondary.opacity(0.4))
                    .offset(x: chevronOffset)
            }
            .frame(minHeight: 56)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                    .strokeBorder(DinoTheme.accent.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Crisis Button (soft pulse)

private struct ProfileCrisisButton: View {
    let action: () -> Void
    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .medium))
                Text("need help now?")
                    .font(DinoTheme.headlineFont())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(DinoTheme.warmRose)
            .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous))
            .shadow(color: DinoTheme.warmRose.opacity(0.25), radius: 8, y: 3)
            .scaleEffect(pulsing ? 1.02 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: pulsing
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear { pulsing = true }
    }
}
