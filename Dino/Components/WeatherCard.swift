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

    private var weatherColor: Color { Color(hex: weather.color) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Text(weather.emoji)
                    .font(.system(size: 40))

                Text(weather.label)
                    .font(DinoTheme.dinoLabelFont(size: 13))
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? DinoTheme.textPrimary : DinoTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 90)
            .padding(.vertical, DinoDesignSystem.space5)
            .background(
                isSelected
                    ? weatherColor.opacity(0.25)
                    : weatherColor.opacity(0.08)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? weatherColor : weatherColor.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? weatherColor.opacity(0.15) : Color.black.opacity(0.04),
                radius: isSelected ? 12 : 8,
                y: DinoDesignSystem.cardShadowY
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
