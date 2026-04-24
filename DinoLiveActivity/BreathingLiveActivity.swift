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
                CanvasDinoBreathing()
                    .frame(width: 18, height: 18)
                    .background(.clear)
            } compactTrailing: {
                Text("\(context.state.currentCycle)/\(context.state.totalCycles)")
                    .font(.custom("DinoInitiativeFont-Regular", size: 18))
                    .foregroundColor(DinoPalette.laInk)
            } minimal: {
                ZStack {
                    Circle()
                        .stroke(DinoPalette.laSageRing.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: max(0.0, min(1.0, context.state.progress)))
                        .stroke(DinoPalette.laSageRing, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 14, height: 14)
            }
        }
    }
}

// MARK: - Helpers

private func phaseDisplayText(_ phase: String) -> String {
    switch phase {
    case "Inhale": return "inhale"
    case "Hold":   return "hold"
    case "Exhale": return "exhale"
    default:       return "breathe"
    }
}

private func phaseCueText(_ phase: String, isPaused: Bool) -> String {
    if isPaused { return "take your time" }
    switch phase {
    case "Inhale": return "smell the flowers"
    case "Hold":   return "hold the calm"
    case "Exhale": return "release and let go"
    default:       return "breathe with dino"
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
    guard !parts.isEmpty else { return "\(sessionType) rhythm" }
    return parts.joined(separator: " · ") + " rhythm"
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
        CanvasDinoBreathing()
            .frame(width: size, height: size)
            .background(.clear)
            .shadow(color: Color(hex: "#11402D").opacity(0.18), radius: 2, x: 0, y: 2)
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
        ZStack {
            Circle()
                .stroke(DinoPalette.laSageRing.opacity(0.45), lineWidth: 1.2)
                .frame(width: 66, height: 66)
            CanvasDinoBreathing()
                .frame(width: 64, height: 64)
                .background(.clear)
        }
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
                .foregroundColor(DinoPalette.laHillFar)
        }
        .padding(.trailing, 4)
    }
}

struct BreathingIslandCenter: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phaseDisplayText(context.state.phase))
                .font(.custom("DinoInitiativeFont-Regular", size: 24))
                .foregroundColor(DinoPalette.laHillFar)
            Text(phaseCueText(context.state.phase, isPaused: context.state.isPaused))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
        }
    }
}

struct BreathingIslandBottom: View {
    let context: ActivityViewContext<BreathingActivityAttributes>

    var body: some View {
        VStack(spacing: 4) {
            CycleDotsRow(total: context.state.totalCycles, current: context.state.currentCycle)
            HStack {
                Text(patternText(context.attributes.sessionType))
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
// Canvas-drawn dino used in place of the DinoFlower-cut image asset.
// Scales to the frame it's given; no bitmap assets involved.
private struct CanvasDinoBreathing: View {
    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let ox = (canvasSize.width - s) / 2
            let oy = (canvasSize.height - s) / 2
            let green = Color(red: 17.0 / 255.0, green: 64.0 / 255.0, blue: 45.0 / 255.0)
            let white = Color.white
            let black = Color.black
            let stroke: CGFloat = max(0.8, min(2.0, s / 56.0 * 2.0))

            // Spikes (drawn first so the body covers their base)
            var spikes = Path()
            let spikeTopY = oy + 0.15 * s
            let spikeBaseY = oy + 0.36 * s
            let halfW = 0.06 * s
            for cx in [0.35, 0.50, 0.65] {
                let x = ox + cx * s
                spikes.move(to: CGPoint(x: x - halfW, y: spikeBaseY))
                spikes.addLine(to: CGPoint(x: x, y: spikeTopY))
                spikes.addLine(to: CGPoint(x: x + halfW, y: spikeBaseY))
                spikes.closeSubpath()
            }
            context.fill(spikes, with: .color(green))
            context.stroke(spikes, with: .color(green), lineWidth: stroke)

            // White oval body
            let bodyRect = CGRect(x: ox + 0.15 * s, y: oy + 0.32 * s, width: 0.70 * s, height: 0.56 * s)
            let body = Path(ellipseIn: bodyRect)
            context.fill(body, with: .color(white))
            context.stroke(body, with: .color(green), lineWidth: stroke)

            // Dot eyes
            let eyeR = max(0.8, 0.04 * s)
            for ex in [0.42, 0.58] {
                let eye = Path(ellipseIn: CGRect(
                    x: ox + ex * s - eyeR,
                    y: oy + 0.52 * s - eyeR,
                    width: eyeR * 2, height: eyeR * 2))
                context.fill(eye, with: .color(black))
            }

            // Smile
            var smile = Path()
            smile.move(to: CGPoint(x: ox + 0.43 * s, y: oy + 0.66 * s))
            smile.addQuadCurve(
                to: CGPoint(x: ox + 0.57 * s, y: oy + 0.66 * s),
                control: CGPoint(x: ox + 0.50 * s, y: oy + 0.72 * s))
            context.stroke(smile, with: .color(green), lineWidth: stroke)
        }
    }
}

