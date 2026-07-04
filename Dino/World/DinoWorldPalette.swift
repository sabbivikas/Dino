//
//  DinoWorldPalette.swift
//  Dino
//
//  Locked DINO WORLD colors (prototype-approved mapping):
//    clear = gold, partlyCloudy = sage, overwhelmed = lavender, drained = rose.
//  Peach is the halo/warmth accent — never a mood. The "find my light" firefly
//  is distinguished by behavior (pulse + label), not by a special color.
//

import SwiftUI
import UIKit

enum DinoWorldPalette {
    static let gold = UIColor(red: 1.0, green: 0.898, blue: 0.4, alpha: 1)        // #FFE066
    static let sage = UIColor(red: 0.482, green: 0.659, blue: 0.447, alpha: 1)    // #7BA872
    static let lavender = UIColor(red: 0.769, green: 0.722, blue: 0.831, alpha: 1) // #C4B8D4
    static let rose = UIColor(red: 0.910, green: 0.533, blue: 0.604, alpha: 1)    // #E8889A
    static let peach = UIColor(red: 0.961, green: 0.776, blue: 0.667, alpha: 1)   // #F5C6AA
    static let ink = UIColor(red: 0.239, green: 0.227, blue: 0.208, alpha: 1)     // #3D3A35
    static let cream = UIColor(red: 0.980, green: 0.965, blue: 0.925, alpha: 1)   // #FAF6EC
    static let card = UIColor(red: 0.996, green: 0.984, blue: 0.953, alpha: 1)    // #FEFBF3

    static func moodColor(_ mood: EmotionalWeather) -> UIColor {
        switch mood {
        case .clear: return gold
        case .partlyCloudy: return sage
        case .overwhelmed: return lavender
        case .drained: return rose
        }
    }

    static func moodSwiftUIColor(_ mood: EmotionalWeather) -> Color { Color(moodColor(mood)) }

    // MARK: - SwiftUI helpers

    /// Soft radial glow sprite used for fireflies (generated, no asset).
    static func glowImage(color: UIColor, diameter: CGFloat = 64) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { ctx in
            let colors = [color.withAlphaComponent(0.95).cgColor,
                          color.withAlphaComponent(0.35).cgColor,
                          color.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors, locations: [0, 0.35, 1]) else { return }
            let c = CGPoint(x: diameter / 2, y: diameter / 2)
            ctx.cgContext.drawRadialGradient(gradient, startCenter: c, startRadius: 0,
                                             endCenter: c, endRadius: diameter / 2, options: [])
        }
    }

    private static var fireflySpriteCache: [String: UIImage] = [:]

    /// Firefly bead for the TOY planet: a solid mood-colored core with a soft
    /// white heart, a thin darker outline for contrast on any land or ocean,
    /// and a gentle halo. Alpha-blended — additive glows wash out against the
    /// bright vinyl planet (they were designed for the old dark dotted globe).
    static func fireflySprite(color: UIColor, diameter: CGFloat = 64) -> UIImage {
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let key = String(format: "%.3f-%.3f-%.3f-%.0f", r, g, b, diameter)
        if let cached = fireflySpriteCache[key] { return cached }

        let outline = UIColor(red: r * 0.55, green: g * 0.55, blue: b * 0.55, alpha: 1)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let c = CGPoint(x: diameter / 2, y: diameter / 2)
            // halo
            let haloColors = [color.withAlphaComponent(0.55).cgColor,
                              color.withAlphaComponent(0).cgColor] as CFArray
            if let halo = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: haloColors, locations: [0.42, 1]) {
                cg.drawRadialGradient(halo, startCenter: c, startRadius: 0,
                                      endCenter: c, endRadius: diameter / 2, options: [])
            }
            // solid core
            let coreR = diameter * 0.26
            let coreRect = CGRect(x: c.x - coreR, y: c.y - coreR, width: coreR * 2, height: coreR * 2)
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: coreRect)
            // thin darker outline — keeps the bead readable on sand and sage
            cg.setStrokeColor(outline.withAlphaComponent(0.85).cgColor)
            cg.setLineWidth(diameter * 0.035)
            cg.strokeEllipse(in: coreRect)
            // white heart — the "lit from inside" read
            let heartR = diameter * 0.11
            cg.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.fillEllipse(in: CGRect(x: c.x - heartR, y: c.y - heartR,
                                      width: heartR * 2, height: heartR * 2))
        }
        fireflySpriteCache[key] = img
        return img
    }
}

extension DinoWorldPalette {
    private static var cachedToyTextures: (diffuse: UIImage, normal: UIImage)?

    // Toy planet palette — designer-vinyl flats.
    static let toyOcean = UIColor(red: 0.290, green: 0.624, blue: 0.847, alpha: 1)  // friendly saturated blue
    static let toyLandSage = UIColor(red: 0.482, green: 0.659, blue: 0.447, alpha: 1) // sage #7BA872
    static let toyLandSand = UIColor(red: 0.910, green: 0.780, blue: 0.490, alpha: 1) // warm sand/gold

    /// The TOY planet textures: the NASA land mask blurred + thresholded into
    /// chunky rounded continents (sage, with warm sand through the tropics) on
    /// one friendly blue ocean, plus a normal map from the blurred mask so the
    /// land reads slightly raised and squishy. One-time CPU pass, cached.
    static func toyPlanetTextures() -> (diffuse: UIImage, normal: UIImage)? {
        if let cached = cachedToyTextures { return cached }
        guard let url = Bundle.main.url(forResource: "earth_land_mask", withExtension: "jpg"),
              let cg = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        // 1) land field from the NASA map (pure water test)
        var land = [Float](repeating: 0, count: w * h)
        for p in 0..<(w * h) {
            let i = p * 4
            land[p] = LandMask.isWaterPixel(r: buf[i], g: buf[i + 1], b: buf[i + 2]) ? 0 : 1
        }
        // 2) blur → threshold: rounded, chunky, toylike coastlines
        let softened = WorldToyMask.boxBlur(land, width: w, height: h, radius: 6)
        let blobs = WorldToyMask.threshold(softened, cutoff: 0.42)
        // 3) puffy heights + tangent normals
        let heights = WorldToyMask.boxBlur(blobs, width: w, height: h, radius: 5)
        let normals = WorldToyMask.normalMap(heights: heights, width: w, height: h, strength: 4.5)

        // 4) paint the diffuse: sage land, sand through the tropics, blue ocean
        var ocean: (r: CGFloat, g: CGFloat, b: CGFloat) = (0, 0, 0)
        var sage = ocean, sand = ocean
        var a: CGFloat = 0
        toyOcean.getRed(&ocean.r, green: &ocean.g, blue: &ocean.b, alpha: &a)
        toyLandSage.getRed(&sage.r, green: &sage.g, blue: &sage.b, alpha: &a)
        toyLandSand.getRed(&sand.r, green: &sand.g, blue: &sand.b, alpha: &a)

        var diffuse = [UInt8](repeating: 255, count: w * h * 4)
        var normalBytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            let lat = 90.0 - (Double(y) + 0.5) / Double(h) * 180.0
            let isTropics = abs(lat) < 23.5
            for x in 0..<w {
                let p = y * w + x
                let i = p * 4
                let c: (r: CGFloat, g: CGFloat, b: CGFloat) = blobs[p] >= 0.5 ? (isTropics ? sand : sage) : ocean
                diffuse[i] = UInt8(c.r * 255)
                diffuse[i + 1] = UInt8(c.g * 255)
                diffuse[i + 2] = UInt8(c.b * 255)
                let n = normals[p]
                normalBytes[i] = UInt8((n.x * 0.5 + 0.5) * 255)
                normalBytes[i + 1] = UInt8((n.y * 0.5 + 0.5) * 255)
                normalBytes[i + 2] = UInt8((n.z * 0.5 + 0.5) * 255)
            }
        }

        func image(from bytes: [UInt8]) -> UIImage? {
            var copy = bytes
            guard let c = CGContext(data: &copy, width: w, height: h,
                                    bitsPerComponent: 8, bytesPerRow: w * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let out = c.makeImage() else { return nil }
            return UIImage(cgImage: out)
        }
        guard let d = image(from: diffuse), let n = image(from: normalBytes) else { return nil }
        cachedToyTextures = (d, n)
        return (d, n)
    }
}

extension UIColor {
    /// Linear blend helper for the ambient mood wash.
    static func blendWorld(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: 1)
    }
}

extension Color {
    /// Gentle 65/35 blend toward `tint` — used for the home tile's subtle
    /// dominant-mood coloring.
    func blendedWorldTint(_ tint: Color) -> Color {
        let a = UIColor(self)
        let b = UIColor(tint)
        var (r1, g1, b1, o1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, o2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &o1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &o2)
        let t: CGFloat = 0.35
        return Color(red: Double(r1 + (r2 - r1) * t),
                     green: Double(g1 + (g2 - g1) * t),
                     blue: Double(b1 + (b2 - b1) * t))
            .opacity(Double(max(o1, 0.9)))
    }
}
