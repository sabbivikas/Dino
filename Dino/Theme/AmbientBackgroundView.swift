//
//  AmbientBackgroundView.swift
//  Dino
//
//  Dynamic ambient background system that adapts to different themes.
//

import SwiftUI
import CoreMotion
import Combine

// MARK: - Ambient Style

enum AmbientStyle {
    case fireflies    // night
    case dustMotes    // default, forest
    case calmWaves    // lavenderCalm
    case sunnyRays    // sunny
    case rain         // rainy
    case cloudyMist   // cloudy
    case snowfall     // snow
    case stormRain    // storm
}

extension DinoAppTheme {
    var ambientStyle: AmbientStyle {
        switch self {
        case .night:                    return .fireflies
        case .storm:                    return .stormRain
        case .sunny:                    return .sunnyRays
        case .rainy:                    return .rain
        case .cloudy:                   return .cloudyMist
        case .snow:                     return .snowfall
        case .lavenderCalm:             return .calmWaves
        case .defaultDino, .forest:     return .dustMotes
        }
    }
}

// MARK: - Main Ambient Background View

struct AmbientBackgroundView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            DinoTheme.background
                .ignoresSafeArea()

            if !reduceMotion {
                Group {
                    switch themeManager.currentTheme.ambientStyle {
                    case .fireflies:  FireflyView()
                    case .dustMotes:  DustMoteView()
                    case .calmWaves:  CalmWaveView()
                    case .sunnyRays:  SunnyRaysView()
                    case .rain:       RainStreaksView(streakCount: 40, baseSpeed: 30)
                    case .snowfall:   SnowfallView()
                    case .stormRain:  StormView()
                    case .cloudyMist: CloudyMistView()
                    }
                }
                .transition(.opacity)
                .onAppear {
                    print("[Dino Ambient] Active style: \(themeManager.currentTheme.ambientStyle) for theme: \(themeManager.currentTheme.rawValue)")
                }
                .onChange(of: themeManager.currentTheme) { newTheme in
                    print("[Dino Ambient] Style changed to: \(newTheme.ambientStyle) for theme: \(newTheme.rawValue)")
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 1.5), value: themeManager.currentTheme)
    }
}

// MARK: - Firefly Particle

private struct FireflyParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var glowRadius: CGFloat
    var opacity: Double
    var peakOpacity: Double
    var duration: Double
    var delay: Double
    var driftX: CGFloat
    var driftY: CGFloat
    var color: Color
    var pulseDuration: Double
    var depthLayer: CGFloat  // 0.0 = far background, 1.0 = near foreground
}

// MARK: - Motion Manager (parallax tilt)

private class TiltManager: ObservableObject {
    @Published var xTilt: CGFloat = 0
    @Published var yTilt: CGFloat = 0

    private let motionManager = CMMotionManager()

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let attitude = motion?.attitude else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                self.xTilt = CGFloat(attitude.roll) * 12
                self.yTilt = CGFloat(attitude.pitch) * 12
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - Firefly View (Night / Storm)

private struct FireflyView: View {
    @State private var particles: [FireflyParticle] = []
    @State private var driftAnimate = false
    @State private var pulseAnimate = false
    @State private var twinkleIndex: Int? = nil
    @State private var gradientPhase: CGFloat = 0
    @StateObject private var tilt = TiltManager()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Ambient gradient shift (deep navy ↔ deep indigo)
                LinearGradient(
                    colors: [
                        Color(hex: "#0D1321").opacity(gradientPhase),
                        Color(hex: "#1A1040").opacity(1.0 - gradientPhase * 0.5),
                        Color(hex: "#0D1321").opacity(0.8 + gradientPhase * 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 25).repeatForever(autoreverses: true), value: gradientPhase)

                // Firefly particles
                ForEach(Array(particles.enumerated()), id: \.element.id) { index, p in
                    let parallaxMultiplier = 0.4 + p.depthLayer * 0.6
                    let isTwinkling = twinkleIndex == index

                    ZStack {
                        // Outer soft glow halo
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        p.color.opacity(isTwinkling ? 0.7 : 0.35),
                                        p.color.opacity(isTwinkling ? 0.3 : 0.12),
                                        p.color.opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: p.glowRadius * (isTwinkling ? 1.8 : 1.0)
                                )
                            )
                            .frame(
                                width: p.glowRadius * (isTwinkling ? 4.0 : 2.5),
                                height: p.glowRadius * (isTwinkling ? 4.0 : 2.5)
                            )
                            .opacity(pulseAnimate ? p.peakOpacity : p.peakOpacity * 0.15)
                            .animation(
                                .easeInOut(duration: p.pulseDuration)
                                .repeatForever(autoreverses: true)
                                .delay(p.delay),
                                value: pulseAnimate
                            )

                        // Inner bright core
                        Circle()
                            .fill(p.color)
                            .frame(
                                width: p.size * (isTwinkling ? 1.6 : 1.0),
                                height: p.size * (isTwinkling ? 1.6 : 1.0)
                            )
                            .blur(radius: p.size * 0.4)
                            .shadow(color: p.color.opacity(isTwinkling ? 1.0 : 0.8), radius: p.size * (isTwinkling ? 3.0 : 1.5))
                            .opacity(pulseAnimate ? (isTwinkling ? 1.0 : p.opacity) : p.opacity * 0.2)
                            .animation(
                                .easeInOut(duration: p.pulseDuration)
                                .repeatForever(autoreverses: true)
                                .delay(p.delay),
                                value: pulseAnimate
                            )

                        // Trailing glow (faint echo behind the drift direction)
                        Circle()
                            .fill(p.color.opacity(0.08))
                            .frame(width: p.size * 3, height: p.size * 3)
                            .blur(radius: p.size * 2)
                            .offset(
                                x: driftAnimate ? -p.driftX * 0.3 : 0,
                                y: driftAnimate ? -p.driftY * 0.3 : 0
                            )
                            .animation(
                                .easeInOut(duration: p.duration * 1.2)
                                .repeatForever(autoreverses: true)
                                .delay(p.delay * 0.5 + 0.5),
                                value: driftAnimate
                            )
                    }
                    // Scale by depth layer (far = small, near = big)
                    .scaleEffect(0.5 + p.depthLayer * 0.5)
                    .opacity(0.4 + p.depthLayer * 0.6)
                    // Twinkle burst animation
                    .animation(.easeInOut(duration: 0.4), value: isTwinkling)
                    .position(
                        x: (driftAnimate ? p.x + p.driftX : p.x) + tilt.xTilt * parallaxMultiplier,
                        y: (driftAnimate ? p.y + p.driftY : p.y) + tilt.yTilt * parallaxMultiplier
                    )
                    .animation(
                        .easeInOut(duration: p.duration)
                        .repeatForever(autoreverses: true)
                        .delay(p.delay * 0.5),
                        value: driftAnimate
                    )
                }
            }
            .onAppear {
                particles = Self.generateParticles(in: geo.size)
                tilt.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    driftAnimate = true
                    pulseAnimate = true
                    gradientPhase = 1.0
                }
                startTwinkleTimer()
            }
            .onDisappear {
                tilt.stop()
            }
        }
    }

    // Random twinkle burst every 3-6 seconds
    private func startTwinkleTimer() {
        let interval = Double.random(in: 3...6)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            guard !particles.isEmpty else { return }
            let idx = Int.random(in: 0..<particles.count)
            withAnimation(.easeIn(duration: 0.3)) {
                twinkleIndex = idx
            }
            // Fade twinkle back after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.6)) {
                    twinkleIndex = nil
                }
            }
            startTwinkleTimer()
        }
    }

    private static let warmColors: [Color] = [
        Color(hex: "#FFD966"),  // warm gold
        Color(hex: "#FFE4A0"),  // soft cream
        Color(hex: "#FFEEBB"),  // pale amber
        Color(hex: "#E8D5A3"),  // muted honey
        Color(hex: "#C8E6C9"),  // faint green (rare)
        Color(hex: "#B8D4E3"),  // cool blue (very rare)
    ]

    private static func generateParticles(in size: CGSize) -> [FireflyParticle] {
        (0..<24).map { _ in
            let depth = CGFloat.random(in: 0...1)
            return FireflyParticle(
                x: CGFloat.random(in: 20...(size.width - 20)),
                y: CGFloat.random(in: 40...(size.height - 40)),
                size: CGFloat.random(in: 2...5),
                glowRadius: CGFloat.random(in: 8...20),
                opacity: Double.random(in: 0.4...0.9),
                peakOpacity: Double.random(in: 0.5...1.0),
                duration: Double.random(in: 8...18),
                delay: Double.random(in: 0...6),
                driftX: CGFloat.random(in: -50...50),
                driftY: CGFloat.random(in: -40...40),
                color: warmColors.randomElement() ?? Color(hex: "#FFD966"),
                pulseDuration: Double.random(in: 3...8),
                depthLayer: depth
            )
        }
    }
}

// MARK: - Dust Mote Particle

private struct DustParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var duration: Double
    var delay: Double
    var driftY: CGFloat
}

// MARK: - Dust Mote View (Light themes)

private struct DustMoteView: View {
    var speedMultiplier: CGFloat = 1.0
    @State private var particles: [DustParticle] = []
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(DinoTheme.textSecondary.opacity(0.08))
                        .frame(width: p.size, height: p.size)
                        .blur(radius: 1)
                        .opacity(animate ? p.opacity : p.opacity * 0.3)
                        .position(
                            x: p.x,
                            y: animate ? p.y + p.driftY : p.y
                        )
                        .animation(
                            .easeInOut(duration: p.duration)
                            .repeatForever(autoreverses: true)
                            .delay(p.delay),
                            value: animate
                        )
                }
            }
            .onAppear {
                particles = Self.generateParticles(in: geo.size, speedMultiplier: speedMultiplier)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animate = true
                }
            }
        }
    }

    private static func generateParticles(in size: CGSize, speedMultiplier: CGFloat = 1.0) -> [DustParticle] {
        (0..<10).map { _ in
            DustParticle(
                x: CGFloat.random(in: 10...(size.width - 10)),
                y: CGFloat.random(in: 40...(size.height - 40)),
                size: CGFloat.random(in: 3...6),
                opacity: Double.random(in: 0.05...0.15),
                duration: Double.random(in: 8...14) / Double(speedMultiplier),
                delay: Double.random(in: 0...5),
                driftY: CGFloat.random(in: (-40)...(-10))
            )
        }
    }
}

// MARK: - Calm Wave View (Calm / Rainy / Cloudy / Snow)

private struct CalmWaveView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Two slow-moving gradient blobs
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                DinoTheme.accent.opacity(0.06),
                                DinoTheme.accent.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: geo.size.width * 0.5
                        )
                    )
                    .frame(width: geo.size.width * 0.8, height: geo.size.height * 0.35)
                    .offset(
                        x: sin(phase * .pi * 2) * 30,
                        y: cos(phase * .pi * 2) * 20 - geo.size.height * 0.1
                    )
                    .blur(radius: 40)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                DinoTheme.lavender.opacity(0.05),
                                DinoTheme.lavender.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.6, height: geo.size.height * 0.3)
                    .offset(
                        x: cos(phase * .pi * 2) * 25,
                        y: sin(phase * .pi * 2) * 15 + geo.size.height * 0.2
                    )
                    .blur(radius: 35)
            }
            .onAppear {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}

// MARK: - Sunny Rays View (Sunny theme)

private struct SunnyRaysView: View {
    @State private var pulseScale: CGFloat = 0.95

    private static let rayCount = 8
    private static let rotationPeriodInSeconds: Double = 60

    private var glowTint: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return Color(hex: "#FFB088")  // soft pink/orange morning
        case 11..<17: return Color(hex: "#FFD966")  // pure golden midday
        case 17..<21: return Color(hex: "#E8A040")  // deeper amber evening
        default:      return Color(hex: "#FFD966")  // fallback golden
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Rotating light rays from top-right corner
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        let center = CGPoint(x: size.width + 20, y: -20)
                        let rotation = (time / Self.rotationPeriodInSeconds) * 2 * .pi
                        let rayLength = hypot(size.width, size.height) * 1.5
                        let rayHalfWidth = Double.pi / 24

                        for i in 0..<Self.rayCount {
                            let baseAngle = rotation + Double(i) * (2 * .pi / Double(Self.rayCount))

                            var path = Path()
                            path.move(to: center)
                            path.addLine(to: CGPoint(
                                x: center.x + cos(baseAngle - rayHalfWidth) * rayLength,
                                y: center.y + sin(baseAngle - rayHalfWidth) * rayLength
                            ))
                            path.addLine(to: CGPoint(
                                x: center.x + cos(baseAngle + rayHalfWidth) * rayLength,
                                y: center.y + sin(baseAngle + rayHalfWidth) * rayLength
                            ))
                            path.closeSubpath()

                            context.fill(path, with: .color(.white.opacity(0.10)))
                        }
                    }
                }

                // Pulsing warm glow circle in top-right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glowTint.opacity(0.16), glowTint.opacity(0.0)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(pulseScale)
                    .position(x: geo.size.width - 40, y: 60)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                            pulseScale = 1.05
                        }
                    }
            }
        }
    }
}

// MARK: - Rain Streak Seed

private struct RainSeed {
    let xNormalized: CGFloat    // 0–1 horizontal position
    let startOffset: CGFloat    // 0–1 vertical stagger
    let speed: CGFloat          // pixels per second
    let opacity: Double
}

// MARK: - Rain Streaks View (Rainy / Storm themes)

private struct RainStreaksView: View {
    let streakCount: Int
    let baseSpeed: CGFloat

    private static let streakLength: CGFloat = 12
    private static let angleInDegrees: Double = 15

    @State private var seeds: [RainSeed] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let angleRad = Self.angleInDegrees * .pi / 180.0
                    let dx = sin(angleRad) * Self.streakLength
                    let dy = cos(angleRad) * Self.streakLength
                    let totalTravel = size.height + Self.streakLength

                    for seed in seeds {
                        let x = seed.xNormalized * size.width
                        let rawY = seed.startOffset * totalTravel + CGFloat(time) * seed.speed
                        let y = rawY.truncatingRemainder(dividingBy: totalTravel) - Self.streakLength

                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + dx, y: y + dy))
                        context.stroke(path, with: .color(.white.opacity(seed.opacity)), lineWidth: 1)
                    }
                }
            }
            .onAppear {
                seeds = (0..<streakCount).map { _ in
                    RainSeed(
                        xNormalized: CGFloat.random(in: 0...1),
                        startOffset: CGFloat.random(in: 0...1),
                        speed: baseSpeed * CGFloat.random(in: 0.8...1.2),
                        opacity: Double.random(in: 0.12...0.18)
                    )
                }
            }
        }
    }
}

// MARK: - Snow Seed

private struct SnowSeed {
    let xNormalized: CGFloat
    let startOffset: CGFloat
    let size: CGFloat
    let speed: CGFloat
    let swayAmplitude: CGFloat
    let swayFrequency: CGFloat
    let swayPhase: CGFloat
    let opacity: Double
}

// MARK: - Snowfall View (Snow theme)

private struct SnowfallView: View {
    @State private var seeds: [SnowSeed] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for seed in seeds {
                        let totalTravel = size.height + seed.size * 2
                        let rawY = seed.startOffset * totalTravel + CGFloat(time) * seed.speed
                        let y = rawY.truncatingRemainder(dividingBy: totalTravel) - seed.size

                        let baseX = seed.xNormalized * size.width
                        let swayX = baseX + sin(CGFloat(time) * seed.swayFrequency + seed.swayPhase) * seed.swayAmplitude

                        let r = seed.size / 2
                        let rect = CGRect(x: swayX - r, y: y - r, width: seed.size, height: seed.size)
                        context.fill(Circle().path(in: rect), with: .color(.white.opacity(seed.opacity)))
                    }
                }
            }
            .onAppear {
                seeds = (0..<30).map { _ in
                    SnowSeed(
                        xNormalized: CGFloat.random(in: 0...1),
                        startOffset: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 3...6),
                        speed: CGFloat.random(in: 12...25),
                        swayAmplitude: CGFloat.random(in: 8...20),
                        swayFrequency: CGFloat.random(in: 0.3...0.8),
                        swayPhase: CGFloat.random(in: 0...(2 * .pi)),
                        opacity: Double.random(in: 0.15...0.22)
                    )
                }
            }
        }
    }
}

// MARK: - Storm View (Storm theme — faster rain + lightning)

private struct StormView: View {
    @State private var flashOpacity: Double = 0

    var body: some View {
        ZStack {
            // Faster, denser rain
            RainStreaksView(streakCount: 60, baseSpeed: 40)

            // Lightning flash overlay
            Rectangle()
                .fill(Color.white.opacity(flashOpacity))
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .onAppear { scheduleFlash() }
        }
    }

    private func scheduleFlash() {
        let delay = Double.random(in: 8...20)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.1)) { flashOpacity = 0.18 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.15)) { flashOpacity = 0 }
            }
            scheduleFlash()
        }
    }
}

// MARK: - Cloud Wisp Seed

private struct CloudWispSeed {
    let yNormalized: CGFloat    // 0–1 vertical position
    let startOffset: CGFloat    // 0–1 horizontal stagger
    let width: CGFloat
    let height: CGFloat
    let speed: CGFloat          // pixels per second (horizontal drift)
    let opacity: Double
}

// MARK: - Cloudy Mist View (Cloudy theme — slow dust motes + cloud wisps)

private struct CloudyMistView: View {
    @State private var wispSeeds: [CloudWispSeed] = []

    var body: some View {
        ZStack {
            // Slow dust motes (30% slower than default)
            DustMoteView(speedMultiplier: 0.7)

            // Large soft cloud wisps drifting left to right
            GeometryReader { geo in
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        for seed in wispSeeds {
                            let totalTravel = size.width + seed.width
                            let rawX = seed.startOffset * totalTravel + CGFloat(time) * seed.speed
                            let x = rawX.truncatingRemainder(dividingBy: totalTravel) - seed.width / 2

                            let y = seed.yNormalized * size.height

                            let rect = CGRect(
                                x: x - seed.width / 2,
                                y: y - seed.height / 2,
                                width: seed.width,
                                height: seed.height
                            )
                            context.fill(
                                Ellipse().path(in: rect),
                                with: .color(.white.opacity(seed.opacity))
                            )
                        }
                    }
                }
                .blur(radius: 25)
                .onAppear {
                    wispSeeds = (0..<3).map { _ in
                        CloudWispSeed(
                            yNormalized: CGFloat.random(in: 0.2...0.8),
                            startOffset: CGFloat.random(in: 0...1),
                            width: CGFloat.random(in: 180...220),
                            height: CGFloat.random(in: 40...70),
                            speed: CGFloat.random(in: 5...10),
                            opacity: Double.random(in: 0.10...0.15)
                        )
                    }
                }
            }
        }
    }
}
