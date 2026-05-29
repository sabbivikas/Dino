//
//  StarfieldBackdrop.swift
//  Dino
//
//  Magical night backdrop: shifting navy gradient, layered stars, aurora,
//  nebula, moon halo, fireflies, shooting stars. TimelineView-driven.
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
                    backgroundLayer(t: t)

                    nebulaLayer(t: t, size: geo.size)

                    auroraLayer(t: t, size: geo.size)

                    moonLayer(t: t, size: geo.size)

                    starsLayer(t: t, size: geo.size)
                        .drawingGroup()

                    firefliesLayer(t: t, size: geo.size)

                    shootingStarsLayer(t: t, size: geo.size)
                        .drawingGroup()
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Background (#0B1120 → #1A1035, 20s shift)

    @ViewBuilder
    private func backgroundLayer(t: TimeInterval) -> some View {
        let phase = sin(t * 2 * .pi / 20.0)
        let topOpacity = reduceMotion ? 1.0 : 0.85 + 0.15 * (phase + 1) / 2
        LinearGradient(
            colors: [
                Color(hex: "#0B1120"),
                Color(hex: "#1A1035").opacity(topOpacity),
                Color(hex: "#0F0F22")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Nebula (purple + rose, 30s drift)

    @ViewBuilder
    private func nebulaLayer(t: TimeInterval, size: CGSize) -> some View {
        let drift = reduceMotion ? 0 : sin(t * 2 * .pi / 30.0) * 24
        let driftB = reduceMotion ? 0 : cos(t * 2 * .pi / 30.0 + 1.2) * 18

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#9B8ED4").opacity(0.08), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            )
            .frame(width: 420, height: 300)
            .offset(x: CGFloat(drift), y: CGFloat(driftB * 0.5))
            .position(x: size.width * 0.32, y: size.height * 0.38)
            .allowsHitTesting(false)

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#E8B4B8").opacity(0.08), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 180
                )
            )
            .frame(width: 380, height: 280)
            .offset(x: CGFloat(-drift * 0.6), y: CGFloat(driftB))
            .position(x: size.width * 0.72, y: size.height * 0.52)
            .allowsHitTesting(false)
    }

    // MARK: - Aurora (12s wave, + teal)

    @ViewBuilder
    private func auroraLayer(t: TimeInterval, size: CGSize) -> some View {
        let phaseA = sin(t * 2 * .pi / 12.0)
        let phaseB = sin(t * 2 * .pi / 12.0 + .pi * 0.6)
        let waveA = reduceMotion ? 0 : sin(t * 2 * .pi / 12.0) * 20
        let scaleA: CGFloat = reduceMotion ? 1.0 : 1.0 + 0.06 * CGFloat(phaseA + 1)
        let opA: Double = reduceMotion ? 0.7 : 0.5 + 0.25 * (phaseA + 1) / 2

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#A8C5A0").opacity(0.22), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 260
                )
            )
            .frame(width: 520, height: 320)
            .scaleEffect(scaleA)
            .opacity(opA)
            .offset(x: CGFloat(waveA))
            .position(x: size.width * 0.22, y: size.height * 0.2)
            .allowsHitTesting(false)

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#7FFFD4").opacity(0.15), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 240
                )
            )
            .frame(width: 480, height: 300)
            .scaleEffect(reduceMotion ? 1.0 : 1.0 + 0.05 * CGFloat(phaseB + 1))
            .opacity(reduceMotion ? 0.6 : 0.45 + 0.2 * (phaseB + 1) / 2)
            .offset(x: CGFloat(-waveA * 0.7))
            .position(x: size.width * 0.55, y: size.height * 0.28)
            .allowsHitTesting(false)

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#C4B8D4").opacity(0.18), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 250
                )
            )
            .frame(width: 500, height: 300)
            .scaleEffect(reduceMotion ? 1.0 : 1.0 + 0.05 * CGFloat(phaseA + 1))
            .opacity(reduceMotion ? 0.65 : 0.5 + 0.2 * (phaseA + 1) / 2)
            .position(x: size.width * 0.78, y: size.height * 0.75)
            .allowsHitTesting(false)
    }

    // MARK: - Moon + halo (6s breathe)

    @ViewBuilder
    private func moonLayer(t: TimeInterval, size: CGSize) -> some View {
        let mx = size.width * 0.78
        let my = size.height * 0.18
        let breathe = sin(t * 2 * .pi / 6.0)
        let scale: CGFloat = reduceMotion ? 1.0 : 1.0 + 0.025 * CGFloat(breathe + 1)
        let haloOpacity: Double = reduceMotion ? 0.2 : 0.14 + 0.08 * (breathe + 1) / 2

        Circle()
            .fill(Color(hex: "#FAF6EC").opacity(haloOpacity))
            .frame(width: 88, height: 88)
            .blur(radius: 12)
            .scaleEffect(scale)
            .position(x: mx, y: my)
            .allowsHitTesting(false)

        Circle()
            .fill(Color(hex: "#FFF8DC"))
            .frame(width: 36, height: 36)
            .shadow(color: Color(hex: "#FAF6EC").opacity(0.35), radius: 8, x: 0, y: 0)
            .scaleEffect(scale)
            .position(x: mx, y: my)
            .allowsHitTesting(false)
    }

    // MARK: - Stars (3 depth layers + parallax)

    private enum StarDepth: Int {
        case distant, mid, near

        var twinklePeriod: Double {
            switch self {
            case .distant: return 3.0
            case .mid: return 2.0
            case .near: return 1.5
            }
        }

        var driftPeriod: Double {
            switch self {
            case .distant: return 120.0
            case .mid: return 80.0
            case .near: return 50.0
            }
        }

        var pointSize: CGFloat {
            switch self {
            case .distant: return 1
            case .mid: return 2
            case .near: return 3
            }
        }

        var count: Int {
            switch self {
            case .distant: return 28
            case .mid: return 16
            case .near: return 8
            }
        }

        var seed: UInt64 {
            switch self {
            case .distant: return 2024
            case .mid: return 3024
            case .near: return 4024
            }
        }
    }

    @ViewBuilder
    private func starsLayer(t: TimeInterval, size: CGSize) -> some View {
        ForEach([StarDepth.distant, .mid, .near], id: \.rawValue) { depth in
            let stars = starSpecs(depth: depth, size: size)
            ForEach(0..<stars.count, id: \.self) { i in
                let s = stars[i]
                let twinkle = sin((t - s.delay) * 2 * .pi / depth.twinklePeriod)
                let op: Double = reduceMotion
                    ? 0.65
                    : (depth == .near ? 0.55 : 0.25) + 0.35 * (twinkle + 1) / 2
                let driftX: CGFloat = reduceMotion
                    ? 0
                    : CGFloat(sin((t + s.delay) * 2 * .pi / depth.driftPeriod)) * (depth == .distant ? 4 : 8)
                Circle()
                    .fill(Color.white)
                    .frame(width: depth.pointSize, height: depth.pointSize)
                    .opacity(op)
                    .position(x: s.x + driftX, y: s.y)
                    .allowsHitTesting(false)
            }
        }
    }

    private struct StarSpec {
        let x: CGFloat
        let y: CGFloat
        let delay: Double
    }

    private func starSpecs(depth: StarDepth, size: CGSize) -> [StarSpec] {
        var rng = SeededRNG(seed: depth.seed)
        var out: [StarSpec] = []
        for i in 0..<depth.count {
            let x = CGFloat(rng.nextDouble()) * size.width
            let y = CGFloat(rng.nextDouble()) * size.height * 0.88
            out.append(StarSpec(x: x, y: y, delay: Double(i) * 0.15 + rng.nextDouble()))
        }
        return out
    }

    // MARK: - Fireflies (10, white + sage)

    private struct NightFirefly {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let isSage: Bool
        let phase: Double
    }

    @ViewBuilder
    private func firefliesLayer(t: TimeInterval, size: CGSize) -> some View {
        let flies = nightFireflySpecs(size: size)
        ForEach(0..<flies.count, id: \.self) { i in
            let f = flies[i]
            let pulse = sin((t + f.phase) * 2 * .pi / 3.8)
            let opacity = reduceMotion ? 0.4 : 0.2 + 0.5 * (pulse + 1) / 2
            let dx: CGFloat = reduceMotion ? 0 : CGFloat(sin((t + f.phase) * 2 * .pi / 5.5)) * 10
            let dy: CGFloat = reduceMotion ? 0 : CGFloat(cos((t + f.phase) * 2 * .pi / 4.8)) * 8
            let tint = f.isSage ? Color(hex: "#A8C5A0") : Color(hex: "#F5F9FF")
            Circle()
                .fill(tint.opacity(opacity))
                .frame(width: f.size, height: f.size)
                .blur(radius: f.size > 3 ? 1 : 0)
                .position(x: f.x + dx, y: f.y + dy)
                .allowsHitTesting(false)
        }
    }

    private func nightFireflySpecs(size: CGSize) -> [NightFirefly] {
        var rng = SeededRNG(seed: 123)
        var out: [NightFirefly] = []
        for i in 0..<10 {
            out.append(NightFirefly(
                x: CGFloat(rng.nextDouble()) * size.width,
                y: CGFloat(rng.nextDouble()) * size.height,
                size: 2 + CGFloat(rng.nextDouble()) * 2,
                isSage: i % 3 == 0,
                phase: Double(i) * 0.55 + rng.nextDouble()
            ))
        }
        return out
    }

    // MARK: - Shooting stars (more frequent, glow trail)

    @ViewBuilder
    private func shootingStarsLayer(t: TimeInterval, size: CGSize) -> some View {
        if reduceMotion {
            EmptyView()
        } else {
            ForEach(0..<3, id: \.self) { i in
                let delay: Double = Double(i) * 2.2
                let period: Double = 5.5
                let norm = (((t - delay) / period).truncatingRemainder(dividingBy: 1.0) + 1)
                    .truncatingRemainder(dividingBy: 1.0)
                let eased = norm * norm
                let startX = -size.width * 0.45
                let endX = size.width * 0.45
                let travel = startX + CGFloat(eased) * (endX - startX)
                let baseY: CGFloat = [0.18, 0.38, 0.58][i] * size.height
                let headOpacity = norm < 0.75 ? 1.0 : Double(1 - (norm - 0.75) / 0.25)
                let angle: Double = -22

                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.15 * headOpacity))
                        .frame(width: 72, height: 3)
                        .blur(radius: 2)
                    Capsule()
                        .fill(Color.white.opacity(0.45 * headOpacity))
                        .frame(width: 36, height: 1.5)
                        .blur(radius: 1)
                    Capsule()
                        .fill(Color.white.opacity(0.95 * headOpacity))
                        .frame(width: 14, height: 1)
                }
                .rotationEffect(.degrees(angle))
                .position(x: size.width * 0.5 + travel, y: baseY + travel * 0.15)
                .opacity(norm < 0.08 ? 0 : headOpacity)
                .allowsHitTesting(false)
            }
        }
    }
}
