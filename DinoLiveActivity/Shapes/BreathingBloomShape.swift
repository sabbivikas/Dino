//
//  BreathingBloomShape.swift
//  DinoLiveActivity
//
//  5-petal flower bloom from widgets.html (class="bloom"). Five ellipse petals
//  rotated 0/72/144/216/288° around the center, plus a cream center disc.
//  Entry-driven `breathPhase` drives outer scale — computed by the TimelineProvider
//  from `0.92 + 0.16 * sin(phase * 2π)` so it walks a smooth sine cycle.
//

import SwiftUI

struct BreathingBloomShape: View {
    /// Scale multiplier driven by the Timeline. Typically 0.92...1.08.
    let breathPhase: Double

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            // Petal size scales with widget size — source is 72x72 from widgets.html,
            // petals are rx=8 ry=12 at that scale. We normalize to our rendered size.
            let petalW = size * (8.0 / 72.0)
            let petalH = size * (12.0 / 72.0)
            let petalDistance = size * 0.25 // radial distance from center to petal centroid
            let centerR = size * (7.0 / 72.0)

            ZStack {
                // 5 petals rotated at 0, 72, 144, 216, 288
                petal(color: DinoPalette.bloomPeach,    angle: 0,    width: petalW, height: petalH, center: center, distance: petalDistance)
                petal(color: DinoPalette.bloomYellow,   angle: 72,   width: petalW, height: petalH, center: center, distance: petalDistance)
                petal(color: DinoPalette.bloomLavender, angle: 144,  width: petalW, height: petalH, center: center, distance: petalDistance)
                petal(color: DinoPalette.bloomSage,     angle: 216,  width: petalW, height: petalH, center: center, distance: petalDistance)
                petal(color: DinoPalette.bloomGold,     angle: 288,  width: petalW, height: petalH, center: center, distance: petalDistance)

                // Center disc
                Circle()
                    .fill(DinoPalette.bloomCenter)
                    .frame(width: centerR * 2, height: centerR * 2)
                    .position(center)
            }
            .frame(width: size, height: size)
            .scaleEffect(breathPhase)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    @ViewBuilder
    private func petal(color: Color, angle: Double, width: CGFloat, height: CGFloat, center: CGPoint, distance: CGFloat) -> some View {
        // Compute petal centroid: start above center, then rotate around the origin.
        let rad = angle * .pi / 180.0
        let dx = sin(rad) * distance
        let dy = -cos(rad) * distance
        Ellipse()
            .fill(color)
            .overlay(
                Ellipse()
                    .stroke(DinoPalette.ink, lineWidth: 1.4)
            )
            .frame(width: width, height: height)
            .rotationEffect(.degrees(angle))
            .position(x: center.x + dx, y: center.y + dy)
    }
}
