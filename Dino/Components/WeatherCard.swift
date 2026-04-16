//
//  WeatherCard.swift
//  Dino
//

import SwiftUI

struct WeatherCard: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let weather: EmotionalWeather
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(weather.emoji)
                    .font(DinoTheme.dinoFont(size: 32))

                Text(weather.label)
                    .font(DinoTheme.captionFont())
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? DinoTheme.textPrimary : DinoTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected
                    ? Color(hex: weather.color).opacity(0.25)
                    : DinoTheme.surfacePrimary
            )
            .cornerRadius(DinoTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                    .strokeBorder(
                        isSelected ? Color(hex: weather.color) : DinoTheme.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
