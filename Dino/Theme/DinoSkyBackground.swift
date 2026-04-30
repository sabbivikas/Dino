//
//  DinoSkyBackground.swift
//  Dino
//
//  Time-aware illustrated sky background that shifts through
//  dawn → morning → noon → dusk → evening → night.
//

import SwiftUI

// MARK: - Time of Day

enum SkyTimeOfDay: Equatable {
    case dawn, morning, noon, dusk, evening, night

    /// Determine from local device hour
    static func current() -> SkyTimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<7:   return .dawn
        case 7..<12:  return .morning
        case 12..<15: return .noon
        case 15..<19: return .dusk
        case 19..<21: return .evening
        default:      return .night
        }
    }

    /// Normalized progress through the day (0.0 = midnight, 0.5 = noon, 1.0 = midnight)
    static func normalizedTime() -> Double {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        return (Double(hour) + Double(minute) / 60.0) / 24.0
    }

    var isDaytime: Bool {
        switch self {
        case .dawn, .morning, .noon, .dusk: return true
        case .evening, .night: return false
        }
    }

    var isNight: Bool {
        switch self {
        case .night, .evening: return true
        default: return false
        }
    }

    var showStars: Bool { self == .night }
    var showMoon: Bool { self == .evening || self == .night }
}

// MARK: - Sky Palette

private struct SkyPalette {
    let topColor: Color
    let bottomColor: Color
    let cloudTint: Color
    let cloudOpacity: Double
    let hillBack: Color
    let hillFront: Color

    static func forTime(_ tod: SkyTimeOfDay) -> SkyPalette {
        switch tod {
        case .dawn:
            return SkyPalette(
                topColor: Color(hex: "#FFB5A0"),
                bottomColor: Color(hex: "#B8D4E8"),
                cloudTint: Color(hex: "#FFD4A0"), cloudOpacity: 0.85,
                hillBack: Color(hex: "#A8C5A0"), hillFront: Color(hex: "#8FB572")
            )
        case .morning:
            return SkyPalette(
                topColor: Color(hex: "#87CEEB"),
                bottomColor: Color(hex: "#C8E8FF"),
                cloudTint: .white, cloudOpacity: 0.9,
                hillBack: Color(hex: "#A8C5A0"), hillFront: Color(hex: "#8FB572")
            )
        case .noon:
            return SkyPalette(
                topColor: Color(hex: "#4FA8D5"),
                bottomColor: Color(hex: "#87CEEB"),
                cloudTint: .white, cloudOpacity: 0.9,
                hillBack: Color(hex: "#A8C5A0"), hillFront: Color(hex: "#8FB572")
            )
        case .dusk:
            return SkyPalette(
                topColor: Color(hex: "#FF9A5C"),
                bottomColor: Color(hex: "#6B4FA0"),
                cloudTint: Color(hex: "#FFD4A0"), cloudOpacity: 0.8,
                hillBack: Color(hex: "#D4956A"), hillFront: Color(hex: "#B87A50")
            )
        case .evening:
            return SkyPalette(
                topColor: Color(hex: "#4A4080"),
                bottomColor: Color(hex: "#2D2B6B"),
                cloudTint: Color(hex: "#3D3D5C"), cloudOpacity: 0.6,
                hillBack: Color(hex: "#4A6741"), hillFront: Color(hex: "#364F31")
            )
        case .night:
            return SkyPalette(
                topColor: Color(hex: "#1a1a2e"),
                bottomColor: Color(hex: "#16213e"),
                cloudTint: Color(hex: "#3D3D5C"), cloudOpacity: 0.6,
                hillBack: Color(hex: "#4A6741"), hillFront: Color(hex: "#364F31")
            )
        }
    }
}

// MARK: - Main Sky Background View

struct DinoSkyBackground: View {
    let currentTheme: DinoAppTheme
    @State private var timeOfDay: SkyTimeOfDay = .current()
    @State private var skyTimer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = SkyPalette.forTime(timeOfDay)

        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Sky gradient
                LinearGradient(
                    colors: [palette.topColor, palette.bottomColor],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Stars (night only)
                if timeOfDay.showStars && !reduceMotion {
                    SkyStarField(screenSize: geo.size)
                        .transition(.opacity)
                }

                // Celestial body
                if timeOfDay.isDaytime {
                    SkySun(screenSize: geo.size, timeOfDay: timeOfDay, reduceMotion: reduceMotion)
                        .transition(.opacity)
                }

                if timeOfDay.showMoon {
                    SkyMoon(screenSize: geo.size, reduceMotion: reduceMotion)
                        .transition(.opacity)
                }

                // Clouds
                if !reduceMotion {
                    SkyClouds(screenSize: geo.size, tint: palette.cloudTint, opacity: palette.cloudOpacity)
                }

                // Hills / landscape (bottom 15%)
                SkyHills(screenSize: geo.size, backColor: palette.hillBack, frontColor: palette.hillFront)
            }
        }
        .ignoresSafeArea(.all)
        .animation(.easeInOut(duration: 60.0), value: timeOfDay)
        .onAppear { startTimeUpdater() }
        .onDisappear {
            skyTimer?.invalidate()
            skyTimer = nil
        }
    }

    private func startTimeUpdater() {
        skyTimer?.invalidate()
        skyTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            let newTod = SkyTimeOfDay.current()
            if newTod != timeOfDay {
                timeOfDay = newTod
            }
        }
    }
}

// MARK: - Sun

private struct SkySun: View {
    let screenSize: CGSize
    let timeOfDay: SkyTimeOfDay
    let reduceMotion: Bool

    @State private var bouncing = false

    // Sun position arc based on time of day
    private var sunPosition: CGPoint {
        let hourFraction = SkyTimeOfDay.normalizedTime()
        // Sun visible from 5am (0.208) to 7pm (0.792)
        let sunStart: Double = 5.0 / 24.0  // 0.208
        let sunEnd: Double = 19.0 / 24.0   // 0.792

        guard hourFraction >= sunStart && hourFraction <= sunEnd else {
            return CGPoint(x: screenSize.width * 0.5, y: screenSize.height * 0.8)
        }

        let progress = (hourFraction - sunStart) / (sunEnd - sunStart) // 0→1 across sun's day

        // Arc: x goes 15%→90%, y follows a parabolic arc (high at noon)
        let xFraction = 0.15 + progress * 0.75
        let yPeak: Double = 0.12  // highest point (noon)
        let yEdge: Double = 0.75  // horizon
        // Parabola: y = yEdge - (yEdge - yPeak) * (1 - (2*p-1)^2)
        let centered = 2.0 * progress - 1.0
        let yFraction = yEdge - (yEdge - yPeak) * (1.0 - centered * centered)

        return CGPoint(x: screenSize.width * xFraction, y: screenSize.height * yFraction)
    }

    private var sunSize: CGFloat { screenSize.width * 0.08 }

    var body: some View {
        Canvas { context, size in
            let cx = sunSize / 2
            let cy = sunSize / 2
            let strokeColor = Color(hex: "#D4920A")
            let eyeColor = Color(hex: "#8B5530")
            let blushColor = Color(hex: "#F5B4B8")

            // Rays
            let innerR: CGFloat = sunSize * 0.30
            let outerR: CGFloat = sunSize * 0.43
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4
                var ray = Path()
                ray.move(to: CGPoint(x: cx + innerR * cos(angle), y: cy + innerR * sin(angle)))
                ray.addLine(to: CGPoint(x: cx + outerR * cos(angle), y: cy + outerR * sin(angle)))
                context.stroke(ray, with: .color(strokeColor),
                               style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }

            // Body
            let r: CGFloat = sunSize * 0.23
            let bodyRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            let body = Path(ellipseIn: bodyRect)
            context.fill(body, with: .color(Color(hex: "#FFD89B")))
            context.stroke(body, with: .color(strokeColor),
                           style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

            // Eyes
            let eyeR: CGFloat = r * 0.10
            let eyeY = cy - r * 0.10
            context.fill(Path(ellipseIn: CGRect(x: cx - r * 0.30 - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(eyeColor))
            context.fill(Path(ellipseIn: CGRect(x: cx + r * 0.10 - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(eyeColor))

            // Smile
            var smile = Path()
            smile.move(to: CGPoint(x: cx - r * 0.30, y: cy + r * 0.15))
            smile.addQuadCurve(to: CGPoint(x: cx + r * 0.30, y: cy + r * 0.15),
                               control: CGPoint(x: cx, y: cy + r * 0.50))
            context.stroke(smile, with: .color(eyeColor),
                           style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            // Blush
            let blushR: CGFloat = r * 0.13
            context.fill(Path(ellipseIn: CGRect(x: cx - r * 0.50 - blushR, y: cy + r * 0.15, width: blushR * 2, height: blushR * 2)),
                         with: .color(blushColor.opacity(0.6)))
            context.fill(Path(ellipseIn: CGRect(x: cx + r * 0.30 - blushR, y: cy + r * 0.15, width: blushR * 2, height: blushR * 2)),
                         with: .color(blushColor.opacity(0.6)))
        }
        .frame(width: sunSize, height: sunSize)
        .scaleEffect(bouncing ? 1.05 : 1.0)
        .position(sunPosition)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                bouncing = true
            }
        }
    }
}

// MARK: - Moon

private struct SkyMoon: View {
    let screenSize: CGSize
    let reduceMotion: Bool

    @State private var floating = false

    private var moonSize: CGFloat { screenSize.width * 0.06 }

    var body: some View {
        ZStack {
            // Soft glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#FFF5E4").opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: moonSize * 0.3,
                        endRadius: moonSize * 1.5
                    )
                )
                .frame(width: moonSize * 3, height: moonSize * 3)

            // Crescent: circle minus overlapping circle
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let moonColor = Color(hex: "#FFF5E4")

                // Full moon circle
                var fullMoon = Path()
                fullMoon.addEllipse(in: CGRect(x: 0, y: 0, width: w, height: h))

                // Shadow circle offset to create crescent
                var shadow = Path()
                shadow.addEllipse(in: CGRect(x: w * 0.25, y: -h * 0.05, width: w * 0.85, height: h * 0.85))

                // Draw full moon, then erase with shadow using even-odd
                var crescent = Path()
                crescent.addPath(fullMoon)
                crescent.addPath(shadow)

                context.fill(crescent, with: .color(moonColor), style: FillStyle(eoFill: true))
            }
            .frame(width: moonSize, height: moonSize)
        }
        .position(
            x: screenSize.width * 0.78,
            y: screenSize.height * 0.15 + (floating ? -6 : 6)
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}

// MARK: - Cloud Seeds

private struct SkyCloudSeed: Identifiable {
    let id: Int
    let yFraction: CGFloat
    let widthFraction: CGFloat
    let speed: CGFloat  // fraction of screen width per second
}

private let cloudSeeds: [SkyCloudSeed] = [
    SkyCloudSeed(id: 0, yFraction: 0.15, widthFraction: 0.18, speed: 0.003),
    SkyCloudSeed(id: 1, yFraction: 0.35, widthFraction: 0.13, speed: 0.002),
    SkyCloudSeed(id: 2, yFraction: 0.55, widthFraction: 0.10, speed: 0.0015),
]

// MARK: - Clouds Layer

private struct SkyClouds: View {
    let screenSize: CGSize
    let tint: Color
    let opacity: Double

    var body: some View {
        ForEach(cloudSeeds) { seed in
            SkyCloudDrifter(
                screenSize: screenSize,
                seed: seed,
                tint: tint,
                opacity: opacity
            )
        }
    }
}

private struct SkyCloudDrifter: View {
    let screenSize: CGSize
    let seed: SkyCloudSeed
    let tint: Color
    let opacity: Double

    @State private var xOffset: CGFloat

    init(screenSize: CGSize, seed: SkyCloudSeed, tint: Color, opacity: Double) {
        self.screenSize = screenSize
        self.seed = seed
        self.tint = tint
        self.opacity = opacity
        self._xOffset = State(initialValue: CGFloat.random(in: -0.2...0.8))
    }

    private var cloudWidth: CGFloat { screenSize.width * seed.widthFraction }
    private var cloudHeight: CGFloat { cloudWidth * 0.4 }

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var cloud = Path()
            cloud.move(to: CGPoint(x: w * 0.20, y: h * 0.45))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.10, y: h * 0.60),
                               control: CGPoint(x: w * 0.10, y: h * 0.45))
            cloud.addQuadCurve(to: CGPoint(x: 0, y: h * 0.75),
                               control: CGPoint(x: 0, y: h * 0.60))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.10, y: h * 0.92),
                               control: CGPoint(x: 0, y: h * 0.92))
            cloud.addLine(to: CGPoint(x: w * 0.87, y: h * 0.92))
            cloud.addQuadCurve(to: CGPoint(x: w, y: h * 0.70),
                               control: CGPoint(x: w, y: h * 0.92))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.89, y: h * 0.50),
                               control: CGPoint(x: w, y: h * 0.50))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.71, y: h * 0.18),
                               control: CGPoint(x: w * 0.87, y: h * 0.18))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.28),
                               control: CGPoint(x: w * 0.56, y: 0))
            cloud.addQuadCurve(to: CGPoint(x: w * 0.20, y: h * 0.45),
                               control: CGPoint(x: w * 0.28, y: h * 0.10))
            cloud.closeSubpath()
            context.fill(cloud, with: .color(tint.opacity(opacity)))
        }
        .frame(width: cloudWidth, height: cloudHeight)
        .position(
            x: screenSize.width * xOffset,
            y: screenSize.height * seed.yFraction
        )
        .onAppear {
            let duration = 1.0 / seed.speed // seconds to cross full screen
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                xOffset = 1.25
            }
        }
    }
}

// MARK: - Star Field

private struct SkyStarField: View {
    let screenSize: CGSize

    @State private var stars: [StarSeed] = []
    @State private var twinkling = false

    var body: some View {
        Canvas { context, size in
            for star in stars {
                let twinklePhase = twinkling ? star.peakOpacity : star.minOpacity
                let rect = CGRect(
                    x: star.x * size.width - star.size / 2,
                    y: star.y * size.height - star.size / 2,
                    width: star.size,
                    height: star.size
                )
                context.fill(
                    Circle().path(in: rect),
                    with: .color(.white.opacity(twinklePhase))
                )
            }
        }
        .onAppear {
            stars = (0..<20).map { _ in
                StarSeed(
                    x: CGFloat.random(in: 0.05...0.95),
                    y: CGFloat.random(in: 0.05...0.55),
                    size: CGFloat.random(in: 2...4),
                    minOpacity: Double.random(in: 0.4...0.6),
                    peakOpacity: Double.random(in: 0.7...0.9)
                )
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                twinkling = true
            }
        }
    }
}

private struct StarSeed {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let minOpacity: Double
    let peakOpacity: Double
}

// MARK: - Rolling Hills

private struct SkyHills: View {
    let screenSize: CGSize
    let backColor: Color
    let frontColor: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Back hill: starts at 87% height
            var backHill = Path()
            backHill.move(to: CGPoint(x: 0, y: h))
            backHill.addLine(to: CGPoint(x: 0, y: h * 0.87))
            backHill.addQuadCurve(to: CGPoint(x: w * 0.35, y: h * 0.82),
                                  control: CGPoint(x: w * 0.15, y: h * 0.78))
            backHill.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.85),
                                  control: CGPoint(x: w * 0.50, y: h * 0.90))
            backHill.addQuadCurve(to: CGPoint(x: w, y: h * 0.83),
                                  control: CGPoint(x: w * 0.85, y: h * 0.80))
            backHill.addLine(to: CGPoint(x: w, y: h))
            backHill.closeSubpath()
            context.fill(backHill, with: .color(backColor))

            // Front hill: starts at 92% height
            var frontHill = Path()
            frontHill.move(to: CGPoint(x: 0, y: h))
            frontHill.addLine(to: CGPoint(x: 0, y: h * 0.92))
            frontHill.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.88),
                                   control: CGPoint(x: w * 0.12, y: h * 0.86))
            frontHill.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.91),
                                   control: CGPoint(x: w * 0.42, y: h * 0.94))
            frontHill.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.89),
                                   control: CGPoint(x: w * 0.68, y: h * 0.86))
            frontHill.addQuadCurve(to: CGPoint(x: w, y: h * 0.91),
                                   control: CGPoint(x: w * 0.92, y: h * 0.93))
            frontHill.addLine(to: CGPoint(x: w, y: h))
            frontHill.closeSubpath()
            context.fill(frontHill, with: .color(frontColor))
        }
    }
}
