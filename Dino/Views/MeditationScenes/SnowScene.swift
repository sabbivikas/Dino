//
//  SnowScene.swift
//  Dino
//
//  Snowy storybook meditation scene (split, no behavior change).
//

import SwiftUI


// MARK: - ═══════════════════════════════════════════
// MARK:   SNOW SCENE
// MARK: - ═══════════════════════════════════════════

struct SnowScene: View {
    let size: CGSize
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            // Sky
            LinearGradient(
                colors: [Color(red: 200/255, green: 220/255, blue: 235/255),
                         Color(red: 230/255, green: 240/255, blue: 245/255)],
                startPoint: .top, endPoint: .bottom
            )

            // Pale sun
            SnowPaleSun(size: size)

            // Back snow hill
            SnowBackHill(size: size)

            // Mid-row pines
            SnowMidPines(size: size, reduceMotion: reduceMotion)

            // Front snow hill
            SnowFrontHill(size: size)

            // Foreground pines
            SnowForegroundPines(size: size, reduceMotion: reduceMotion)

            // Snow mounds
            SnowMounds(size: size)

            // Mist layers
            SnowMistLayers(size: size, reduceMotion: reduceMotion)

            // Gusty wisps
            if !reduceMotion {
                SnowWisps(size: size)
            }

            // Snowfall overlay
            if !reduceMotion {
                SnowOverlay(size: size)
            }
        }
    }
}

// MARK: - Snow Pale Sun

private struct SnowPaleSun: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let cx = size.width * 0.20
            let cy = size.height * 0.15
            let r1 = size.width * 0.08
            let r2 = size.width * 0.06
            let r3 = size.width * 0.045

            let rect1 = CGRect(x: cx - r1, y: cy - r1, width: r1 * 2, height: r1 * 2)
            context.fill(Ellipse().path(in: rect1), with: .color(Color(hex: "#FFF5E4").opacity(0.35)))

            let rect2 = CGRect(x: cx - r2, y: cy - r2, width: r2 * 2, height: r2 * 2)
            context.fill(Ellipse().path(in: rect2), with: .color(Color(hex: "#FFF5E4").opacity(0.55)))

            let rect3 = CGRect(x: cx - r3, y: cy - r3, width: r3 * 2, height: r3 * 2)
            context.fill(Ellipse().path(in: rect3), with: .color(Color(hex: "#FFFAF0").opacity(0.9)))
        }
    }
}

// MARK: - Snow Back Hill

private struct SnowBackHill: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height

            var hill = Path()
            hill.move(to: CGPoint(x: -20, y: h * 0.73))
            hill.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.70), control: CGPoint(x: w * 0.2, y: h * 0.60))
            hill.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.67), control: CGPoint(x: w * 0.65, y: h * 0.77))
            hill.addLine(to: CGPoint(x: w + 20, y: h))
            hill.addLine(to: CGPoint(x: -20, y: h))
            hill.closeSubpath()
            context.fill(hill, with: .linearGradient(
                Gradient(colors: [Color(hex: "#F8FAFC"), Color(hex: "#D0D8E2")]),
                startPoint: CGPoint(x: w/2, y: h * 0.60),
                endPoint: CGPoint(x: w/2, y: h)
            ))

            // Ridge haze
            var haze = Path()
            haze.move(to: CGPoint(x: -20, y: h * 0.73))
            haze.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.70), control: CGPoint(x: w * 0.2, y: h * 0.60))
            haze.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.67), control: CGPoint(x: w * 0.65, y: h * 0.77))
            haze.addLine(to: CGPoint(x: w + 20, y: h * 0.72))
            haze.addLine(to: CGPoint(x: -20, y: h * 0.78))
            haze.closeSubpath()
            context.fill(haze, with: .color(.white.opacity(0.5)))
        }
    }
}

// MARK: - Snow Mid Pines

private struct SnowMidPines: View {
    let size: CGSize
    let reduceMotion: Bool

    private let pines: [(CGFloat, CGFloat, CGFloat, Bool)] = [
        (0.175, 0.73, 0.75, true),
        (0.325, 0.71, 0.90, false),
        (0.488, 0.74, 0.65, true),
        (0.613, 0.73, 0.80, false),
        (0.775, 0.71, 0.70, true),
        (0.913, 0.74, 0.60, false),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<pines.count, id: \.self) { i in
                SnowPineView(
                    size: size,
                    xFrac: pines[i].0,
                    yFrac: pines[i].1,
                    scale: pines[i].2,
                    swayDuration: pines[i].3 ? 14 : 17,
                    reduceMotion: reduceMotion
                )
            }
        }
    }
}

// MARK: - Snow Pine View (snow-capped)

private struct SnowPineView: View {
    let size: CGSize
    let xFrac: CGFloat
    let yFrac: CGFloat
    let scale: CGFloat
    let swayDuration: Double
    let reduceMotion: Bool
    @State private var swaying = false

    var body: some View {
        Canvas { context, canvasSize in
            let x = size.width * xFrac
            let y = size.height * yFrac
            let s = scale * size.width * 0.002

            // Trunk
            var trunk = Path()
            trunk.addRect(CGRect(x: x - 2*s, y: y, width: 4*s, height: 5*s))
            context.fill(trunk, with: .color(Color(hex: "#3D2818")))

            // Main pine body
            var body = Path()
            body.move(to: CGPoint(x: x, y: y - 50*s))
            body.addQuadCurve(
                to: CGPoint(x: x - 16*s, y: y - 14*s),
                control: CGPoint(x: x - 14*s, y: y - 30*s)
            )
            body.addQuadCurve(
                to: CGPoint(x: x, y: y),
                control: CGPoint(x: x - 18*s, y: y)
            )
            body.addQuadCurve(
                to: CGPoint(x: x + 16*s, y: y - 14*s),
                control: CGPoint(x: x + 18*s, y: y)
            )
            body.addQuadCurve(
                to: CGPoint(x: x, y: y - 50*s),
                control: CGPoint(x: x + 14*s, y: y - 30*s)
            )
            body.closeSubpath()
            context.fill(body, with: .linearGradient(
                Gradient(colors: [Color(hex: "#4E6B56"), Color(hex: "#1E3326")]),
                startPoint: CGPoint(x: x, y: y - 50*s),
                endPoint: CGPoint(x: x, y: y)
            ))

            // Shadow on right side
            var shadow = Path()
            shadow.move(to: CGPoint(x: x, y: y - 50*s))
            shadow.addQuadCurve(
                to: CGPoint(x: x, y: y),
                control: CGPoint(x: x + 8*s, y: y - 14*s)
            )
            context.fill(shadow, with: .color(Color(hex: "#1A2C22").opacity(0.35)))

            // Snow on top
            var snowTop = Path()
            snowTop.move(to: CGPoint(x: x, y: y - 50*s))
            snowTop.addQuadCurve(
                to: CGPoint(x: x + 2*s, y: y - 40*s),
                control: CGPoint(x: x + 5*s, y: y - 44*s)
            )
            snowTop.addQuadCurve(
                to: CGPoint(x: x - 2*s, y: y - 40*s),
                control: CGPoint(x: x, y: y - 38*s)
            )
            snowTop.closeSubpath()
            context.fill(snowTop, with: .color(.white))

            // Mid snow tier
            var snowMid = Path()
            snowMid.move(to: CGPoint(x: x - 7*s, y: y - 30*s))
            snowMid.addQuadCurve(
                to: CGPoint(x: x + 7*s, y: y - 30*s),
                control: CGPoint(x: x, y: y - 25*s)
            )
            context.fill(snowMid, with: .color(.white.opacity(0.9)))

            // Bottom snow tier
            var snowBot = Path()
            snowBot.move(to: CGPoint(x: x - 12*s, y: y - 12*s))
            snowBot.addQuadCurve(
                to: CGPoint(x: x + 12*s, y: y - 12*s),
                control: CGPoint(x: x, y: y - 6*s)
            )
            context.fill(snowBot, with: .color(.white.opacity(0.85)))
        }
        .rotationEffect(.degrees(swaying ? 0.8 : -0.8), anchor: .bottom)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: swayDuration).repeatForever(autoreverses: true),
            value: swaying
        )
        .onAppear { if !reduceMotion { swaying = true } }
    }
}

// MARK: - Snow Front Hill

private struct SnowFrontHill: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height

            var hill = Path()
            hill.move(to: CGPoint(x: -20, y: h * 0.87))
            hill.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.86), control: CGPoint(x: w * 0.3, y: h * 0.78))
            hill.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.83), control: CGPoint(x: w * 0.8, y: h * 0.92))
            hill.addLine(to: CGPoint(x: w + 20, y: h))
            hill.addLine(to: CGPoint(x: -20, y: h))
            hill.closeSubpath()
            context.fill(hill, with: .linearGradient(
                Gradient(colors: [.white, Color(hex: "#E6EAF0")]),
                startPoint: CGPoint(x: w/2, y: h * 0.78),
                endPoint: CGPoint(x: w/2, y: h)
            ))

            // Soft shadow under ridge
            var shadow = Path()
            shadow.move(to: CGPoint(x: -20, y: h * 0.87))
            shadow.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.86), control: CGPoint(x: w * 0.3, y: h * 0.78))
            shadow.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.83), control: CGPoint(x: w * 0.8, y: h * 0.92))
            shadow.addLine(to: CGPoint(x: w + 20, y: h * 0.89))
            shadow.addLine(to: CGPoint(x: -20, y: h * 0.93))
            shadow.closeSubpath()
            context.fill(shadow, with: .color(Color(hex: "#C8D1DC").opacity(0.35)))
        }
    }
}

// MARK: - Snow Foreground Pines

private struct SnowForegroundPines: View {
    let size: CGSize
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            SnowPineView(size: size, xFrac: 0.11, yFrac: 0.87, scale: 1.25, swayDuration: 14, reduceMotion: reduceMotion)
            SnowPineView(size: size, xFrac: 0.875, yFrac: 0.87, scale: 1.1, swayDuration: 17, reduceMotion: reduceMotion)
            SnowPineView(size: size, xFrac: 0.36, yFrac: 0.90, scale: 0.5, swayDuration: 14, reduceMotion: reduceMotion)
        }
    }
}

// MARK: - Snow Mounds

private struct SnowMounds: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height
            let mounds: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
                (0.225, 0.95, 30, 6, 0.9),
                (0.55, 0.97, 42, 7, 0.9),
                (0.75, 0.96, 25, 5, 0.85),
            ]
            for (xf, yf, rx, ry, op) in mounds {
                let rect = CGRect(x: w * xf - rx, y: h * yf - ry, width: rx * 2, height: ry * 2)
                context.fill(Ellipse().path(in: rect), with: .color(.white.opacity(op)))
            }
        }
    }
}

// MARK: - Snow Mist Layers

private struct SnowMistLayers: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var drifting = false

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height
            let dx: CGFloat = drifting ? 20 : -20
            let opacity = drifting ? 0.55 : 0.3

            // First mist layer
            let rect1 = CGRect(x: w * 0.25 + dx - 120, y: h * 0.42 - 18, width: 240, height: 36)
            context.fill(Ellipse().path(in: rect1), with: .color(.white.opacity(opacity)))

            // Second mist layer
            let rect2 = CGRect(x: w * 0.6 + dx - 100, y: h * 0.50 - 14, width: 200, height: 28)
            context.fill(Ellipse().path(in: rect2), with: .color(.white.opacity(opacity * 0.85)))
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 20).repeatForever(autoreverses: true),
            value: drifting
        )
        .onAppear { if !reduceMotion { drifting = true } }
    }
}

// MARK: - Snow Wisps

private struct SnowWisps: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let w = size.width
                let h = size.height
                let wisps: [(CGFloat, Double, Double)] = [
                    (0.28, 14, 0), (0.39, 18, -5)
                ]
                for (yFrac, dur, delay) in wisps {
                    let cycle = dur
                    let t = ((time + delay).truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle) / cycle
                    let xOffset = -80 + (w + 160) * t
                    let opacity = t < 0.2 ? t / 0.2 * 0.5 : (t > 0.8 ? (1 - t) / 0.2 * 0.5 : 0.5)
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
                    context.stroke(wisp, with: .color(.white.opacity(opacity)),
                                  style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                }
            }
        }
    }
}

// MARK: - Snow Overlay (Canvas)

private struct SnowFlake {
    var x: CGFloat
    var y: CGFloat
    let r: CGFloat
    let speed: CGFloat
    var sway: CGFloat
    let swaySpeed: CGFloat
    let alpha: Double
}

private struct SnowOverlay: View {
    let size: CGSize
    @State private var flakes: [SnowFlake] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: false)) { timeline in
            Canvas { context, canvasSize in
                let w = size.width
                let h = size.height

                for i in flakes.indices {
                    var f = flakes[i]
                    f.sway += f.swaySpeed
                    let sx = sin(f.sway) * 0.8
                    let rect = CGRect(x: f.x + sx - f.r, y: f.y - f.r, width: f.r * 2, height: f.r * 2)
                    context.fill(Ellipse().path(in: rect), with: .color(.white.opacity(f.alpha)))
                    f.y += f.speed
                    f.x += sx * 0.3
                    if f.y > h + 5 {
                        f.y = -5
                        f.x = CGFloat.random(in: 0...w)
                    }
                    flakes[i] = f
                }
            }
        }
        .onAppear {
            var generated: [SnowFlake] = []
            for _ in 0..<90 {
                generated.append(SnowFlake(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height),
                    r: 1.2 + CGFloat.random(in: 0...2.6),
                    speed: 0.6 + CGFloat.random(in: 0...0.9),
                    sway: CGFloat.random(in: 0...(.pi * 2)),
                    swaySpeed: 0.008 + CGFloat.random(in: 0...0.012),
                    alpha: 0.6 + Double.random(in: 0...0.4)
                ))
            }
            flakes = generated
        }
    }
}
