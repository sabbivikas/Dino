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
    /// force-static (no idle animation) regardless of reduce motion — e.g. the
    /// week strip, where seven breathing glyphs would be noise
    var paused: Bool = false

    var body: some View {
        Group {
            switch weather {
            case .clear:        SunGlyph(muted: muted, paused: paused)
            case .partlyCloudy: DriftCloudGlyph(muted: muted, paused: paused)
            case .overwhelmed:  StormGlyph(muted: muted, paused: paused)
            case .drained:      MistGlyph(muted: muted, paused: paused)
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
    var paused: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // uneven angles and lengths — no two rays agree
    private static let rays: [(deg: Double, len: CGFloat)] = [
        (3, 0.140), (49, 0.108), (92, 0.150), (137, 0.100),
        (184, 0.132), (226, 0.112), (271, 0.146), (317, 0.118),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused || reduceMotion)) { timeline in
            let t = (paused || reduceMotion) ? 0 : timeline.date.timeIntervalSinceReferenceDate
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
    var paused: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused || reduceMotion)) { timeline in
            let t = (paused || reduceMotion) ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                let s = rect.side
                let ink = DinoWeatherGlyph.inkColor(muted: muted)
                let soft = DinoWeatherGlyph.softInkColor(muted: muted)
                let style = inkStyle(rect)

                // the sun peeks with a soft pulse — 3s swell and glow
                let pulse = 0.5 + 0.5 * sin(t * 2 * .pi / 3.0)
                let sunScale = 0.94 + 0.12 * CGFloat(pulse)
                let sunC = CGPoint(x: rect.midX + s * 0.20, y: rect.midY - s * 0.16)
                ctx.drawLayer { sun in
                    sun.opacity = 0.72 + 0.28 * pulse
                    sun.translateBy(x: sunC.x, y: sunC.y)
                    sun.scaleBy(x: sunScale, y: sunScale)
                    sun.translateBy(x: -sunC.x, y: -sunC.y)
                    sun.stroke(PeekSun().path(in: rect), with: .color(soft), style: style)
                }

                // cloud drifts — the old ±7px stroll, scaled to the glyph,
                // with the faintest vertical bob riding along
                let dx = CGFloat(sin(t * 2 * .pi / 4.0)) * s * 0.11
                let dy = CGFloat(sin(t * 2 * .pi / 4.0 + 1.3)) * s * 0.02
                ctx.translateBy(x: dx, y: dy)
                let lump = CloudLump().path(in: rect)
                ctx.fill(lump, with: .color(Color(hex: "#A8D4E6").opacity(muted ? 0.12 : 0.26)))
                ctx.stroke(lump, with: .color(ink), style: style)

                // a quiet face, drifting with its cloud
                let eyeY = rect.midY + s * 0.05
                let eyeR = s * 0.018
                for ex in [rect.midX - s * 0.115, rect.midX + s * 0.005] {
                    ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR,
                                                    width: eyeR * 2, height: eyeR * 2)),
                             with: .color(ink))
                }
                var smile = Path()
                smile.move(to: CGPoint(x: rect.midX - s * 0.085, y: eyeY + s * 0.055))
                smile.addQuadCurve(to: CGPoint(x: rect.midX - s * 0.025, y: eyeY + s * 0.055),
                                   control: CGPoint(x: rect.midX - s * 0.055, y: eyeY + s * 0.082))
                ctx.stroke(smile, with: .color(ink),
                           style: StrokeStyle(lineWidth: rect.inkWidth * 0.8, lineCap: .round))
            }
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
    var paused: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // (x offset, phase delay, stroke length) — three drops, none agreeing
    private static let drops: [(x: CGFloat, delay: Double, len: CGFloat)] = [
        (-0.17, 0.00, 0.075), (0.02, 0.62, 0.058), (0.20, 1.15, 0.068),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused || reduceMotion)) { timeline in
            let t = (paused || reduceMotion) ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                let s = rect.side
                let ink = DinoWeatherGlyph.inkColor(muted: muted)
                let soft = DinoWeatherGlyph.softInkColor(muted: muted)
                let style = inkStyle(rect)

                // the cloud sways — weary and slow, nothing like the old jiggle
                let sway = sin(t * 2 * .pi / 3.2)
                ctx.drawLayer { cloud in
                    cloud.translateBy(x: CGFloat(sway) * s * 0.025,
                                      y: CGFloat(sin(t * 2 * .pi / 3.2 + 0.9)) * s * 0.012)
                    let path = StormCloud().path(in: rect)
                    cloud.fill(path, with: .color(Color(hex: "#C4B8D4").opacity(muted ? 0.13 : 0.28)))
                    cloud.stroke(path, with: .color(ink), style: style)
                }

                // rain, drop by drop — each stroke falls and fades on its own time
                let slant = CGPoint(x: -0.20, y: 0.98)
                let topY = rect.midY + s * 0.08
                let travel = s * 0.26
                for drop in Self.drops {
                    let cycle = 1.7
                    let dt = (((t + drop.delay) / cycle).truncatingRemainder(dividingBy: 1) + 1)
                        .truncatingRemainder(dividingBy: 1)
                    let y = topY + CGFloat(dt) * travel
                    let fade = dt < 0.15 ? dt / 0.15 : (dt > 0.72 ? max(0, (1.0 - dt) / 0.28) : 1.0)
                    let x = rect.midX + drop.x * s
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + slant.x * drop.len * s,
                                          y: y + slant.y * drop.len * s))
                    ctx.stroke(p, with: .color(soft.opacity(fade)), style: style)

                    // a tiny splash where the drop lands — blink and it's gone
                    if dt > 0.80 {
                        let sp = (dt - 0.80) / 0.20
                        let r = s * 0.030 * (0.6 + CGFloat(sp) * 0.7)
                        let splashY = topY + travel + s * 0.035
                        var splash = Path()
                        splash.addEllipse(in: CGRect(x: x - r, y: splashY - r * 0.35,
                                                     width: r * 2, height: r * 0.7))
                        let splashFade = sp < 0.4 ? sp / 0.4 : (1.0 - sp) / 0.6
                        ctx.stroke(splash, with: .color(soft.opacity(0.55 * splashFade)),
                                   style: StrokeStyle(lineWidth: rect.inkWidth * 0.6))
                    }
                }
            }
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

// MARK: - Mist (drained) — low bands that trail off and drift

private struct MistGlyph: View {
    let muted: Bool
    var paused: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // (start x, y, width, drift dir, phase) — every band a different reach
    private static let bands: [(x: CGFloat, y: CGFloat, w: CGFloat, dir: CGFloat, phase: Double)] = [
        (-0.26, -0.02, 0.46,  1, 0.0),
        (-0.20,  0.10, 0.62, -1, 0.9),
        (-0.32,  0.21, 0.44,  1, 1.7),
        (-0.12,  0.32, 0.42, -1, 2.6),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused || reduceMotion)) { timeline in
            let t = (paused || reduceMotion) ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                let s = rect.side
                let ink = DinoWeatherGlyph.ink.opacity(muted ? 0.38 : 0.72)
                let style = inkStyle(rect)

                // a small tired cloud, sinking a little as it breathes
                let bob = CGFloat(sin(t * 2 * .pi / 4.4)) * s * 0.015
                ctx.drawLayer { cloud in
                    cloud.translateBy(x: 0, y: bob)
                    let cc = CGPoint(x: rect.midX - s * 0.14, y: rect.midY - s * 0.27)
                    var lump = Path()
                    lump.move(to: CGPoint(x: cc.x - s * 0.17, y: cc.y + s * 0.07))
                    lump.addQuadCurve(to: CGPoint(x: cc.x - s * 0.06, y: cc.y - s * 0.075),
                                      control: CGPoint(x: cc.x - s * 0.20, y: cc.y - s * 0.05))
                    lump.addQuadCurve(to: CGPoint(x: cc.x + s * 0.09, y: cc.y - s * 0.045),
                                      control: CGPoint(x: cc.x + s * 0.03, y: cc.y - s * 0.12))
                    lump.addQuadCurve(to: CGPoint(x: cc.x + s * 0.17, y: cc.y + s * 0.07),
                                      control: CGPoint(x: cc.x + s * 0.21, y: cc.y - s * 0.01))
                    lump.addQuadCurve(to: CGPoint(x: cc.x - s * 0.17, y: cc.y + s * 0.07),
                                      control: CGPoint(x: cc.x, y: cc.y + s * 0.10))
                    lump.closeSubpath()
                    cloud.fill(lump, with: .color(Color(hex: "#C8CDD4").opacity(muted ? 0.13 : 0.26)))
                    cloud.stroke(lump, with: .color(ink), style: style)

                    // heavy lids — two small downward arcs, nearly closed
                    let lidStyle = StrokeStyle(lineWidth: rect.inkWidth * 0.8, lineCap: .round)
                    for ex in [cc.x - s * 0.065, cc.x + s * 0.045] {
                        var lid = Path()
                        lid.move(to: CGPoint(x: ex - s * 0.025, y: cc.y - s * 0.005))
                        lid.addQuadCurve(to: CGPoint(x: ex + s * 0.025, y: cc.y - s * 0.005),
                                         control: CGPoint(x: ex, y: cc.y + s * 0.022))
                        cloud.stroke(lid, with: .color(ink), style: lidStyle)
                    }
                    // a flat little mouth — not sad, just tired
                    var mouth = Path()
                    mouth.move(to: CGPoint(x: cc.x - s * 0.028, y: cc.y + s * 0.048))
                    mouth.addLine(to: CGPoint(x: cc.x + s * 0.024, y: cc.y + s * 0.046))
                    cloud.stroke(mouth, with: .color(ink), style: lidStyle)
                }

                // mist bands drift — visibly now, each on its own slow walk
                for band in Self.bands {
                    let dx = CGFloat(sin(t * 2 * .pi / 3.9 + band.phase)) * band.dir * s * 0.10
                    let alpha = 0.78 + 0.22 * sin(t * 2 * .pi / 3.9 + band.phase + 0.6)
                    let y = rect.midY + band.y * s
                    let x0 = rect.midX + band.x * s + dx
                    var p = Path()
                    p.move(to: CGPoint(x: x0, y: y))
                    p.addQuadCurve(to: CGPoint(x: x0 + band.w * s * 0.55, y: y - s * 0.020),
                                   control: CGPoint(x: x0 + band.w * s * 0.28, y: y - s * 0.055))
                    p.addQuadCurve(to: CGPoint(x: x0 + band.w * s, y: y),
                                   control: CGPoint(x: x0 + band.w * s * 0.80, y: y + s * 0.030))
                    ctx.stroke(p, with: .color(ink.opacity(alpha)), style: style)
                }
            }
        }
    }
}
