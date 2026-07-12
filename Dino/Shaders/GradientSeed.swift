//
//  GradientSeed.swift
//  Dino
//
//  Seed string → deterministic warm palette → mesh-style gradient grid.
//  Same seed always yields identical colors (tested), and every color is
//  bounded to dino's warm world: cream/peach, sage, or dusk navy — never
//  saturated, never neon. Gradient-fill technique informed by Inferno
//  (github.com/twostraws/Inferno, MIT) with dino's own palette math.
//

import SwiftUI

enum GradientSeed {

    /// Warm hue families: (hue range, saturation range, brightness range).
    /// cream/peach · sage · dusk navy (the only cool guest, kept dim).
    static let families: [(hue: ClosedRange<Double>, sat: ClosedRange<Double>, bri: ClosedRange<Double>)] = [
        (0.05...0.13, 0.14...0.38, 0.86...0.98),   // cream → peach
        (0.24...0.34, 0.12...0.36, 0.72...0.92),   // sage
        (0.58...0.68, 0.18...0.42, 0.28...0.46),   // dusk navy
    ]

    /// FNV-1a — stable across launches and devices (never hashValue).
    static func hash(_ seed: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        return h
    }

    struct HSB: Equatable {
        let hue: Double
        let saturation: Double
        let brightness: Double
        var color: Color { Color(hue: hue, saturation: saturation, brightness: brightness) }
    }

    /// Deterministic warm palette. Family weights lean warm: cream and sage
    /// carry the gradient; dusk appears at most once per palette.
    static func palette(_ seed: String, count: Int = 4) -> [HSB] {
        var state = hash(seed) | 1
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 33) / Double(UInt32.max)
        }
        var out: [HSB] = []
        var duskUsed = false
        for _ in 0..<max(count, 1) {
            var familyIndex = next() < 0.42 ? 0 : (next() < 0.78 ? 1 : 2)
            if familyIndex == 2 && duskUsed { familyIndex = Int(next() * 2) }   // 0 or 1
            if familyIndex == 2 { duskUsed = true }
            let f = families[familyIndex]
            out.append(HSB(
                hue: f.hue.lowerBound + next() * (f.hue.upperBound - f.hue.lowerBound),
                saturation: f.sat.lowerBound + next() * (f.sat.upperBound - f.sat.lowerBound),
                brightness: f.bri.lowerBound + next() * (f.bri.upperBound - f.bri.lowerBound)))
        }
        return out
    }

    /// 3×3 mesh grid interpolated from the palette corners — renderable as
    /// stacked soft radials today, drop-in for MeshGradient when we move to
    /// iOS 18.
    static func meshGrid(_ seed: String) -> [[HSB]] {
        let p = palette(seed, count: 4)
        func mix(_ a: HSB, _ b: HSB, _ t: Double) -> HSB {
            HSB(hue: a.hue + (b.hue - a.hue) * t,
                saturation: a.saturation + (b.saturation - a.saturation) * t,
                brightness: a.brightness + (b.brightness - a.brightness) * t)
        }
        let corners = [p[0], p[1], p[2], p[3 % p.count]]
        var grid: [[HSB]] = []
        for row in 0..<3 {
            let t = Double(row) / 2
            let left = mix(corners[0], corners[2], t)
            let right = mix(corners[1], corners[3], t)
            grid.append([left, mix(left, right, 0.5), right])
        }
        return grid
    }

    /// Stable string form for tests and debugging.
    static func fingerprint(_ seed: String) -> String {
        palette(seed).map {
            String(format: "%.4f/%.4f/%.4f", $0.hue, $0.saturation, $0.brightness)
        }.joined(separator: "|")
    }
}

/// The mesh renderer for iOS 17: soft stacked radials over the base color —
/// visually mesh-like, cheap, and honest about its era.
struct SeededMeshGradient: View {
    let seed: String
    /// roughly the rendered size — small tiles need small radials or the
    /// mesh flattens into one blended tone
    var radius: CGFloat = 220

    var body: some View {
        let grid = GradientSeed.meshGrid(seed)
        ZStack {
            grid[1][1].color
            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<3, id: \.self) { col in
                    RadialGradient(
                        gradient: Gradient(colors: [grid[row][col].color, .clear]),
                        center: UnitPoint(x: Double(col) / 2, y: Double(row) / 2),
                        startRadius: 0, endRadius: radius)
                        .opacity(0.65)
                }
            }
        }
        .compositingGroup()
        .accessibilityHidden(true)
    }
}
