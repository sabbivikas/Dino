//
//  RainyScene.swift
//  Dino
//
//  Rainy storybook meditation scene (split, no behavior change).
//

import SwiftUI


// MARK: - ═══════════════════════════════════════════
// MARK:   RAINY SCENE
// MARK: - ═══════════════════════════════════════════

struct RainyScene: View {
    let size: CGSize
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            // Sky
            LinearGradient(
                colors: [Color(red: 120/255, green: 130/255, blue: 150/255),
                         Color(red: 155/255, green: 165/255, blue: 180/255)],
                startPoint: .top, endPoint: .bottom
            )

            // Dark clouds
            RainyClouds(size: size, reduceMotion: reduceMotion)

            // Hills
            RainyHills(size: size)

            // Puddles with ripples
            RainyPuddles(size: size, reduceMotion: reduceMotion)

            // Wet tree
            RainyWetTree(size: size, reduceMotion: reduceMotion)

            // Wind-tossed leaves
            if !reduceMotion {
                RainyLeaves(size: size)
            }

            // Wind wisps
            if !reduceMotion {
                RainyWisps(size: size)
            }

            // Rain overlay
            if !reduceMotion {
                RainOverlay(size: size)
            }
        }
    }
}

// MARK: - Rainy Clouds

private struct RainyClouds: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var drift1: CGFloat = -0.3
    @State private var drift2: CGFloat = -0.2

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height

            // Large dark cloud
            let x1 = w * drift1
            let y1 = h * 0.10
            let s1: CGFloat = 1.0
            drawRainCloud(context: &context, x: x1, y: y1, scale: s1 * w * 0.003, fillColor: Color(hex: "#6B7280"))

            // Smaller cloud
            let x2 = w * drift2
            let y2 = h * 0.06
            let s2: CGFloat = 0.75
            drawRainCloud(context: &context, x: x2, y: y2, scale: s2 * w * 0.003, fillColor: Color(hex: "#8891A1"))
        }
        .animation(
            reduceMotion ? nil : .linear(duration: 75).repeatForever(autoreverses: false),
            value: drift1
        )
        .animation(
            reduceMotion ? nil : .linear(duration: 90).repeatForever(autoreverses: false),
            value: drift2
        )
        .onAppear {
            if !reduceMotion {
                drift1 = 1.3
                drift2 = 1.3
            }
        }
    }

    private func drawRainCloud(context: inout GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat, fillColor: Color) {
        let s = scale
        var cloud = Path()
        cloud.move(to: CGPoint(x: x + 20*s, y: y + 20*s))
        cloud.addQuadCurve(to: CGPoint(x: x + 5*s, y: y + 35*s), control: CGPoint(x: x + 5*s, y: y + 20*s))
        cloud.addQuadCurve(to: CGPoint(x: x - 5*s, y: y + 48*s), control: CGPoint(x: x - 5*s, y: y + 35*s))
        cloud.addQuadCurve(to: CGPoint(x: x + 10*s, y: y + 60*s), control: CGPoint(x: x - 5*s, y: y + 60*s))
        cloud.addLine(to: CGPoint(x: x + 100*s, y: y + 60*s))
        cloud.addQuadCurve(to: CGPoint(x: x + 102*s, y: y + 32*s), control: CGPoint(x: x + 118*s, y: y + 46*s))
        cloud.addQuadCurve(to: CGPoint(x: x + 80*s, y: y + 15*s), control: CGPoint(x: x + 100*s, y: y + 15*s))
        cloud.addQuadCurve(to: CGPoint(x: x + 48*s, y: y + 18*s), control: CGPoint(x: x + 65*s, y: y + 8*s))
        cloud.addQuadCurve(to: CGPoint(x: x + 20*s, y: y + 20*s), control: CGPoint(x: x + 38*s, y: y + 8*s))
        cloud.closeSubpath()
        context.fill(cloud, with: .color(fillColor))
        context.stroke(cloud, with: .color(Color(hex: "#2D3142")), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Rainy Hills

private struct RainyHills: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height

            // Far hill
            var far = Path()
            far.move(to: CGPoint(x: -20, y: h * 0.80))
            far.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.75), control: CGPoint(x: w * 0.2, y: h * 0.67))
            far.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.72), control: CGPoint(x: w * 0.65, y: h * 0.83))
            far.addLine(to: CGPoint(x: w + 20, y: h))
            far.addLine(to: CGPoint(x: -20, y: h))
            far.closeSubpath()
            context.fill(far, with: .linearGradient(
                Gradient(colors: [Color(hex: "#7A8A8E"), Color(hex: "#4F6266")]),
                startPoint: CGPoint(x: w/2, y: h * 0.67),
                endPoint: CGPoint(x: w/2, y: h)
            ))
            // Misty haze
            var haze = Path()
            haze.move(to: CGPoint(x: -20, y: h * 0.80))
            haze.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.75), control: CGPoint(x: w * 0.2, y: h * 0.67))
            haze.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.72), control: CGPoint(x: w * 0.65, y: h * 0.83))
            haze.addLine(to: CGPoint(x: w + 20, y: h * 0.75))
            haze.addLine(to: CGPoint(x: -20, y: h * 0.83))
            haze.closeSubpath()
            context.fill(haze, with: .color(Color(hex: "#BFC7CA").opacity(0.35)))

            // Near hill
            var near = Path()
            near.move(to: CGPoint(x: -20, y: h * 0.88))
            near.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.86), control: CGPoint(x: w * 0.3, y: h * 0.78))
            near.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.83), control: CGPoint(x: w * 0.8, y: h * 0.92))
            near.addLine(to: CGPoint(x: w + 20, y: h))
            near.addLine(to: CGPoint(x: -20, y: h))
            near.closeSubpath()
            context.fill(near, with: .linearGradient(
                Gradient(colors: [Color(hex: "#5A6E70"), Color(hex: "#2F4448")]),
                startPoint: CGPoint(x: w/2, y: h * 0.78),
                endPoint: CGPoint(x: w/2, y: h)
            ))
            // Ridge accent
            var nearRidge = Path()
            nearRidge.move(to: CGPoint(x: -20, y: h * 0.88))
            nearRidge.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.86), control: CGPoint(x: w * 0.3, y: h * 0.78))
            nearRidge.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.83), control: CGPoint(x: w * 0.8, y: h * 0.92))
            context.stroke(nearRidge, with: .color(Color(hex: "#1E2E32").opacity(0.4)), style: StrokeStyle(lineWidth: 1.2))
        }
    }
}

// MARK: - Rainy Puddles

private struct RainyPuddles: View {
    let size: CGSize
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let w = size.width
                let h = size.height

                let puddles: [(CGFloat, CGFloat, CGFloat, CGFloat, [Double])] = [
                    (0.20, 0.91, 22, 4, [0, -1.2]),
                    (0.70, 0.95, 30, 5, [-0.6, 0]),
                    (0.50, 0.97, 15, 3, [-1.0]),
                ]
                for (xf, yf, rx, ry, delays) in puddles {
                    let x = w * xf
                    let y = h * yf

                    // Puddle base
                    let baseRect = CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2)
                    context.fill(Ellipse().path(in: baseRect), with: .color(Color(hex: "#6B8398").opacity(0.7)))

                    // Ripple rings
                    for delay in delays {
                        let cycle: Double = 2.4
                        let t = ((time + delay).truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle) / cycle
                        let scale = 0.1 + t * 1.7
                        let opacity = 0.9 * (1 - t)
                        let rippleRx = 8 * scale
                        let rippleRy = 1.5 * scale
                        let rippleRect = CGRect(x: x - rippleRx, y: y - rippleRy, width: rippleRx * 2, height: rippleRy * 2)
                        context.stroke(Ellipse().path(in: rippleRect),
                                      with: .color(.white.opacity(0.6 * opacity)),
                                      style: StrokeStyle(lineWidth: 0.8))
                    }
                }
            }
        }
    }
}

// MARK: - Rainy Wet Tree

private struct RainyWetTree: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var swaying = false

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height
            let x = w * 0.84
            let y = h * 0.90
            let s = w * 0.0025

            // Trunk
            var trunk = Path()
            trunk.move(to: CGPoint(x: x - 3*s, y: y))
            trunk.addCurve(
                to: CGPoint(x: x - 2*s, y: y - 34*s),
                control1: CGPoint(x: x - 4*s, y: y - 12*s),
                control2: CGPoint(x: x - 3*s, y: y - 24*s)
            )
            trunk.addCurve(
                to: CGPoint(x: x + 3*s, y: y),
                control1: CGPoint(x: x + 1*s, y: y - 34*s),
                control2: CGPoint(x: x + 4*s, y: y - 12*s)
            )
            trunk.closeSubpath()
            context.fill(trunk, with: .color(Color(hex: "#2E1F14")))

            // Dark wet canopy layers
            let dark: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (-12, -28, 15, 14), (10, -26, 17, 14), (-2, -40, 18, 14)
            ]
            for (ox, oy, rx, ry) in dark {
                let rect = CGRect(x: x + ox*s - rx*s, y: y + oy*s - ry*s, width: rx*2*s, height: ry*2*s)
                context.fill(Ellipse().path(in: rect), with: .color(Color(hex: "#223C2C")))
            }

            // Mid tone
            let mid: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (-10, -32, 12, 11), (8, -30, 14, 12), (-2, -42, 13, 10)
            ]
            for (ox, oy, rx, ry) in mid {
                let rect = CGRect(x: x + ox*s - rx*s, y: y + oy*s - ry*s, width: rx*2*s, height: ry*2*s)
                context.fill(Ellipse().path(in: rect), with: .color(Color(hex: "#3D5C48")))
            }

            // Highlight
            let hiRect = CGRect(x: x - 6*s - 6*s, y: y - 38*s - 5*s, width: 12*s, height: 10*s)
            context.fill(Ellipse().path(in: hiRect), with: .color(Color(hex: "#5F8268").opacity(0.7)))

            // Water sheen
            let sheenRect = CGRect(x: x - 4*s - 2*s, y: y - 44*s - 1.2*s, width: 4*s, height: 2.4*s)
            context.fill(Ellipse().path(in: sheenRect), with: .color(Color(hex: "#9CB8A0").opacity(0.5)))
        }
        .rotationEffect(.degrees(swaying ? 1.5 : -1.5), anchor: .bottom)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 7.5).repeatForever(autoreverses: true),
            value: swaying
        )
        .onAppear { if !reduceMotion { swaying = true } }
    }
}

// MARK: - Rainy Leaves

private struct RainyLeaves: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let w = size.width
                let h = size.height
                let leaves: [(CGFloat, CGFloat, Double, Double)] = [
                    (0.30, 3.5, 6, 0),
                    (0.22, 3.0, 8, -2),
                    (0.38, 4.0, 7, -5),
                ]
                for (yFrac, rx, dur, delay) in leaves {
                    let cycle = dur
                    let t = ((time + delay).truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle) / cycle
                    let x = -30 + (w + 60) * t
                    let y = h * yFrac + 80 * t
                    let rotation = t * 540
                    let opacity = t < 0.1 ? t / 0.1 : (t > 0.9 ? (1 - t) / 0.1 : 0.85)

                    context.drawLayer { ctx in
                        ctx.translateBy(x: x, y: y)
                        ctx.rotate(by: .degrees(rotation))
                        ctx.opacity = opacity
                        let rect = CGRect(x: -rx, y: -rx * 0.5, width: rx * 2, height: rx)
                        ctx.fill(Ellipse().path(in: rect), with: .color(Color(hex: "#3D5C48")))
                    }
                }
            }
        }
    }
}

// MARK: - Rainy Wisps

private struct RainyWisps: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let w = size.width
                let h = size.height
                let wisps: [(CGFloat, Double, Double)] = [
                    (0.20, 8, 0), (0.35, 10, -4)
                ]
                for (yFrac, dur, delay) in wisps {
                    let cycle = dur
                    let t = ((time + delay).truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle) / cycle
                    let xOffset = -80 + (w + 160) * t
                    let opacity = t < 0.2 ? t / 0.2 * 0.55 : (t > 0.8 ? (1 - t) / 0.2 * 0.55 : 0.55)
                    let y = h * yFrac

                    var wisp = Path()
                    wisp.move(to: CGPoint(x: xOffset, y: y))
                    wisp.addQuadCurve(
                        to: CGPoint(x: xOffset + 100, y: y + 5),
                        control: CGPoint(x: xOffset + 50, y: y - 2)
                    )
                    wisp.addQuadCurve(
                        to: CGPoint(x: xOffset + 200, y: y + 5),
                        control: CGPoint(x: xOffset + 150, y: y + 10)
                    )
                    context.stroke(wisp, with: .color(Color(hex: "#D8DEE2").opacity(opacity)),
                                  style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                }
            }
        }
    }
}

// MARK: - Rain Overlay (Canvas)

private struct RainDropSeed {
    let baseX: CGFloat
    let baseY: CGFloat
    let len: CGFloat
    let speed: CGFloat
    let alpha: Double
}

private struct RainOverlay: View {
    let size: CGSize
    @State private var seeds: [RainDropSeed] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: false)) { timeline in
            Canvas { context, _ in
                let w = size.width
                let h = size.height
                let time = timeline.date.timeIntervalSinceReferenceDate

                for seed in seeds {
                    // Compute position from time — wraps seamlessly
                    let totalFall = seed.speed * CGFloat(time)
                    let y = (seed.baseY + totalFall).truncatingRemainder(dividingBy: h + seed.len) - seed.len
                    let drift = totalFall * 0.2
                    let x = (seed.baseX - drift).truncatingRemainder(dividingBy: w + 40)

                    var line = Path()
                    line.move(to: CGPoint(x: x, y: y))
                    line.addLine(to: CGPoint(x: x - seed.len * 0.2, y: y + seed.len))
                    context.stroke(line, with: .color(Color(red: 180/255, green: 200/255, blue: 220/255).opacity(seed.alpha)),
                                  style: StrokeStyle(lineWidth: 1.1))
                }
            }
        }
        .onAppear {
            var generated: [RainDropSeed] = []
            for _ in 0..<120 {
                generated.append(RainDropSeed(
                    baseX: CGFloat.random(in: 0...size.width),
                    baseY: CGFloat.random(in: 0...size.height),
                    len: 12 + CGFloat.random(in: 0...8),
                    speed: 11 + CGFloat.random(in: 0...6),
                    alpha: 0.35 + Double.random(in: 0...0.35)
                ))
            }
            seeds = generated
        }
    }
}
