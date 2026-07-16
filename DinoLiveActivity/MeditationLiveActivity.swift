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
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#F5E9C4"))
                        .frame(width: 22, height: 22)
                    Text("stillness")
                        .font(.custom("DinoInitiativeFont-Regular", size: 14))
                        .foregroundColor(Color(hex: "#F5E9C4"))
                }
            } compactTrailing: {
                Text(formatMeditationTime(context.state.secondsRemaining))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#F5E9C4"))
                    .monospacedDigit()
            } minimal: {
                Circle()
                    .fill(Color(hex: "#F5E9C4"))
                    .frame(width: 24, height: 24)
                    .shadow(color: Color(hex: "#F5E9C4").opacity(0.6), radius: 4)
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
    return String(localized: "\(minute)m")
}

private func sessionTitle(isPaused: Bool) -> String {
    isPaused ? String(localized: "paused") : String(localized: "meditating")
}

// MARK: - Dino on Moon (scene composite)

private struct MeditationScene: View {
    var moonSize: CGFloat
    var dinoSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing: Bool = false

    var body: some View {
        ZStack {
            // v5 spec: three concentric lavender halos behind the moon
            Circle()
                .stroke(Color(hex: "#BAA9DB").opacity(0.32), lineWidth: 1)
                .frame(width: moonSize * 1.4, height: moonSize * 1.4)
            Circle()
                .stroke(Color(hex: "#BAA9DB").opacity(0.22), lineWidth: 1)
                .frame(width: moonSize * 1.7, height: moonSize * 1.7)
            Circle()
                .stroke(Color(hex: "#BAA9DB").opacity(0.14), lineWidth: 1)
                .frame(width: moonSize * 2.0, height: moonSize * 2.0)

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

// MARK: - Minute dots (progress row)

private struct MinuteDotsRow: View {
    let progress: Double

    var body: some View {
        let active = Int((max(0.0, min(1.0, progress)) * 8.0).rounded())
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { i in
                if i < active {
                    Circle()
                        .fill(Color(hex: "#F5E9C4"))
                        .frame(width: 7, height: 7)
                } else {
                    Circle()
                        .stroke(Color(hex: "#BAA9DB").opacity(0.5), lineWidth: 1)
                        .frame(width: 7, height: 7)
                }
            }
        }
    }
}

// MARK: - Lock screen

struct MeditationLockScreenView: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        ZStack {
            NightBackground()

            HStack(alignment: .top, spacing: 10) {
                // Left: scene (88 × 112)
                MeditationScene(moonSize: 86, dinoSize: 44)
                    .frame(width: 88, height: 112)

                // Middle: title + whisper + session pill
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionTitle(isPaused: context.state.isPaused))
                        .font(.custom("DinoInitiativeFont-Regular", size: 30))
                        .foregroundColor(Color(hex: "#F5E9C4"))
                        .lineLimit(1)

                    Text(context.state.calmMessage)
                        .font(.custom("DinoInitiativeFont-Regular", size: 14))
                        .foregroundColor(Color(hex: "#F5E9C4").opacity(0.78))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "#BAA9DB"))
                            .frame(width: 5, height: 5)
                        Text(context.state.isPaused ? String(localized: "paused") : String(localized: "meditating"))
                            .font(.custom("DinoInitiativeFont-Regular", size: 12))
                            .foregroundColor(Color(hex: "#F5E9C4"))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#BAA9DB").opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#BAA9DB").opacity(0.4), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: timer + remaining label + minute dots
                VStack(alignment: .trailing, spacing: 6) {
                    Text(formatMeditationTime(context.state.secondsRemaining))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#F5E9C4"))
                        .monospacedDigit()

                    Text("remaining")
                        .font(.custom("DinoInitiativeFont-Regular", size: 13))
                        .foregroundColor(Color(hex: "#F5E9C4").opacity(0.65))

                    MinuteDotsRow(progress: context.state.progress)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 16))
        }
        .frame(height: 136)
    }
}

// MARK: - Dynamic Island regions

struct MeditationIslandLeading: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        ZStack {
            MoonView(size: 58)
            Image("dino-meditation")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 30)
                .offset(y: 12)
        }
        .frame(width: 72, height: 58)
        .padding(.leading, 4)
    }
}

struct MeditationIslandTrailing: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(formatMeditationTime(context.state.secondsRemaining))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "#F5E9C4"))
                .monospacedDigit()
            Text("\(max(1, context.attributes.totalDurationSeconds / 60)) min")
                .font(.custom("DinoInitiativeFont-Regular", size: 11))
                .foregroundColor(Color(hex: "#BAA9DB").opacity(0.7))
        }
        .padding(.trailing, 4)
    }
}

struct MeditationIslandCenter: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sessionTitle(isPaused: context.state.isPaused))
                .font(.custom("DinoInitiativeFont-Regular", size: 22))
                .foregroundColor(Color(hex: "#F5E9C4"))
                .lineLimit(1)
            Text(context.state.calmMessage)
                .font(.custom("DinoInitiativeFont-Regular", size: 13).italic())
                .foregroundColor(Color(hex: "#BAA9DB").opacity(0.85))
                .lineLimit(1)
        }
    }
}

struct MeditationIslandBottom: View {
    let context: ActivityViewContext<MeditationActivityAttributes>

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "#BAA9DB").opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#BAA9DB"), Color(hex: "#F5E9C4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(2, geo.size.width * max(0.0, min(1.0, context.state.progress))),
                            height: 4
                        )
                }
            }
            .frame(height: 4)

            HStack {
                Text("evening stillness")
                Spacer()
                Text("stillness · dino")
            }
            .font(.custom("DinoInitiativeFont-Regular", size: 11))
            .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}
