//
//  BreathingCircle.swift
//  Dino
//

import SwiftUI

struct BreathingCircle: View {
    let scale: CGFloat
    let opacity: Double
    let phase: BreathingPhase
    let countdown: Int

    // Map VM scale (0.6→1.1) to design system scale (1.0→1.08)
    private var breatheScale: CGFloat {
        let normalized = (scale - 0.6) / 0.5 // 0.0 → 1.0
        return 1.0 + (normalized * 0.08)      // 1.0 → 1.08
    }

    var body: some View {
        ZStack {
            // Outer glow — 200pt, sage green 25%
            Circle()
                .fill(DinoTheme.sageGreen.opacity(0.25))
                .frame(width: 200, height: 200)
                .scaleEffect(breatheScale)

            // Mid ring — 160pt, sage green 45%, 0.5s delay feel via slightly dampened scale
            Circle()
                .fill(DinoTheme.sageGreen.opacity(0.45))
                .frame(width: 160, height: 160)
                .scaleEffect(1.0 + ((breatheScale - 1.0) * 0.85))

            // Main circle — 120pt, sage→sky gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#A8C5A0"), Color(hex: "#A8D4E6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: DinoTheme.sageGreen.opacity(0.35), radius: 24, y: 4)

            // Phase label & countdown
            VStack(spacing: 6) {
                Text(phase.label)
                    .font(.custom(DinoTheme.customFontName, size: 19))
                    .foregroundColor(.white)

                Text("\(countdown)")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .frame(width: 220, height: 220)
    }
}
