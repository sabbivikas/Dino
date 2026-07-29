//
//  FindingsSpaceBackdrop.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo — the full-bleed deep-space backdrop the
//  free-floating star and Earth live over.
//
//  Reworked for the redesign:
//    • a dark-violet base graded slightly WARMER toward the bottom;
//    • THREE parallax star layers of different sizes / opacities / speeds AND
//      DIRECTIONS — the cross-drift (one tier easing right-and-up while another
//      eases left-and-down) is what creates the depth; they never move as one;
//    • TWO slow nebula washes drifting AGAINST each other;
//    • a vignette so the edges fall off.
//  Everything is seeded from GradientSeed.hash(...) — no per-frame randomness,
//  so the sky is identical on every launch. Reduce Motion: every drift stops
//  (the depth stays, the motion does not).
//
//  English-only demo (owner decision): plain string literals only.
//

import SwiftUI

struct FindingsSpaceBackdrop: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nebulaDrift = false

    // MARK: - Seeded star field (deterministic — no runtime randomness)

    private struct StarDot {
        let x: Double
        let y: Double
        let size: Double        // pt
        let alpha: Double
        let near: Bool          // only the near tier twinkles
        let phase: Double       // twinkle phase, seeded
        let layer: Int          // 0/1/2 parallax layer (each drifts differently)
    }

    /// Each parallax layer drifts a different distance in a DIFFERENT direction
    /// and at a different speed — the cross-drift is the depth cue. (dx, dy) is
    /// the drift amplitude in pt; period is the seconds for one full cycle.
    private struct Layer { let dx: Double; let dy: Double; let period: Double }
    private static let layers: [Layer] = [
        Layer(dx:  8, dy:  4, period: 120),   // far: slow, drifts right + up
        Layer(dx: -16, dy: 9, period:  84),   // mid: faster, drifts left + down
        Layer(dx: 22, dy: -6, period:  60),   // near: fastest, drifts right + down
    ]

    private static let stars: [StarDot] = {
        var state = GradientSeed.hash("findings.space") | 1
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 33) / Double(UInt32.max)
        }
        var out: [StarDot] = []
        func tier(_ count: Int, size: ClosedRange<Double>,
                  alpha: ClosedRange<Double>, near: Bool, layer: Int) {
            for _ in 0..<count {
                out.append(StarDot(
                    x: next(), y: next(),
                    size: size.lowerBound + next() * (size.upperBound - size.lowerBound),
                    alpha: alpha.lowerBound + next() * (alpha.upperBound - alpha.lowerBound),
                    near: near,
                    phase: next() * 2 * .pi,
                    layer: layer))
            }
        }
        // Three depth tiers, each bound to its own drift layer.
        tier(70, size: 0.6...1.1, alpha: 0.16...0.34, near: false, layer: 0)   // far, faint, tiny
        tier(42, size: 1.2...1.9, alpha: 0.32...0.58, near: false, layer: 1)   // mid
        tier(18, size: 2.0...2.9, alpha: 0.60...0.95, near: true,  layer: 2)   // near, bright, twinkles
        return out
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dark violet base, WARMER toward the bottom.
                LinearGradient(
                    colors: [Color(hex: "07060F"), Color(hex: "0E0A1C"), Color(hex: "17101C")],
                    startPoint: .top, endPoint: .bottom)

                nebula(in: geo.size)
                starField
                vignette(in: geo.size)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 70).repeatForever(autoreverses: true)) {
                    nebulaDrift = true
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: - Layers

    @ViewBuilder
    private var starField: some View {
        if reduceMotion {
            starCanvas(at: nil)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                starCanvas(at: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func starCanvas(at time: TimeInterval?) -> some View {
        Canvas { context, size in
            for star in Self.stars {
                var alpha = star.alpha
                var dx = 0.0
                var dy = 0.0
                if let time {
                    if star.near {
                        alpha = min(1.0, max(0.05,
                            alpha + 0.12 * sin(time * (2 * .pi / 8) + star.phase)))
                    }
                    let L = Self.layers[star.layer]
                    let t = time * (2 * .pi / L.period) + star.phase
                    dx = L.dx * sin(t)
                    dy = L.dy * cos(t)   // sin/cos on the two axes ⇒ a gentle drift, not a line
                }
                let rect = CGRect(
                    x: star.x * size.width - star.size / 2 + dx,
                    y: star.y * size.height - star.size / 2 + dy,
                    width: star.size, height: star.size)
                context.fill(Path(ellipseIn: rect),
                             with: .color(Color(hex: "FFF8E7").opacity(alpha)))
            }
        }
    }

    /// TWO nebula washes drifting AGAINST each other: a violet one high-right
    /// eases one way, a warmer indigo one mid-left eases the opposite way, so
    /// the sky slowly breathes rather than sliding as a block.
    private func nebula(in size: CGSize) -> some View {
        ZStack {
            // Wash A — violet, upper right.
            ZStack {
                Ellipse().fill(Color(hex: "3A2E58").opacity(0.24))
                    .frame(width: 420, height: 280).blur(radius: 66)
                Ellipse().fill(Color(hex: "2A3457").opacity(0.16))
                    .frame(width: 340, height: 230).blur(radius: 44)
                    .offset(x: 36, y: 26)
            }
            .position(x: size.width * 0.70, y: size.height * 0.16)
            .offset(x: nebulaDrift ? 22 : -22, y: nebulaDrift ? -12 : 12)

            // Wash B — warmer plum, lower left, drifting the OPPOSITE way.
            ZStack {
                Ellipse().fill(Color(hex: "4A2E4A").opacity(0.18))
                    .frame(width: 380, height: 300).blur(radius: 70)
                Ellipse().fill(Color(hex: "3A2440").opacity(0.14))
                    .frame(width: 300, height: 240).blur(radius: 48)
                    .offset(x: -28, y: 18)
            }
            .position(x: size.width * 0.28, y: size.height * 0.66)
            .offset(x: nebulaDrift ? -20 : 20, y: nebulaDrift ? 12 : -12)
        }
        .allowsHitTesting(false)
    }

    /// Soft corner vignette so the edges fall off (~16% darkening).
    private func vignette(in size: CGSize) -> some View {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.58),
                .init(color: Color.black.opacity(0.16), location: 1.0)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: hypot(size.width, size.height) / 2)
    }
}

// MARK: - A single lonely mote for the AWAY state

/// One faint, slow-drifting mote shown while the star is out looking, so the
/// empty sky still feels alive but lonely. Seeded drift; Reduce Motion = still.
/// The tab shows one or two of these, each with its own seeded phase.
struct FindingsLonelyMote: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var phase: Double = 0

    var body: some View {
        if reduceMotion {
            dot.opacity(0.5)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate + phase
                let dx = 26.0 * sin(t * (2 * .pi / 14))
                let dy = 14.0 * sin(t * (2 * .pi / 19) + 1.3)
                let pulse = 0.35 + 0.2 * (sin(t * (2 * .pi / 6)) + 1) / 2
                dot
                    .opacity(pulse)
                    .offset(x: dx, y: dy)
            }
        }
    }

    private var dot: some View {
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: "FFF3D6").opacity(0.9), location: 0),
                    .init(color: Color(hex: "FFE08A").opacity(0.35), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                center: .center, startRadius: 0, endRadius: 9))
            .frame(width: 18, height: 18)
            .allowsHitTesting(false)
    }
}
