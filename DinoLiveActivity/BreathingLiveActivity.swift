//
//  BreathingLiveActivity.swift
//  DinoLiveActivity
//
//  Calm, emotional Live Activity for breathing sessions — lock screen & Dynamic Island.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Breathing Live Activity Widget

struct BreathingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreathingActivityAttributes.self) { context in
            BreathingLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BreathingIslandLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BreathingIslandTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BreathingIslandBottom(context: context)
                }
            } compactLeading: {
                // Dino accent dot + phase
                HStack(spacing: 4) {
                    Circle()
                        .fill(BreathingColors.accent)
                        .frame(width: 8, height: 8)
                    Text(compactPhaseText(context.state.phase))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                Text(formatTime(context.state.secondsRemaining))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(BreathingColors.accent)
                    .monospacedDigit()
            } minimal: {
                ZStack {
                    Circle()
                        .stroke(BreathingColors.accent.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(BreathingColors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .padding(2)
            }
        }
    }

    private func compactPhaseText(_ phase: String) -> String {
        switch phase {
        case "Inhale": return "inhale"
        case "Hold":   return "hold"
        case "Exhale": return "exhale"
        default:       return "breathe"
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Theme-aware colors

private struct BreathingColors {
    private static var theme: WidgetTheme { WidgetTheme.current }

    static var accent: Color { theme.accent }
    static var textPrimary: Color { .white }
    static var textSecondary: Color { .white.opacity(0.7) }
    static var textMuted: Color { .white.opacity(0.5) }
    static var surfaceTint: Color { theme.accent.opacity(0.15) }

    static var backgroundGradient: [Color] {
        [theme.background.opacity(0.95), theme.accent.opacity(0.3)]
    }
}

// MARK: - Calming text

private func phaseDisplayText(_ phase: String) -> String {
    switch phase {
    case "Inhale": return "inhale"
    case "Hold":   return "hold"
    case "Exhale": return "exhale"
    default:       return "breathe"
    }
}

private func phaseSubtext(_ phase: String, isPaused: Bool) -> String {
    if isPaused {
        return ["pause and feel your breath", "take your time", "no rush, just be"].randomElement() ?? "take your time"
    }
    switch phase {
    case "Inhale": return "let it in slowly"
    case "Hold":   return "stay here"
    case "Exhale": return "let it all go"
    default:       return "just breathe"
    }
}

private func completionText() -> (title: String, subtitle: String) {
    let options: [(String, String)] = [
        ("you did it", "feel the calm"),
        ("well done", "carry this peace with you"),
        ("beautiful", "you showed up for yourself")
    ]
    return options.randomElement() ?? ("you did it", "feel the calm")
}

private func formatTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

// MARK: - Lock Screen View

struct BreathingLockScreenView: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        let isComplete = context.state.secondsRemaining <= 0 && !context.state.isPaused

        HStack(spacing: 16) {
            // Left: breathing ring with dino dot
            breathingRing

            // Center: phase text + calming subtext
            VStack(alignment: .leading, spacing: 4) {
                if isComplete {
                    let text = completionText()
                    Text(text.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(BreathingColors.textPrimary)
                    Text(text.subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(BreathingColors.textSecondary)
                } else {
                    Text(phaseDisplayText(context.state.phase))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(BreathingColors.textPrimary)

                    Text(phaseSubtext(context.state.phase, isPaused: context.state.isPaused))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(BreathingColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right: timer
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(context.state.secondsRemaining))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(BreathingColors.textPrimary)
                    .monospacedDigit()

                Text("cycle \(context.state.currentCycle)/\(context.state.totalCycles)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(BreathingColors.textMuted)
            }
        }
        .padding(18)
        .background(
            ZStack {
                LinearGradient(
                    colors: BreathingColors.backgroundGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle breathing glow behind the ring
                Circle()
                    .fill(BreathingColors.accent.opacity(context.state.isPaused ? 0.05 : 0.1))
                    .frame(width: 120, height: 120)
                    .blur(radius: 40)
                    .offset(x: -80, y: 0)
            }
        )
    }

    private var breathingRing: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(BreathingColors.accent.opacity(0.08))
                .frame(width: 62, height: 62)

            // Track ring
            Circle()
                .stroke(BreathingColors.accent.opacity(0.2), lineWidth: 3)
                .frame(width: 52, height: 52)

            // Progress ring
            Circle()
                .trim(from: 0, to: context.state.progress)
                .stroke(
                    BreathingColors.accent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))

            // Inner breathing circle — scales with phase
            Circle()
                .fill(BreathingColors.accent.opacity(0.25))
                .frame(width: breathCircleSize, height: breathCircleSize)

            // Dino dot
            Circle()
                .fill(BreathingColors.accent)
                .frame(width: 10, height: 10)
        }
    }

    private var breathCircleSize: CGFloat {
        switch context.state.phase {
        case "Inhale": return 30
        case "Hold":   return 30
        case "Exhale": return 16
        default:       return 20
        }
    }
}

// MARK: - Dynamic Island Expanded

struct BreathingIslandLeading: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        HStack(spacing: 8) {
            // Small breathing indicator
            ZStack {
                Circle()
                    .stroke(BreathingColors.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(BreathingColors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(BreathingColors.accent)
                    .frame(width: 6, height: 6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(phaseDisplayText(context.state.phase))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                if context.state.isPaused {
                    Text("paused")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text(phaseSubtext(context.state.phase, isPaused: false))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
        }
        .padding(.leading, 4)
    }
}

struct BreathingIslandTrailing: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formatTime(context.state.secondsRemaining))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            Text("cycle \(context.state.currentCycle)/\(context.state.totalCycles)")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.trailing, 4)
    }
}

struct BreathingIslandBottom: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        VStack(spacing: 6) {
            // Soft rounded progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 4)

                    Capsule()
                        .fill(BreathingColors.accent)
                        .frame(width: max(4, geo.size.width * context.state.progress), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 4)

            Text("breathe with dino")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Color Extension (shared across widget extension)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
