//
//  FindingsSpaceBackdrop.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo. A full-bleed deep-space backdrop for the
//  findings tab so the star reads as living IN a night sky (owner fix #2).
//
//  This is a branch-OWNED port of the shipping QuietSpaceBackdrop's deep-space
//  visuals (seeded depth tiers of star dots, near-tier twinkle, one soft
//  drifting nebula, a corner vignette). It is reimplemented here — rather than
//  importing QuietSpaceBackdrop — because that file lives on the sibling
//  feature/star-journey branch and is NOT compiled into this target; adding it
//  (and its pbxproj/reading-glow API) would mean touching shipping surface this
//  branch is forbidden from touching. So the sky is rebuilt in-namespace with
//  the SAME deterministic technique, and the reading-glow / star-pin overlays
//  are simply omitted (pure space, no cream wash over the hero).
//
//  Extra local depth per the fix: two slow parallax dust layers drift at
//  different rates over the fixed star tiers. Every position/size/phase is
//  seeded from GradientSeed.hash("findings.space") so the sky is identical on
//  every launch. Reduce Motion: no twinkle, no drift — still, depth retained.
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
        let parallax: Double    // 0 = fixed sky; >0 = drifting dust tier
        let drift: Double        // seeded per-mote drift-rate multiplier
    }

    private static let stars: [StarDot] = {
        var state = GradientSeed.hash("findings.space") | 1
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 33) / Double(UInt32.max)
        }
        var out: [StarDot] = []
        func tier(_ count: Int, size: ClosedRange<Double>,
                  alpha: ClosedRange<Double>, near: Bool,
                  parallax: Double) {
            for _ in 0..<count {
                out.append(StarDot(
                    x: next(), y: next(),
                    size: size.lowerBound + next() * (size.upperBound - size.lowerBound),
                    alpha: alpha.lowerBound + next() * (alpha.upperBound - alpha.lowerBound),
                    near: near,
                    phase: next() * 2 * .pi,
                    parallax: parallax,
                    drift: 0.7 + next() * 0.6))
            }
        }
        // Fixed star tiers (same shape as QuietSpaceBackdrop).
        tier(64, size: 0.6...1.1, alpha: 0.18...0.35, near: false, parallax: 0)   // far
        tier(38, size: 1.3...1.9, alpha: 0.35...0.60, near: false, parallax: 0)   // mid
        tier(16, size: 2.0...2.9, alpha: 0.60...0.95, near: true,  parallax: 0)   // near
        // Two slow parallax dust layers for extra local depth (owner fix #2).
        tier(30, size: 0.7...1.3, alpha: 0.10...0.22, near: false, parallax: 10)  // deep dust, slow
        tier(18, size: 1.0...1.7, alpha: 0.16...0.30, near: false, parallax: 22)  // near dust, faster
        return out
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "05060F"), Color(hex: "0B0E1E")],
                    startPoint: .top, endPoint: .bottom)

                nebula(in: geo.size)
                starField
                vignette(in: geo.size)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 60).repeatForever(autoreverses: true)) {
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
                if let time {
                    if star.near {
                        // Gentle 8s sine twinkle, near tier only.
                        alpha = min(1.0, max(0.05,
                            alpha + 0.12 * sin(time * (2 * .pi / 8) + star.phase)))
                    }
                    if star.parallax > 0 {
                        // Slow horizontal drift; amplitude scaled by the tier's
                        // parallax factor and each mote's seeded drift rate.
                        dx = star.parallax * sin(time * (2 * .pi / 90) * star.drift + star.phase)
                    }
                }
                let rect = CGRect(
                    x: star.x * size.width - star.size / 2 + dx,
                    y: star.y * size.height - star.size / 2,
                    width: star.size, height: star.size)
                context.fill(Path(ellipseIn: rect),
                             with: .color(Color(hex: "FFF8E7").opacity(alpha)))
            }
        }
    }

    /// One nebula: two stacked blurred ellipses, drifting ~40pt over 60s, high
    /// in the upper sky clear of the hero star. Pure-space palette (the
    /// QuietSpaceBackdrop `.none` case) — faint violet/indigo over the gradient.
    private func nebula(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width * 0.66, y: size.height * 0.14)
        return ZStack {
            Ellipse()
                .fill(Color(hex: "3A2E58").opacity(0.22))
                .frame(width: 390, height: 260)
                .blur(radius: 60)
            Ellipse()
                .fill(Color(hex: "2A3454").opacity(0.16))
                .frame(width: 330, height: 220)
                .blur(radius: 40)
                .offset(x: 36, y: 26)
        }
        .position(center)
        .offset(x: nebulaDrift ? 18 : -18, y: nebulaDrift ? -9 : 9)
    }

    /// Soft corner vignette (~14% darkening at the edges).
    private func vignette(in size: CGSize) -> some View {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.62),
                .init(color: Color.black.opacity(0.14), location: 1.0)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: hypot(size.width, size.height) / 2)
    }
}

// MARK: - A single lonely mote for the AWAY state (owner fix #6)

/// One faint, slow-drifting mote shown while the star is out looking, so the
/// empty sky still feels alive but lonely. Seeded drift; Reduce Motion = still.
struct FindingsLonelyMote: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            dot.opacity(0.5)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
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
