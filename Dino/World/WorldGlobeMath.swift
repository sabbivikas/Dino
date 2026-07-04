//
//  WorldGlobeMath.swift
//  Dino
//
//  Pure math for the DINO WORLD globe — fibonacci sphere sampling, lat/lon ↔
//  unit-vector conversion, equirectangular UV mapping, and the day/night
//  terminator fade. No SceneKit, no UIKit — fully unit-testable.
//
//  Conventions:
//   • unit sphere, +Y = north pole
//   • longitude 0° faces +Z, positive longitudes rotate toward +X (east)
//   • equirectangular UV: u 0→1 = lon −180→+180, v 0→1 = lat +90→−90
//

import Foundation
import simd

enum WorldGlobeMath {

    /// Evenly-distributed points on the unit sphere (golden-angle spiral).
    static func fibonacciSphere(count: Int) -> [SIMD3<Float>] {
        guard count > 0 else { return [] }
        let golden = Float.pi * (3 - sqrt(5))          // golden angle ≈ 2.39996
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(count)
        for i in 0..<count {
            let y = 1 - (Float(i) + 0.5) * 2 / Float(count)   // 1 → -1
            let radius = sqrt(max(0, 1 - y * y))
            let theta = golden * Float(i)
            points.append(SIMD3(radius * sin(theta), y, radius * cos(theta)))
        }
        return points
    }

    static func unitVector(latitude: Double, longitude: Double) -> SIMD3<Float> {
        let lat = latitude * .pi / 180
        let lon = longitude * .pi / 180
        return SIMD3(Float(cos(lat) * sin(lon)),
                     Float(sin(lat)),
                     Float(cos(lat) * cos(lon)))
    }

    static func latLon(from v: SIMD3<Float>) -> (lat: Double, lon: Double) {
        let n = simd_normalize(v)
        let lat = asin(Double(max(-1, min(1, n.y)))) * 180 / .pi
        let lon = atan2(Double(n.x), Double(n.z)) * 180 / .pi
        return (lat, lon)
    }

    /// Equirectangular texture coordinates for a lat/lon (u,v in 0...1).
    static func equirectangularUV(latitude: Double, longitude: Double) -> (u: Double, v: Double) {
        let u = (longitude + 180) / 360
        let v = (90 - latitude) / 180
        return (min(max(u, 0), 1), min(max(v, 0), 1))
    }

    /// Night factor for a surface point: 0 = full day, 1 = full night, with a
    /// smooth band of width `band` across the terminator. `normal` is the
    /// point's (world-space) unit normal, `sunDirection` the unit vector TOWARD
    /// the sun.
    static func nightFade(normal: SIMD3<Float>, sunDirection: SIMD3<Float>, band: Float = 0.25) -> Float {
        let d = simd_dot(simd_normalize(normal), simd_normalize(sunDirection))
        // d = 1 noon → fade 0; d = -1 midnight → fade 1; smoothstep across ±band.
        let t = (band - d) / (2 * band)
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)   // smoothstep
    }
}

// MARK: - Mood tint + earth warming (pure → unit-testable)

enum WorldMoodTint {
    // Locked palette as linear-ish RGB (0...1): gold, sage, lavender, rose.
    static let gold = SIMD3<Float>(1.0, 0.898, 0.4)
    static let sage = SIMD3<Float>(0.482, 0.659, 0.447)
    static let lavender = SIMD3<Float>(0.769, 0.722, 0.831)
    static let rose = SIMD3<Float>(0.910, 0.533, 0.604)
    /// Peach — the neutral atmosphere when the world is quiet.
    static let neutral = SIMD3<Float>(0.961, 0.776, 0.667)

    /// Snap-to-dominant margin: if the lead mood's share beats the runner-up
    /// by at least this, the planet wears that mood alone.
    static let snapMargin: Double = 0.15

    static func color(for mood: EmotionalWeather) -> SIMD3<Float> {
        switch mood {
        case .clear: return gold
        case .partlyCloudy: return sage
        case .overwhelmed: return lavender
        case .drained: return rose
        }
    }

    /// The planet's mood tint for a day: neutral when quiet, snapped to the
    /// dominant mood when it clearly leads, otherwise a share-weighted blend.
    static func tint(clear: Int, partlyCloudy: Int, overwhelmed: Int, drained: Int) -> SIMD3<Float> {
        let counts: [(SIMD3<Float>, Int)] = [
            (gold, clear), (sage, partlyCloudy), (lavender, overwhelmed), (rose, drained),
        ]
        let total = counts.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return neutral }

        let shares = counts.map { Double($0.1) / Double(total) }.sorted(by: >)
        let lead = shares[0]
        let runnerUp = shares.count > 1 ? shares[1] : 0

        if lead - runnerUp >= snapMargin {
            // clear winner → snap
            let winner = counts.max { $0.1 < $1.1 }!.0
            return winner
        }
        // close race → proportional blend
        var blended = SIMD3<Float>(0, 0, 0)
        for (color, n) in counts where n > 0 {
            blended += color * Float(Double(n) / Double(total))
        }
        return blended
    }
}

enum WorldEarthToning {
    /// The "sepia-cream" treatment for the NASA map: desaturate ~45%, lift
    /// toward cream, warm the channels — our world, not google earth.
    /// Pure per-pixel math → unit-testable.
    static func warmed(r: Float, g: Float, b: Float) -> (r: Float, g: Float, b: Float) {
        let gray = 0.299 * r + 0.587 * g + 0.114 * b
        // desaturate
        var nr = r + (gray - r) * 0.45
        var ng = g + (gray - g) * 0.45
        var nb = b + (gray - b) * 0.45
        // lift toward cream (#FAF6EC)
        let cream = SIMD3<Float>(0.980, 0.965, 0.925)
        nr += (cream.x - nr) * 0.16
        ng += (cream.y - ng) * 0.16
        nb += (cream.z - nb) * 0.16
        // gentle warm cast
        nr = min(nr * 1.06, 1)
        ng = min(ng * 1.01, 1)
        nb = min(nb * 0.94, 1)
        return (nr, ng, nb)
    }
}

// MARK: - Land mask sampler

#if canImport(CoreGraphics)
import CoreGraphics

/// Samples the bundled equirectangular land/ocean bitmap.
/// Asset: Dino/WorldAssets/earth_land_mask.jpg — NASA Blue Marble
/// "land_ocean_ice" composite (public domain), via the Wikimedia mirror
/// https://upload.wikimedia.org/wikipedia/commons/c/cd/Land_ocean_ice_2048.jpg
/// downsampled to 1024×512. Water is blue-dominant; land (incl. ice) is not.
struct LandMask {
    private let width: Int
    private let height: Int
    private let pixels: [UInt8]   // RGBA8, row-major

    init?(image: CGImage) {
        width = image.width
        height = image.height
        guard width > 0, height > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(data: &buf, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        pixels = buf
    }

    /// Blue-dominance water test — pure and unit-testable given raw RGB.
    static func isWaterPixel(r: UInt8, g: UInt8, b: UInt8) -> Bool {
        Int(b) > Int(r) + 10 && Int(b) > Int(g) + 5
    }

    func isLand(latitude: Double, longitude: Double) -> Bool {
        let uv = WorldGlobeMath.equirectangularUV(latitude: latitude, longitude: longitude)
        let x = min(width - 1, Int(uv.u * Double(width)))
        let y = min(height - 1, Int(uv.v * Double(height)))
        let i = (y * width + x) * 4
        return !Self.isWaterPixel(r: pixels[i], g: pixels[i + 1], b: pixels[i + 2])
    }
}
#endif
