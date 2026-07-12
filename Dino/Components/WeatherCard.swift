//
//  WeatherCard.swift
//  Dino
//
//  A mood as a small paper card: cream stock with shader grain, hairline
//  edge, the hand-drawn weather glyph. Choosing one lifts it off the desk —
//  alternating tilt, sage tape, deeper shadow, a spring with a little
//  overshoot. Heavy moods lift SOFTER than light ones (dimmer tape, gentler
//  rise): picking a hard day should never feel chirpy.
//

import SwiftUI

struct WeatherCard: View {
    let weather: EmotionalWeather
    let isSelected: Bool
    /// grid position — drives the alternating tilt direction
    var index: Int = 0
    let onTap: () -> Void

    private var weatherColor: Color { Color(hex: weather.color) }
    private var heavy: Bool { weather == .overwhelmed || weather == .drained }

    private var tilt: Double {
        guard isSelected else { return 0 }
        let magnitude = heavy ? 1.0 : 1.4
        return index.isMultiple(of: 2) ? magnitude : -magnitude
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                DinoWeatherGlyph(weather: weather, size: 46, muted: !isSelected)

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
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(hex: "#FFFDF6"))
                    // the same paper fiber as the comfort slip — static, never boils
                    .colorEffect(ShaderLibrary.dinoPaperGrain(.float(0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(weatherColor.opacity(isSelected ? 0.09 : 0))
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color(hex: "#EFE7D2"), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                if isSelected {
                    TapeStrip(dimmed: heavy)
                        .offset(y: -8)
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                }
            }
            .rotationEffect(.degrees(tilt))
            .scaleEffect(isSelected ? (heavy ? 1.02 : 1.035) : 1.0)
            .shadow(
                color: Color(red: 40/255, green: 30/255, blue: 15/255)
                    .opacity(isSelected ? (heavy ? 0.11 : 0.16) : 0.05),
                radius: isSelected ? (heavy ? 9 : 13) : 5,
                y: isSelected ? 7 : 3
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isSelected)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(weather.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// the choosing mark — always sage, dimmer over heavy skies
private struct TapeStrip: View {
    let dimmed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(red: 168/255, green: 197/255, blue: 160/255).opacity(dimmed ? 0.45 : 0.78))
            .overlay(
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    while x < size.width + size.height {
                        ctx.fill(Path(CGRect(x: x, y: -2, width: 3.5, height: size.height + 4)),
                                 with: .color(.white.opacity(0.22)))
                        x += 7
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            )
            .frame(width: 64, height: 16)
            .rotationEffect(.degrees(-4))
            .shadow(color: Color(red: 40/255, green: 30/255, blue: 15/255).opacity(0.10), radius: 1, y: 1)
            .accessibilityHidden(true)
    }
}
