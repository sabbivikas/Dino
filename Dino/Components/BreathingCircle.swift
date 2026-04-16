//
//  BreathingCircle.swift
//  Dino
//

import SwiftUI

struct BreathingCircle: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let scale: CGFloat
    let opacity: Double
    let phase: BreathingPhase
    let countdown: Int

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(DinoTheme.sageGreen.opacity(opacity * 0.2))
                .scaleEffect(scale * 1.3)

            // Mid ring
            Circle()
                .fill(DinoTheme.sageGreen.opacity(opacity * 0.4))
                .scaleEffect(scale * 1.1)

            // Main circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DinoTheme.sageGreen.opacity(opacity), DinoTheme.skyBlue.opacity(opacity * 0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(scale)

            // Phase label & countdown
            VStack(spacing: 6) {
                Text(phase.label)
                    .font(DinoTheme.dinoFont(size: 17))
                    .foregroundColor(.white)

                Text("\(countdown)")
                    .font(DinoTheme.dinoFont(size: 28))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(width: 220, height: 220)
    }
}
