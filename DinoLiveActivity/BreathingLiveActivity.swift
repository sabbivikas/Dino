//
//  BreathingLiveActivity.swift
//  DinoLiveActivity
//
//  v6 redesign: sage meadow, dino holding a flower, breathing hoops, pattern pill.
//  Lock-screen layout fits a 374x136 budget with ~16pt horizontal safe margins.
//  Reduce Motion falls back to a static frame.
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
                DynamicIslandExpandedRegion(.center) {
                    BreathingIslandCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BreathingIslandBottom(context: context)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image("DinoFlower-cut")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 24)
                    Text(phaseDisplayText(context.state.phase))
                        .font(.custom("DinoInitiativeFont-Regular", size: 14))
                        .foregroundColor(Color(hex: "#B9D3A8"))
                }
            } compactTrailing: {
                Text(formatBreathingTime(context.state.secondsRemaining))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#B9D3A8"))
                    .monospacedDigit()
            } minimal: {
                Image("DinoFlower-cut")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 26)
            }
        }
    }
}

// MARK: - Helpers

private func phaseDisplayText(_ phase: String) -> String {
    switch phase {
    case "Inhale": return String(localized: "inhale")
    case "Hold":   return String(localized: "hold")
    case "Exhale": return String(localized: "exhale")
    default:       return String(localized: "breathe")
    }
}

private func phaseCueText(_ phase: String, isPaused: Bool) -> String {
    if isPaused { return String(localized: "take your time") }
    switch phase {
    case "Inhale": return String(localized: "smell the flowers")
    case "Hold":   return String(localized: "hold the calm")
    case "Exhale": return String(localized: "release and let go")
    default:       return String(localized: "breathe with dino")
    }
}

private func formatBreathingTime(_ seconds: Int) -> String {
    let clamped = max(0, seconds)
    let m = clamped / 60
    let s = clamped % 60
    return String(format: "%d:%02d", m, s)
}

private func patternText(_ sessionType: String) -> String {
    // "4-7-8" -> "4 · 7 · 8 rhythm"
    let parts = sessionType.split(separator: "-")
    guard !parts.isEmpty else { return String(localized: "\(sessionType) rhythm") }
    return String(localized: "\(parts.joined(separator: " · ")) rhythm")
}

// MARK: - Pattern Pill

private struct PatternPill: View {
    let sessionType: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(DinoPalette.laCuePeach)
                .frame(width: 6, height: 6)
            Text(patternText(sessionType))
                .font(.custom("DinoInitiativeFont-Regular", size: 12))
                .foregroundColor(DinoPalette.laInk)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(Color(hex: "#11402D").opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 999))
    }
}

// MARK: - Dino w/ sway

private struct DinoBreathingMascot: View {
    var size: CGFloat = 112

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swaying: Bool = false

    var body: some View {
        Image("DinoFlower-cut")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(.clear)
            .rotationEffect(.degrees(reduceMotion ? 0 : (swaying ? 1.4 : -1.4)))
            .offset(y: reduceMotion ? 0 : (swaying ? -3 : 0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
                    swaying = true
                }
            }
    }
}

// MARK: - Lock Screen

struct BreathingLockScreenView: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        ZStack {
            MeadowBackground()

            HStack(alignment: .center, spacing: 12) {
                // Left column: hoops + dino
                ZStack {
                    BreathingHoops()
                    DinoBreathingMascot(size: 112)
                }
                .frame(width: 112, height: 112)

                // Center: text
                VStack(alignment: .leading, spacing: 4) {
                    Text(phaseDisplayText(context.state.phase))
                        .font(.custom("DinoInitiativeFont-Regular", size: 34))
                        .kerning(-0.5)
                        .foregroundColor(DinoPalette.laInk)
                        .lineLimit(1)

                    Text(phaseCueText(context.state.phase, isPaused: context.state.isPaused))
                        .font(.system(.callout))
                        .foregroundColor(DinoPalette.laCueText.opacity(0.9))
                        .lineLimit(1)

                    PatternPill(sessionType: context.attributes.sessionType)
                        .padding(.top, 2)
                }

                Spacer(minLength: 4)

                // Right: timer + cycle dots
                VStack(alignment: .trailing, spacing: 6) {
                    Text(formatBreathingTime(context.state.secondsRemaining))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundColor(DinoPalette.laInk)
                        .monospacedDigit()

                    CycleDotsRow(total: context.state.totalCycles, current: context.state.currentCycle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(height: 136)
    }
}

// MARK: - Dynamic Island

struct BreathingIslandLeading: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        Image("DinoFlower-cut")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(height: 62)
            .shadow(color: Color(hex: "#B9D3A8").opacity(0.55), radius: 4)
            .frame(width: 72, alignment: .center)
            .padding(.leading, 4)
    }
}

struct BreathingIslandTrailing: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(formatBreathingTime(context.state.secondsRemaining))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text("\(context.state.currentCycle)/\(context.state.totalCycles)")
                .font(.custom("DinoInitiativeFont-Regular", size: 11))
                .foregroundColor(Color(hex: "#B9D3A8").opacity(0.85))
        }
        .padding(.trailing, 4)
    }
}

struct BreathingIslandCenter: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(phaseDisplayText(context.state.phase))
                .font(.custom("DinoInitiativeFont-Regular", size: 24))
                .foregroundColor(Color(hex: "#B9D3A8"))
                .lineLimit(1)
            Text(phaseCueText(context.state.phase, isPaused: context.state.isPaused))
                .font(.custom("DinoInitiativeFont-Regular", size: 13))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
        }
    }
}

struct BreathingIslandBottom: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    private var sessionProgress: Double {
        let total = max(1, context.state.totalCycles)
        let phase = max(0.0, min(1.0, context.state.progress))
        let cycles = Double(max(0, context.state.currentCycle - 1)) + phase
        return max(0.0, min(1.0, cycles / Double(total)))
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "#B9D3A8").opacity(0.18))
                        .frame(height: 4)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#B9D3A8"), Color(hex: "#E8B4B8")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * sessionProgress), height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text(context.attributes.sessionType.split(separator: "-").joined(separator: " · "))
                Spacer()
                Text("breathe with dino")
            }
            .font(.custom("DinoInitiativeFont-Regular", size: 11))
            .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

// MARK: - Color Hex (shared across widget extension)
// Keep this here — both LA files referenced it in the legacy code and other
// files in this target rely on it being in this file.

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
