//
//  HomeView.swift
//  Dino
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: HomeViewModel = HomeViewModel(dataManager: SharedDataManager.shared)

    var body: some View {
        NavigationStack {
            ZStack {
                DinoTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Greeting header with mascot
                        greetingHeader

                        // Action Grid
                        actionGrid

                        // Today's Focus Card
                        focusCard

                        // Gentle note
                        gentleNoteCard

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, DinoTheme.padding)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    headerLeading
                }
                ToolbarItem(placement: .topBarTrailing) {
                    headerTrailing
                }
            }
            .navigationDestination(isPresented: $viewModel.showBreathing) {
                BreathingView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showMeditation) {
                MeditationView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showFocus) {
                FocusView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showAffirmations) {
                AffirmationsView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showGrowth) {
                GrowthView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showAssessment) {
                AssessmentView().environmentObject(dataManager)
            }
            .navigationDestination(isPresented: $viewModel.showResources) {
                ResourcesView().environmentObject(dataManager)
            }
        }
    }

    // MARK: - Header Leading (Avatar)

    private var headerLeading: some View {
        NavigationLink {
            SettingsView().environmentObject(dataManager)
        } label: {
            Image("DinoMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        }
    }

    // MARK: - Header Trailing (Streak + Settings)

    private var headerTrailing: some View {
        HStack(spacing: 14) {
            // Streak egg
            NavigationLink {
                StreakCalendarView().environmentObject(dataManager)
            } label: {
                ZStack {
                    Image(systemName: "oval.fill")
                        .font(DinoTheme.dinoFont(size: 22))
                        .foregroundColor(DinoTheme.peach.opacity(0.5))
                    Text("\(dataManager.streakData.currentStreak)")
                        .font(DinoTheme.numericFont(size: 10))
                        .foregroundColor(DinoTheme.textPrimary)
                        .offset(y: 1)
                }
            }

            NavigationLink {
                SettingsView().environmentObject(dataManager)
            } label: {
                Image(systemName: "gearshape")
                    .font(DinoTheme.dinoFont(size: 18))
                    .foregroundColor(DinoTheme.textSecondary)
            }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(displayName) 🌿")
                    .font(DinoTheme.dinoLabelFont(size: 14))
                    .foregroundColor(DinoTheme.textSecondary)

                Text("how are you\nfeeling today?")
                    .font(DinoTheme.dinoDisplayFont(size: 30))
                    .foregroundColor(DinoTheme.textPrimary)
                    .lineSpacing(2)
            }

            Spacer()

            Image("DinoMascot")
                .resizable()
                .scaledToFit()
                .frame(height: 64)
        }
        .padding(.top, DinoDesignSystem.space7)
        .padding(.bottom, DinoDesignSystem.space2)
    }

    // MARK: - Today's Focus Card

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("today's focus")
                        .font(DinoTheme.dinoLabelFont(size: 13))
                        .foregroundColor(DinoTheme.textSecondary)

                    HStack(spacing: 8) {
                        Text(viewModel.todaysFocusEmoji)
                            .font(DinoTheme.dinoFont(size: 22))
                        Text(viewModel.todaysFocus)
                            .font(DinoTheme.dinoDisplayFont(size: 22))
                            .foregroundColor(DinoTheme.textPrimary)
                    }
                }
                Spacer()
            }

            // Weekly tracker
            weeklyTracker
        }
        .padding(DinoTheme.padding)
        .dsCardLarge()
    }

    // MARK: - Weekly Tracker

    private var weeklyTracker: some View {
        let days = viewModel.weeklyActivity()
        return HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 6) {
                    Text(day.label)
                        .font(DinoTheme.dinoFont(size: 11))
                        .foregroundColor(DinoTheme.textSecondary)

                    ZStack {
                        Circle()
                            .fill(day.isCompleted || day.isToday ? DinoTheme.peach : DinoTheme.surfaceSecondary)
                            .frame(width: day.isToday ? 30 : 26, height: day.isToday ? 30 : 26)

                        if day.isToday {
                            Circle()
                                .strokeBorder(DinoTheme.peach, lineWidth: 2)
                                .frame(width: 30, height: 30)
                        }

                        if day.isCompleted {
                            Image(systemName: "checkmark")
                                .font(DinoTheme.numericFont(size: 11))
                                .foregroundColor(.white)
                        }
                    }
                    .animation(.spring(response: DinoDesignSystem.interactiveSpringResponse, dampingFraction: DinoDesignSystem.interactiveSpringDamping), value: day.isCompleted)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 3x3 Action Grid

    private var actionGrid: some View {
        let rows = [
            [
                ActionItem(id: "journal", title: "Journal", icon: "mic.fill", color: DinoTheme.sageGreen, tab: 1),
                ActionItem(id: "mood", title: "Mood", icon: "cloud.sun.fill", color: DinoTheme.skyBlue, tab: 2),
                ActionItem(id: "gratitude", title: "Gratitude", icon: "archivebox.fill", color: DinoTheme.peach, tab: 3),
            ],
            [
                ActionItem(id: "breathing", title: "Breathing", icon: "circle.circle", color: DinoTheme.lavender, tab: nil),
                ActionItem(id: "meditation", title: "Meditation", icon: "leaf.fill", color: DinoTheme.sageGreen.opacity(0.8), tab: nil),
                ActionItem(id: "affirmations", title: "Affirm", icon: "sparkles", color: DinoTheme.warmRose, tab: nil),
            ],
            [
                ActionItem(id: "assessment", title: "Assess", icon: "chart.bar.fill", color: DinoTheme.skyBlue.opacity(0.8), tab: nil),
                ActionItem(id: "growth", title: "Growth", icon: "tree.fill", color: DinoTheme.sageGreen, tab: nil),
                ActionItem(id: "resources", title: "Help", icon: "heart.fill", color: DinoTheme.warmRose.opacity(0.8), tab: nil),
            ]
        ]

        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 10) {
                    ForEach(row) { item in
                        actionCard(item: item)
                    }
                }
            }
        }
    }

    // MARK: - Action Card

    private func actionCard(item: ActionItem) -> some View {
        let isPressed = viewModel.tappedCard == item.id

        return Button {
            viewModel.animateCardTap(item.id)
            handleCardTap(item)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.20))
                        .frame(width: DinoDesignSystem.iconCircleSize, height: DinoDesignSystem.iconCircleSize)

                    Image(systemName: item.icon)
                        .font(DinoTheme.dinoFont(size: 20))
                        .foregroundColor(item.color)
                }

                Text(item.title)
                    .font(DinoTheme.dinoLabelFont(size: 13))
                    .foregroundColor(DinoTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, DinoDesignSystem.space3)
            .background(DinoTheme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(item.color.opacity(0.25), lineWidth: 1.5)
            )
            .shadow(
                color: isPressed ? item.color.opacity(0.15) : Color.black.opacity(0.04),
                radius: isPressed ? DinoDesignSystem.pressShadowRadius : 10,
                y: DinoDesignSystem.cardShadowY
            )
            .scaleEffect(isPressed ? DinoDesignSystem.pressScaleDeep : 1.0)
            .animation(.spring(response: DinoDesignSystem.interactiveSpringResponse, dampingFraction: DinoDesignSystem.interactiveSpringDamping), value: isPressed)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gentle Note Card

    private var gentleNoteCard: some View {
        VStack(alignment: .leading, spacing: DinoDesignSystem.space2) {
            Text("a gentle note")
                .font(DinoTheme.dinoLabelFont(size: 13))
                .foregroundColor(DinoTheme.textSecondary)

            Text("you showed up today — and that's already something. 🌱")
                .font(DinoTheme.dinoFont(size: 18))
                .foregroundColor(DinoTheme.textPrimary)
                .lineSpacing(4)
        }
        .padding(DinoTheme.padding)
        .dsCardLarge()
    }

    // MARK: - Card Tap Handler

    private func handleCardTap(_ item: ActionItem) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let tab = item.tab {
                dataManager.deepLinkTab = tab
            } else {
                switch item.id {
                case "breathing":
                    viewModel.showBreathing = true
                case "meditation":
                    viewModel.showMeditation = true
                case "affirmations":
                    viewModel.showAffirmations = true
                case "growth":
                    viewModel.showGrowth = true
                case "assessment":
                    viewModel.showAssessment = true
                case "resources":
                    viewModel.showResources = true
                default:
                    break
                }
            }
        }
    }

    // MARK: - Helpers

    private var displayName: String {
        let name = dataManager.userName
        if name.isEmpty { return viewModel.greeting }
        return "\(viewModel.greeting), \(name)"
    }

    private var avatarInitial: String {
        let name = dataManager.userName
        if name.isEmpty { return "🦕" }
        return String(name.prefix(1)).uppercased()
    }
}

// MARK: - ActionItem Model

private struct ActionItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let tab: Int? // if set, switches tab instead of navigation push
}
