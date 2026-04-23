//
//  LiveActivityBackgrounds.swift
//  DinoLiveActivity
//
//  Shared v6 Live Activity visual primitives: MeadowBackground,
//  NightBackground, CycleDotsRow, BreathingHoops, MoonView.
//
//  Color(hex:) initializer is defined in BreathingLiveActivity.swift.
//  DinoPalette (which carries the la* tokens) is defined in
//  Theme/WidgetThemeExtensions.swift.
//

import SwiftUI

// MARK: - Meadow (Breathing) Background

struct MeadowHillFarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Rolling far hill occupying the bottom 55% — two gentle bumps.
        p.move(to: CGPoint(x: 0, y: h * 0.66))
        p.addCurve(
            to: CGPoint(x: w * 0.52, y: h * 0.58),
            control1: CGPoint(x: w * 0.18, y: h * 0.54),
            control2: CGPoint(x: w * 0.32, y: h * 0.50)
        )
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.70),
            control1: CGPoint(x: w * 0.72, y: h * 0.66),
            control2: CGPoint(x: w * 0.88, y: h * 0.56)
        )
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

struct MeadowHillNearShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Nearer hill — lower, more foreground presence.
        p.move(to: CGPoint(x: 0, y: h * 0.82))
        p.addCurve(
            to: CGPoint(x: w * 0.40, y: h * 0.76),
            control1: CGPoint(x: w * 0.12, y: h * 0.74),
            control2: CGPoint(x: w * 0.28, y: h * 0.72)
        )
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.84),
            control1: CGPoint(x: w * 0.62, y: h * 0.82),
            control2: CGPoint(x: w * 0.82, y: h * 0.74)
        )
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

struct MeadowSun: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [DinoPalette.laSunCore, DinoPalette.laSunEdge, .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 30
                )
            )
            .frame(width: 60, height: 60)
            .opacity(0.85)
    }
}

struct MeadowBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DinoPalette.laMeadowTop, DinoPalette.laMeadowMid, DinoPalette.laMeadowBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            MeadowHillFarShape()
                .fill(DinoPalette.laHillFar)

            MeadowHillNearShape()
                .fill(DinoPalette.laHillNear)

            // Sun anchored top-left (per v6 spec diagram: warm bloom above mascot).
            MeadowSun()
                .offset(x: -120, y: -40)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Night (Meditation) Background

/// Deterministic star positions so the field doesn't reshuffle on every tick.
private let starPositions: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
    (0.06, 0.18, 1.5), (0.11, 0.62, 1.5), (0.18, 0.28, 1.8), (0.22, 0.82, 1.4),
    (0.27, 0.12, 1.5), (0.33, 0.48, 1.5), (0.39, 0.22, 1.7), (0.44, 0.74, 1.5),
    (0.50, 0.16, 1.5), (0.56, 0.54, 1.5), (0.62, 0.30, 1.5), (0.68, 0.72, 1.8),
    (0.74, 0.20, 1.5), (0.80, 0.58, 1.5), (0.85, 0.36, 1.5), (0.90, 0.78, 1.6),
    (0.14, 0.44, 1.4), (0.46, 0.36, 1.5)
]

struct StarField: View {
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<min(count, starPositions.count), id: \.self) { i in
                    let p = starPositions[i]
                    TwinklingStar(
                        phaseDelay: Double(i) * 0.2,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: p.size, height: p.size)
                    .position(x: geo.size.width * p.x, y: geo.size.height * p.y)
                }
            }
        }
    }
}

private struct TwinklingStar: View {
    let phaseDelay: Double
    let reduceMotion: Bool
    @State private var bright: Bool = false

    var body: some View {
        Circle()
            .fill(Color.white)
            .opacity(reduceMotion ? 0.7 : (bright ? 1.0 : 0.35))
            .scaleEffect(reduceMotion ? 1.0 : (bright ? 1.15 : 0.9))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 3.5)
                        .repeatForever(autoreverses: true)
                        .delay(phaseDelay)
                ) {
                    bright = true
                }
            }
    }
}

struct Nebula: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsed: Bool = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [DinoPalette.laNebula.opacity(0.22), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 110
                )
            )
            .frame(width: 220, height: 180)
            .scaleEffect(reduceMotion ? 1.0 : (pulsed ? 1.05 : 0.95))
            .opacity(reduceMotion ? 1.0 : (pulsed ? 1.0 : 0.75))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    pulsed = true
                }
            }
    }
}

struct NightBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DinoPalette.laNightTop, DinoPalette.laNightMid, DinoPalette.laNightBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            Nebula()
                .offset(x: -60, y: 30)

            StarField(count: 18)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Cycle Dots

struct CycleDotsRow: View {
    let total: Int
    let current: Int   // 1-based current cycle

    /// Clamp visible indices to a 1-based window of at most 8 trailing positions.
    private var visible: (dots: [Int], currentVisible: Int) {
        let cap = 8
        if total <= cap {
            return (Array(1...max(total, 1)), current)
        }
        // Show the last `cap` positions centered around `current`.
        // If current is within the final window, render that window.
        // Otherwise render the most-recently-relevant window.
        let end = min(total, max(current, cap))
        let start = max(1, end - cap + 1)
        let dots = Array(start...end)
        return (dots, current)
    }

    var body: some View {
        let v = visible
        HStack(spacing: 4) {
            ForEach(v.dots, id: \.self) { idx in
                Circle()
                    .fill(idx == v.currentVisible
                          ? DinoPalette.laCuePeach
                          : Color(hex: "#B9D3A8"))
                    .overlay(
                        Circle()
                            .stroke(
                                idx == v.currentVisible
                                ? Color(hex: "#C88990")
                                : Color(hex: "#7BA872"),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 7, height: 7)
                    .scaleEffect(idx == v.currentVisible ? 1.15 : 1.0)
            }
        }
    }
}

// MARK: - Breathing Hoops

struct BreathingHoops: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded: Bool = false

    private let radii: [CGFloat] = [42, 54, 66]

    var body: some View {
        ZStack {
            ForEach(Array(radii.enumerated()), id: \.offset) { (i, r) in
                Circle()
                    .stroke(DinoPalette.laSageRing, lineWidth: 1.4)
                    .frame(width: r * 2, height: r * 2)
                    .scaleEffect(reduceMotion ? 1.0 : (expanded ? 1.08 : 0.88))
                    .opacity(reduceMotion ? 0.4 : (expanded ? 0.6 : 0.25))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.6),
                        value: expanded
                    )
            }
        }
        .onAppear { expanded = true }
    }
}

// MARK: - Moon View

struct MoonView: View {
    var size: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing: Bool = false

    var body: some View {
        ZStack {
            // Outer rotating ring (dashed)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let rot = reduceMotion
                    ? 0.0
                    : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 40) / 40 * 360
                Circle()
                    .stroke(
                        DinoPalette.laMoonFace.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 5])
                    )
                    .frame(width: size * 1.22, height: size * 1.22)
                    .rotationEffect(.degrees(rot))
            }

            // Ripples under moon
            RippleLayer(size: size, reduceMotion: reduceMotion)

            // Moon body
            Circle()
                .fill(DinoPalette.laMoonFace)
                .overlay(Circle().stroke(DinoPalette.laMoonStroke, lineWidth: 1.6))
                .frame(width: size, height: size)

            // Craters — normalized offsets from spec (0.32,0.38 r=6), (0.58,0.55 r=4), (0.44,0.68 r=3)
            Circle()
                .fill(DinoPalette.laMoonCrater)
                .frame(width: 6, height: 6)
                .offset(x: (0.32 - 0.5) * size, y: (0.38 - 0.5) * size)
            Circle()
                .fill(DinoPalette.laMoonCrater)
                .frame(width: 4, height: 4)
                .offset(x: (0.58 - 0.5) * size, y: (0.55 - 0.5) * size)
            Circle()
                .fill(DinoPalette.laMoonCrater)
                .frame(width: 3, height: 3)
                .offset(x: (0.44 - 0.5) * size, y: (0.68 - 0.5) * size)
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .scaleEffect(reduceMotion ? 1.0 : (breathing ? 1.04 : 0.96))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

private struct RippleLayer: View {
    let size: CGFloat
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            RippleCircle(delay: 0, size: size, reduceMotion: reduceMotion)
            RippleCircle(delay: 2, size: size, reduceMotion: reduceMotion)
            RippleCircle(delay: 4, size: size, reduceMotion: reduceMotion)
        }
    }
}

private struct RippleCircle: View {
    let delay: Double
    let size: CGFloat
    let reduceMotion: Bool
    @State private var expanded: Bool = false

    var body: some View {
        Circle()
            .stroke(DinoPalette.laMoonFace.opacity(0.35), lineWidth: 1)
            .frame(width: size, height: size)
            .scaleEffect(reduceMotion ? 1.0 : (expanded ? 1.8 : 0.4))
            .opacity(reduceMotion ? 0.15 : (expanded ? 0 : 0.8))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeOut(duration: 6)
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                ) {
                    expanded = true
                }
            }
    }
}
