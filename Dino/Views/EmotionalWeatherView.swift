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
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 6) {
                        Text("what's your emotional weather today?")
                            .font(DinoTheme.dinoDisplayFont(size: 22))
                            .foregroundColor(DinoTheme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, DinoTheme.padding)

                    // Weather cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(EmotionalWeather.allCases, id: \.self) { weather in
                            WeatherCard(
                                weather: weather,
                                isSelected: viewModel.selectedWeather == weather,
                                onTap: {
                                    withAnimation(.spring(response: 0.3)) {
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
                            .padding(.vertical, 12)
                            .background(DinoTheme.sageGreen.opacity(0.1).cornerRadius(DinoTheme.cornerRadius))
                            .padding(.horizontal, DinoTheme.padding)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }

                    // Sliders
                    VStack(spacing: 20) {
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
                    .dinoCardWhite()
                    .padding(.horizontal, DinoTheme.padding)

                    // Save button
                    Button(action: { viewModel.saveMood() }) {
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
                        .padding(.vertical, 16)
                        .background(
                            viewModel.saved ? DinoTheme.sageGreen : (viewModel.selectedWeather == nil ? DinoTheme.textSecondary : DinoTheme.skyBlue)
                        )
                        .cornerRadius(DinoTheme.cornerRadius)
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
            .background(DinoTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarHidden(true)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(DinoTheme.textPrimary)
                Spacer()
                Text("\(Int(value.rounded()))/10")
                    .font(DinoTheme.subheadlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            Slider(value: $value, in: 1...10, step: 1)
                .tint(color)

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
                .font(DinoTheme.headlineFont())
                .foregroundColor(DinoTheme.textPrimary)

            HStack(spacing: 0) {
                ForEach(viewModel.last7Days, id: \.self) { date in
                    VStack(spacing: 6) {
                        Text(viewModel.moodForDay(date)?.emoji ?? "·")
                            .font(.system(size: viewModel.moodForDay(date) != nil ? 22 : 16))

                        Text(dayLabel(date))
                            .font(DinoTheme.caption2Font())
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(DinoTheme.cardBackground)
            .cornerRadius(DinoTheme.cornerRadius)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).lowercased()
    }
}
