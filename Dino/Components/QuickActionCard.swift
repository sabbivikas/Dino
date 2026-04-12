//
//  QuickActionCard.swift
//  Dino
//

import SwiftUI

struct QuickActionCard: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(color)

                Text(label)
                    .font(DinoTheme.captionFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                color.opacity(0.12)
                    .cornerRadius(DinoTheme.cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                    .stroke(color.opacity(0.25), lineWidth: 1)
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
