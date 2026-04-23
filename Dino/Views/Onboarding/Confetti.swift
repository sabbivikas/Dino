//
//  Confetti.swift
//  Dino
//
//  15 confetti pieces falling + rotating. Returns EmptyView when reduceMotion.
//

import SwiftUI

public struct Confetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    private static let colors: [Color] = [
        Color(hex: "#F5C6AA"),
        Color(hex: "#A8C5A0"),
        Color(hex: "#C4B8D4"),
        Color(hex: "#E8B4B8")
    ]

    private struct Piece {
        let x: CGFloat         // 0…1 horizontal position
        let color: Color
        let delay: Double
        let driftX: CGFloat    // lateral sway amount in points
        let phase: Double      // per-piece phase offset so rotations stagger
    }

    private static let pieces: [Piece] = {
        var rng = SeededRNG(seed: 9001)
        var out: [Piece] = []
        for i in 0..<15 {
            let x = CGFloat(rng.nextDouble())
            let color = colors[i % colors.count]
            let delay = Double(i) * 0.15
            let drift = CGFloat(rng.nextDouble() * 40 - 20)
            let phase = rng.nextDouble()
            out.append(Piece(x: x, color: color, delay: delay, driftX: drift, phase: phase))
        }
        return out
    }()

    public var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    ZStack {
                        ForEach(0..<Self.pieces.count, id: \.self) { i in
                            let piece = Self.pieces[i]
                            let period: Double = 3.2
                            let raw = ((t - piece.delay) / period).truncatingRemainder(dividingBy: 1.0)
                            let norm = raw < 0 ? raw + 1 : raw
                            // Y: -10% → 110% of viewport
                            let startY = -geo.size.height * 0.10
                            let endY = geo.size.height * 1.10
                            let y = startY + CGFloat(norm) * (endY - startY)
                            // Rotation: 0 → 720
                            let rotation = norm * 720
                            // Lateral sway
                            let swayX = piece.driftX * CGFloat(sin((norm + piece.phase) * 2 * .pi))

                            Rectangle()
                                .fill(piece.color)
                                .frame(width: 8, height: 12)
                                .rotationEffect(.degrees(rotation))
                                .position(x: piece.x * geo.size.width + swayX, y: y)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}
