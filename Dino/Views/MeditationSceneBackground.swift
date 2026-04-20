//
//  MeditationSceneBackground.swift
//  Dino
//
//  Four storybook ambient scenes matching the Dino Design System:
//  sunny, rainy, night, snow. Scene selection based on weather theme.
//

import SwiftUI

// MARK: - Scene Type

enum MeditationScene: Equatable {
    case sunny
    case rainy
    case night
    case snow

    /// Pick scene based on current weather theme from ThemeManager
    static func current() -> MeditationScene {
        switch ThemeManager.shared.currentTheme {
        case .sunny, .defaultDino, .forest, .lavenderCalm:
            return .sunny
        case .night:
            return .night
        case .rainy, .cloudy, .storm:
            return .rainy
        case .snow:
            return .snow
        }
    }
}

// MARK: - Time of Day

private enum TimeOfDay {
    case dawn, noon, dusk

    static func current() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10:  return .dawn
        case 10..<17: return .noon
        default:      return .dusk
        }
    }
}

// MARK: - Scene Background

struct MeditationSceneBackground: View {
    let scene: MeditationScene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch scene {
                case .sunny: SunnyScene(size: geo.size, reduceMotion: reduceMotion)
                case .rainy: RainyScene(size: geo.size, reduceMotion: reduceMotion)
                case .night: NightScene(size: geo.size, reduceMotion: reduceMotion)
                case .snow:  SnowScene(size: geo.size, reduceMotion: reduceMotion)
                }

                // Dino meditation character on top of all scenes
                DinoMeditationCharacter(size: geo.size, reduceMotion: reduceMotion)
            }
        }
        .ignoresSafeArea(.all)
        .animation(.easeInOut(duration: 2), value: scene)
    }
}

// MARK: - Dino Meditation Character

private struct DinoMeditationCharacter: View {
    let size: CGSize
    let reduceMotion: Bool
    @State private var floating = false

    var body: some View {
        Image("DinoMeditation")
            .resizable()
            .scaledToFit()
            .frame(width: size.width * 0.45)
            .position(x: size.width / 2, y: size.height * 0.58)
            .offset(y: floating ? -12 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true),
                value: floating
            )
            .onAppear { floating = true }
    }
}

// MARK: - ═══════════════════════════════════════════
// MARK:   SUNNY SCENE
// MARK: - ═══════════════════════════════════════════

private struct SunnyScene: View {
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

// MARK: - ═══════════════════════════════════════════
// MARK:   NIGHT SCENE
// MARK: - ═══════════════════════════════════════════

private struct NightScene: View {
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
                ctx.rotate(by: .degrees(-12), anchor: CGPoint(x: size.width * 0.5, y: size.height * 0.15))
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

// MARK: - ═══════════════════════════════════════════
// MARK:   RAINY SCENE
// MARK: - ═══════════════════════════════════════════

private struct RainyScene: View {
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

private struct RainDrop {
    var x: CGFloat
    var y: CGFloat
    let len: CGFloat
    let speed: CGFloat
    let alpha: Double
}

private struct RainOverlay: View {
    let size: CGSize
    @State private var drops: [RainDrop] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: false)) { timeline in
            Canvas { context, canvasSize in
                let w = size.width
                let h = size.height

                for i in drops.indices {
                    var d = drops[i]
                    var line = Path()
                    line.move(to: CGPoint(x: d.x, y: d.y))
                    line.addLine(to: CGPoint(x: d.x - d.len * 0.2, y: d.y + d.len))
                    context.stroke(line, with: .color(Color(red: 180/255, green: 200/255, blue: 220/255).opacity(d.alpha)),
                                  style: StrokeStyle(lineWidth: 1.1))
                    d.y += d.speed
                    d.x -= d.speed * 0.2
                    if d.y > h {
                        d.y = -d.len
                        d.x = CGFloat.random(in: 0...(w + 40))
                    }
                    drops[i] = d
                }
            }
        }
        .onAppear {
            var generated: [RainDrop] = []
            for _ in 0..<120 {
                generated.append(RainDrop(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height),
                    len: 12 + CGFloat.random(in: 0...8),
                    speed: 11 + CGFloat.random(in: 0...6),
                    alpha: 0.35 + Double.random(in: 0...0.35)
                ))
            }
            drops = generated
        }
    }
}

// MARK: - ═══════════════════════════════════════════
// MARK:   SNOW SCENE
// MARK: - ═══════════════════════════════════════════

private struct SnowScene: View {
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
