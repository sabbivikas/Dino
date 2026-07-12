//
//  DinoWeatherGlyph.swift
//  Dino
//
//  The four mood-weather marks, drawn as SwiftUI paths at hand-drawn weight:
//  ink strokes over a soft mood-color wash, deliberately uneven — ray lengths
//  differ, cloud bulges are lopsided, mist bands trail off mid-air. No emoji,
//  no icon-pack geometry. Each glyph is its own small view so future artwork
//  can replace them one at a time (swap a body, keep the API).
//  Idle animations stay under a 4s cycle and go still under Reduce Motion.
//

import SwiftUI

struct DinoWeatherGlyph: View {
    let weather: EmotionalWeather
    var size: CGFloat = 44
    /// unselected cards: ink softens, the wash nearly disappears
    var muted: Bool = false

    var body: some View {
        Group {
            switch weather {
            case .clear:        SunGlyph(muted: muted)
            case .partlyCloudy: DriftCloudGlyph(muted: muted)
            case .overwhelmed:  StormGlyph(muted: muted)
            case .drained:      MistGlyph(muted: muted)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)   // the enclosing card/button carries the label
    }

    static let ink = Color(hex: "#3D3A35")

    static func inkColor(muted: Bool) -> Color { ink.opacity(muted ? 0.40 : 0.82) }
    static func softInkColor(muted: Bool) -> Color { ink.opacity(muted ? 0.32 : 0.62) }
}

// MARK: - Shared stroke maths

private extension CGRect {
    var side: CGFloat { min(width, height) }
    var inkWidth: CGFloat { side * 0.062 }   // the hand-drawn weight
}

private func inkStyle(_ rect: CGRect) -> StrokeStyle {
    StrokeStyle(lineWidth: rect.inkWidth, lineCap: .round, lineJoin: .round)
}

// MARK: - Sun (clear) — a little sun with a face: it bounces, blinks, and
// its rays breathe. Time-driven Canvas (Double math — no shader precision
// worries); paused-still under Reduce Motion.

private struct SunGlyph: View {
    let muted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // uneven angles and lengths — no two rays agree
    private static let rays: [(deg: Double, len: CGFloat)] = [
        (3, 0.140), (49, 0.108), (92, 0.150), (137, 0.100),
        (184, 0.132), (226, 0.112), (271, 0.146), (317, 0.118),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                let s = rect.side
                let c = CGPoint(x: rect.midX, y: rect.midY + s * 0.01)
                let ink = DinoWeatherGlyph.inkColor(muted: muted)
                let style = StrokeStyle(lineWidth: rect.inkWidth, lineCap: .round, lineJoin: .round)

                // rays breathe — 3.6s swell
                let breathe = 0.5 + 0.5 * sin(t * 2 * .pi / 3.6)
                let rayScale = 0.92 + 0.14 * CGFloat(breathe)
                let r0 = s * 0.30 * rayScale
                for ray in Self.rays {
                    let a = ray.deg * .pi / 180
                    let dir = CGPoint(x: CGFloat(cos(a)), y: CGFloat(sin(a)))
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + dir.x * r0, y: c.y + dir.y * r0))
                    p.addLine(to: CGPoint(x: c.x + dir.x * (r0 + s * ray.len * rayScale),
                                          y: c.y + dir.y * (r0 + s * ray.len * rayScale)))
                    ctx.stroke(p, with: .color(ink), style: style)
                }

                // gentle squash and stretch — 2.2s, calmer than the old cartoon
                let bt = ((t / 2.2).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
                let (sx, sy) = Self.bounceScale(bt)
                ctx.translateBy(x: c.x, y: c.y)
                ctx.scaleBy(x: sx, y: sy)
                ctx.translateBy(x: -c.x, y: -c.y)

                // core — a hair squashed, drawn not lathed
                let w = s * 0.42, h = s * 0.40
                let core = Path(ellipseIn: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
                ctx.fill(core, with: .color(Color(hex: "#F5D98C").opacity(muted ? 0.13 : 0.30)))
                ctx.stroke(core, with: .color(ink), style: style)

                // blush — two warm thumbprints
                let blushR = s * 0.036
                let blushY = c.y + h * 0.17
                for bx in [c.x - w * 0.31, c.x + w * 0.31] {
                    ctx.fill(Path(ellipseIn: CGRect(x: bx - blushR, y: blushY - blushR,
                                                    width: blushR * 2, height: blushR * 2)),
                             with: .color(Color(hex: "#F5C6AA").opacity(muted ? 0.28 : 0.60)))
                }

                // eyes — ink dots that blink on a ~4s natural cycle
                let blinkT = ((t / 4.0).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
                let eyeSquash: CGFloat = (blinkT > 0.90 && blinkT < 0.96) ? 0.14 : 1.0
                let eyeR = s * 0.023
                let eyeY = c.y - h * 0.10
                for ex in [c.x - w * 0.19, c.x + w * 0.19] {
                    ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR * eyeSquash,
                                                    width: eyeR * 2, height: eyeR * 2 * eyeSquash)),
                             with: .color(ink))
                }

                // smile — one quad curve, slightly off true
                var smile = Path()
                let smileY = c.y + h * 0.11
                smile.move(to: CGPoint(x: c.x - w * 0.18, y: smileY))
                smile.addQuadCurve(to: CGPoint(x: c.x + w * 0.18, y: smileY - s * 0.004),
                                   control: CGPoint(x: c.x, y: smileY + h * 0.18))
                ctx.stroke(smile, with: .color(ink),
                           style: StrokeStyle(lineWidth: rect.inkWidth * 0.85, lineCap: .round))
            }
        }
    }

    /// squash-stretch profile — the old cartoon's arc at roughly 0.6x amplitude
    private static func bounceScale(_ t: Double) -> (CGFloat, CGFloat) {
        if t < 0.35 {
            let p = CGFloat(t / 0.35)
            return (1 + 0.07 * p, 1 - 0.06 * p)
        } else if t < 0.50 {
            let p = CGFloat((t - 0.35) / 0.15)
            return (1.07 - 0.10 * p, 0.94 + 0.12 * p)
        } else if t < 0.70 {
            let p = CGFloat((t - 0.50) / 0.20)
            return (0.97 + 0.06 * p, 1.06 - 0.09 * p)
        } else {
            let p = CGFloat((t - 0.70) / 0.30)
            return (1.03 - 0.03 * p, 0.97 + 0.03 * p)
        }
    }
}

// MARK: - Drifting cloud (partly cloudy) — lopsided cloud, sliver of sun

private struct DriftCloudGlyph: View {
    let muted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            ZStack {
                // the sun peeks from behind, upper right — just an arc and two rays
                PeekSun()
                    .stroke(DinoWeatherGlyph.ink.opacity(muted ? 0.32 : 0.62), style: inkStyle(rect))
                CloudLump()
                    .fill(Color(hex: "#A8D4E6").opacity(muted ? 0.12 : 0.26))
                    .offset(x: reduceMotion ? 0 : (drift - 0.5) * rect.side * 0.07)
                CloudLump()
                    .stroke(DinoWeatherGlyph.ink.opacity(muted ? 0.40 : 0.82), style: inkStyle(rect))
                    .offset(x: reduceMotion ? 0 : (drift - 0.5) * rect.side * 0.07)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) { drift = 1 }
        }
    }
}

private struct PeekSun: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX + rect.side * 0.20, y: rect.midY - rect.side * 0.16)
        p.addArc(center: c, radius: rect.side * 0.155,
                 startAngle: .degrees(-150), endAngle: .degrees(55), clockwise: false)
        for deg in [-118.0, -62.0, -8.0] {
            let a = deg * .pi / 180
            let dir = CGPoint(x: cos(a), y: sin(a))
            let r0 = rect.side * 0.21, r1 = rect.side * (deg == -62 ? 0.30 : 0.27)
            p.move(to: CGPoint(x: c.x + dir.x * r0, y: c.y + dir.y * r0))
            p.addLine(to: CGPoint(x: c.x + dir.x * r1, y: c.y + dir.y * r1))
        }
        return p
    }
}

private struct CloudLump: Shape {
    func path(in rect: CGRect) -> Path {
        // lopsided: big shoulder left, smaller tumble right, flat-ish base
        let s = rect.side
        let baseY = rect.midY + s * 0.16
        let leftX = rect.midX - s * 0.34
        let rightX = rect.midX + s * 0.26
        var p = Path()
        p.move(to: CGPoint(x: leftX, y: baseY))
        p.addQuadCurve(to: CGPoint(x: leftX + s * 0.02, y: baseY - s * 0.20),
                       control: CGPoint(x: leftX - s * 0.14, y: baseY - s * 0.16))
        p.addQuadCurve(to: CGPoint(x: rect.midX - s * 0.02, y: baseY - s * 0.30),
                       control: CGPoint(x: rect.midX - s * 0.22, y: baseY - s * 0.40))
        p.addQuadCurve(to: CGPoint(x: rect.midX + s * 0.18, y: baseY - s * 0.16),
                       control: CGPoint(x: rect.midX + s * 0.16, y: baseY - s * 0.30))
        p.addQuadCurve(to: CGPoint(x: rightX, y: baseY),
                       control: CGPoint(x: rightX + s * 0.12, y: baseY - s * 0.12))
        p.addQuadCurve(to: CGPoint(x: leftX, y: baseY),
                       control: CGPoint(x: rect.midX - s * 0.04, y: baseY + s * 0.05))
        p.closeSubpath()
        return p
    }
}

// MARK: - Storm cloud (overwhelmed) — rain strokes, none the same length

private struct StormGlyph: View {
    let muted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fall: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            ZStack {
                StormCloud()
                    .fill(Color(hex: "#C4B8D4").opacity(muted ? 0.13 : 0.28))
                StormCloud()
                    .stroke(DinoWeatherGlyph.ink.opacity(muted ? 0.40 : 0.82), style: inkStyle(rect))
                RainStrokes()
                    .stroke(DinoWeatherGlyph.ink.opacity(muted ? 0.32 : 0.62), style: inkStyle(rect))
                    .offset(y: reduceMotion ? 0 : fall * rect.side * 0.05)
                    .opacity(reduceMotion ? 1.0 : 1.0 - 0.35 * Double(fall))
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { fall = 1 }
        }
    }
}

private struct StormCloud: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.side
        let baseY = rect.midY - s * 0.02
        let leftX = rect.midX - s * 0.32
        let rightX = rect.midX + s * 0.30
        var p = Path()
        p.move(to: CGPoint(x: leftX, y: baseY))
        p.addQuadCurve(to: CGPoint(x: leftX + s * 0.05, y: baseY - s * 0.19),
                       control: CGPoint(x: leftX - s * 0.13, y: baseY - s * 0.14))
        p.addQuadCurve(to: CGPoint(x: rect.midX + s * 0.03, y: baseY - s * 0.27),
                       control: CGPoint(x: rect.midX - s * 0.18, y: baseY - s * 0.38))
        p.addQuadCurve(to: CGPoint(x: rightX, y: baseY),
                       control: CGPoint(x: rightX + s * 0.14, y: baseY - s * 0.20))
        p.addQuadCurve(to: CGPoint(x: leftX, y: baseY),
                       control: CGPoint(x: rect.midX, y: baseY + s * 0.06))
        p.closeSubpath()
        return p
    }
}

private struct RainStrokes: Shape {
    // three slanted strokes — staggered starts, uneven lengths
    private static let drops: [(x: CGFloat, y: CGFloat, len: CGFloat)] = [
        (-0.18, 0.14, 0.16), (0.02, 0.18, 0.11), (0.20, 0.13, 0.14),
    ]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = rect.side
        let slant = CGPoint(x: -0.22, y: 0.975)   // rain leans a little
        for d in Self.drops {
            let start = CGPoint(x: rect.midX + d.x * s, y: rect.midY + d.y * s)
            p.move(to: start)
            p.addLine(to: CGPoint(x: start.x + slant.x * d.len * s,
                                  y: start.y + slant.y * d.len * s))
        }
        return p
    }
}

// MARK: - Mist (drained) — low bands that trail off and drift

private struct MistGlyph: View {
    let muted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let inkColor = DinoWeatherGlyph.ink.opacity(muted ? 0.38 : 0.72)
            ZStack {
                MistBand(index: 0)
                    .stroke(inkColor, style: inkStyle(rect))
                    .offset(x: reduceMotion ? 0 : (drift - 0.5) * rect.side * 0.06)
                MistBand(index: 1)
                    .stroke(inkColor, style: inkStyle(rect))
                    .offset(x: reduceMotion ? 0 : (0.5 - drift) * rect.side * 0.06)
                MistBand(index: 2)
                    .stroke(inkColor, style: inkStyle(rect))
                    .offset(x: reduceMotion ? 0 : (drift - 0.5) * rect.side * 0.045)
                MistBand(index: 3)
                    .stroke(inkColor.opacity(0.75), style: inkStyle(rect))
                    .offset(x: reduceMotion ? 0 : (0.5 - drift) * rect.side * 0.045)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.9).repeatForever(autoreverses: true)) { drift = 1 }
        }
    }
}

private struct MistBand: Shape {
    let index: Int
    // (start x, y, width) fractions — every band a different reach
    private static let bands: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [
        (-0.30, -0.20, 0.52), (-0.20, -0.04, 0.62), (-0.32, 0.12, 0.44), (-0.12, 0.26, 0.42),
    ]
    func path(in rect: CGRect) -> Path {
        let b = Self.bands[index]
        let s = rect.side
        let y = rect.midY + b.y * s
        let x0 = rect.midX + b.x * s
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y))
        // a soft single wave, not a straight rule
        p.addQuadCurve(to: CGPoint(x: x0 + b.w * s * 0.55, y: y - s * 0.020),
                       control: CGPoint(x: x0 + b.w * s * 0.28, y: y - s * 0.055))
        p.addQuadCurve(to: CGPoint(x: x0 + b.w * s, y: y),
                       control: CGPoint(x: x0 + b.w * s * 0.80, y: y + s * 0.030))
        return p
    }
}
