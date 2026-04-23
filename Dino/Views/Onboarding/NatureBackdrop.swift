//
//  NatureBackdrop.swift
//  Dino
//
//  v6 onboarding nature scene: sky, sun, rays, clouds, hills, grass,
//  mist, birds, dust motes, vignette, grain. All animations use a
//  single TimelineView(.animation) clock and are gated by reduceMotion.
//

import SwiftUI

public struct NatureBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        TimelineView(.animation) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    // a) Sky
                    LinearGradient(
                        colors: [
                            Color(hex: "#FFF6DF"),
                            Color(hex: "#F9F0D4"),
                            Color(hex: "#F4E8C4")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    // b) Sun (top-right), ken-burns 18s
                    sunLayer(t: t, size: geo.size)

                    // c) 12 rotating rays
                    raysLayer(t: t, size: geo.size)

                    // d) 3 parallax clouds
                    cloudsLayer(t: t, size: geo.size)

                    // e) Hills (far / mid / near)
                    hillsLayer(size: geo.size)

                    // f) 24 grass blades over near hill
                    grassLayer(t: t, size: geo.size)

                    // g) 3 mist bands
                    mistLayer(t: t, size: geo.size)

                    // h) 2 birds
                    birdsLayer(t: t, size: geo.size)

                    // i) 14 dust motes
                    motesLayer(t: t, size: geo.size)

                    // j) Vignette
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.45),
                            .init(color: Color(hex: "#4A3520").opacity(0.22), location: 1)
                        ]),
                        center: .center,
                        startRadius: 200,
                        endRadius: 600
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    // k) Grain
                    Image("noise-grain")
                        .resizable(resizingMode: .tile)
                        .ignoresSafeArea()
                        .opacity(0.06)
                        .blendMode(.overlay)
                        .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Sun
    @ViewBuilder
    private func sunLayer(t: TimeInterval, size: CGSize) -> some View {
        let phase = sin(t * 2 * .pi / 18)
        let scale: CGFloat = reduceMotion ? 1.0 : 1.0 + 0.03 * CGFloat(phase + 1) // 1.0↔1.06
        let dx: CGFloat = reduceMotion ? 0 : CGFloat(phase) * 2
        let dy: CGFloat = reduceMotion ? 0 : -CGFloat(phase) * 2
        let sunX = size.width - 60 - 20
        let sunY: CGFloat = 60 + 20

        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: "#FFF2B3"),
                        Color(hex: "#FFD56E"),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 60
                )
            )
            .frame(width: 120, height: 120)
            .scaleEffect(scale)
            .position(x: sunX + dx, y: sunY + dy)
            .allowsHitTesting(false)
    }

    // MARK: - Rays
    private func raysLayer(t: TimeInterval, size: CGSize) -> some View {
        let rotation: Double = reduceMotion ? 0 : (t / 60.0) * 360.0
        let cx = size.width - 60 - 20
        let cy: CGFloat = 60 + 20
        return Canvas { ctx, _ in
            for i in 0..<12 {
                let angle = (Double(i) * 30.0 + rotation) * .pi / 180.0
                let x1 = cx + 60 * CGFloat(cos(angle))
                let y1 = cy + 60 * CGFloat(sin(angle))
                let x2 = cx + 180 * CGFloat(cos(angle))
                let y2 = cy + 180 * CGFloat(sin(angle))
                var path = Path()
                path.move(to: CGPoint(x: x1, y: y1))
                path.addLine(to: CGPoint(x: x2, y: y2))
                ctx.stroke(path, with: .color(Color(hex: "#FFE9B8").opacity(0.35)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Clouds
    @ViewBuilder
    private func cloudsLayer(t: TimeInterval, size: CGSize) -> some View {
        CloudShape()
            .fill(Color(hex: "#FEFBF3").opacity(0.7))
            .frame(width: 140, height: 50)
            .position(x: cloudX(t: t, width: size.width, period: 40, phase: 0.0), y: 60)
            .allowsHitTesting(false)

        CloudShape()
            .fill(Color(hex: "#FEFBF3").opacity(0.7))
            .frame(width: 180, height: 60)
            .position(x: cloudX(t: t, width: size.width, period: 55, phase: 0.33), y: 90)
            .allowsHitTesting(false)

        CloudShape()
            .fill(Color(hex: "#FEFBF3").opacity(0.7))
            .frame(width: 120, height: 44)
            .position(x: cloudX(t: t, width: size.width, period: 70, phase: 0.66), y: 130)
            .allowsHitTesting(false)
    }

    private func cloudX(t: TimeInterval, width: CGFloat, period: Double, phase: Double) -> CGFloat {
        if reduceMotion { return width * 0.5 }
        let travel = width + 200
        let norm = ((t / period) + phase).truncatingRemainder(dividingBy: 1.0)
        return CGFloat(norm) * travel - 100
    }

    // MARK: - Hills
    @ViewBuilder
    private func hillsLayer(size: CGSize) -> some View {
        HillFarShape()
            .fill(DinoTheme.hillGrassFar)
            .frame(width: size.width, height: 280)
            .position(x: size.width / 2, y: size.height - 140)
            .allowsHitTesting(false)

        HillMidShape()
            .fill(DinoTheme.hillGrassMid)
            .frame(width: size.width, height: 240)
            .position(x: size.width / 2, y: size.height - 120)
            .allowsHitTesting(false)

        HillNearShape()
            .fill(DinoTheme.hillGrassNear)
            .frame(width: size.width, height: 200)
            .position(x: size.width / 2, y: size.height - 100)
            .allowsHitTesting(false)
    }

    // MARK: - Grass
    @ViewBuilder
    private func grassLayer(t: TimeInterval, size: CGSize) -> some View {
        let positions = grassPositions(width: size.width)
        ForEach(0..<positions.count, id: \.self) { i in
            let data = positions[i]
            let swayPhase = reduceMotion ? 0 : sin((t - Double(i) * 0.06) * 2 * .pi / 3.0)
            let angle: Double = reduceMotion ? 0 : swayPhase * 2.0
            GrassBladeShape()
                .stroke(Color(hex: "#6B8A52"), lineWidth: 1)
                .frame(width: 2, height: data.height)
                .rotationEffect(.degrees(angle), anchor: .bottom)
                .position(x: data.x, y: size.height - 80)
                .allowsHitTesting(false)
        }
    }

    private func grassPositions(width: CGFloat) -> [(x: CGFloat, height: CGFloat)] {
        var rng = SeededRNG(seed: 42)
        var out: [(CGFloat, CGFloat)] = []
        for _ in 0..<24 {
            let x = CGFloat(rng.nextDouble()) * width
            let h = 8 + CGFloat(rng.nextDouble()) * 6
            out.append((x, h))
        }
        return out
    }

    // MARK: - Mist bands
    @ViewBuilder
    private func mistLayer(t: TimeInterval, size: CGSize) -> some View {
        let offsets: [CGFloat] = reduceMotion
            ? [0, 0, 0]
            : [
                CGFloat(sin(t * 2 * .pi / 24.0)) * 8,
                CGFloat(sin(t * 2 * .pi / 24.0 + .pi / 2)) * 8,
                CGFloat(sin(t * 2 * .pi / 24.0 + .pi)) * 8
            ]
        let yPositions: [CGFloat] = [180, 220, 260]
        ForEach(0..<3, id: \.self) { i in
            Rectangle()
                .fill(Color(hex: "#FEFBF3").opacity(0.35))
                .frame(width: size.width, height: 12)
                .offset(x: offsets[i])
                .position(x: size.width / 2, y: yPositions[i])
                .allowsHitTesting(false)
        }
    }

    // MARK: - Birds
    @ViewBuilder
    private func birdsLayer(t: TimeInterval, size: CGSize) -> some View {
        if !reduceMotion {
            ForEach(0..<2, id: \.self) { i in
                let delay: Double = i == 0 ? 0 : 12
                let period: Double = 28
                let norm = (((t - delay) / period).truncatingRemainder(dividingBy: 1.0) + 1)
                    .truncatingRemainder(dividingBy: 1.0)
                let x = CGFloat(norm) * (size.width + 40) - 20
                let baseY: CGFloat = i == 0 ? 110 : 150
                BirdShape()
                    .stroke(Color(hex: "#6B5A3C"), lineWidth: 1.2)
                    .frame(width: 16, height: 8)
                    .position(x: x, y: baseY)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Dust motes
    @ViewBuilder
    private func motesLayer(t: TimeInterval, size: CGSize) -> some View {
        let motes = motePositions(size: size)
        ForEach(0..<motes.count, id: \.self) { i in
            let mote = motes[i]
            let phase = reduceMotion ? 0 : sin((t + Double(i) * 0.8) * 2 * .pi / 12.0)
            let dy: CGFloat = reduceMotion ? 0 : -5 - CGFloat(phase) * 5
            let op: Double = reduceMotion ? 0.4 : 0.4 + (phase + 1) * 0.15
            Circle()
                .fill(Color(hex: "#FFE9B8").opacity(op))
                .frame(width: 2, height: 2)
                .position(x: mote.x, y: mote.y + dy)
                .allowsHitTesting(false)
        }
    }

    private func motePositions(size: CGSize) -> [(x: CGFloat, y: CGFloat)] {
        var rng = SeededRNG(seed: 777)
        var out: [(CGFloat, CGFloat)] = []
        for _ in 0..<14 {
            let x = CGFloat(rng.nextDouble()) * size.width
            let y = CGFloat(rng.nextDouble()) * (size.height * 0.7)
            out.append((x, y))
        }
        return out
    }
}

// MARK: - Cloud Shape (overlapping ellipses)
private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // 4 overlapping ellipses merged via path
        p.addEllipse(in: CGRect(x: 0, y: h * 0.25, width: w * 0.5, height: h * 0.7))
        p.addEllipse(in: CGRect(x: w * 0.25, y: 0, width: w * 0.45, height: h))
        p.addEllipse(in: CGRect(x: w * 0.45, y: h * 0.1, width: w * 0.45, height: h * 0.9))
        p.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.3, width: w * 0.45, height: h * 0.65))
        return p
    }
}

// MARK: - Hill Shapes (normalized to 720x400 design frame)
private struct HillFarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let sx = rect.width / 720
        let sy = rect.height / 120 // hill portion of the 400-tall design is bottom ~120
        // Path original: M0 280 Q 180 240 360 260 T 720 260 L 720 400 L 0 400 Z
        // Map y: 280→0, 400→rect.height ; so y' = (y - 280) * rect.height / 120
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: (y - 280) * sy)
        }
        p.move(to: pt(0, 280))
        p.addQuadCurve(to: pt(360, 260), control: pt(180, 240))
        // T 720 260 → reflect previous control point (180,240) about (360,260) = (540, 280)
        p.addQuadCurve(to: pt(720, 260), control: pt(540, 280))
        p.addLine(to: pt(720, 400))
        p.addLine(to: pt(0, 400))
        p.closeSubpath()
        return p
    }
}

private struct HillMidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let sx = rect.width / 720
        let sy = rect.height / 100
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: (y - 300) * sy)
        }
        // M0 310 Q 160 270 320 295 T 640 300 L 720 300 L 720 400 L 0 400 Z
        p.move(to: pt(0, 310))
        p.addQuadCurve(to: pt(320, 295), control: pt(160, 270))
        // T 640 300 → reflect (160,270) about (320,295) = (480, 320)
        p.addQuadCurve(to: pt(640, 300), control: pt(480, 320))
        p.addLine(to: pt(720, 300))
        p.addLine(to: pt(720, 400))
        p.addLine(to: pt(0, 400))
        p.closeSubpath()
        return p
    }
}

private struct HillNearShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let sx = rect.width / 720
        let sy = rect.height / 80
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: (y - 320) * sy)
        }
        // M0 340 Q 140 310 280 330 T 560 330 L 720 340 L 720 400 L 0 400 Z
        p.move(to: pt(0, 340))
        p.addQuadCurve(to: pt(280, 330), control: pt(140, 310))
        // T 560 330 → reflect (140,310) about (280,330) = (420, 350)
        p.addQuadCurve(to: pt(560, 330), control: pt(420, 350))
        p.addLine(to: pt(720, 340))
        p.addLine(to: pt(720, 400))
        p.addLine(to: pt(0, 400))
        p.closeSubpath()
        return p
    }
}

// MARK: - Grass blade
private struct GrassBladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}

// MARK: - Bird (V shape)
private struct BirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

// MARK: - Deterministic RNG (Linear Congruential Generator)
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func nextUInt64() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func nextDouble() -> Double {
        Double(nextUInt64() >> 11) / Double(UInt64(1) << 53)
    }
}
