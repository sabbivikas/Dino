//
//  HomeView.swift
//  Dino
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: HomeViewModel = HomeViewModel(dataManager: SharedDataManager.shared)

    @State private var showBreathing = false
    @State private var showAffirmations = false
    @State private var showGrowth = false
    @State private var navigateToMood = false
    @State private var navigateToJournal = false
    @State private var navigateToGratitude = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(viewModel.greeting),")
                                .font(DinoTheme.subheadlineFont())
                                .foregroundColor(DinoTheme.textSecondary)
                            HStack(spacing: 8) {
                                Text(dataManager.userName.isEmpty ? "friend" : dataManager.userName)
                                    .font(DinoTheme.largeFont())
                                    .foregroundColor(DinoTheme.textPrimary)
                                Text("🦕")
                                    .font(.system(size: 28))
                            }
                        }
                        Spacer()
                        StreakBadge(streak: dataManager.streakData.currentStreak)
                    }
                    .padding(.horizontal, DinoTheme.padding)
                    .padding(.top, 8)

                    // Mood check-in card
                    Button(action: { navigateToMood = true }) {
                        HStack(spacing: 16) {
                            Text("🌤")
                                .font(.system(size: 32))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("how are you feeling today?")
                                    .font(DinoTheme.headlineFont())
                                    .foregroundColor(DinoTheme.textPrimary)
                                Text("tap to log your emotional weather")
                                    .font(DinoTheme.captionFont())
                                    .foregroundColor(DinoTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DinoTheme.textSecondary)
                        }
                        .padding(DinoTheme.padding)
                        .dinoCard()
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, DinoTheme.padding)

                    // Quick actions grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("quick actions")
                            .font(DinoTheme.captionFont())
                            .fontWeight(.semibold)
                            .foregroundColor(DinoTheme.textSecondary)
                            .padding(.horizontal, DinoTheme.padding)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            QuickActionCard(
                                icon: "mic.circle.fill",
                                label: "record journal",
                                color: DinoTheme.lavender
                            ) { navigateToJournal = true }

                            QuickActionCard(
                                icon: "cloud.sun.fill",
                                label: "log mood",
                                color: DinoTheme.skyBlue
                            ) { navigateToMood = true }

                            QuickActionCard(
                                icon: "heart.fill",
                                label: "add gratitude",
                                color: DinoTheme.warmRose
                            ) { navigateToGratitude = true }

                            QuickActionCard(
                                icon: "wind",
                                label: "start breathing",
                                color: DinoTheme.sageGreen
                            ) { showBreathing = true }
                        }
                        .padding(.horizontal, DinoTheme.padding)
                    }

                    // Growth card
                    Button(action: { showGrowth = true }) {
                        HStack(spacing: 14) {
                            Text("🦕")
                                .font(.system(size: 30))

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("level \(dataManager.growthStats.level)")
                                        .font(DinoTheme.headlineFont())
                                        .foregroundColor(DinoTheme.textPrimary)
                                    Spacer()
                                    Text("\(dataManager.growthStats.xpInCurrentLevel)/100 xp")
                                        .font(DinoTheme.captionFont())
                                        .foregroundColor(DinoTheme.textSecondary)
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(DinoTheme.sageGreen.opacity(0.2))
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(DinoTheme.sageGreen)
                                            .frame(width: max(4, geo.size.width * dataManager.growthStats.xpProgress), height: 6)
                                    }
                                }
                                .frame(height: 6)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DinoTheme.textSecondary)
                        }
                        .padding(DinoTheme.padding)
                        .dinoCard()
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, DinoTheme.padding)

                    // Affirmation card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("today's affirmation")
                            .font(DinoTheme.captionFont())
                            .fontWeight(.semibold)
                            .foregroundColor(DinoTheme.textSecondary)
                            .padding(.horizontal, DinoTheme.padding)

                        TabView(selection: .constant(viewModel.currentAffirmationIndex)) {
                            ForEach(Array(AffirmationsData.all.enumerated()), id: \.offset) { i, text in
                                AffirmationCard(
                                    text: text,
                                    index: i,
                                    isSaved: dataManager.isAffirmationSaved(text),
                                    onSave: {
                                        if dataManager.isAffirmationSaved(text) {
                                            dataManager.removeAffirmation(text)
                                        } else {
                                            dataManager.saveAffirmation(text)
                                        }
                                    }
                                )
                                .padding(.horizontal, DinoTheme.padding)
                                .tag(i)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 220)
                        .onTapGesture { viewModel.nextAffirmation() }

                        Button(action: { showAffirmations = true }) {
                            Text("see all affirmations →")
                                .font(DinoTheme.captionFont())
                                .foregroundColor(DinoTheme.sageGreen)
                        }
                        .padding(.horizontal, DinoTheme.padding)
                    }

                    // Self-care reminders
                    VStack(alignment: .leading, spacing: 12) {
                        Text("self-care today")
                            .font(DinoTheme.captionFont())
                            .fontWeight(.semibold)
                            .foregroundColor(DinoTheme.textSecondary)
                            .padding(.horizontal, DinoTheme.padding)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                SelfCareButton(emoji: "💧", label: "drink water", isChecked: dataManager.selfCareWater) {
                                    dataManager.toggleSelfCare(.water)
                                }
                                SelfCareButton(emoji: "🍎", label: "eat something", isChecked: dataManager.selfCareEat) {
                                    dataManager.toggleSelfCare(.eat)
                                }
                                SelfCareButton(emoji: "😴", label: "rest", isChecked: dataManager.selfCareRest) {
                                    dataManager.toggleSelfCare(.rest)
                                }
                                SelfCareButton(emoji: "💬", label: "connect", isChecked: dataManager.selfCareConnect) {
                                    dataManager.toggleSelfCare(.connect)
                                }
                            }
                            .padding(.horizontal, DinoTheme.padding)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showBreathing) {
            BreathingView()
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showAffirmations) {
            AffirmationsView()
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showGrowth) {
            GrowthView()
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $navigateToMood) {
            EmotionalWeatherView()
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $navigateToJournal) {
            VoiceJournalView()
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $navigateToGratitude) {
            GratitudeJarView()
                .environmentObject(dataManager)
        }
        .onReceive(dataManager.$showBreathingFromDeepLink) { show in
            if show {
                showBreathing = true
                dataManager.showBreathingFromDeepLink = false
            }
        }
    }
}

// MARK: - Self-care Button
struct SelfCareButton: View {
    let emoji: String
    let label: String
    let isChecked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isChecked ? DinoTheme.sageGreen : DinoTheme.cardBackground)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle()
                                .stroke(isChecked ? DinoTheme.sageGreen : DinoTheme.divider, lineWidth: 1.5)
                        )

                    Text(emoji)
                        .font(.system(size: 22))
                }

                Text(label)
                    .font(DinoTheme.caption2Font())
                    .foregroundColor(isChecked ? DinoTheme.sageGreen : DinoTheme.textSecondary)
                    .fontWeight(isChecked ? .semibold : .regular)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
