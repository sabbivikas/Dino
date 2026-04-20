//
//  QuickActionCard.swift
//  Dino
//

import SwiftUI

struct QuickActionCard: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DinoTheme.iconCircleBackground)
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(DinoTheme.dinoFont(size: 22))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(DinoTheme.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(DinoTheme.surfacePrimary)
            .cornerRadius(DinoTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                    .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
