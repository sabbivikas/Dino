//
//  MeditationSceneBackground.swift
//  Dino
//
//  Four storybook ambient scenes for the meditation screen:
//  sunny, rainy, night, snow. Scene selection based on time of day.
//

import SwiftUI

// MARK: - Scene Type

enum MeditationScene: Equatable {
    case sunny
    case rainy
    case night
    case snow

    /// Pick scene based on current hour
    static func current() -> MeditationScene {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<18:  return .sunny
        case 18..<21: return .sunny  // dusk still sunny scene
        default:      return .night
        }
    }
}

// MARK: - Scene Background

struct MeditationSceneBackground: View {
    let scene: MeditationScene

    var body: some View {
        ZStack {
            switch scene {
            case .sunny:  SunnyScene()
            case .rainy:  RainyScene()
            case .night:  NightScene()
            case .snow:   SnowScene()
            }
        }
    }
}

// MARK: - Color Palettes

private enum ScenePalette {
    // Sunny
    static let sunnyTop = Color(hex: "#87CEEB")
    static let sunnyBot = Color(hex: "#C3E8F5")
    static let sunColor = Color(hex: "#FFC94D")
    static let sunGlow  = Color(hex: "#FFD966")
    static let hillFar  = Color(hex: "#B8D4A2")
    static let hillMid  = Color(hex: "#8FB96A")
    static let hillNear = Color(hex: "#6E9E58")
    static let trunkColor = Color(hex: "#6E4A2E")

    // Rainy
    static let rainyTop = Color(hex: "#8C96A6")
    static let rainyBot = Color(hex: "#AFB4BE")
    static let cloudDark = Color(hex: "#6B7280")
    static let cloudMid  = Color(hex: "#8891A1")
    static let hillRainFar = Color(hex: "#7A8A8E")
    static let hillRainNear = Color(hex: "#5A6E70")
    static let puddleColor = Color(hex: "#6B8398")

    // Night
    static let nightTop = Color(hex: "#0F1228")
    static let nightBot = Color(hex: "#1E233C")
    static let moonColor = Color(hex: "#FFF8DC")
    static let moonCrater = Color(hex: "#D8CFA8")
    static let mtnBack = Color(hex: "#4A4D7A")
    static let mtnMid  = Color(hex: "#353866")
    static let mtnFront = Color(hex: "#1F223E")
    static let snowCap = Color(hex: "#E8E0FF")

    // Snow
    static let snowTop = Color(hex: "#C8D7EB")
    static let snowBot = Color(hex: "#E6EBF5")
    static let snowHillFar = Color(hex: "#F8FAFC")
    static let snowHillNear = Color(hex: "#FFFFFF")
    static let pineGreen = Color(hex: "#4E6B56")
    static let pineDark  = Color(hex: "#1E3326")
}

// ================================================================
// MARK: - SUNNY SCENE
// ================================================================

private struct SunnyScene: View {
    @State private var cloudDrift1: CGFloat = -0.15
    @State private var cloudDrift2: CGFloat = -0.2
    @State private var cloudDrift3: CGFloat = -0.1
    @State private var sunPulse = false
    @State private var birdPath1: CGFloat = -0.1
    @State private var birdPath2: CGFloat = 1.1
    @State private var petalDrift: CGFloat = -0.1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Sky gradient
                LinearGradient(
                    colors: [ScenePalette.sunnyTop, ScenePalette.sunnyBot],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Sun with rays
                SunnySun(size: w * 0.18)
                    .scaleEffect(sunPulse ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: sunPulse)
                    .position(x: w * 0.5, y: h * 0.18)

                // Clouds
                SunnyCloud(cloudWidth: w * 0.22)
                    .position(x: w * cloudDrift1, y: h * 0.14)
                SunnyCloud(cloudWidth: w * 0.16)
                    .opacity(0.9)
                    .position(x: w * cloudDrift2, y: h * 0.08)
                SunnyCloud(cloudWidth: w * 0.12)
                    .opacity(0.85)
                    .position(x: w * cloudDrift3, y: h * 0.24)

                // Birds
                SunnyBird(size: 16)
                    .position(x: w * birdPath1, y: h * 0.12)
                SunnyBird(size: 12)
                    .position(x: w * birdPath2, y: h * 0.18)

                // Far hill
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    path.addQuadCurve(
                        to: CGPoint(x: size.width * 0.4, y: size.height * 0.65),
                        control: CGPoint(x: size.width * 0.18, y: size.height * 0.55)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: size.width * 0.76, y: size.height * 0.7),
                        control: CGPoint(x: size.width * 0.6, y: size.height * 0.78)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: size.width + 20, y: size.height * 0.6),
                        control: CGPoint(x: size.width * 0.95, y: size.height * 0.55)
                    )
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.hillFar))

                    // Haze overlay on far hill
                    context.fill(path, with: .color(.white.opacity(0.18)))
                }
                .frame(width: w, height: h * 0.45)
                .position(x: w / 2, y: h * 0.78)

                // Mid hill with trees
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    path.addQuadCurve(
                        to: CGPoint(x: size.width * 0.5, y: size.height * 0.45),
                        control: CGPoint(x: size.width * 0.22, y: size.height * 0.3)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: size.width + 20, y: size.height * 0.4),
                        control: CGPoint(x: size.width * 0.75, y: size.height * 0.6)
                    )
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.hillMid))
                }
                .frame(width: w, height: h * 0.4)
                .position(x: w / 2, y: h * 0.82)

                // Near hill
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    path.addQuadCurve(
                        to: CGPoint(x: size.width * 0.6, y: size.height * 0.35),
                        control: CGPoint(x: size.width * 0.3, y: size.height * 0.15)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: size.width + 20, y: size.height * 0.3),
                        control: CGPoint(x: size.width * 0.8, y: size.height * 0.5)
                    )
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.hillNear))
                }
                .frame(width: w, height: h * 0.35)
                .position(x: w / 2, y: h * 0.86)

                // Trees on near hill
                SunnyTree(height: 50)
                    .position(x: w * 0.18, y: h * 0.82)
                SunnyTree(height: 65)
                    .position(x: w * 0.82, y: h * 0.80)
                SunnyTree(height: 35)
                    .position(x: w * 0.50, y: h * 0.85)

                // Wildflowers
                ForEach(0..<5, id: \.self) { i in
                    let positions: [(CGFloat, CGFloat)] = [
                        (0.25, 0.90), (0.38, 0.92), (0.55, 0.93), (0.70, 0.91), (0.88, 0.94)
                    ]
                    let colors: [Color] = [ScenePalette.sunColor, Color(hex: "#E8B4B8"), Color(hex: "#C4B8D4"), Color(hex: "#F5C6AA"), Color(hex: "#FFDCA0")]
                    Circle()
                        .fill(colors[i])
                        .frame(width: 5, height: 5)
                        .position(x: w * positions[i].0, y: h * positions[i].1)
                }

                // Drifting petals
                SunnyPetal(color: Color(hex: "#F5C6AA"))
                    .position(x: w * petalDrift, y: h * 0.35)
                SunnyPetal(color: Color(hex: "#E8B4B8"))
                    .position(x: w * (petalDrift + 0.15), y: h * 0.5)
                SunnyPetal(color: Color(hex: "#C4B8D4"))
                    .position(x: w * (petalDrift - 0.1), y: h * 0.28)
            }
            .onAppear {
                sunPulse = true
                withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                    cloudDrift1 = 1.2
                }
                withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                    cloudDrift2 = 1.2
                }
                withAnimation(.linear(duration: 75).repeatForever(autoreverses: false)) {
                    cloudDrift3 = 1.2
                }
                withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
                    birdPath1 = 1.15
                }
                withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                    birdPath2 = -0.15
                }
                withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                    petalDrift = 1.2
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sunny Sub-views

private struct SunnySun: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ScenePalette.sunGlow.opacity(0.5), ScenePalette.sunGlow.opacity(0)],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.9
                    )
                )
                .frame(width: size * 1.8, height: size * 1.8)

            // Rays
            Canvas { context, canvasSize in
                let cx = canvasSize.width / 2
                let cy = canvasSize.height / 2
                let innerR = size * 0.38
                let outerR = size * 0.55
                for i in 0..<8 {
                    let angle = Double(i) * .pi / 4
                    var ray = Path()
                    ray.move(to: CGPoint(x: cx + innerR * cos(angle), y: cy + innerR * sin(angle)))
                    ray.addLine(to: CGPoint(x: cx + outerR * cos(angle), y: cy + outerR * sin(angle)))
                    context.stroke(ray, with: .color(Color(hex: "#D4920A")), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
            .frame(width: size, height: size)

            // Body
            Circle()
                .fill(ScenePalette.sunColor)
                .frame(width: size * 0.6, height: size * 0.6)
        }
    }
}

private struct SunnyCloud: View {
    let cloudWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            // Multi-ellipse puffy cloud
            let ovals: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
                (0.15, 0.55, 0.30, 0.38, 0.95),
                (0.45, 0.40, 0.38, 0.45, 0.95),
                (0.75, 0.55, 0.28, 0.38, 0.90),
                (0.30, 0.70, 0.22, 0.22, 0.60),
                (0.60, 0.72, 0.28, 0.22, 0.50),
            ]
            for (cx, cy, rw, rh, op) in ovals {
                let rect = CGRect(
                    x: w * cx - w * rw / 2,
                    y: h * cy - h * rh / 2,
                    width: w * rw,
                    height: h * rh
                )
                context.fill(Ellipse().path(in: rect), with: .color(.white.opacity(op)))
            }
        }
        .frame(width: cloudWidth, height: cloudWidth * 0.45)
    }
}

private struct SunnyBird: View {
    let size: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let flapAmt = 0.5 + 0.5 * cos(time * 10)
            Canvas { context, canvasSize in
                let s = canvasSize.width
                var path = Path()
                path.move(to: CGPoint(x: 0, y: s * 0.5))
                path.addQuadCurve(
                    to: CGPoint(x: s * 0.35, y: s * 0.5),
                    control: CGPoint(x: s * 0.18, y: s * (0.5 - 0.3 * flapAmt))
                )
                path.addQuadCurve(
                    to: CGPoint(x: s * 0.7, y: s * 0.5),
                    control: CGPoint(x: s * 0.52, y: s * (0.5 - 0.3 * flapAmt))
                )
                context.stroke(path, with: .color(Color(hex: "#3D2A1F")), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

private struct SunnyTree: View {
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2

            // Trunk
            var trunk = Path()
            trunk.addRect(CGRect(x: cx - 3, y: h * 0.55, width: 6, height: h * 0.45))
            context.fill(trunk, with: .color(ScenePalette.trunkColor))

            // Canopy layers (dark → light)
            let canopyLayers: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
                (cx - 2, h * 0.25, w * 0.65, h * 0.45, Color(hex: "#3F6B47")),
                (cx + 2, h * 0.22, w * 0.7,  h * 0.48, Color(hex: "#3F6B47")),
                (cx,     h * 0.15, w * 0.75, h * 0.5,  Color(hex: "#7CA758")),
                (cx - 4, h * 0.2,  w * 0.5,  h * 0.35, Color(hex: "#B8D88A")),
            ]
            for (lx, ly, lw, lh, color) in canopyLayers {
                let rect = CGRect(x: lx - lw / 2, y: ly - lh / 2, width: lw, height: lh)
                context.fill(Ellipse().path(in: rect), with: .color(color))
            }
        }
        .frame(width: height * 0.8, height: height)
    }
}

private struct SunnyPetal: View {
    let color: Color
    @State private var rotate: Double = 0

    var body: some View {
        Ellipse()
            .fill(color.opacity(0.85))
            .frame(width: 6, height: 4)
            .rotationEffect(.degrees(rotate))
            .animation(.linear(duration: 14).repeatForever(autoreverses: false), value: rotate)
            .onAppear { rotate = 720 }
    }
}

// ================================================================
// MARK: - RAINY SCENE
// ================================================================

private struct RainyScene: View {
    @State private var cloudDrift1: CGFloat = -0.3
    @State private var cloudDrift2: CGFloat = -0.2

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Grey sky
                LinearGradient(
                    colors: [ScenePalette.rainyTop, ScenePalette.rainyBot],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Dark clouds
                RainyCloud(cloudWidth: w * 0.35)
                    .position(x: w * cloudDrift1, y: h * 0.12)
                RainyCloud(cloudWidth: w * 0.25)
                    .opacity(0.85)
                    .position(x: w * cloudDrift2, y: h * 0.08)

                // Far hill with mist
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    path.addQuadCurve(
                        to: CGPoint(x: size.width * 0.45, y: size.height * 0.5),
                        control: CGPoint(x: size.width * 0.2, y: size.height * 0.3)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: size.width + 20, y: size.height * 0.4),
                        control: CGPoint(x: size.width * 0.65, y: size.height * 0.65)
                    )
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.hillRainFar.opacity(0.85)))

                    // Misty haze
                    var haze = path
                    context.fill(haze, with: .color(Color(hex: "#BFC7CA").opacity(0.35)))
                }
                .frame(width: w, height: h * 0.45)
                .position(x: w / 2, y: h * 0.78)

                // Near hill
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    path.addQuadCurve(
                        to: CGPoint(x: size.width * 0.6, y: size.height * 0.3),
                        control: CGPoint(x: size.width * 0.3, y: size.height * 0.1)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: size.width + 20, y: size.height * 0.25),
                        control: CGPoint(x: size.width * 0.8, y: size.height * 0.45)
                    )
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.hillRainNear))
                }
                .frame(width: w, height: h * 0.35)
                .position(x: w / 2, y: h * 0.86)

                // Puddles with ripples
                RainyPuddle(width: 44, rippleDelay: 0)
                    .position(x: w * 0.2, y: h * 0.88)
                RainyPuddle(width: 60, rippleDelay: 0.8)
                    .position(x: w * 0.7, y: h * 0.91)
                RainyPuddle(width: 30, rippleDelay: 1.4)
                    .position(x: w * 0.5, y: h * 0.93)

                // Lone wet tree
                RainyTree(height: 55)
                    .position(x: w * 0.82, y: h * 0.84)

                // Rain canvas overlay
                RainOverlay()
                    .ignoresSafeArea()

                // Wind wisps
                RainyWisp()
                    .position(x: w * 0.5, y: h * 0.3)
            }
            .onAppear {
                withAnimation(.linear(duration: 75).repeatForever(autoreverses: false)) {
                    cloudDrift1 = 1.3
                }
                withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                    cloudDrift2 = 1.3
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct RainyCloud: View {
    let cloudWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var cloud = Path()
            cloud.move(to: CGPoint(x: w * 0.15, y: h * 0.4))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.05, y: h * 0.65), control: CGPoint(x: w * 0.02, y: h * 0.4))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.05, y: h * 0.9), control: CGPoint(x: -w * 0.03, y: h * 0.75))
            cloud.addLine(to: CGPoint(x: w * 0.95, y: h * 0.9))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.55), control: CGPoint(x: w * 1.03, y: h * 0.75))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.7, y: h * 0.25), control: CGPoint(x: w * 0.95, y: h * 0.25))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.15), control: CGPoint(x: w * 0.55, y: h * 0.1))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.4), control: CGPoint(x: w * 0.25, y: h * 0.12))
            cloud.closeSubpath()
            context.fill(cloud, with: .color(ScenePalette.cloudDark))
        }
        .frame(width: cloudWidth, height: cloudWidth * 0.5)
    }
}

private struct RainyPuddle: View {
    let width: CGFloat
    let rippleDelay: Double
    @State private var rippleScale: CGFloat = 0.1

    var body: some View {
        ZStack {
            Ellipse()
                .fill(ScenePalette.puddleColor.opacity(0.7))
                .frame(width: width, height: width * 0.2)

            Ellipse()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: width * 0.5 * rippleScale, height: width * 0.1 * rippleScale)
                .opacity(1.0 - Double(rippleScale) / 1.8)
        }
        .animation(
            .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(rippleDelay),
            value: rippleScale
        )
        .onAppear { rippleScale = 1.8 }
    }
}

private struct RainyTree: View {
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let h = size.height

            // Dark wet trunk
            var trunk = Path()
            trunk.addRect(CGRect(x: cx - 3, y: h * 0.55, width: 6, height: h * 0.45))
            context.fill(trunk, with: .color(Color(hex: "#2E1F14")))

            // Wet canopy (dark greens)
            let layers: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
                (cx - 3, h * 0.25, size.width * 0.60, h * 0.42, Color(hex: "#223C2C")),
                (cx + 3, h * 0.22, size.width * 0.68, h * 0.45, Color(hex: "#223C2C")),
                (cx,     h * 0.18, size.width * 0.72, h * 0.45, Color(hex: "#3D5C48")),
                (cx - 2, h * 0.22, size.width * 0.45, h * 0.35, Color(hex: "#5F8268").opacity(0.7)),
            ]
            for (lx, ly, lw, lh, color) in layers {
                let rect = CGRect(x: lx - lw / 2, y: ly - lh / 2, width: lw, height: lh)
                context.fill(Ellipse().path(in: rect), with: .color(color))
            }
        }
        .frame(width: height * 0.8, height: height)
    }
}

private struct RainOverlay: View {
    @State private var seeds: [RainDropSeed] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let angleRad = 15.0 * .pi / 180.0
                    let streakLen: CGFloat = 14
                    let dx = sin(angleRad) * streakLen
                    let dy = cos(angleRad) * streakLen
                    let totalTravel = size.height + streakLen

                    for seed in seeds {
                        let x = seed.xNorm * size.width
                        let rawY = seed.startOff * totalTravel + CGFloat(time) * seed.speed
                        let y = rawY.truncatingRemainder(dividingBy: totalTravel) - streakLen

                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + dx, y: y + dy))
                        context.stroke(path, with: .color(.white.opacity(seed.opacity)), lineWidth: 1)
                    }
                }
            }
            .onAppear {
                seeds = (0..<50).map { _ in
                    RainDropSeed(
                        xNorm: CGFloat.random(in: 0...1),
                        startOff: CGFloat.random(in: 0...1),
                        speed: CGFloat.random(in: 28...38),
                        opacity: Double.random(in: 0.12...0.20)
                    )
                }
            }
        }
    }
}

private struct RainDropSeed {
    let xNorm: CGFloat
    let startOff: CGFloat
    let speed: CGFloat
    let opacity: Double
}

private struct RainyWisp: View {
    @State private var drift: CGFloat = -80

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height * 0.4))
            path.addQuadCurve(
                to: CGPoint(x: size.width, y: size.height * 0.5),
                control: CGPoint(x: size.width * 0.5, y: size.height * 0.3)
            )
            context.stroke(path, with: .color(Color(hex: "#D8DEE2").opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .frame(width: 240, height: 40)
        .offset(x: drift)
        .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = 80 }
    }
}

// ================================================================
// MARK: - NIGHT SCENE
// ================================================================

private struct NightScene: View {
    @State private var moonFloat = false
    @State private var shootingStar = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Dark sky gradient
                LinearGradient(
                    colors: [ScenePalette.nightTop, ScenePalette.nightBot],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Milky way band
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#B4A0DC").opacity(0),
                                Color(hex: "#C8B4E6").opacity(0.12),
                                Color(hex: "#DCC8F0").opacity(0.2),
                                Color(hex: "#C8B4E6").opacity(0.12),
                                Color(hex: "#B4A0DC").opacity(0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: w * 1.4, height: 80)
                    .rotationEffect(.degrees(-12))
                    .position(x: w * 0.5, y: h * 0.18)

                // Stars
                NightStarField()
                    .frame(width: w, height: h * 0.55)
                    .position(x: w / 2, y: h * 0.25)

                // Moon
                NightMoon(size: 52)
                    .offset(y: moonFloat ? -6 : 6)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: moonFloat)
                    .position(x: w * 0.75, y: h * 0.2)

                // Far mountains
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    // Jagged peaks
                    let peaks: [(CGFloat, CGFloat)] = [
                        (0.08, 0.35), (0.14, 0.55), (0.22, 0.20),
                        (0.33, 0.50), (0.42, 0.15), (0.53, 0.45),
                        (0.63, 0.25), (0.73, 0.50), (0.83, 0.12),
                        (0.93, 0.45), (1.05, 0.55)
                    ]
                    for (px, py) in peaks {
                        path.addLine(to: CGPoint(x: size.width * px, y: size.height * py))
                    }
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.mtnBack))

                    // Snow caps on peaks
                    let snowPeaks: [(CGFloat, CGFloat)] = [(0.22, 0.20), (0.42, 0.15), (0.83, 0.12)]
                    for (px, py) in snowPeaks {
                        let peakX = size.width * px
                        let peakY = size.height * py
                        var cap = Path()
                        cap.move(to: CGPoint(x: peakX, y: peakY))
                        cap.addLine(to: CGPoint(x: peakX - 12, y: peakY + 18))
                        cap.addLine(to: CGPoint(x: peakX + 12, y: peakY + 18))
                        cap.closeSubpath()
                        context.fill(cap, with: .color(ScenePalette.snowCap.opacity(0.8)))
                    }
                }
                .frame(width: w, height: h * 0.5)
                .position(x: w / 2, y: h * 0.72)

                // Mid mountains
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    let peaks: [(CGFloat, CGFloat)] = [
                        (0.05, 0.4), (0.13, 0.55), (0.25, 0.25),
                        (0.38, 0.55), (0.50, 0.20), (0.65, 0.48),
                        (0.78, 0.28), (0.90, 0.52), (1.05, 0.50)
                    ]
                    for (px, py) in peaks {
                        path.addLine(to: CGPoint(x: size.width * px, y: size.height * py))
                    }
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.mtnMid))
                }
                .frame(width: w, height: h * 0.45)
                .position(x: w / 2, y: h * 0.78)

                // Front mountains
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    let peaks: [(CGFloat, CGFloat)] = [
                        (0.10, 0.35), (0.22, 0.55), (0.40, 0.25),
                        (0.60, 0.55), (0.78, 0.30), (0.95, 0.55), (1.05, 0.50)
                    ]
                    for (px, py) in peaks {
                        path.addLine(to: CGPoint(x: size.width * px, y: size.height * py))
                    }
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.mtnFront))
                }
                .frame(width: w, height: h * 0.4)
                .position(x: w / 2, y: h * 0.84)

                // Pine silhouettes
                NightPine(height: 42)
                    .position(x: w * 0.18, y: h * 0.87)
                NightPine(height: 48)
                    .position(x: w * 0.85, y: h * 0.86)

                // Moon reflection on lake
                VStack(spacing: 3) {
                    Ellipse()
                        .fill(ScenePalette.moonColor.opacity(0.2))
                        .frame(width: 12, height: 3)
                    Ellipse()
                        .fill(ScenePalette.moonColor.opacity(0.12))
                        .frame(width: 20, height: 2)
                    Ellipse()
                        .fill(ScenePalette.moonColor.opacity(0.08))
                        .frame(width: 28, height: 2)
                }
                .position(x: w * 0.75, y: h * 0.92)

                // Firefly overlay
                NightFireflies()
                    .frame(width: w, height: h)
            }
            .onAppear { moonFloat = true }
        }
        .ignoresSafeArea()
    }
}

private struct NightMoon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ScenePalette.moonColor.opacity(0.5), ScenePalette.moonColor.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 1.1
                    )
                )
                .frame(width: size * 2.2, height: size * 2.2)

            // Moon body
            Circle()
                .fill(ScenePalette.moonColor)
                .frame(width: size, height: size)

            // Craters
            Ellipse()
                .fill(ScenePalette.moonCrater.opacity(0.7))
                .frame(width: size * 0.15, height: size * 0.12)
                .offset(x: -size * 0.15, y: -size * 0.12)
            Ellipse()
                .fill(ScenePalette.moonCrater.opacity(0.7))
                .frame(width: size * 0.2, height: size * 0.15)
                .offset(x: size * 0.17, y: size * 0.08)
            Ellipse()
                .fill(ScenePalette.moonCrater.opacity(0.6))
                .frame(width: size * 0.12, height: size * 0.1)
                .offset(x: -size * 0.08, y: size * 0.2)
        }
    }
}

private struct StarSeed {
    let xNorm: CGFloat
    let yNorm: CGFloat
    let radius: CGFloat
    let baseOpacity: Double
    let twinkleSpeed: Double   // radians per second
    let twinklePhase: Double
}

private struct NightStarField: View {
    @State private var smallStars: [StarSeed] = []
    @State private var bigStars: [StarSeed] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                // Small twinkling stars
                for star in smallStars {
                    let x = star.xNorm * size.width
                    let y = star.yNorm * size.height
                    let twinkle = 0.5 + 0.5 * sin(time * star.twinkleSpeed + star.twinklePhase)
                    let opacity = star.baseOpacity * (0.3 + 0.7 * twinkle)
                    let rect = CGRect(x: x - star.radius, y: y - star.radius, width: star.radius * 2, height: star.radius * 2)
                    context.fill(Circle().path(in: rect), with: .color(ScenePalette.moonColor.opacity(opacity)))
                }

                // Big hero stars with cross flares
                for star in bigStars {
                    let x = star.xNorm * size.width
                    let y = star.yNorm * size.height
                    let twinkle = 0.5 + 0.5 * sin(time * star.twinkleSpeed + star.twinklePhase)
                    let opacity = 0.5 + 0.5 * twinkle

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
                    context.fill(flare, with: .color(ScenePalette.moonColor.opacity(opacity * 0.9)))

                    // Center glow
                    let haloRect = CGRect(x: x - 2.2, y: y - 2.2, width: 4.4, height: 4.4)
                    context.fill(Circle().path(in: haloRect), with: .color(ScenePalette.moonColor.opacity(opacity * 0.4)))
                }
            }
        }
        .onAppear {
            smallStars = (0..<100).map { _ in
                StarSeed(
                    xNorm: CGFloat.random(in: 0...1),
                    yNorm: CGFloat.random(in: 0...1),
                    radius: CGFloat.random(in: 0.4...1.2),
                    baseOpacity: Double.random(in: 0.4...0.9),
                    twinkleSpeed: Double.random(in: 0.8...2.5),
                    twinklePhase: Double.random(in: 0...(2 * .pi))
                )
            }
            let bigPositions: [(CGFloat, CGFloat)] = [
                (0.12, 0.2), (0.24, 0.1), (0.38, 0.3), (0.52, 0.12),
                (0.44, 0.5), (0.24, 0.6), (0.62, 0.35), (0.56, 0.6),
                (0.15, 0.45), (0.92, 0.2), (0.96, 0.5), (0.33, 0.15)
            ]
            bigStars = bigPositions.map { (px, py) in
                StarSeed(
                    xNorm: px,
                    yNorm: py,
                    radius: 2.2,
                    baseOpacity: 1.0,
                    twinkleSpeed: Double.random(in: 0.5...1.5),
                    twinklePhase: Double.random(in: 0...(2 * .pi))
                )
            }
        }
    }
}

private struct NightPine: View {
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let h = size.height

            // Trunk
            var trunk = Path()
            trunk.addRect(CGRect(x: cx - 1.5, y: h * 0.7, width: 3, height: h * 0.3))
            context.fill(trunk, with: .color(Color(hex: "#06081A")))

            // Pine silhouette
            var pine = Path()
            pine.move(to: CGPoint(x: cx, y: 0))
            pine.addQuadCurve(
                to: CGPoint(x: cx - h * 0.22, y: h * 0.7),
                control: CGPoint(x: cx - h * 0.18, y: h * 0.35)
            )
            pine.addLine(to: CGPoint(x: cx + h * 0.22, y: h * 0.7))
            pine.addQuadCurve(
                to: CGPoint(x: cx, y: 0),
                control: CGPoint(x: cx + h * 0.18, y: h * 0.35)
            )
            pine.closeSubpath()
            context.fill(pine, with: .color(Color(hex: "#05061A")))

            // Moonlit edge highlight
            var edge = Path()
            edge.move(to: CGPoint(x: cx, y: 0))
            edge.addQuadCurve(
                to: CGPoint(x: cx - h * 0.15, y: h * 0.7),
                control: CGPoint(x: cx - h * 0.1, y: h * 0.35)
            )
            context.stroke(edge, with: .color(Color(hex: "#1B1E3A").opacity(0.8)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        .frame(width: height * 0.5, height: height)
    }
}

private struct NightFireflies: View {
    @State private var particles: [(CGFloat, CGFloat, CGFloat, Double, Double)] = []
    @State private var glowing = false

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(particles.enumerated()), id: \.offset) { _, p in
                Circle()
                    .fill(Color(hex: "#FFD966"))
                    .frame(width: p.2, height: p.2)
                    .blur(radius: p.2 * 0.5)
                    .opacity(glowing ? p.3 : p.3 * 0.2)
                    .animation(
                        .easeInOut(duration: p.4).repeatForever(autoreverses: true),
                        value: glowing
                    )
                    .position(x: p.0, y: p.1)
            }
        }
        .onAppear {
            particles = (0..<12).map { _ in
                (
                    CGFloat.random(in: 20...350),
                    CGFloat.random(in: 200...700),
                    CGFloat.random(in: 2...4),
                    Double.random(in: 0.4...0.8),
                    Double.random(in: 3...7)
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                glowing = true
            }
        }
    }
}

// ================================================================
// MARK: - SNOW SCENE
// ================================================================

private struct SnowScene: View {
    @State private var mistDrift: CGFloat = -20

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Pale winter sky
                LinearGradient(
                    colors: [ScenePalette.snowTop, ScenePalette.snowBot],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Pale sun glow
                ZStack {
                    Circle()
                        .fill(Color(hex: "#FFF5E4").opacity(0.35))
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Color(hex: "#FFF5E4").opacity(0.55))
                        .frame(width: 60, height: 60)
                    Circle()
                        .fill(Color(hex: "#FFFAF0").opacity(0.9))
                        .frame(width: 44, height: 44)
                }
                .position(x: w * 0.2, y: h * 0.15)

                // Back snow hill
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    path.addQuadCurve(
                        to: CGPoint(x: size.width * 0.45, y: size.height * 0.4),
                        control: CGPoint(x: size.width * 0.2, y: size.height * 0.2)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: size.width + 20, y: size.height * 0.3),
                        control: CGPoint(x: size.width * 0.65, y: size.height * 0.55)
                    )
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.snowHillFar))

                    // Ridge haze
                    context.fill(path, with: .color(.white.opacity(0.45)))
                }
                .frame(width: w, height: h * 0.45)
                .position(x: w / 2, y: h * 0.72)

                // Snow pines row (middle)
                SnowPine(height: 38)
                    .position(x: w * 0.18, y: h * 0.68)
                SnowPine(height: 45)
                    .position(x: w * 0.33, y: h * 0.66)
                SnowPine(height: 32)
                    .position(x: w * 0.50, y: h * 0.70)
                SnowPine(height: 40)
                    .position(x: w * 0.62, y: h * 0.69)
                SnowPine(height: 35)
                    .position(x: w * 0.78, y: h * 0.67)
                SnowPine(height: 30)
                    .position(x: w * 0.92, y: h * 0.70)

                // Front snow hill
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: -20, y: size.height))
                    path.addQuadCurve(
                        to: CGPoint(x: size.width * 0.6, y: size.height * 0.25),
                        control: CGPoint(x: size.width * 0.3, y: size.height * 0.05)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: size.width + 20, y: size.height * 0.2),
                        control: CGPoint(x: size.width * 0.8, y: size.height * 0.4)
                    )
                    path.addLine(to: CGPoint(x: size.width + 20, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(ScenePalette.snowHillNear))

                    // Shadow under ridge
                    var shadow = Path()
                    shadow.move(to: CGPoint(x: -20, y: size.height * 0.25))
                    shadow.addQuadCurve(
                        to: CGPoint(x: size.width + 20, y: size.height * 0.2),
                        control: CGPoint(x: size.width * 0.5, y: size.height * 0.35)
                    )
                    shadow.addLine(to: CGPoint(x: size.width + 20, y: size.height * 0.35))
                    shadow.addLine(to: CGPoint(x: -20, y: size.height * 0.4))
                    shadow.closeSubpath()
                    context.fill(shadow, with: .color(Color(hex: "#C8D1DC").opacity(0.35)))
                }
                .frame(width: w, height: h * 0.35)
                .position(x: w / 2, y: h * 0.86)

                // Foreground pines
                SnowPine(height: 62)
                    .position(x: w * 0.12, y: h * 0.86)
                SnowPine(height: 55)
                    .position(x: w * 0.88, y: h * 0.85)
                SnowPine(height: 25)
                    .position(x: w * 0.38, y: h * 0.89)

                // Snow mounds
                Ellipse()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 60, height: 12)
                    .position(x: w * 0.22, y: h * 0.93)
                Ellipse()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 84, height: 14)
                    .position(x: w * 0.55, y: h * 0.95)
                Ellipse()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 50, height: 10)
                    .position(x: w * 0.75, y: h * 0.94)

                // Mist drift layers
                Ellipse()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 240, height: 36)
                    .offset(x: mistDrift)
                    .position(x: w * 0.4, y: h * 0.5)

                Ellipse()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 200, height: 28)
                    .offset(x: -mistDrift)
                    .position(x: w * 0.7, y: h * 0.58)

                // Snowfall overlay
                SnowOverlay()
                    .ignoresSafeArea()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                    mistDrift = 20
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct SnowPine: View {
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let h = size.height

            // Trunk
            var trunk = Path()
            trunk.addRect(CGRect(x: cx - 2, y: h * 0.75, width: 4, height: h * 0.25))
            context.fill(trunk, with: .color(Color(hex: "#3D2818")))

            // Pine body
            var pine = Path()
            pine.move(to: CGPoint(x: cx, y: 0))
            pine.addQuadCurve(
                to: CGPoint(x: cx - h * 0.28, y: h * 0.75),
                control: CGPoint(x: cx - h * 0.22, y: h * 0.38)
            )
            pine.addLine(to: CGPoint(x: cx + h * 0.28, y: h * 0.75))
            pine.addQuadCurve(
                to: CGPoint(x: cx, y: 0),
                control: CGPoint(x: cx + h * 0.22, y: h * 0.38)
            )
            pine.closeSubpath()

            // Fill with gradient-like layers
            context.fill(pine, with: .color(ScenePalette.pineDark))

            // Lighter left side
            var left = Path()
            left.move(to: CGPoint(x: cx, y: 0))
            left.addQuadCurve(
                to: CGPoint(x: cx - h * 0.22, y: h * 0.75),
                control: CGPoint(x: cx - h * 0.18, y: h * 0.38)
            )
            left.addLine(to: CGPoint(x: cx, y: h * 0.75))
            left.closeSubpath()
            context.fill(left, with: .color(ScenePalette.pineGreen))

            // Snow on top
            var snowTop = Path()
            snowTop.move(to: CGPoint(x: cx, y: 0))
            snowTop.addLine(to: CGPoint(x: cx - 5, y: 10))
            snowTop.addLine(to: CGPoint(x: cx + 5, y: 10))
            snowTop.closeSubpath()
            context.fill(snowTop, with: .color(.white))

            // Snow tiers
            let tiers: [(CGFloat, CGFloat)] = [(0.35, 10), (0.55, 14)]
            for (yFrac, snowW) in tiers {
                var tier = Path()
                let ty = h * yFrac
                tier.move(to: CGPoint(x: cx - snowW, y: ty))
                tier.addQuadCurve(
                    to: CGPoint(x: cx + snowW, y: ty),
                    control: CGPoint(x: cx, y: ty + 4)
                )
                tier.addQuadCurve(
                    to: CGPoint(x: cx - snowW, y: ty),
                    control: CGPoint(x: cx, y: ty - 2)
                )
                tier.closeSubpath()
                context.fill(tier, with: .color(.white.opacity(0.85)))
            }
        }
        .frame(width: height * 0.55, height: height)
    }
}

private struct SnowOverlay: View {
    @State private var seeds: [SnowFlakeSeed] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for seed in seeds {
                        let totalTravel = size.height + seed.size * 2
                        let rawY = seed.startOff * totalTravel + CGFloat(time) * seed.speed
                        let y = rawY.truncatingRemainder(dividingBy: totalTravel) - seed.size

                        let baseX = seed.xNorm * size.width
                        let swayX = baseX + sin(CGFloat(time) * seed.swayFreq + seed.swayPhase) * seed.swayAmp

                        let r = seed.size / 2
                        let rect = CGRect(x: swayX - r, y: y - r, width: seed.size, height: seed.size)
                        context.fill(Circle().path(in: rect), with: .color(.white.opacity(seed.opacity)))
                    }
                }
            }
            .onAppear {
                seeds = (0..<35).map { _ in
                    SnowFlakeSeed(
                        xNorm: CGFloat.random(in: 0...1),
                        startOff: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 3...7),
                        speed: CGFloat.random(in: 10...22),
                        swayAmp: CGFloat.random(in: 8...20),
                        swayFreq: CGFloat.random(in: 0.3...0.8),
                        swayPhase: CGFloat.random(in: 0...(2 * .pi)),
                        opacity: Double.random(in: 0.18...0.28)
                    )
                }
            }
        }
    }
}

private struct SnowFlakeSeed {
    let xNorm: CGFloat
    let startOff: CGFloat
    let size: CGFloat
    let speed: CGFloat
    let swayAmp: CGFloat
    let swayFreq: CGFloat
    let swayPhase: CGFloat
    let opacity: Double
}
