//
//  WorldToyMask.swift
//  Dino
//
//  Pure image-field math for the TOY planet: wrapped box blur (equirectangular
//  maps wrap horizontally), threshold, and tangent-space normal-map generation
//  so the chunky continents read slightly raised and squishy under the light.
//  No UIKit, no SceneKit — fully unit-testable.
//

import Foundation
import simd

enum WorldToyMask {

    /// Separable box blur over a scalar field. Wraps horizontally (the map is
    /// a globe), clamps vertically (poles). Window is normalized, so a
    /// constant field is preserved exactly.
    static func boxBlur(_ values: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        guard radius > 0, width > 0, height > 0, values.count == width * height else { return values }
        let window = Float(2 * radius + 1)
        var horizontal = [Float](repeating: 0, count: values.count)
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                var sum: Float = 0
                for d in -radius...radius {
                    let sx = ((x + d) % width + width) % width   // wrap
                    sum += values[row + sx]
                }
                horizontal[row + x] = sum / window
            }
        }
        var out = [Float](repeating: 0, count: values.count)
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                for d in -radius...radius {
                    let sy = min(max(y + d, 0), height - 1)      // clamp
                    sum += horizontal[sy * width + x]
                }
                out[y * width + x] = sum / window
            }
        }
        return out
    }

    /// Binary threshold: 1 where the field clears `cutoff`, else 0. Rounded,
    /// toylike coastlines come from blur → threshold.
    static func threshold(_ values: [Float], cutoff: Float) -> [Float] {
        values.map { $0 >= cutoff ? 1 : 0 }
    }

    /// Tangent-space normals from a height field (central differences; wraps
    /// horizontally, clamps vertically). Flat field → (0, 0, 1).
    static func normalMap(heights: [Float], width: Int, height: Int, strength: Float) -> [SIMD3<Float>] {
        guard width > 2, height > 2, heights.count == width * height else {
            return [SIMD3<Float>](repeating: SIMD3(0, 0, 1), count: heights.count)
        }
        var out = [SIMD3<Float>](repeating: SIMD3(0, 0, 1), count: heights.count)
        for y in 0..<height {
            let yUp = min(max(y - 1, 0), height - 1)
            let yDown = min(max(y + 1, 0), height - 1)
            for x in 0..<width {
                let xL = ((x - 1) % width + width) % width
                let xR = (x + 1) % width
                let dx = heights[y * width + xR] - heights[y * width + xL]
                let dy = heights[yDown * width + x] - heights[yUp * width + x]
                out[y * width + x] = simd_normalize(SIMD3(-dx * strength, -dy * strength, 1))
            }
        }
        return out
    }
}
