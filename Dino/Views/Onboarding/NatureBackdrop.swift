//
//  NatureBackdrop.swift
//  Dino
//
//  v6 onboarding nature scene: animated sky, sun, clouds, hills, mist,
//  birds, dust motes, fireflies, vignette, grain. TimelineView-driven;
//  gated by accessibilityReduceMotion.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct NatureBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        TimelineView(.animation) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    skyLayer(t: t)

                    sunLayer(t: t, size: geo.size)

                    raysLayer(t: t, size: geo.size)
                        .drawingGroup()

                    cloudsLayer(t: t, size: geo.size)

                    hillsLayer(t: t, size: geo.size)

                    grassLayer(t: t, size: geo.size)

                    mistLayer(t: t, size: geo.size)

                    birdsLayer(t: t, size: geo.size)
                        .drawingGroup()

                    motesLayer(t: t, size: geo.size)

                    firefliesLayer(t: t, size: geo.size)

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

    // MARK: - Sky (peach → gold → sky, 12s)

    @ViewBuilder
    private func skyLayer(t: TimeInterval) -> some View {
        let phase = reduceMotion ? 0.0 : (sin(t * 2 * .pi / 12.0) + 1) / 2
        let peach = Color(hex: "#FDE8D0")
        let gold = Color(hex: "#F9C784")
        let sky = Color(hex: "#C8E6F5")

        let top: Color
        let mid: Color
        let bottom: Color
        if phase < 0.5 {
            let u = phase * 2
            top = lerpColor(peach, gold, u)
            mid = lerpColor(gold, sky, u)
            bottom = lerpColor(peach, gold, u)
        } else {
            let u = (phase - 0.5) * 2
            top = lerpColor(gold, sky, u)
            mid = lerpColor(sky, peach, u)
            bottom = lerpColor(gold, sky, u)
        }

        LinearGradient(colors: [top, mid, bottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: - Sun + glow ring (8s pulse)

    @ViewBuilder
    private func sunLayer(t: TimeInterval, size: CGSize) -> some View {
        let sunX = size.width - 80
        let sunY: CGFloat = 80
        let glowPhase = sin(t * 2 * .pi / 8.0)
        let glowScale: CGFloat = reduceMotion ? 1.0 : 1.0 + 0.04 * CGFloat(glowPhase + 1)
        let glowOpacity: Double = reduceMotion ? 0.45 : 0.3 + 0.3 * (glowPhase + 1) / 2
        let bodyPhase = sin(t * 2 * .pi / 18.0)
        let bodyDx: CGFloat = reduceMotion ? 0 : CGFloat(bodyPhase) * 2
        let bodyDy: CGFloat = reduceMotion ? 0 : -CGFloat(bodyPhase) * 2

        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: "#FFD56E").opacity(0.55),
                        Color(hex: "#FFF2B3").opacity(0.25),
                        .clear
                    ],
                    center: .center,
                    startRadius: 40,
                    endRadius: 95
                )
            )
            .frame(width: 190, height: 190)
            .scaleEffect(glowScale)
            .opacity(glowOpacity)
            .position(x: sunX + bodyDx, y: sunY + bodyDy)
            .allowsHitTesting(false)

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
            .position(x: sunX + bodyDx, y: sunY + bodyDy)
            .allowsHitTesting(false)
    }

    // MARK: - Rays

    private func raysLayer(t: TimeInterval, size: CGSize) -> some View {
        let rotation: Double = reduceMotion ? 0 : (t / 60.0) * 360.0
        let cx = size.width - 80
        let cy: CGFloat = 80
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

    // MARK: - Clouds (5 layers, parallax speeds)

    private struct CloudSpec {
        let width: CGFloat
        let height: CGFloat
        let y: CGFloat
        let period: Double
        let phase: Double
        let opacity: Double
    }

    private static let cloudSpecs: [CloudSpec] = [
        CloudSpec(width: 200, height: 68, y: 48, period: 170, phase: 0.0, opacity: 0.70),
        CloudSpec(width: 160, height: 54, y: 72, period: 150, phase: 0.18, opacity: 0.80),
        CloudSpec(width: 140, height: 50, y: 96, period: 120, phase: 0.35, opacity: 0.85),
        CloudSpec(width: 120, height: 44, y: 118, period: 90, phase: 0.52, opacity: 0.90),
        CloudSpec(width: 100, height: 38, y: 142, period: 80, phase: 0.70, opacity: 0.95)
    ]

    @ViewBuilder
    private func cloudsLayer(t: TimeInterval, size: CGSize) -> some View {
        ForEach(0..<Self.cloudSpecs.count, id: \.self) { i in
            let spec = Self.cloudSpecs[i]
            CloudShape()
                .fill(Color(hex: "#FEFBF3").opacity(spec.opacity))
                .frame(width: spec.width, height: spec.height)
                .position(
                    x: cloudX(t: t, width: size.width, period: spec.period, phase: spec.phase),
                    y: spec.y
                )
                .allowsHitTesting(false)
        }
    }

    private func cloudX(t: TimeInterval, width: CGFloat, period: Double, phase: Double) -> CGFloat {
        if reduceMotion { return width * 0.5 }
        let travel = width + 220
        let norm = ((t / period) + phase).truncatingRemainder(dividingBy: 1.0)
        return CGFloat(norm) * travel - 110
    }

    // MARK: - Hills (near hill breathes, 8s)

    @ViewBuilder
    private func hillsLayer(t: TimeInterval, size: CGSize) -> some View {
        let breathe = sin(t * 2 * .pi / 8.0)
        let nearOffsetY: CGFloat = reduceMotion ? 0 : -1.5 * CGFloat(breathe)

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
            .position(x: size.width / 2, y: size.height - 100 + nearOffsetY)
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

    // MARK: - Mist (2 layers, 60s)

    @ViewBuilder
    private func mistLayer(t: TimeInterval, size: CGSize) -> some View {
        let layers: [(y: CGFloat, phaseOffset: Double)] = [
            (200, 0),
            (248, 0.4)
        ]
        ForEach(0..<layers.count, id: \.self) { i in
            let layer = layers[i]
            let drift = reduceMotion
                ? 0
                : sin((t + layer.phaseOffset) * 2 * .pi / 60.0) * 14
            let opPhase = sin((t + layer.phaseOffset) * 2 * .pi / 60.0)
            let opacity = reduceMotion ? 0.25 : 0.15 + 0.20 * (opPhase + 1) / 2
            Rectangle()
                .fill(Color(hex: "#FEFBF3").opacity(opacity))
                .frame(width: size.width * 1.15, height: 28)
                .blur(radius: 6)
                .offset(x: CGFloat(drift))
                .position(x: size.width / 2, y: layer.y)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Birds (4, wing flap)

    private struct BirdSpec {
        let y: CGFloat
        let period: Double
        let delay: Double
        let flapPeriod: Double
    }

    private static let birdSpecs: [BirdSpec] = [
        BirdSpec(y: 88, period: 32, delay: 0, flapPeriod: 0.45),
        BirdSpec(y: 118, period: 26, delay: 4, flapPeriod: 0.52),
        BirdSpec(y: 148, period: 38, delay: 9, flapPeriod: 0.38),
        BirdSpec(y: 178, period: 22, delay: 14, flapPeriod: 0.48)
    ]

    @ViewBuilder
    private func birdsLayer(t: TimeInterval, size: CGSize) -> some View {
        if reduceMotion {
            ForEach(0..<Self.birdSpecs.count, id: \.self) { i in
                let spec = Self.birdSpecs[i]
                BirdShape()
                    .stroke(Color(hex: "#6B5A3C"), lineWidth: 1.2)
                    .frame(width: 16, height: 8)
                    .opacity(0.7)
                    .position(x: size.width * 0.5, y: spec.y)
                    .allowsHitTesting(false)
            }
        } else {
            ForEach(0..<Self.birdSpecs.count, id: \.self) { i in
                let spec = Self.birdSpecs[i]
                let norm = (((t - spec.delay) / spec.period).truncatingRemainder(dividingBy: 1.0) + 1)
                    .truncatingRemainder(dividingBy: 1.0)
                let x = CGFloat(norm) * (size.width + 50) - 25
                let flap = abs(sin((t - spec.delay) * 2 * .pi / spec.flapPeriod))
                let wingScale = 0.35 + 0.65 * CGFloat(flap)
                BirdShape()
                    .stroke(Color(hex: "#6B5A3C"), lineWidth: 1.2)
                    .frame(width: 16, height: 8)
                    .scaleEffect(x: 1, y: wingScale, anchor: .center)
                    .position(x: x, y: spec.y)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Dust motes (12)

    private struct MoteSpec {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let speed: Double
        let drift: Double
        let phase: Double
    }

    @ViewBuilder
    private func motesLayer(t: TimeInterval, size: CGSize) -> some View {
        let motes = moteSpecs(size: size)
        ForEach(0..<motes.count, id: \.self) { i in
            let m = motes[i]
            let wave = sin((t + m.phase) * 2 * .pi / m.speed)
            let dx: CGFloat = reduceMotion ? 0 : CGFloat(sin((t + m.drift) * 2 * .pi / (m.speed * 1.3))) * 8
            let dy: CGFloat = reduceMotion ? 0 : CGFloat(wave) * 10 - 5
            let op: Double = reduceMotion ? 0.4 : 0.35 + 0.25 * (wave + 1) / 2
            Circle()
                .fill(Color(hex: "#FFE9B8").opacity(op))
                .frame(width: m.size, height: m.size)
                .position(x: m.x + dx, y: m.y + dy)
                .allowsHitTesting(false)
        }
    }

    private func moteSpecs(size: CGSize) -> [MoteSpec] {
        var rng = SeededRNG(seed: 777)
        var out: [MoteSpec] = []
        for i in 0..<12 {
            let x = CGFloat(rng.nextDouble()) * size.width
            let y = CGFloat(rng.nextDouble()) * (size.height * 0.72)
            let s = 2 + CGFloat(rng.nextDouble()) * 2
            let speed = 10 + rng.nextDouble() * 6
            let drift = rng.nextDouble() * 4
            let phase = Double(i) * 0.7 + rng.nextDouble()
            out.append(MoteSpec(x: x, y: y, size: s, speed: speed, drift: drift, phase: phase))
        }
        return out
    }

    // MARK: - Fireflies (6, sage glow)

    private struct FireflySpec {
        let x: CGFloat
        let y: CGFloat
        let pathPhase: Double
        let fadePeriod: Double
    }

    @ViewBuilder
    private func firefliesLayer(t: TimeInterval, size: CGSize) -> some View {
        let flies = fireflySpecs(size: size)
        ForEach(0..<flies.count, id: \.self) { i in
            let f = flies[i]
            let fade = sin((t + f.fadePeriod) * 2 * .pi / 3.5)
            let opacity = reduceMotion ? 0.35 : 0.15 + 0.35 * (fade + 1) / 2
            let dx: CGFloat = reduceMotion ? 0 : CGFloat(sin((t + f.pathPhase) * 2 * .pi / 5.0)) * 12
            let dy: CGFloat = reduceMotion ? 0 : CGFloat(cos((t + f.pathPhase) * 2 * .pi / 4.2)) * 10
            ZStack {
                Circle()
                    .fill(Color(hex: "#A8C5A0").opacity(opacity * 0.5))
                    .frame(width: 10, height: 10)
                    .blur(radius: 4)
                Circle()
                    .fill(Color(hex: "#A8C5A0").opacity(opacity))
                    .frame(width: 3, height: 3)
            }
            .position(x: f.x + dx, y: f.y + dy)
            .allowsHitTesting(false)
        }
    }

    private func fireflySpecs(size: CGSize) -> [FireflySpec] {
        var rng = SeededRNG(seed: 4242)
        var out: [FireflySpec] = []
        for i in 0..<6 {
            let x = CGFloat(rng.nextDouble()) * size.width
            let y = CGFloat(rng.nextDouble()) * size.height * 0.65
            out.append(FireflySpec(
                x: x,
                y: y,
                pathPhase: Double(i) * 0.9,
                fadePeriod: 3.0 + rng.nextDouble()
            ))
        }
        return out
    }

    private func lerpColor(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let u = min(max(t, 0), 1)
        #if canImport(UIKit)
        let ca = UIColor(a)
        let cb = UIColor(b)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ca.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        cb.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            red: Double(ar + (br - ar) * u),
            green: Double(ag + (bg - ag) * u),
            blue: Double(ab + (bb - ab) * u),
            opacity: Double(aa + (ba - aa) * u)
        )
        #else
        return u < 0.5 ? a : b
        #endif
    }
}

// MARK: - Cloud Shape

private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.addEllipse(in: CGRect(x: 0, y: h * 0.25, width: w * 0.5, height: h * 0.7))
        p.addEllipse(in: CGRect(x: w * 0.25, y: 0, width: w * 0.45, height: h))
        p.addEllipse(in: CGRect(x: w * 0.45, y: h * 0.1, width: w * 0.45, height: h * 0.9))
        p.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.3, width: w * 0.45, height: h * 0.65))
        return p
    }
}

// MARK: - Hill Shapes

private struct HillFarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let sx = rect.width / 720
        let sy = rect.height / 120
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: (y - 280) * sy)
        }
        p.move(to: pt(0, 280))
        p.addQuadCurve(to: pt(360, 260), control: pt(180, 240))
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
        p.move(to: pt(0, 310))
        p.addQuadCurve(to: pt(320, 295), control: pt(160, 270))
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
        p.move(to: pt(0, 340))
        p.addQuadCurve(to: pt(280, 330), control: pt(140, 310))
        p.addQuadCurve(to: pt(560, 330), control: pt(420, 350))
        p.addLine(to: pt(720, 340))
        p.addLine(to: pt(720, 400))
        p.addLine(to: pt(0, 400))
        p.closeSubpath()
        return p
    }
}

private struct GrassBladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}

private struct BirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}
