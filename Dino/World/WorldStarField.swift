//
//  WorldStarField.swift
//  Dino
//
//  The soft star field behind the space-dark globe — sparse warm stars with
//  a slow twinkle. Deterministic positions (seeded LCG) so the sky never
//  reshuffles between opens; static under reduce-motion.
//

import SwiftUI

struct WorldStarField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star {
        let x: CGFloat        // 0...1 of width
        let y: CGFloat        // 0...1 of height
        let radius: CGFloat
        let baseOpacity: Double
        let twinkleSpeed: Double
        let phase: Double
        let warm: Bool        // a few gold stars among the cream
    }

    private static let stars: [Star] = {
        var seed: UInt64 = 0x5EED_D1_50
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt32.max)
        }
        return (0..<90).map { _ in
            Star(x: CGFloat(next()), y: CGFloat(next()),
                 radius: CGFloat(0.6 + next() * 1.2),
                 baseOpacity: 0.25 + next() * 0.45,
                 twinkleSpeed: 0.4 + next() * 0.9,
                 phase: next() * .pi * 2,
                 warm: next() < 0.18)
        }
    }()

    var body: some View {
        if reduceMotion {
            canvas(at: 0)
        } else {
            TimelineView(.animation(minimumInterval: 0.9)) { timeline in
                canvas(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func canvas(at time: TimeInterval) -> some View {
        Canvas { context, size in
            for star in Self.stars {
                let twinkle = reduceMotion ? 0 : 0.20 * sin(time * star.twinkleSpeed + star.phase)
                let opacity = max(0.08, star.baseOpacity + twinkle)
                let rect = CGRect(x: star.x * size.width - star.radius,
                                  y: star.y * size.height - star.radius,
                                  width: star.radius * 2, height: star.radius * 2)
                let color = star.warm
                    ? Color(hex: "#F5D9A8").opacity(opacity)
                    : Color(hex: "#EDE8DC").opacity(opacity)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}
