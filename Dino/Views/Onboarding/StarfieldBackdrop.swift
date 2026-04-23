//
//  StarfieldBackdrop.swift
//  Dino
//
//  v6 navy/starfield backdrop: aurora, nebula, fireflies, stars, shooting stars.
//  Driven by a single TimelineView(.animation) clock, gated by reduceMotion.
//

import SwiftUI

public struct StarfieldBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        TimelineView(.animation) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    // a) Background navy gradient
                    LinearGradient(
                        colors: [
                            Color(hex: "#1A1A33"),
                            Color(hex: "#0F0F22")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    // b) 2 aurora blobs
                    auroraLayer(t: t, size: geo.size)

                    // c) Nebula
                    nebulaLayer(t: t, size: geo.size)

                    // d) 8 fireflies
                    firefliesLayer(t: t, size: geo.size)

                    // e) 15 stars
                    starsLayer(t: t, size: geo.size)

                    // f) 2 shooting stars
                    shootingStarsLayer(t: t, size: geo.size)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Aurora
    @ViewBuilder
    private func auroraLayer(t: TimeInterval, size: CGSize) -> some View {
        let phaseA = sin(t * 2 * .pi / 22.0)
        let phaseB = sin(t * 2 * .pi / 22.0 + .pi)
        let scaleA: CGFloat = reduceMotion ? 1.0 : 1.0 + 0.05 * CGFloat(phaseA + 1)
        let scaleB: CGFloat = reduceMotion ? 1.0 : 1.0 + 0.05 * CGFloat(phaseB + 1)
        let opA: Double = reduceMotion ? 0.8 : 0.6 + 0.2 * (phaseA + 1) / 2
        let opB: Double = reduceMotion ? 0.8 : 0.6 + 0.2 * (phaseB + 1) / 2

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#A8C5A0").opacity(0.22), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 250
                )
            )
            .frame(width: 500, height: 300)
            .scaleEffect(scaleA)
            .opacity(opA)
            .position(x: size.width * 0.25, y: size.height * 0.22)
            .allowsHitTesting(false)

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#C4B8D4").opacity(0.20), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 250
                )
            )
            .frame(width: 500, height: 300)
            .scaleEffect(scaleB)
            .opacity(opB)
            .position(x: size.width * 0.75, y: size.height * 0.78)
            .allowsHitTesting(false)
    }

    // MARK: - Nebula
    @ViewBuilder
    private func nebulaLayer(t: TimeInterval, size: CGSize) -> some View {
        let phase = sin(t * 2 * .pi / 18.0)
        let scale: CGFloat = reduceMotion ? 1.0 : 1.0 + 0.04 * CGFloat(phase + 1)
        let op: Double = reduceMotion ? 0.7 : 0.5 + 0.35 * (phase + 1) / 2

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#F5C6AA").opacity(0.12), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 180
                )
            )
            .frame(width: 360, height: 260)
            .scaleEffect(scale)
            .opacity(op)
            .position(x: size.width * 0.5, y: size.height * 0.45)
            .allowsHitTesting(false)
    }

    // MARK: - Fireflies
    @ViewBuilder
    private func firefliesLayer(t: TimeInterval, size: CGSize) -> some View {
        let positions = fireflyPositions(size: size)
        ForEach(0..<positions.count, id: \.self) { i in
            let pos = positions[i]
            let phaseOffset = Double(i) * 0.5
            let phase = sin((t + phaseOffset) * 2 * .pi / 4.0)
            let scale: CGFloat = reduceMotion ? 1.0 : 0.6 + 0.3 * CGFloat(phase + 1)
            let op: Double = reduceMotion ? 0.4 : 0.3 + 0.35 * (phase + 1)
            Circle()
                .fill(Color(hex: "#F5E9C4"))
                .frame(width: 3, height: 3)
                .scaleEffect(scale)
                .opacity(op)
                .position(x: pos.x, y: pos.y)
                .allowsHitTesting(false)
        }
    }

    private func fireflyPositions(size: CGSize) -> [(x: CGFloat, y: CGFloat)] {
        var rng = SeededRNG(seed: 123)
        var out: [(CGFloat, CGFloat)] = []
        for _ in 0..<8 {
            let x = CGFloat(rng.nextDouble()) * size.width
            let y = CGFloat(rng.nextDouble()) * size.height
            out.append((x, y))
        }
        return out
    }

    // MARK: - Stars
    @ViewBuilder
    private func starsLayer(t: TimeInterval, size: CGSize) -> some View {
        let stars = starPositions(size: size)
        ForEach(0..<stars.count, id: \.self) { i in
            let s = stars[i]
            let delay = Double(i) * 0.2
            let phase = sin((t - delay) * 2 * .pi / 3.5)
            let op: Double = reduceMotion ? 0.7 : 0.3 + 0.3 * (phase + 1)
            Circle()
                .fill(Color.white)
                .frame(width: s.size, height: s.size)
                .opacity(op)
                .position(x: s.x, y: s.y)
                .allowsHitTesting(false)
        }
    }

    private func starPositions(size: CGSize) -> [(x: CGFloat, y: CGFloat, size: CGFloat)] {
        var rng = SeededRNG(seed: 2024)
        var out: [(CGFloat, CGFloat, CGFloat)] = []
        for _ in 0..<15 {
            let x = CGFloat(rng.nextDouble()) * size.width
            let y = CGFloat(rng.nextDouble()) * size.height
            let s = 1.5 + CGFloat(rng.nextDouble()) * 1.0
            out.append((x, y, s))
        }
        return out
    }

    // MARK: - Shooting stars
    @ViewBuilder
    private func shootingStarsLayer(t: TimeInterval, size: CGSize) -> some View {
        if !reduceMotion {
            ForEach(0..<2, id: \.self) { i in
                let delay: Double = i == 0 ? 0 : 3.5
                let period: Double = 7.0
                let norm = (((t - delay) / period).truncatingRemainder(dividingBy: 1.0) + 1)
                    .truncatingRemainder(dividingBy: 1.0)
                // ease-in
                let eased = norm * norm
                let startX = -size.width * 0.4
                let endX = size.width * 0.4
                let travel = startX + CGFloat(eased) * (endX - startX)
                let baseY: CGFloat = i == 0 ? size.height * 0.25 : size.height * 0.55
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 60, height: 1)
                    .rotationEffect(.degrees(-20))
                    .position(x: size.width * 0.5 + travel, y: baseY + travel * 0.2)
                    .opacity(norm < 0.7 ? 1 : Double(1 - (norm - 0.7) / 0.3))
                    .allowsHitTesting(false)
            }
        }
    }
}
