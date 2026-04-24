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

            CanvasDinoMeditation()
                .frame(width: dinoSize, height: dinoSize)
                .background(.clear)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
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
// Canvas-drawn meditation dino used in place of the dino-meditation image asset.
// Scales to the frame it's given; no bitmap assets involved.
private struct CanvasDinoMeditation: View {
    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let ox = (canvasSize.width - s) / 2
            let oy = (canvasSize.height - s) / 2
            let green = Color(red: 17.0 / 255.0, green: 64.0 / 255.0, blue: 45.0 / 255.0)
            let white = Color.white
            let stroke: CGFloat = max(0.8, min(2.0, s / 56.0 * 2.0))

            // Spikes (drawn first so the body covers their base)
            var spikes = Path()
            let spikeTopY = oy + 0.10 * s
            let spikeBaseY = oy + 0.30 * s
            let halfW = 0.05 * s
            for cx in [0.38, 0.50, 0.62] {
                let x = ox + cx * s
                spikes.move(to: CGPoint(x: x - halfW, y: spikeBaseY))
                spikes.addLine(to: CGPoint(x: x, y: spikeTopY))
                spikes.addLine(to: CGPoint(x: x + halfW, y: spikeBaseY))
                spikes.closeSubpath()
            }
            context.fill(spikes, with: .color(green))
            context.stroke(spikes, with: .color(green), lineWidth: stroke)

            // Wider white oval body (seated)
            let bodyRect = CGRect(x: ox + 0.10 * s, y: oy + 0.28 * s, width: 0.80 * s, height: 0.60 * s)
            let body = Path(ellipseIn: bodyRect)
            context.fill(body, with: .color(white))
            context.stroke(body, with: .color(green), lineWidth: stroke)

            // Meditation-pose arm curves extending slightly out
            var leftArm = Path()
            leftArm.move(to: CGPoint(x: ox + 0.18 * s, y: oy + 0.56 * s))
            leftArm.addQuadCurve(
                to: CGPoint(x: ox + 0.06 * s, y: oy + 0.72 * s),
                control: CGPoint(x: ox + 0.06 * s, y: oy + 0.62 * s))
            context.stroke(leftArm, with: .color(green), lineWidth: stroke)

            var rightArm = Path()
            rightArm.move(to: CGPoint(x: ox + 0.82 * s, y: oy + 0.56 * s))
            rightArm.addQuadCurve(
                to: CGPoint(x: ox + 0.94 * s, y: oy + 0.72 * s),
                control: CGPoint(x: ox + 0.94 * s, y: oy + 0.62 * s))
            context.stroke(rightArm, with: .color(green), lineWidth: stroke)

            // Closed peaceful eyes (∩ arcs)
            for ex in [0.40, 0.60] {
                var eye = Path()
                let cx = ox + ex * s
                let cy = oy + 0.50 * s
                eye.move(to: CGPoint(x: cx - 0.05 * s, y: cy))
                eye.addQuadCurve(
                    to: CGPoint(x: cx + 0.05 * s, y: cy),
                    control: CGPoint(x: cx, y: cy - 0.04 * s))
                context.stroke(eye, with: .color(green), lineWidth: stroke)
            }

            // Small smile (∪ arc)
            var smile = Path()
            smile.move(to: CGPoint(x: ox + 0.44 * s, y: oy + 0.64 * s))
            smile.addQuadCurve(
                to: CGPoint(x: ox + 0.56 * s, y: oy + 0.64 * s),
                control: CGPoint(x: ox + 0.50 * s, y: oy + 0.70 * s))
            context.stroke(smile, with: .color(green), lineWidth: stroke)
        }
    }
}

