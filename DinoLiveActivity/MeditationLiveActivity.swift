//
//  MeditationLiveActivity.swift
//  DinoLiveActivity
//
//  v6 redesign: moonlit stillness. Hand-drawn moon w/ craters, drifting stars,
//  slow ripples, and a sleeping-dino asset below. Respects Reduce Motion.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget

struct MeditationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationActivityAttributes.self) { context in
            MeditationLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MeditationIslandLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MeditationIslandTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    MeditationIslandCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    MeditationIslandBottom(context: context)
                }
            } compactLeading: {
                // Lightweight moon icon (stroke + fill), no SwiftUI animations.
                Circle()
                    .fill(DinoPalette.laMoonFace)
                    .overlay(Circle().stroke(DinoPalette.laMoonStroke, lineWidth: 1.2))
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                Text(meditationTrailingText(context.state.secondsRemaining))
                    .font(.custom("DinoInitiativeFont-Regular", size: 18))
                    .foregroundColor(DinoPalette.laMoonFace)
                    .monospacedDigit()
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

private func formatMeditationTime(_ seconds: Int) -> String {
    let clamped = max(0, seconds)
    let m = clamped / 60
    let s = clamped % 60
    return String(format: "%02d:%02d", m, s)
}

private func meditationTrailingText(_ secondsRemaining: Int) -> String {
    // Current minute of the session — compact trailing display.
    let clamped = max(0, secondsRemaining)
    let minute = clamped / 60
    return "\(minute)m"
}

private func sessionTitle(isPaused: Bool) -> String {
    isPaused ? "paused" : "meditating"
}

// MARK: - Dino on Moon (scene composite)

private struct MeditationScene: View {
    var moonSize: CGFloat
    var dinoSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing: Bool = false

    var body: some View {
        ZStack {
            MoonView(size: moonSize)

            Image("dino-meditation")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: dinoSize, height: dinoSize)
                .background(.clear)
                .scaleEffect(reduceMotion ? 1.0 : (breathing ? 1.03 : 0.97))
                .offset(y: moonSize * 0.16)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                        breathing = true
                    }
                }
        }
        .frame(width: moonSize * 1.3, height: moonSize * 1.3)
    }
}

// MARK: - Progress bar

private struct MeditationProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DinoPalette.laMoonFace.opacity(0.18))
                    .frame(height: 3)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [DinoPalette.laProgressFillStart, DinoPalette.laProgressFillEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(2, geo.size.width * max(0.0, min(1.0, progress))),
                        height: 3
                    )
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Lock screen

struct MeditationLockScreenView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        ZStack {
            NightBackground()

            HStack(alignment: .center, spacing: 14) {
                // Scene: moon + dino
                MeditationScene(moonSize: 72, dinoSize: 56)
                    .frame(width: 96, height: 104)

                // Text column
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionTitle(isPaused: context.state.isPaused))
                        .font(.custom("DinoInitiativeFont-Regular", size: 30))
                        .foregroundColor(DinoPalette.laMoonFace)
                        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                        .lineLimit(1)

                    Text(context.state.calmMessage)
                        .font(.system(size: 16).italic())
                        .foregroundColor(DinoPalette.laMoonFace.opacity(0.78))
                        .lineLimit(2)

                    Spacer(minLength: 2)

                    HStack(alignment: .center, spacing: 8) {
                        MeditationProgressBar(progress: context.state.progress)
                        Text(formatMeditationTime(context.state.secondsRemaining))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(DinoPalette.laMoonFace)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 136)
    }
}

// MARK: - Dynamic Island regions

struct MeditationIslandLeading: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        MeditationScene(moonSize: 48, dinoSize: 32)
            .frame(width: 62, height: 62)
            .padding(.leading, 4)
    }
}

struct MeditationIslandTrailing: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(formatMeditationTime(context.state.secondsRemaining))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(DinoPalette.laMoonFace)
                .monospacedDigit()
            Text("stillness")
                .font(.custom("DinoInitiativeFont-Regular", size: 11))
                .foregroundColor(DinoPalette.laProgressFillStart.opacity(0.85))
        }
        .padding(.trailing, 4)
    }
}

struct MeditationIslandCenter: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sessionTitle(isPaused: context.state.isPaused))
                .font(.custom("DinoInitiativeFont-Regular", size: 22))
                .foregroundColor(DinoPalette.laMoonFace)
            Text(context.state.calmMessage)
                .font(.system(size: 12).italic())
                .foregroundColor(DinoPalette.laProgressFillStart.opacity(0.85))
                .lineLimit(1)
        }
    }
}

struct MeditationIslandBottom: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        MeditationProgressBar(progress: context.state.progress)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
    }
}
