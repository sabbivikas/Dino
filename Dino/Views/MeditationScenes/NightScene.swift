//
//  NightScene.swift
//  Dino
//
//  Moonlit storybook meditation scene (split, no behavior change).
//

import SwiftUI


// MARK: - ═══════════════════════════════════════════
// MARK:   NIGHT SCENE
// MARK: - ═══════════════════════════════════════════

struct NightScene: View {
    let size: CGSize
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            // Sky
            LinearGradient(
                colors: [Color(red: 15/255, green: 18/255, blue: 40/255),
                         Color(red: 30/255, green: 35/255, blue: 60/255)],
                startPoint: .top, endPoint: .bottom
            )

            // Moon radial vignette glow
            RadialGradient(
                colors: [Color(hex: "#FFF0C8").opacity(0.18), .clear],
                center: .init(x: 0.75, y: 0.20),
                startRadius: 0,
                endRadius: size.width * 0.35
            )

            // Milky way band
            NightMilkyWay(size: size)

            // Stars
            NightStarField(size: size, reduceMotion: reduceMotion)

            // Shooting star
            if !reduceMotion {
                NightShootingStar(size: size)
            }

            // Moon
            NightMoon(size: size, reduceMotion: reduceMotion)

            // Mountains
            NightMountains(size: size)

            // Pine silhouettes
            NightPines(size: size, reduceMotion: reduceMotion)

            // Moon reflection
            NightMoonReflection(size: size)

            // Wind wisps
            NightWisps(size: size, reduceMotion: reduceMotion)

            // Fireflies
            if !reduceMotion {
                NightFireflies(size: size)
            }
        }
    }
}

// MARK: - Night Milky Way

private struct NightMilkyWay: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            context.drawLayer { ctx in
                let anchorPt = CGPoint(x: size.width * 0.5, y: size.height * 0.15)
                ctx.translateBy(x: anchorPt.x, y: anchorPt.y)
                ctx.rotate(by: .degrees(-12))
                ctx.translateBy(x: -anchorPt.x, y: -anchorPt.y)
                let rect = CGRect(x: -50, y: size.height * 0.05, width: size.width + 100, height: size.height * 0.2)
                ctx.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 180/255, green: 160/255, blue: 220/255).opacity(0),
                        Color(red: 200/255, green: 180/255, blue: 230/255).opacity(0.12),
                        Color(red: 220/255, green: 200/255, blue: 240/255).opacity(0.22),
                        Color(red: 200/255, green: 180/255, blue: 230/255).opacity(0.12),
                        Color(red: 180/255, green: 160/255, blue: 220/255).opacity(0)
                    ]),
                    startPoint: CGPoint(x: rect.minX, y: rect.midY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                ))
            }
        }
    }
}

// MARK: - Night Star Field

private struct StarSeed {
    let xNorm: CGFloat
    let yNorm: CGFloat
    let radius: CGFloat
    let baseOpacity: Double
    let twinkleSpeed: Double
    let twinklePhase: Double
}

private struct BigStarSeed {
    let xNorm: CGFloat
    let yNorm: CGFloat
    let twinkleSpeed: Double
    let twinklePhase: Double
}

private struct NightStarField: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var smallStars: [StarSeed] = []
    @State private var bigStars: [BigStarSeed] = []

    private let moonExcludeX: CGFloat = 0.75
    private let moonExcludeY: CGFloat = 0.20
    private let moonExcludeR: CGFloat = 0.18

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let w = size.width
                let h = size.height

                // Small stars
                for star in smallStars {
                    let twinkle = 0.5 + 0.5 * sin(time * star.twinkleSpeed + star.twinklePhase)
                    let opacity = star.baseOpacity * (0.3 + 0.7 * twinkle)
                    let x = star.xNorm * w
                    let y = star.yNorm * h
                    let r = star.radius
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(Ellipse().path(in: rect), with: .color(Color(hex: "#FFF8DC").opacity(opacity)))
                }

                // Big stars with flares
                for star in bigStars {
                    let twinkle = 0.5 + 0.5 * sin(time * star.twinkleSpeed + star.twinklePhase)
                    let opacity = 0.7 + 0.3 * twinkle
                    let x = star.xNorm * w
                    let y = star.yNorm * h

                    // Halo
                    let haloRect = CGRect(x: x - 2.2, y: y - 2.2, width: 4.4, height: 4.4)
                    context.fill(Ellipse().path(in: haloRect), with: .color(Color(hex: "#FFF8DC").opacity(0.35 * opacity)))

                    // 4-point flare
                    var flare = Path()
                    flare.move(to: CGPoint(x: x, y: y - 5))
                    flare.addLine(to: CGPoint(x: x + 0.6, y: y - 0.6))
                    flare.addLine(to: CGPoint(x: x + 5, y: y))
                    flare.addLine(to: CGPoint(x: x + 0.6, y: y + 0.6))
                    flare.addLine(to: CGPoint(x: x, y: y + 5))
                    flare.addLine(to: CGPoint(x: x - 0.6, y: y + 0.6))
                    flare.addLine(to: CGPoint(x: x - 5, y: y))
                    flare.addLine(to: CGPoint(x: x - 0.6, y: y - 0.6))
                    flare.closeSubpath()
                    context.fill(flare, with: .color(Color(hex: "#FFF8DC").opacity(0.9 * opacity)))

                    // Core
                    let coreRect = CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)
                    context.fill(Ellipse().path(in: coreRect), with: .color(Color(hex: "#FFFBE8").opacity(opacity)))

                    // Glow drop-shadow effect
                    if twinkle > 0.7 {
                        let glowRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                        context.fill(Ellipse().path(in: glowRect), with: .color(Color(hex: "#FFF8DC").opacity(0.15)))
                    }
                }
            }
        }
        .onAppear {
            generateStars()
        }
    }

    private func generateStars() {
        var stars: [StarSeed] = []
        var attempts = 0
        while stars.count < 120 && attempts < 500 {
            attempts += 1
            let x = CGFloat.random(in: 0...1)
            let y = CGFloat.random(in: 0...0.55) // Keep above mountains
            let dx = x - moonExcludeX
            let dy = y - moonExcludeY
            if sqrt(dx * dx + dy * dy) < moonExcludeR { continue }
            stars.append(StarSeed(
                xNorm: x, yNorm: y,
                radius: 0.3 + CGFloat.random(in: 0...0.9),
                baseOpacity: 0.4 + Double.random(in: 0...0.5),
                twinkleSpeed: Double.random(in: 1.5...3.5),
                twinklePhase: Double.random(in: 0...(.pi * 2))
            ))
        }
        smallStars = stars

        let bigPositions: [(CGFloat, CGFloat)] = [
            (0.11, 0.12), (0.24, 0.07), (0.38, 0.20), (0.51, 0.08),
            (0.44, 0.30), (0.24, 0.40), (0.61, 0.22), (0.56, 0.38),
            (0.15, 0.27), (0.93, 0.15), (0.96, 0.32), (0.33, 0.11)
        ]
        bigStars = bigPositions.compactMap { (x, y) in
            let dx = x - moonExcludeX
            let dy = y - moonExcludeY
            if sqrt(dx * dx + dy * dy) < moonExcludeR { return nil }
            return BigStarSeed(
                xNorm: x, yNorm: y,
                twinkleSpeed: Double.random(in: 1...2),
                twinklePhase: Double.random(in: 0...(.pi * 2))
            )
        }
    }
}

// MARK: - Night Shooting Star

private struct NightShootingStar: View {
    let size: CGSize
    @State private var shooting = false
    @State private var shootX: CGFloat = 0
    @State private var shootY: CGFloat = 0
    @State private var shootAngle: Double = 25
    @State private var shootLen: CGFloat = 40

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                guard shooting else { return }
                let dur: Double = 0.7
                let cycle = time.truncatingRemainder(dividingBy: 20)
                let t = min(1, cycle / dur)
                guard t < 1 else { return }

                let ease = 1 - pow(1 - t, 2)
                let rad = shootAngle * .pi / 180
                let sx = shootX
                let sy = shootY
                let ex = sx + cos(rad) * shootLen * ease
                let ey = sy + sin(rad) * shootLen * ease
                let opacity = t < 0.2 ? t / 0.2 : (1 - (t - 0.2) / 0.8)

                var line = Path()
                line.move(to: CGPoint(x: sx, y: sy))
                line.addLine(to: CGPoint(x: ex, y: ey))
                context.stroke(line, with: .color(Color(hex: "#FFF8DC").opacity(opacity)),
                              style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
        .onAppear {
            scheduleShot()
        }
    }

    private func scheduleShot() {
        let delay = Double.random(in: 4...10)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            shootX = CGFloat.random(in: 20...(size.width * 0.4))
            shootY = CGFloat.random(in: 20...(size.height * 0.2))
            shootAngle = Double.random(in: 20...35)
            shootLen = CGFloat.random(in: 35...60)
            shooting = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                shooting = false
                scheduleShot()
            }
        }
    }
}

// MARK: - Night Moon

private struct NightMoon: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var glowPulsing = false

    var body: some View {
        let cx = size.width * 0.75
        let cy = size.height * 0.20
        let bodyR = size.width * 0.055
        let haloR = bodyR * 2.2

        Canvas { context, canvasSize in
            // Soft halo
            let haloPulse: Double = glowPulsing ? 0.6 : 0.35
            let haloRect = CGRect(x: cx - haloR, y: cy - haloR, width: haloR * 2, height: haloR * 2)
            context.fill(Ellipse().path(in: haloRect), with: .radialGradient(
                Gradient(colors: [
                    Color(hex: "#FFF8DC").opacity(haloPulse),
                    Color(hex: "#FFF8DC").opacity(haloPulse * 0.25),
                    Color(hex: "#FFF8DC").opacity(0)
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0,
                endRadius: haloR
            ))

            // Moon body
            let moonRect = CGRect(x: cx - bodyR, y: cy - bodyR, width: bodyR * 2, height: bodyR * 2)
            context.fill(Ellipse().path(in: moonRect), with: .color(Color(hex: "#FFF8DC")))

            // Craters
            let craters: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
                (-0.31, -0.23, 0.15, 0.12, 0.7),
                (0.35, 0.15, 0.19, 0.15, 0.7),
                (-0.15, 0.38, 0.12, 0.10, 0.6),
                (0.42, -0.38, 0.08, 0.06, 0.55),
            ]
            for (ox, oy, rx, ry, op) in craters {
                let craterRect = CGRect(
                    x: cx + ox * bodyR - rx * bodyR,
                    y: cy + oy * bodyR - ry * bodyR,
                    width: rx * bodyR * 2,
                    height: ry * bodyR * 2
                )
                context.fill(Ellipse().path(in: craterRect), with: .color(Color(hex: "#D8CFA8").opacity(op)))
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 6).repeatForever(autoreverses: true),
            value: glowPulsing
        )
        .onAppear { if !reduceMotion { glowPulsing = true } }
    }
}

// MARK: - Night Mountains

private struct NightMountains: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height

            // Back mountains
            var back = Path()
            back.move(to: CGPoint(x: -30, y: h * 0.70))
            back.addLine(to: CGPoint(x: w * 0.075, y: h * 0.47))
            back.addLine(to: CGPoint(x: w * 0.14, y: h * 0.57))
            back.addLine(to: CGPoint(x: w * 0.225, y: h * 0.40))
            back.addLine(to: CGPoint(x: w * 0.325, y: h * 0.55))
            back.addLine(to: CGPoint(x: w * 0.425, y: h * 0.37))
            back.addLine(to: CGPoint(x: w * 0.525, y: h * 0.52))
            back.addLine(to: CGPoint(x: w * 0.625, y: h * 0.43))
            back.addLine(to: CGPoint(x: w * 0.725, y: h * 0.55))
            back.addLine(to: CGPoint(x: w * 0.825, y: h * 0.38))
            back.addLine(to: CGPoint(x: w * 0.925, y: h * 0.52))
            back.addLine(to: CGPoint(x: w + 30, y: h * 0.67))
            back.addLine(to: CGPoint(x: w + 30, y: h))
            back.addLine(to: CGPoint(x: -30, y: h))
            back.closeSubpath()
            context.fill(back, with: .linearGradient(
                Gradient(colors: [Color(hex: "#4A4D7A"), Color(hex: "#25284A")]),
                startPoint: CGPoint(x: w/2, y: h * 0.37),
                endPoint: CGPoint(x: w/2, y: h)
            ))

            // Snow caps on back range
            let snowCapPeaks: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.075, 0.47, 0.10, 0.51, 0.125, 0.49),
                (0.225, 0.40, 0.27, 0.47, 0.29, 0.46),
                (0.425, 0.37, 0.47, 0.43, 0.49, 0.42),
                (0.825, 0.38, 0.86, 0.45, 0.88, 0.44),
            ]
            for (px, py, lx, ly, rx, ry) in snowCapPeaks {
                var cap = Path()
                cap.move(to: CGPoint(x: w * px, y: h * py))
                cap.addLine(to: CGPoint(x: w * lx, y: h * ly))
                cap.addLine(to: CGPoint(x: w * rx, y: h * ry))
                cap.closeSubpath()
                context.fill(cap, with: .linearGradient(
                    Gradient(colors: [Color(hex: "#E8E0FF").opacity(0.85), Color(hex: "#8890C0").opacity(0.2)]),
                    startPoint: CGPoint(x: w * px, y: h * py),
                    endPoint: CGPoint(x: w * lx, y: h * ly)
                ))
            }

            // Mid mountains
            var mid = Path()
            mid.move(to: CGPoint(x: -30, y: h * 0.80))
            mid.addLine(to: CGPoint(x: w * 0.025, y: h * 0.65))
            mid.addLine(to: CGPoint(x: w * 0.125, y: h * 0.72))
            mid.addLine(to: CGPoint(x: w * 0.25, y: h * 0.58))
            mid.addLine(to: CGPoint(x: w * 0.375, y: h * 0.73))
            mid.addLine(to: CGPoint(x: w * 0.5, y: h * 0.60))
            mid.addLine(to: CGPoint(x: w * 0.65, y: h * 0.72))
            mid.addLine(to: CGPoint(x: w * 0.775, y: h * 0.62))
            mid.addLine(to: CGPoint(x: w * 0.9, y: h * 0.73))
            mid.addLine(to: CGPoint(x: w + 30, y: h * 0.70))
            mid.addLine(to: CGPoint(x: w + 30, y: h))
            mid.addLine(to: CGPoint(x: -30, y: h))
            mid.closeSubpath()
            context.fill(mid, with: .linearGradient(
                Gradient(colors: [Color(hex: "#353866"), Color(hex: "#1A1D40")]),
                startPoint: CGPoint(x: w/2, y: h * 0.58),
                endPoint: CGPoint(x: w/2, y: h)
            ))

            // Snow on mid range peaks
            let midCaps: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.25, 0.58, 0.30, 0.63),
                (0.5, 0.60, 0.55, 0.65),
                (0.775, 0.62, 0.82, 0.66),
            ]
            for (px, py, rx, ry) in midCaps {
                var cap = Path()
                cap.move(to: CGPoint(x: w * px, y: h * py))
                cap.addLine(to: CGPoint(x: w * (px + 0.03), y: h * (py + 0.04)))
                cap.addLine(to: CGPoint(x: w * rx, y: h * ry))
                cap.closeSubpath()
                context.fill(cap, with: .color(Color(hex: "#E8E0FF").opacity(0.7)))
            }

            // Front mountains
            var front = Path()
            front.move(to: CGPoint(x: -30, y: h * 0.90))
            front.addLine(to: CGPoint(x: w * 0.1, y: h * 0.78))
            front.addLine(to: CGPoint(x: w * 0.225, y: h * 0.87))
            front.addLine(to: CGPoint(x: w * 0.4, y: h * 0.77))
            front.addLine(to: CGPoint(x: w * 0.6, y: h * 0.88))
            front.addLine(to: CGPoint(x: w * 0.775, y: h * 0.80))
            front.addLine(to: CGPoint(x: w * 0.95, y: h * 0.90))
            front.addLine(to: CGPoint(x: w + 30, y: h * 0.87))
            front.addLine(to: CGPoint(x: w + 30, y: h))
            front.addLine(to: CGPoint(x: -30, y: h))
            front.closeSubpath()
            context.fill(front, with: .linearGradient(
                Gradient(colors: [Color(hex: "#1F223E"), Color(hex: "#0C0E1F")]),
                startPoint: CGPoint(x: w/2, y: h * 0.77),
                endPoint: CGPoint(x: w/2, y: h)
            ))

            // Mist between mid/front
            let mist1 = CGRect(x: w * 0.15, y: h * 0.82 - 10, width: w * 0.35, height: 20)
            let mist2 = CGRect(x: w * 0.55, y: h * 0.83 - 8, width: w * 0.30, height: 16)
            context.fill(Ellipse().path(in: mist1), with: .color(Color(hex: "#3A3D66").opacity(0.35)))
            context.fill(Ellipse().path(in: mist2), with: .color(Color(hex: "#3A3D66").opacity(0.3)))
        }
    }
}

// MARK: - Night Pine Silhouettes

private struct NightPines: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var sway1 = false
    @State private var sway2 = false

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height

            // Pines at various positions
            let pines: [(CGFloat, CGFloat, CGFloat, Bool)] = [
                (0.175, 0.88, 1.0, true),
                (0.85, 0.87, 1.15, false),
            ]
            for (xf, yf, sc, isFirst) in pines {
                let x = w * xf
                let y = h * yf
                let s = sc * w * 0.002
                let rot = (isFirst ? sway1 : sway2) ? 1.0 : -1.0

                context.drawLayer { ctx in
                    let anchorX = x
                    let anchorY = y + 4 * s
                    ctx.translateBy(x: anchorX, y: anchorY)
                    ctx.rotate(by: .degrees(rot * 0.8))
                    ctx.translateBy(x: -anchorX, y: -anchorY)

                    // Trunk
                    var trunk = Path()
                    trunk.addRect(CGRect(x: x - 1.5*s, y: y, width: 3*s, height: 4*s))
                    ctx.fill(trunk, with: .color(Color(hex: "#06081A")))

                    // Pine body
                    var body = Path()
                    body.move(to: CGPoint(x: x, y: y - 42*s))
                    body.addQuadCurve(
                        to: CGPoint(x: x - 11*s, y: y - 10*s),
                        control: CGPoint(x: x - 10*s, y: y - 22*s)
                    )
                    body.addQuadCurve(
                        to: CGPoint(x: x, y: y),
                        control: CGPoint(x: x - 12*s, y: y)
                    )
                    body.addQuadCurve(
                        to: CGPoint(x: x + 11*s, y: y - 10*s),
                        control: CGPoint(x: x + 12*s, y: y)
                    )
                    body.addQuadCurve(
                        to: CGPoint(x: x, y: y - 42*s),
                        control: CGPoint(x: x + 10*s, y: y - 22*s)
                    )
                    body.closeSubpath()
                    ctx.fill(body, with: .color(Color(hex: "#05061A")))

                    // Moonlit edge
                    var edge = Path()
                    edge.move(to: CGPoint(x: x, y: y - 42*s))
                    edge.addQuadCurve(
                        to: CGPoint(x: x - 8*s, y: y),
                        control: CGPoint(x: x - 7*s, y: y - 22*s)
                    )
                    ctx.stroke(edge, with: .color(Color(hex: "#1B1E3A").opacity(0.8)),
                              style: StrokeStyle(lineWidth: 1, lineCap: .round))

                    // Branch tufts
                    let tuftRect1 = CGRect(x: x - 5*s - 3*s, y: y - 28*s - 1.5*s, width: 6*s, height: 3*s)
                    let tuftRect2 = CGRect(x: x - 6*s - 4*s, y: y - 16*s - 2*s, width: 8*s, height: 4*s)
                    ctx.fill(Ellipse().path(in: tuftRect1), with: .color(Color(hex: "#0A0D22")))
                    ctx.fill(Ellipse().path(in: tuftRect2), with: .color(Color(hex: "#0A0D22")))
                }
            }

            // Small distant tree cluster
            let cx = w * 0.45
            let cy = h * 0.86
            let clusterTrees: [(CGFloat, CGFloat)] = [(0, -16), (-10, -20), (12, -22)]
            for (ox, oy) in clusterTrees {
                let s = w * 0.001
                var pine = Path()
                pine.move(to: CGPoint(x: cx + ox * s, y: cy + oy * s))
                pine.addQuadCurve(
                    to: CGPoint(x: cx + (ox - 5) * s, y: cy + (oy + 16) * s),
                    control: CGPoint(x: cx + (ox - 5) * s, y: cy + (oy + 6) * s)
                )
                pine.addQuadCurve(
                    to: CGPoint(x: cx + (ox + 5) * s, y: cy + (oy + 16) * s),
                    control: CGPoint(x: cx + (ox + 5) * s, y: cy + (oy + 6) * s)
                )
                pine.closeSubpath()
                context.fill(pine, with: .color(Color(hex: "#0A0D22").opacity(0.75)))
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 14).repeatForever(autoreverses: true),
            value: sway1
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 17).repeatForever(autoreverses: true),
            value: sway2
        )
        .onAppear {
            if !reduceMotion {
                sway1 = true
                sway2 = true
            }
        }
    }
}

// MARK: - Night Moon Reflection

private struct NightMoonReflection: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height
            let cx = w * 0.75

            let reflections: [(CGFloat, CGFloat, CGFloat, Double)] = [
                (cx, h * 0.91, 6, 0.25),
                (cx, h * 0.93, 10, 0.15),
                (cx, h * 0.95, 14, 0.10),
            ]
            for (x, y, rx, op) in reflections {
                let rect = CGRect(x: x - rx, y: y - 1.3, width: rx * 2, height: 2.6)
                context.fill(Ellipse().path(in: rect), with: .color(Color(hex: "#FFF8DC").opacity(op)))
            }
        }
    }
}

// MARK: - Night Wisps

private struct NightWisps: View {
    let size: CGSize
    let reduceMotion: Bool

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, canvasSize in
                    let w = size.width
                    let h = size.height
                    let wisps: [(CGFloat, Double, Double)] = [
                        (0.55, 16, -2), (0.70, 20, -8)
                    ]
                    for (yFrac, dur, delay) in wisps {
                        let cycle = dur
                        let t = ((time + delay).truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle) / cycle
                        let xOffset = -80 + (w + 160) * t
                        let opacity = t < 0.2 ? t / 0.2 * 0.35 : (t > 0.8 ? (1 - t) / 0.2 * 0.35 : 0.35)
                        let y = h * yFrac

                        var wisp = Path()
                        wisp.move(to: CGPoint(x: xOffset, y: y))
                        wisp.addQuadCurve(
                            to: CGPoint(x: xOffset + 120, y: y + 7),
                            control: CGPoint(x: xOffset + 60, y: y - 2)
                        )
                        wisp.addQuadCurve(
                            to: CGPoint(x: xOffset + 240, y: y),
                            control: CGPoint(x: xOffset + 180, y: y + 12)
                        )
                        context.stroke(wisp, with: .color(Color(hex: "#B8C0DC").opacity(opacity)),
                                      style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                    }
                }
            }
        }
    }
}

// MARK: - Night Fireflies

private struct FireflySeed {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    let phase: CGFloat
    let speed: CGFloat
    let size: CGFloat
}

private struct NightFireflies: View {
    let size: CGSize
    @State private var flies: [FireflySeed] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let w = size.width
                let h = size.height

                for i in flies.indices {
                    var f = flies[i]
                    let glow = 0.3 + abs(sin(CGFloat(time) * f.speed + f.phase)) * 0.7

                    // Outer glow
                    let glowR = f.size * 8
                    let glowRect = CGRect(x: f.x - glowR, y: f.y - glowR, width: glowR * 2, height: glowR * 2)
                    context.fill(Ellipse().path(in: glowRect), with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 1, green: 0.94, blue: 0.59).opacity(glow),
                            Color(red: 1, green: 0.86, blue: 0.39).opacity(glow * 0.3),
                            Color(red: 1, green: 0.86, blue: 0.39).opacity(0)
                        ]),
                        center: CGPoint(x: f.x, y: f.y),
                        startRadius: 0,
                        endRadius: glowR
                    ))

                    // Core
                    let coreRect = CGRect(x: f.x - f.size, y: f.y - f.size, width: f.size * 2, height: f.size * 2)
                    context.fill(Ellipse().path(in: coreRect), with: .color(Color(red: 1, green: 0.98, blue: 0.78).opacity(glow)))

                    // Update position
                    f.x += f.vx
                    f.y += f.vy
                    f.vx += CGFloat.random(in: -0.04...0.04)
                    f.vy += CGFloat.random(in: -0.04...0.04)
                    f.vx = max(-0.5, min(0.5, f.vx))
                    f.vy = max(-0.3, min(0.3, f.vy))
                    if f.x < 0 { f.x = w }
                    if f.x > w { f.x = 0 }
                    if f.y < h * 0.5 { f.y = h * 0.5 }
                    if f.y > h { f.y = h }
                    flies[i] = f
                }
            }
            .blendMode(.plusLighter)
        }
        .onAppear {
            var generated: [FireflySeed] = []
            for _ in 0..<22 {
                generated.append(FireflySeed(
                    x: CGFloat.random(in: 0...size.width),
                    y: size.height * 0.5 + CGFloat.random(in: 0...(size.height * 0.45)),
                    vx: CGFloat.random(in: -0.15...0.15),
                    vy: CGFloat.random(in: -0.1...0.1),
                    phase: CGFloat.random(in: 0...(.pi * 2)),
                    speed: CGFloat.random(in: 0.02...0.05),
                    size: 1.2 + CGFloat.random(in: 0...1.5)
                ))
            }
            flies = generated
        }
    }
}
