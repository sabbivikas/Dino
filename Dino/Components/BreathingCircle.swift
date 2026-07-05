//
//  BreathingCircle.swift
//  Dino
//

import SwiftUI

struct BreathingCircle: View {
    let scale: CGFloat
    let opacity: Double
    let label: String
    let countdown: Int
    let accent: Color
    /// steady square holds: fills one quarter per count; nil hides the ring
    let quarterRingProgress: Double?
    /// big sigh exhale: the mid ring thins slightly as the breath empties
    let emptying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tickScale: CGFloat = 1.0

    // Map VM scale (0.6→1.1) to design system scale (1.0→1.08); the big
    // sigh's 1.15 top up intentionally swells a hair past the usual peak.
    private var breatheScale: CGFloat {
        1.0 + (normalized * 0.08)
    }

    private var normalized: CGFloat {
        (scale - 0.6) / 0.5
    }

    private var midRingOpacity: Double {
        emptying ? 0.30 + 0.15 * Double(normalized) : 0.45
    }

    var body: some View {
        ZStack {
            // Outer glow — 200pt, sage green 25%
            Circle()
                .fill(DinoTheme.sageGreen.opacity(0.25))
                .frame(width: 200, height: 200)
                .scaleEffect(breatheScale)

            // Mid ring — 160pt, sage green, 0.5s delay feel via slightly dampened scale
            Circle()
                .fill(DinoTheme.sageGreen.opacity(midRingOpacity))
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

            // Steady square hold ring — one quarter arc per count
            if let progress = quarterRingProgress {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accent.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 196, height: 196)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.35), value: progress)
                    .transition(.opacity)
            }

            // Phase label & countdown
            VStack(spacing: 6) {
                ZStack {
                    Text(label)
                        .font(DinoTheme.dinoFont(size: 19))
                        .foregroundColor(.white)
                        .id(label)
                        .transition(.opacity)
                }
                .frame(minHeight: 26)   // grows with the boosted baseline
                .animation(.easeInOut(duration: 0.3), value: label)

                Text("\(countdown)")
                    .font(DinoTheme.numericFont(size: 32))
                    .foregroundColor(.white.opacity(0.95))
                    .scaleEffect(tickScale)
            }
        }
        .opacity(opacity)
        .frame(width: 220, height: 220)
        .onChange(of: countdown) { _, _ in
            guard !reduceMotion else { return }
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) { tickScale = 1.05 }
            withAnimation(.easeOut(duration: 0.3)) { tickScale = 1.0 }
        }
    }
}
