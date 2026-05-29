//
//  OnboardingAmbientEffects.swift
//  Dino
//
//  Step-specific ambient overlays (background/animation only).
//

import SwiftUI

// MARK: - Step 1: Feeling color wash

struct OnboardingFeelingColorWash: View {
    let selectedFeeling: String

    private var washColor: Color {
        switch selectedFeeling {
        case "doing great!":
            return Color(hex: "#FDE8D0")
        case "ongoing mental health challenges":
            return Color(hex: "#C8E6F5")
        case "having a hard time getting over something":
            return Color(hex: "#E8E0F5")
        default:
            return .clear
        }
    }

    var body: some View {
        washColor
            .opacity(selectedFeeling.isEmpty ? 0 : 0.42)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: selectedFeeling)
            .allowsHitTesting(false)
    }
}

// MARK: - Step 3: Floating hearts (screen ambient)

struct OnboardingEncouragementHeartsAmbient: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct HeartParticle {
        let xFactor: CGFloat
        let size: CGFloat
        let delay: Double
        let drift: CGFloat
    }

    private static let hearts: [HeartParticle] = [
        HeartParticle(xFactor: 0.15, size: 5, delay: 0, drift: -12),
        HeartParticle(xFactor: 0.38, size: 6, delay: 1.2, drift: 8),
        HeartParticle(xFactor: 0.62, size: 4, delay: 2.4, drift: -6),
        HeartParticle(xFactor: 0.85, size: 5.5, delay: 3.6, drift: 14)
    ]

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    ZStack {
                        ForEach(0..<Self.hearts.count, id: \.self) { i in
                            let h = Self.hearts[i]
                            let period: Double = 6.0
                            let raw = ((t - h.delay) / period).truncatingRemainder(dividingBy: 1.0)
                            let norm = raw < 0 ? raw + 1 : raw
                            let y = geo.size.height * (1.05 - CGFloat(norm) * 1.15)
                            let driftX = h.drift * CGFloat(sin(norm * .pi))
                            let fade = norm < 0.12 ? norm / 0.12 : (norm > 0.82 ? (1 - norm) / 0.18 : 1.0)

                            Circle()
                                .fill(Color(hex: "#E8B4B8"))
                                .frame(width: h.size, height: h.size)
                                .opacity(0.75 * fade)
                                .position(
                                    x: geo.size.width * h.xFactor + driftX,
                                    y: y
                                )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Step 8: Breathing preview ambient

struct OnboardingBreathingAmbient: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct LeafSpec {
        let xFactor: CGFloat
        let startYFactor: CGFloat
        let rotation: Double
        let delay: Double
    }

    private static let leaves: [LeafSpec] = [
        LeafSpec(xFactor: 0.22, startYFactor: 0.15, rotation: -18, delay: 0),
        LeafSpec(xFactor: 0.55, startYFactor: 0.08, rotation: 12, delay: 2.2),
        LeafSpec(xFactor: 0.78, startYFactor: 0.2, rotation: -8, delay: 4.4)
    ]

    var body: some View {
        ZStack {
            GeometryReader { geo in
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color(hex: "#C8E0C0").opacity(0),
                            Color(hex: "#C8E0C0").opacity(0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blur(radius: 8)
                    .frame(height: geo.size.height * 0.22)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if !reduceMotion {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    GeometryReader { geo in
                        ForEach(0..<Self.leaves.count, id: \.self) { i in
                            let leaf = Self.leaves[i]
                            let period: Double = 8.0
                            let norm = ((t - leaf.delay) / period).truncatingRemainder(dividingBy: 1.0)
                            let x = geo.size.width * leaf.xFactor + CGFloat(sin(norm * .pi * 2)) * 20
                            let y = geo.size.height * (leaf.startYFactor + CGFloat(norm) * 0.55)
                            let rot = leaf.rotation + norm * 40

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "#A8C5A0"))
                                .frame(width: 7, height: 5)
                                .rotationEffect(.degrees(rot))
                                .opacity(0.7 * (1 - norm * 0.35))
                                .position(x: x, y: y)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

/// Outer bloom behind the breathing circle; matches pulse scale.
struct OnboardingBreathingBloom: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pulsing: Bool

    var body: some View {
        Circle()
            .fill(Color(hex: "#A8C5A0").opacity(0.15))
            .frame(width: 220, height: 220)
            .blur(radius: 20)
            .scaleEffect(reduceMotion || !pulsing ? 1.0 : 1.18)
            .animation(
                reduceMotion
                    ? .default
                    : .easeInOut(duration: 3).repeatForever(autoreverses: true),
                value: pulsing
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Step 9: Gratitude jar ambient

struct OnboardingGratitudeJarAmbient: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct MoteSpec {
        let x: CGFloat
        let delay: Double
        let size: CGFloat
    }

    var body: some View {
        ZStack {
            lightBeam

            if !reduceMotion {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    GeometryReader { geo in
                        let motes = moteSpecs(width: geo.size.width)
                        ForEach(0..<motes.count, id: \.self) { i in
                            let m = motes[i]
                            let period: Double = 4.0
                            let raw = ((t - m.delay) / period).truncatingRemainder(dividingBy: 1.0)
                            let norm = raw < 0 ? raw + 1 : raw
                            let y = geo.size.height * (0.72 - CGFloat(norm) * 0.35)
                            let fade = sin(norm * .pi)

                            Circle()
                                .fill(Color(hex: "#F5C6AA"))
                                .frame(width: m.size, height: m.size)
                                .opacity(0.55 * fade)
                                .position(x: m.x, y: y)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(false)
    }

    private var lightBeam: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0.5 : (sin(t * 2 * .pi / 5.0) + 1) / 2
            GeometryReader { geo in
                Path { path in
                    let top = CGPoint(x: geo.size.width / 2, y: -20)
                    path.move(to: top)
                    path.addLine(to: CGPoint(x: geo.size.width * 0.2, y: geo.size.height * 0.55))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.8, y: geo.size.height * 0.55))
                    path.closeSubpath()
                }
                .fill(Color(hex: "#FAF6EC").opacity(0.10 * pulse))
            }
        }
        .allowsHitTesting(false)
    }

    private func moteSpecs(width: CGFloat) -> [MoteSpec] {
        var rng = SeededRNG(seed: 8809)
        var out: [MoteSpec] = []
        for i in 0..<8 {
            out.append(MoteSpec(
                x: CGFloat(rng.nextDouble()) * width,
                delay: Double(i) * 0.5,
                size: 3 + CGFloat(rng.nextDouble())
            ))
        }
        return out
    }
}

// MARK: - Step 10: Celebration (confetti + rising stars)

struct OnboardingCelebrationAmbient: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startTime: TimeInterval?

    var body: some View {
        Group {
            if reduceMotion {
                EmptyView()
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let origin = startTime ?? t
                    let elapsed = t - origin
                    GeometryReader { geo in
                        ZStack {
                            confettiLayer(elapsed: elapsed, size: geo.size)
                            risingStarsLayer(elapsed: elapsed, size: geo.size)
                        }
                    }
                }
            }
        }
        .onAppear {
            if startTime == nil {
                startTime = Date().timeIntervalSinceReferenceDate
            }
        }
        .allowsHitTesting(false)
    }

    private static let confettiColors: [Color] = [
        Color(hex: "#A8C5A0"),
        Color(hex: "#F5C6AA"),
        Color(hex: "#C4B8D4"),
        Color(hex: "#E8B4B8")
    ]

    private struct ConfettiPiece {
        let x: CGFloat
        let color: Color
        let width: CGFloat
        let height: CGFloat
        let drift: CGFloat
        let rotationOffset: Double
        let horizontalPhase: Double
    }

    private static let confettiPieces: [ConfettiPiece] = {
        var rng = SeededRNG(seed: 9001)
        var out: [ConfettiPiece] = []
        for i in 0..<20 {
            let w = 6 + CGFloat(rng.nextDouble()) * 8
            let h = 6 + CGFloat(rng.nextDouble()) * 8
            out.append(ConfettiPiece(
                x: CGFloat(rng.nextDouble()),
                color: confettiColors[i % confettiColors.count],
                width: w,
                height: h,
                drift: CGFloat(rng.nextDouble() * 50 - 25),
                rotationOffset: rng.nextDouble() * 360,
                horizontalPhase: rng.nextDouble()
            ))
        }
        return out
    }()

    @ViewBuilder
    private func confettiLayer(elapsed: TimeInterval, size: CGSize) -> some View {
        let fallDuration: Double = 2.8
        let fadeStart: Double = 3.0
        let fadeEnd: Double = 3.8
        let layerOpacity: Double = elapsed < fadeStart
            ? 1
            : max(0, 1 - (elapsed - fadeStart) / (fadeEnd - fadeStart))

        if layerOpacity <= 0.01 {
            EmptyView()
        } else {
            ForEach(0..<Self.confettiPieces.count, id: \.self) { i in
                let piece = Self.confettiPieces[i]
                let stagger = Double(i) * 0.04
                let local = max(0, elapsed - stagger)
                let norm = min(1, local / fallDuration)
                let startY = -size.height * 0.08
                let endY = size.height * 1.05
                let y = startY + CGFloat(norm) * (endY - startY)
                let sway = piece.drift * CGFloat(sin((norm + piece.horizontalPhase) * 2 * .pi))
                let rotation = piece.rotationOffset + norm * 540

                RoundedRectangle(cornerRadius: 1)
                    .fill(piece.color)
                    .frame(width: piece.width, height: piece.height)
                    .rotationEffect(.degrees(rotation))
                    .opacity(layerOpacity * (norm < 0.05 ? norm / 0.05 : 1))
                    .position(x: piece.x * size.width + sway, y: y)
            }
        }
    }

    private struct RisingStar {
        let xFactor: CGFloat
        let delay: Double
        let size: CGFloat
    }

    private static let risingStars: [RisingStar] = [
        RisingStar(xFactor: 0.2, delay: 3.2, size: 4),
        RisingStar(xFactor: 0.35, delay: 3.6, size: 3),
        RisingStar(xFactor: 0.5, delay: 3.0, size: 5),
        RisingStar(xFactor: 0.68, delay: 3.8, size: 3.5),
        RisingStar(xFactor: 0.82, delay: 3.4, size: 4.5)
    ]

    @ViewBuilder
    private func risingStarsLayer(elapsed: TimeInterval, size: CGSize) -> some View {
        ForEach(0..<Self.risingStars.count, id: \.self) { i in
            risingStarView(star: Self.risingStars[i], elapsed: elapsed, size: size)
        }
    }

    @ViewBuilder
    private func risingStarView(star: RisingStar, elapsed: TimeInterval, size: CGSize) -> some View {
        if elapsed >= star.delay {
            let local = elapsed - star.delay
            let period: Double = 5.5
            let norm = (local / period).truncatingRemainder(dividingBy: 1.0)
            let y = size.height * (1.02 - CGFloat(norm) * 1.05)
            let twinkle = sin(local * 2 * .pi / 1.2)
            let opacity = (twinkle + 1) / 2 * (norm < 0.1 ? norm / 0.1 : (norm > 0.85 ? (1 - norm) / 0.15 : 1))

            Image(systemName: "star.fill")
                .font(.system(size: star.size))
                .foregroundColor(Color(hex: "#F9C784"))
                .opacity(opacity)
                .position(x: size.width * star.xFactor, y: y)
        }
    }
}
