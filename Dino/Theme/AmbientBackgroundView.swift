//
//  AmbientBackgroundView.swift
//  Dino
//
//  Dynamic ambient background system that adapts to different themes.
//

import SwiftUI

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
    var opacity: Double
    var duration: Double
    var delay: Double
    var driftX: CGFloat
    var driftY: CGFloat
}

// MARK: - Firefly View (Night / Storm)

private struct FireflyView: View {
    @State private var particles: [FireflyParticle] = []
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(Color(hex: "#FFD966"))
                        .frame(width: p.size, height: p.size)
                        .blur(radius: p.size * 0.8)
                        .shadow(color: Color(hex: "#FFD966").opacity(0.6), radius: p.size * 2)
                        .opacity(animate ? p.opacity : p.opacity * 0.25)
                        .position(
                            x: animate ? p.x + p.driftX : p.x,
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

    private static func generateParticles(in size: CGSize) -> [FireflyParticle] {
        (0..<12).map { _ in
            // Bias y toward bottom 60% of screen
            let yBias = CGFloat.random(in: 0.4...1.0)
            return FireflyParticle(
                x: CGFloat.random(in: 20...(size.width - 20)),
                y: yBias * size.height,
                size: CGFloat.random(in: 2...4),
                opacity: Double.random(in: 0.3...0.8),
                duration: Double.random(in: 6...12),
                delay: Double.random(in: 0...4),
                driftX: CGFloat.random(in: -30...30),
                driftY: CGFloat.random(in: -20...20)
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
