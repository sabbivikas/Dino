//
//  CeremonySkyView.swift
//  Dino
//
//  The ceremony's sky: cream→night lerp, 90 seeded twinkling stars, 26
//  ember dust motes, the lantern bloom and jar glow — all drawn in ONE
//  Canvas pass with additive (.plusLighter) blending, per the handoff's
//  swiftui+metal mapping (owner-approved Canvas route; MPSImageGaussianBlur
//  is the named upgrade if the glow reads flat on device).
//

import SwiftUI

struct CeremonySkyView: View {
    /// 0 = cream day, 1 = full night.
    let night: Double
    /// Lantern bloom in DESIGN coordinates (390×844).
    let glowCenter: CGPoint
    let glowAlpha: Double
    let glowRadius: Double
    let jarGlow: Double
    let reduceMotion: Bool

    private struct Star {
        let x: Double; let y: Double; let r: Double
        let tw: Double; let ph: Double; let o: Double
    }
    private struct Ember {
        let x0: Double; let y0: Double; let r: Double
        let vx: Double; let vy: Double; let ph: Double; let o: Double
    }

    // Seeded LCG (seed 11), verbatim from the handoff engine.
    private static let (stars, embers): ([Star], [Ember]) = {
        var seed = 11.0
        func rnd() -> Double {
            seed = (seed * 16807).truncatingRemainder(dividingBy: 2147483647)
            return seed / 2147483647
        }
        var stars: [Star] = []
        for _ in 0..<90 {
            stars.append(Star(x: rnd(), y: rnd() * 0.75,
                              r: 0.5 + rnd() * 1.3,
                              tw: 1.5 + rnd() * 3,
                              ph: rnd() * 2 * .pi,
                              o: 0.3 + rnd() * 0.6))
        }
        var embers: [Ember] = []
        for _ in 0..<26 {
            embers.append(Ember(x0: rnd(), y0: rnd(),
                                r: 0.8 + rnd() * 1.6,
                                vx: (rnd() - 0.5) * 6,
                                vy: 4 + rnd() * 8,
                                ph: rnd() * 2 * .pi,
                                o: 0.10 + rnd() * 0.16))
        }
        return (stars, embers)
    }()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * 1000   // ms
            Canvas { ctx, size in
                let n = night
                // — sky: two-stop vertical lerp, cream → night —
                let top = mix(Color(hex: "#FAF6EC"), Color(hex: "#1f2338"), n)
                let bottom = mix(Color(hex: "#F2EDDE"), Color(hex: "#3a3651"), n)
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [top, bottom]),
                                               startPoint: .zero,
                                               endPoint: CGPoint(x: 0, y: size.height)))
                guard n > 0.05 else { return }

                // — additive pass —
                ctx.blendMode = .plusLighter
                let sx = size.width, sy = size.height

                for star in Self.stars {
                    let twinkle = reduceMotion ? 0.8
                        : 0.55 + 0.45 * sin(t / 1000 * (2 * .pi / star.tw) + star.ph)
                    let a = star.o * twinkle * n
                    guard a >= 0.02 else { continue }
                    let c = CGPoint(x: star.x * sx, y: star.y * sy)
                    let r = star.r * 5 * (sx / 390)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(stops: [
                                .init(color: Color(red: 1, green: 249/255, blue: 232/255).opacity(a * 0.9), location: 0),
                                .init(color: Color(red: 1, green: 240/255, blue: 210/255).opacity(a * 0.35), location: 0.35),
                                .init(color: .clear, location: 1),
                             ]), center: c, startRadius: 0, endRadius: r))
                }

                if !reduceMotion {
                    for ember in Self.embers {
                        let rise = (t / 1000 * ember.vy / 844).truncatingRemainder(dividingBy: 1)
                        let y = ((ember.y0 - rise).truncatingRemainder(dividingBy: 1) + 1)
                            .truncatingRemainder(dividingBy: 1)
                        let x = ember.x0 + (t / 1000 * ember.vx / 390)
                            + sin(t / 900 + ember.ph) * 0.0004
                        let a = ember.o * n * (0.6 + 0.4 * sin(t / 700 + ember.ph))
                        guard a >= 0.02 else { continue }
                        let c = CGPoint(x: (x.truncatingRemainder(dividingBy: 1) + 1)
                            .truncatingRemainder(dividingBy: 1) * sx, y: y * sy)
                        let r = ember.r * (sx / 390)
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                                 with: .color(Color(red: 1, green: 214/255, blue: 150/255).opacity(a)))
                    }
                }

                // — lantern bloom: flicker = two slow sines multiplied —
                if glowAlpha > 0.01 {
                    let flick = reduceMotion ? 1.0 : 0.9 + 0.1 * sin(t / 210) * sin(t / 470)
                    let a = glowAlpha * flick
                    let c = CGPoint(x: glowCenter.x / 390 * sx, y: glowCenter.y / 844 * sy)
                    let r = glowRadius / 390 * sx
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(stops: [
                                .init(color: Color(red: 1, green: 204/255, blue: 130/255).opacity(a * 0.55), location: 0),
                                .init(color: Color(red: 1, green: 180/255, blue: 100/255).opacity(a * 0.22), location: 0.4),
                                .init(color: .clear, location: 1),
                             ]), center: c, startRadius: 0, endRadius: r))
                }

                // — jar glow —
                if jarGlow > 0.01 {
                    let c = CGPoint(x: sx / 2, y: 560 / 844 * sy)
                    let r = 170 / 390 * sx
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(stops: [
                                .init(color: Color(red: 1, green: 196/255, blue: 120/255).opacity(jarGlow * 0.4), location: 0),
                                .init(color: .clear, location: 1),
                             ]), center: c, startRadius: 0, endRadius: r))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(min(max(t, 0), 1))
        return Color(red: r1 + (r2 - r1) * k, green: g1 + (g2 - g1) * k, blue: b1 + (b2 - b1) * k)
    }
}
