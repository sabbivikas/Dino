//
//  EmotionalWeatherView.swift
//  Dino
//

import SwiftUI

struct EmotionalWeatherView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: MoodViewModel = MoodViewModel(dataManager: SharedDataManager.shared)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // Header
                    VStack(spacing: 6) {
                        Text("how's your\ninner weather?")
                            .font(DinoTheme.dinoDisplayFont(size: 28))
                            .foregroundColor(DinoTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, DinoTheme.padding)

                    // Weather cards
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(EmotionalWeather.allCases, id: \.self) { weather in
                            WeatherCard(
                                weather: weather,
                                isSelected: viewModel.selectedWeather == weather,
                                onTap: {
                                    HapticManager.shared.light()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.selectedWeather = weather
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DinoTheme.padding)

                    // Suggestion text
                    if viewModel.selectedWeather != nil {
                        Text(viewModel.suggestion)
                            .font(DinoTheme.bodyFont())
                            .foregroundColor(DinoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DinoTheme.largePadding)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                                    .fill(DinoTheme.accent.opacity(0.10))
                            )
                            .padding(.horizontal, DinoTheme.padding)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }

                    // Sliders
                    VStack(spacing: 24) {
                        MoodSlider(
                            title: "energy",
                            value: $viewModel.energyLevel,
                            lowLabel: "drained",
                            highLabel: "energized",
                            color: DinoTheme.skyBlue
                        )

                        MoodSlider(
                            title: "intensity",
                            value: $viewModel.intensityLevel,
                            lowLabel: "calm",
                            highLabel: "intense",
                            color: DinoTheme.lavender
                        )
                    }
                    .padding(DinoTheme.padding)
                    .dsCardLarge()
                    .padding(.horizontal, DinoTheme.padding)

                    // Save button
                    Button(action: {
                        HapticManager.shared.success()
                        viewModel.saveMood()
                    }) {
                        HStack(spacing: 10) {
                            if viewModel.saved {
                                Image(systemName: "checkmark.circle.fill")
                                Text("saved!")
                            } else {
                                Image(systemName: "cloud.fill")
                                Text("log this feeling")
                            }
                        }
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            viewModel.saved
                                ? DinoTheme.sageGreen
                                : (viewModel.selectedWeather == nil ? DinoTheme.textSecondary.opacity(0.5) : DinoTheme.accent)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous))
                        .shadow(
                            color: viewModel.selectedWeather != nil && !viewModel.saved
                                ? DinoTheme.accent.opacity(0.35)
                                : Color.clear,
                            radius: 8, y: 3
                        )
                        .animation(.easeInOut(duration: 0.2), value: viewModel.saved)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(viewModel.selectedWeather == nil)
                    .padding(.horizontal, DinoTheme.padding)

                    // Weekly trend
                    WeeklyMoodTrend(viewModel: viewModel)
                        .padding(.horizontal, DinoTheme.padding)
                        .padding(.bottom, 20)
                }
            }
            .scrollIndicators(.hidden)
            .background(DinoTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarHidden(true)
            .onAppear { AnalyticsManager.shared.trackMoodScreenOpened() }
        }
    }
}

// MARK: - Mood Slider
struct MoodSlider: View {
    let title: String
    @Binding var value: Double
    let lowLabel: String
    let highLabel: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(DinoTheme.textPrimary)
                Spacer()
                Text("\(Int(value.rounded()))/10")
                    .font(DinoTheme.numericFont(size: 16))
                    .foregroundColor(color)
            }

            // Custom thick slider track with large thumb
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 6)

                    // Track fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat((value - 1) / 9), height: 6)

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: color.opacity(0.30), radius: 6, y: 2)
                        .overlay(
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)
                        )
                        .offset(x: geo.size.width * CGFloat((value - 1) / 9) - 13)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let fraction = max(0, min(1, drag.location.x / geo.size.width))
                                    value = 1 + (fraction * 9).rounded()
                                }
                        )
                }
                .frame(height: 26)
            }
            .frame(height: 26)

            HStack {
                Text(lowLabel)
                    .font(DinoTheme.captionFont())
                    .foregroundColor(DinoTheme.textSecondary)
                Spacer()
                Text(highLabel)
                    .font(DinoTheme.captionFont())
                    .foregroundColor(DinoTheme.textSecondary)
            }
        }
    }
}

// MARK: - Weekly Trend
struct WeeklyMoodTrend: View {
    @ObservedObject var viewModel: MoodViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("this week")
                .font(DinoTheme.dinoLabelFont(size: 14))
                .foregroundColor(DinoTheme.textSecondary)

            HStack(spacing: 0) {
                ForEach(viewModel.last7Days, id: \.self) { date in
                    let mood = viewModel.moodForDay(date)
                    VStack(spacing: 8) {
                        Text(mood?.emoji ?? "·")
                            .font(.system(size: mood != nil ? 28 : 16))

                        Text(dayLabel(date))
                            .font(DinoTheme.dinoFont(size: 11))
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .dsCardLarge()
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).lowercased()
    }
}
