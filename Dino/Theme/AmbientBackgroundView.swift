//
//  AmbientBackgroundView.swift
//  Dino
//
//  Dynamic ambient background system that adapts to different themes.
//

import SwiftUI
import CoreMotion

// MARK: - Ambient Style

enum AmbientStyle {
    case fireflies    // night, storm
    case dustMotes    // default, sunny, forest
    case calmWaves    // lavenderCalm, rainy, cloudy, snow
}

extension DinoAppTheme {
    var ambientStyle: AmbientStyle {
        switch self {
        case .night, .storm:
            return .fireflies
        case .lavenderCalm, .rainy, .cloudy, .snow:
            return .calmWaves
        default:
            return .dustMotes
        }
    }
}

// MARK: - Main Ambient Background View

struct AmbientBackgroundView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            DinoTheme.background
                .ignoresSafeArea()

            switch themeManager.currentTheme.ambientStyle {
            case .fireflies:
                FireflyView()
            case .dustMotes:
                DustMoteView()
            case .calmWaves:
                CalmWaveView()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
                particles = Self.generateParticles(in: geo.size)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animate = true
                }
            }
        }
    }

    private static func generateParticles(in size: CGSize) -> [DustParticle] {
        (0..<10).map { _ in
            DustParticle(
                x: CGFloat.random(in: 10...(size.width - 10)),
                y: CGFloat.random(in: 40...(size.height - 40)),
                size: CGFloat.random(in: 3...6),
                opacity: Double.random(in: 0.05...0.15),
                duration: Double.random(in: 8...14),
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
