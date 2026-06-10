//
//  SunnyScene.swift
//  Dino
//
//  Golden-hour storybook meditation scene (split, no behavior change).
//

import SwiftUI


// MARK: - Time of Day

private enum TimeOfDay {
    case dawn, noon, dusk

    static func current() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<8:   return .dawn
        case 8..<17:  return .noon
        case 17..<21: return .dusk
        default:      return .noon // Night scene handles 21-5 at scene level
        }
    }
}

// MARK: - ═══════════════════════════════════════════
// MARK:   SUNNY SCENE
// MARK: - ═══════════════════════════════════════════

struct SunnyScene: View {
    let size: CGSize
    let reduceMotion: Bool
    private let tod = TimeOfDay.current()

    var skyTop: Color {
        switch tod {
        case .dawn: return Color(red: 255/255, green: 196/255, blue: 155/255)
        case .noon: return Color(red: 135/255, green: 206/255, blue: 235/255)
        case .dusk: return Color(red: 255/255, green: 149/255, blue: 115/255)
        }
    }
    var skyBottom: Color {
        switch tod {
        case .dawn: return Color(red: 255/255, green: 224/255, blue: 196/255)
        case .noon: return Color(red: 195/255, green: 232/255, blue: 245/255)
        case .dusk: return Color(red: 255/255, green: 192/255, blue: 145/255)
        }
    }
    var sunPosition: CGPoint {
        switch tod {
        case .dawn: return CGPoint(x: size.width * 0.15, y: size.height * 0.38)
        case .noon: return CGPoint(x: size.width * 0.50, y: size.height * 0.13)
        case .dusk: return CGPoint(x: size.width * 0.85, y: size.height * 0.38)
        }
    }

    var body: some View {
        ZStack {
            // Sky gradient
            LinearGradient(colors: [skyTop, skyBottom], startPoint: .top, endPoint: .bottom)

            // Sun with rays
            SunnySun(position: sunPosition, size: size, reduceMotion: reduceMotion)

            // Clouds
            SunnyCloud(size: size, xOffset: 0, yFraction: 0.10, scale: 1.0, durationSec: 60, delaySec: 0, reduceMotion: reduceMotion)
            SunnyCloud(size: size, xOffset: -size.width * 0.15, yFraction: 0.06, scale: 0.75, durationSec: 90, delaySec: -20, reduceMotion: reduceMotion)
            SunnyCloud(size: size, xOffset: -size.width * 0.1, yFraction: 0.18, scale: 0.55, durationSec: 75, delaySec: -40, reduceMotion: reduceMotion)

            // Birds
            SunnyBird(size: size, startX: -0.05, startY: 0.09, endX: 1.1, endY: 0.06, birdSize: 16, durationSec: 22, reduceMotion: reduceMotion)
            SunnyBird(size: size, startX: 1.1, startY: 0.14, endX: -0.1, endY: 0.10, birdSize: 12, durationSec: 28, reduceMotion: reduceMotion)

            // Hills
            SunnyHills(size: size, reduceMotion: reduceMotion)

            // Foreground trees
            GhibliTree(size: size, xFrac: 0.175, yFrac: 0.78, scale: 0.95, swayDuration: 6, reduceMotion: reduceMotion)
            GhibliTree(size: size, xFrac: 0.81, yFrac: 0.77, scale: 1.15, swayDuration: 7.5, reduceMotion: reduceMotion)
            GhibliTree(size: size, xFrac: 0.49, yFrac: 0.80, scale: 0.55, swayDuration: 6, reduceMotion: reduceMotion)

            // Wildflowers
            SunnyWildflowers(size: size)

            // Drifting petals
            SunnyPetals(size: size, reduceMotion: reduceMotion)

            // Wind wisps
            SunnyWisps(size: size, reduceMotion: reduceMotion)
        }
    }
}

// MARK: - Sunny Sun

private struct SunnySun: View {
    let position: CGPoint
    let size: CGSize
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees(time.truncatingRemainder(dividingBy: 80) / 80 * 360)
            Canvas { context, canvasSize in
                let cx = position.x
                let cy = position.y
                let r: CGFloat = size.width * 0.06

                // Glow
                let glowRect = CGRect(x: cx - r * 2.5, y: cy - r * 2.5, width: r * 5, height: r * 5)
                context.opacity = 0.4
                context.fill(Ellipse().path(in: glowRect), with: .color(Color(hex: "#FFC94D").opacity(0.5)))
                context.opacity = 1

                // 8 Ray lines (rotated)
                let rayAngles: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
                for ra in rayAngles {
                    let a = Angle.degrees(ra + angle.degrees)
                    let innerR = r * 1.4
                    let outerR = r * 1.8
                    let x1 = cx + cos(a.radians) * innerR
                    let y1 = cy + sin(a.radians) * innerR
                    let x2 = cx + cos(a.radians) * outerR
                    let y2 = cy + sin(a.radians) * outerR
                    var ray = Path()
                    ray.move(to: CGPoint(x: x1, y: y1))
                    ray.addLine(to: CGPoint(x: x2, y: y2))
                    context.stroke(ray, with: .color(Color(hex: "#2D3142")), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }

                // Sun body
                let sunRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                context.fill(Ellipse().path(in: sunRect), with: .color(Color(hex: "#FFC94D")))

                // Ink outline
                context.stroke(Ellipse().path(in: sunRect), with: .color(Color(hex: "#2D3142")), style: StrokeStyle(lineWidth: 2))
            }
        }
    }
}

// MARK: - Sunny Cloud

private struct SunnyCloud: View {
    let size: CGSize
    let xOffset: CGFloat
    let yFraction: CGFloat
    let scale: CGFloat
    let durationSec: Double
    let delaySec: Double
    let reduceMotion: Bool
    @State private var driftX: CGFloat = -0.15

    var body: some View {
        Canvas { context, canvasSize in
            let s = scale
            let y = size.height * yFraction
            let x = size.width * driftX + xOffset

            // Main puffs
            let puffs: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
                (x + 20*s, y + 30*s, 22*s, 10*s, 0.95),
                (x + 42*s, y + 22*s, 26*s, 14*s, 0.95),
                (x + 64*s, y + 30*s, 20*s, 11*s, 0.90),
            ]
            for (px, py, rx, ry, op) in puffs {
                let rect = CGRect(x: px - rx, y: py - ry, width: rx * 2, height: ry * 2)
                context.fill(Ellipse().path(in: rect), with: .color(.white.opacity(op)))
            }
            // Shadow puffs
            let shadows: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
                (x + 30*s, y + 36*s, 14*s, 6*s, 0.6),
                (x + 54*s, y + 38*s, 18*s, 6*s, 0.5),
            ]
            for (px, py, rx, ry, op) in shadows {
                let rect = CGRect(x: px - rx, y: py - ry, width: rx * 2, height: ry * 2)
                context.fill(Ellipse().path(in: rect), with: .color(Color(hex: "#E8E0D0").opacity(op)))
            }
        }
        .animation(
            reduceMotion ? nil : .linear(duration: durationSec).repeatForever(autoreverses: false).delay(delaySec),
            value: driftX
        )
        .onAppear {
            if !reduceMotion { driftX = 1.15 }
        }
    }
}

// MARK: - Sunny Bird

private struct SunnyBird: View {
    let size: CGSize
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let birdSize: CGFloat
    let durationSec: Double
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            // Flap: scaleY oscillates 0.5 → 1.0 at 0.6s
            let flap = 0.5 + 0.5 * cos(time * .pi / 0.3)

            Canvas { context, canvasSize in
                let x = size.width * (startX + (endX - startX) * progress)
                let y = size.height * (startY + (endY - startY) * progress)
                let s = birdSize

                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addQuadCurve(
                    to: CGPoint(x: x + s * 0.5, y: y),
                    control: CGPoint(x: x + s * 0.25, y: y - s * 0.25 * flap)
                )
                path.addQuadCurve(
                    to: CGPoint(x: x + s, y: y),
                    control: CGPoint(x: x + s * 0.75, y: y - s * 0.25 * flap)
                )
                context.stroke(path, with: .color(Color(hex: "#3D2A1F")), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
        .animation(
            reduceMotion ? nil : .linear(duration: durationSec).repeatForever(autoreverses: false),
            value: progress
        )
        .onAppear {
            if !reduceMotion { progress = 1 }
        }
    }
}

// MARK: - Sunny Hills

private struct SunnyHills: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var sway1 = false
    @State private var sway2 = false

    var body: some View {
        let w = size.width
        let h = size.height

        Canvas { context, canvasSize in
            // Far hill
            let rot1: CGFloat = sway1 ? 0.6 : -0.6
            context.drawLayer { ctx in
                ctx.transform = CGAffineTransform(translationX: w / 2, y: h)
                    .rotated(by: rot1 * .pi / 180)
                    .translatedBy(x: -w / 2, y: -h)

                var farHill = Path()
                farHill.move(to: CGPoint(x: -20, y: h * 0.72))
                farHill.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.66), control: CGPoint(x: w * 0.18, y: h * 0.57))
                farHill.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.70), control: CGPoint(x: w * 0.6, y: h * 0.75))
                farHill.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.62), control: CGPoint(x: w * 0.95, y: h * 0.57))
                farHill.addLine(to: CGPoint(x: w + 20, y: h))
                farHill.addLine(to: CGPoint(x: -20, y: h))
                farHill.closeSubpath()

                // Fill gradient top: #B8D4A2 → bottom: #7FA872
                ctx.fill(farHill, with: .linearGradient(
                    Gradient(colors: [Color(hex: "#B8D4A2"), Color(hex: "#7FA872")]),
                    startPoint: CGPoint(x: w/2, y: h * 0.57),
                    endPoint: CGPoint(x: w/2, y: h)
                ))
                // Haze
                ctx.fill(farHill, with: .color(.white.opacity(0.18)))
            }

            // Mid hill
            var midHill = Path()
            midHill.move(to: CGPoint(x: -20, y: h * 0.80))
            midHill.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.73), control: CGPoint(x: w * 0.22, y: h * 0.68))
            midHill.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.71), control: CGPoint(x: w * 0.75, y: h * 0.77))
            midHill.addLine(to: CGPoint(x: w + 20, y: h))
            midHill.addLine(to: CGPoint(x: -20, y: h))
            midHill.closeSubpath()
            context.fill(midHill, with: .linearGradient(
                Gradient(colors: [Color(hex: "#8FB96A"), Color(hex: "#4F7A4C")]),
                startPoint: CGPoint(x: w/2, y: h * 0.68),
                endPoint: CGPoint(x: w/2, y: h)
            ))
            // Ridge stroke
            var ridge = Path()
            ridge.move(to: CGPoint(x: -20, y: h * 0.80))
            ridge.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.73), control: CGPoint(x: w * 0.22, y: h * 0.68))
            ridge.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.71), control: CGPoint(x: w * 0.75, y: h * 0.77))
            context.stroke(ridge, with: .color(Color(hex: "#2F4E32").opacity(0.35)), style: StrokeStyle(lineWidth: 1.2))

            // Background trees on mid hill
            let bgTreePositions: [(CGFloat, CGFloat, CGFloat)] = [
                (0.28, 0.73, 0.38), (0.36, 0.74, 0.32), (0.55, 0.73, 0.30),
                (0.69, 0.75, 0.36), (0.90, 0.72, 0.40)
            ]
            for (xf, yf, sc) in bgTreePositions {
                drawBgTree(context: &context, x: w * xf, y: h * yf, scale: sc * size.width * 0.003, opacity: 0.9)
            }

            // Near hill
            let rot2: CGFloat = sway2 ? 0.6 : -0.6
            context.drawLayer { ctx in
                ctx.transform = CGAffineTransform(translationX: w / 2, y: h)
                    .rotated(by: rot2 * .pi / 180)
                    .translatedBy(x: -w / 2, y: -h)

                var nearHill = Path()
                nearHill.move(to: CGPoint(x: -20, y: h * 0.88))
                nearHill.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.82), control: CGPoint(x: w * 0.3, y: h * 0.75))
                nearHill.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.81), control: CGPoint(x: w * 0.8, y: h * 0.90))
                nearHill.addLine(to: CGPoint(x: w + 20, y: h))
                nearHill.addLine(to: CGPoint(x: -20, y: h))
                nearHill.closeSubpath()

                ctx.fill(nearHill, with: .linearGradient(
                    Gradient(colors: [Color(hex: "#6E9E58"), Color(hex: "#35583A")]),
                    startPoint: CGPoint(x: w/2, y: h * 0.75),
                    endPoint: CGPoint(x: w/2, y: h)
                ))
                // Ridge accent
                var nearRidge = Path()
                nearRidge.move(to: CGPoint(x: -20, y: h * 0.88))
                nearRidge.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.82), control: CGPoint(x: w * 0.3, y: h * 0.75))
                nearRidge.addQuadCurve(to: CGPoint(x: w + 20, y: h * 0.81), control: CGPoint(x: w * 0.8, y: h * 0.90))
                ctx.stroke(nearRidge, with: .color(Color(hex: "#2A4630").opacity(0.4)), style: StrokeStyle(lineWidth: 1.5))

                // Grass tufts
                let tufts: [CGFloat] = [0.05, 0.13, 0.24, 0.40, 0.53, 0.68, 0.83, 0.95]
                for xf in tufts {
                    drawGrassTuft(ctx: &ctx, x: w * xf, baseY: h * 0.84, w: w)
                }
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 11).repeatForever(autoreverses: true),
            value: sway1
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 9).repeatForever(autoreverses: true),
            value: sway2
        )
        .onAppear {
            if !reduceMotion {
                sway1 = true
                sway2 = true
            }
        }
    }

    private func drawBgTree(context: inout GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double) {
        let s = scale
        // Trunk
        var trunk = Path()
        trunk.addRect(CGRect(x: x - 1.5 * s, y: y - 18 * s, width: 3 * s, height: 22 * s))
        context.fill(trunk, with: .color(Color(hex: "#5A3E26").opacity(opacity * 0.8)))

        // Canopy layers
        let layers: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (x - 8*s, y - 20*s, 10*s, 9*s, Color(hex: "#6B9254")),
            (x + 6*s, y - 22*s, 11*s, 9*s, Color(hex: "#6B9254")),
            (x - 1*s, y - 30*s, 12*s, 10*s, Color(hex: "#6B9254")),
            (x - 4*s, y - 27*s, 7*s, 6*s, Color(hex: "#9ABF74")),
        ]
        for (lx, ly, rx, ry, color) in layers {
            let rect = CGRect(x: lx - rx, y: ly - ry, width: rx * 2, height: ry * 2)
            context.fill(Ellipse().path(in: rect), with: .color(color.opacity(opacity)))
        }
    }

    private func drawGrassTuft(ctx: inout GraphicsContext, x: CGFloat, baseY: CGFloat, w: CGFloat) {
        var tuft = Path()
        tuft.move(to: CGPoint(x: x, y: baseY))
        tuft.addQuadCurve(to: CGPoint(x: x, y: baseY - 7), control: CGPoint(x: x - 2, y: baseY - 4))
        tuft.addQuadCurve(to: CGPoint(x: x + 2, y: baseY), control: CGPoint(x: x + 1, y: baseY - 5))
        ctx.fill(tuft, with: .linearGradient(
            Gradient(colors: [Color(hex: "#A8C97A"), Color(hex: "#4F7A4C")]),
            startPoint: CGPoint(x: x, y: baseY - 7),
            endPoint: CGPoint(x: x, y: baseY)
        ))
    }
}

// MARK: - Ghibli Tree (foreground broadleaf)

private struct GhibliTree: View {
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
            let s = scale * size.width * 0.0025

            // Ground shadow
            let shadowRect = CGRect(x: x - 14*s, y: y + 4*s, width: 28*s, height: 5*s)
            context.fill(Ellipse().path(in: shadowRect), with: .color(.black.opacity(0.18)))

            // Trunk
            var trunk = Path()
            trunk.move(to: CGPoint(x: x - 3*s, y: y))
            trunk.addCurve(
                to: CGPoint(x: x - 2*s, y: y - 36*s),
                control1: CGPoint(x: x - 4*s, y: y - 12*s),
                control2: CGPoint(x: x - 3*s, y: y - 24*s)
            )
            trunk.addCurve(
                to: CGPoint(x: x + 3*s, y: y),
                control1: CGPoint(x: x + 1*s, y: y - 36*s),
                control2: CGPoint(x: x + 4*s, y: y - 12*s)
            )
            trunk.closeSubpath()
            context.fill(trunk, with: .linearGradient(
                Gradient(colors: [Color(hex: "#4F3420"), Color(hex: "#6E4A2E"), Color(hex: "#3D2818")]),
                startPoint: CGPoint(x: x - 3*s, y: y - 36*s),
                endPoint: CGPoint(x: x + 3*s, y: y)
            ))

            // Canopy — shadow layer #3F6B47
            let shadowPositions: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (-14, -30, 18, 16), (12, -28, 20, 17), (0, -42, 22, 18),
                (18, -44, 15, 14), (-20, -40, 14, 13)
            ]
            for (ox, oy, rx, ry) in shadowPositions {
                let rect = CGRect(x: x + ox*s - rx*s, y: y + oy*s - ry*s, width: rx*2*s, height: ry*2*s)
                context.fill(Ellipse().path(in: rect), with: .color(Color(hex: "#3F6B47").opacity(0.9)))
            }

            // Mid tone #7CA758
            let midPositions: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (-12, -34, 16, 14), (10, -32, 18, 15), (2, -46, 19, 15), (14, -46, 11, 10)
            ]
            for (ox, oy, rx, ry) in midPositions {
                let rect = CGRect(x: x + ox*s - rx*s, y: y + oy*s - ry*s, width: rx*2*s, height: ry*2*s)
                context.fill(Ellipse().path(in: rect), with: .color(Color(hex: "#7CA758")))
            }

            // Highlight #B8D88A
            let hiPositions: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
                (-6, -42, 11, 9, 0.85), (8, -38, 9, 8, 0.75), (-14, -32, 7, 6, 0.7)
            ]
            for (ox, oy, rx, ry, op) in hiPositions {
                let rect = CGRect(x: x + ox*s - rx*s, y: y + oy*s - ry*s, width: rx*2*s, height: ry*2*s)
                context.fill(Ellipse().path(in: rect), with: .color(Color(hex: "#B8D88A").opacity(op)))
            }

            // Top sparkle
            let sparkRect = CGRect(x: x - 4*s - 4*s, y: y - 48*s - 3*s, width: 8*s, height: 6*s)
            context.fill(Ellipse().path(in: sparkRect), with: .color(Color(hex: "#E8F2C0").opacity(0.7)))
        }
        .rotationEffect(.degrees(swaying ? 1.5 : -1.5), anchor: .bottom)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: swayDuration).repeatForever(autoreverses: true),
            value: swaying
        )
        .onAppear { if !reduceMotion { swaying = true } }
    }
}

// MARK: - Sunny Wildflowers

private struct SunnyWildflowers: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let w = size.width
            let h = size.height
            let flowers: [(CGFloat, CGFloat, CGFloat, Color)] = [
                (0.25, 0.92, 2.5, Color(hex: "#F5C6AA")),
                (0.36, 0.94, 2.2, Color(hex: "#E8B4B8")),
                (0.56, 0.95, 2.4, Color(hex: "#C4B8D4")),
                (0.71, 0.94, 2.2, Color(hex: "#F5C6AA")),
                (0.93, 0.96, 2.0, Color(hex: "#FFDCA0")),
            ]
            for (xf, yf, r, color) in flowers {
                let x = w * xf
                let y = h * yf

                // Leaf
                let leafRect = CGRect(x: x - 5, y: y + 1, width: 10, height: 5)
                context.fill(Ellipse().path(in: leafRect), with: .color(Color(hex: "#3E5F2F").opacity(0.6)))

                // Flower
                let flowerRect = CGRect(x: x - r, y: y - 2 - r, width: r * 2, height: r * 2)
                context.fill(Ellipse().path(in: flowerRect), with: .color(color))

                // Center
                let centerRect = CGRect(x: x - r * 0.4, y: y - 2 - r * 0.4, width: r * 0.8, height: r * 0.8)
                context.fill(Ellipse().path(in: centerRect), with: .color(Color(hex: "#FFF4E0")))

                // Stem
                var stem = Path()
                stem.addRect(CGRect(x: x - 0.4, y: y - 1, width: 0.8, height: 6))
                context.fill(stem, with: .color(Color(hex: "#4F7A4C")))
            }
        }
    }
}

// MARK: - Sunny Petals

private struct SunnyPetals: View {
    let size: CGSize
    let reduceMotion: Bool

    private struct PetalSeed: Identifiable {
        let id: Int
        let yFrac: CGFloat
        let rx: CGFloat
        let ry: CGFloat
        let color: Color
        let duration: Double
        let delay: Double
    }

    private let petals: [PetalSeed] = [
        PetalSeed(id: 0, yFrac: 0.28, rx: 3, ry: 1.8, color: Color(hex: "#F5C6AA"), duration: 14, delay: 0),
        PetalSeed(id: 1, yFrac: 0.40, rx: 2.5, ry: 1.5, color: Color(hex: "#FFDCA0"), duration: 16, delay: -3),
        PetalSeed(id: 2, yFrac: 0.22, rx: 3.2, ry: 2, color: Color(hex: "#E8B4B8"), duration: 18, delay: -7),
        PetalSeed(id: 3, yFrac: 0.50, rx: 2.2, ry: 1.3, color: Color(hex: "#F5C6AA"), duration: 15, delay: -10),
        PetalSeed(id: 4, yFrac: 0.35, rx: 2.8, ry: 1.6, color: Color(hex: "#C4B8D4"), duration: 20, delay: -5),
    ]

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, canvasSize in
                    let w = size.width
                    let h = size.height
                    for petal in petals {
                        let cycle = petal.duration
                        let t = ((time + petal.delay).truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle) / cycle
                        let x = -40 + (w + 80) * t
                        let baseY = h * petal.yFrac
                        let bobY = baseY + sin(time * 2 + Double(petal.id)) * 3
                        let rotation = t * 720
                        let opacity = t < 0.1 ? t / 0.1 : (t > 0.9 ? (1 - t) / 0.1 : 0.9)

                        context.drawLayer { ctx in
                            ctx.translateBy(x: x, y: bobY)
                            ctx.rotate(by: .degrees(rotation))
                            ctx.opacity = opacity
                            let rect = CGRect(x: -petal.rx, y: -petal.ry, width: petal.rx * 2, height: petal.ry * 2)
                            ctx.fill(Ellipse().path(in: rect), with: .color(petal.color))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sunny Wisps

private struct SunnyWisps: View {
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
                        (0.18, 12, 0), (0.33, 16, -6)
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
                            to: CGPoint(x: xOffset + 80, y: y),
                            control: CGPoint(x: xOffset + 40, y: y - 5)
                        )
                        wisp.addQuadCurve(
                            to: CGPoint(x: xOffset + 160, y: y),
                            control: CGPoint(x: xOffset + 120, y: y + 5)
                        )
                        context.stroke(wisp, with: .color(.white.opacity(opacity)),
                                      style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                    }
                }
            }
        }
    }
}
