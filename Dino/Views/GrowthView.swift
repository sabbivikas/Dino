//
//  GrowthView.swift
//  Dino
//

import SwiftUI

struct GrowthView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: GrowthViewModel = GrowthViewModel(dataManager: SharedDataManager.shared)
    @Environment(\.dismiss) private var dismiss
    @State private var glowPulse: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Dino character
                    VStack(spacing: 12) {
                        Text(viewModel.dinoEmoji)
                            .font(.system(size: 80))
                            .padding(.top, 16)

                        Text("your dino grows with you")
                            .font(DinoTheme.subheadlineFont())
                            .foregroundColor(DinoTheme.textSecondary)
                    }

                    // Level & XP
                    VStack(spacing: 12) {
                        HStack {
                            Text(viewModel.levelLabel)
                                .font(DinoTheme.titleFont())
                                .foregroundColor(DinoTheme.textPrimary)
                            Spacer()
                            Text(viewModel.xpLabel)
                                .font(DinoTheme.captionFont())
                                .foregroundColor(DinoTheme.textSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(DinoTheme.sageGreen.opacity(0.2))
                                    .frame(height: 12)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [DinoTheme.sageGreen, DinoTheme.skyBlue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, geo.size.width * viewModel.xpProgress), height: 12)
                                    .shadow(
                                        color: viewModel.xpProgress < 0.5
                                            ? DinoTheme.sageGreen.opacity(glowPulse ? 0.5 : 0.12)
                                            : Color.clear,
                                        radius: glowPulse ? 10 : 4,
                                        y: 0
                                    )
                                    .animation(.easeInOut(duration: 0.6), value: viewModel.xpProgress)
                            }
                        }
                        .frame(height: 12)
                        .onAppear {
                            if viewModel.xpProgress < 0.5 {
                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                    glowPulse = true
                                }
                            }
                        }
                        .onChange(of: viewModel.xpProgress) { _, newVal in
                            if newVal >= 0.5 {
                                withAnimation { glowPulse = false }
                            } else if !glowPulse {
                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                    glowPulse = true
                                }
                            }
                        }

                        Text("earn xp by logging moods, journaling, adding gratitude, and breathing")
                            .font(DinoTheme.captionFont())
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                    .padding(DinoTheme.padding)
                    .dinoCardWhite()
                    .padding(.horizontal, DinoTheme.padding)

                    // Stats grid
                    VStack(alignment: .leading, spacing: 14) {
                        Text("your stats")
                            .font(DinoTheme.headlineFont())
                            .foregroundColor(DinoTheme.textPrimary)
                            .padding(.horizontal, DinoTheme.padding)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(viewModel.statItems, id: \.label) { stat in
                                GrowthStatCard(stat: stat)
                            }
                        }
                        .padding(.horizontal, DinoTheme.padding)
                    }

                    // XP breakdown
                    VStack(alignment: .leading, spacing: 14) {
                        Text("how to earn xp")
                            .font(DinoTheme.headlineFont())
                            .foregroundColor(DinoTheme.textPrimary)
                            .padding(.horizontal, DinoTheme.padding)

                        VStack(spacing: 10) {
                            XPRow(icon: "cloud.sun.fill", action: "log mood", xp: "+10", color: DinoTheme.skyBlue)
                            XPRow(icon: "mic.fill", action: "voice journal", xp: "+15", color: DinoTheme.lavender)
                            XPRow(icon: "heart.fill", action: "gratitude note", xp: "+5", color: DinoTheme.warmRose)
                            XPRow(icon: "wind", action: "breathing session", xp: "+20", color: DinoTheme.sageGreen)
                        }
                        .padding(.horizontal, DinoTheme.padding)
                    }

                    // Milestones
                    VStack(alignment: .leading, spacing: 14) {
                        Text("milestones")
                            .font(DinoTheme.headlineFont())
                            .foregroundColor(DinoTheme.textPrimary)
                            .padding(.horizontal, DinoTheme.padding)

                        VStack(spacing: 8) {
                            ForEach([
                                (1, "🥚", "hatchling"),
                                (4, "🦕", "dino"),
                                (8, "🦖", "apex dino"),
                                (15, "⭐️", "legend")
                            ], id: \.0) { level, emoji, title in
                                HStack(spacing: 12) {
                                    Text(emoji)
                                        .font(DinoTheme.dinoFont(size: 24))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(title)
                                            .font(DinoTheme.headlineFont())
                                            .foregroundColor(DinoTheme.textPrimary)
                                        Text("level \(level)")
                                            .font(DinoTheme.captionFont())
                                            .foregroundColor(DinoTheme.textSecondary)
                                    }

                                    Spacer()

                                    if viewModel.stats.level >= level {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(DinoTheme.sageGreen)
                                    } else {
                                        Text("level \(level)")
                                            .font(DinoTheme.captionFont())
                                            .foregroundColor(DinoTheme.textSecondary)
                                    }
                                }
                                .padding(14)
                                .background(
                                    viewModel.stats.level >= level
                                        ? DinoTheme.sageGreen.opacity(0.08)
                                        : DinoTheme.cardBackground
                                )
                                .cornerRadius(DinoTheme.cornerRadius)
                                .padding(.horizontal, DinoTheme.padding)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(DinoTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(DinoTheme.sageGreen)
                }
            }
            .navigationTitle("growth")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Growth Stat Card
struct GrowthStatCard: View {
    let stat: GrowthViewModel.StatItem

    var body: some View {
        VStack(spacing: 8) {
            Text(stat.emoji)
                .font(DinoTheme.dinoFont(size: 28))

            if stat.value == 0 {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(DinoTheme.dinoFont(size: 13))
                    Text("Log Now")
                        .font(DinoTheme.dinoFont(size: 13))
                }
                .foregroundColor(Color(hex: stat.color).opacity(0.7))
            } else {
                Text("\(stat.value)")
                    .font(DinoTheme.titleFont())
                    .foregroundColor(DinoTheme.textPrimary)
            }

            Text(stat.label)
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(hex: stat.color).opacity(stat.value == 0 ? 0.08 : 0.15))
        .cornerRadius(DinoTheme.cornerRadius)
    }
}

// MARK: - XP Row
struct XPRow: View {
    let icon: String
    let action: String
    let xp: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(DinoTheme.dinoFont(size: 18))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .cornerRadius(10)

            Text(action)
                .font(DinoTheme.bodyFont())
                .foregroundColor(DinoTheme.textPrimary)

            Spacer()

            Text(xp)
                .font(DinoTheme.headlineFont())
                .foregroundColor(DinoTheme.sageGreen)
        }
        .padding(14)
        .background(DinoTheme.cardBackground)
        .cornerRadius(DinoTheme.cornerRadius)
    }
}
