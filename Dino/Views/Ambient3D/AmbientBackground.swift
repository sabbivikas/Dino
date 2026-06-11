//
//  AmbientBackground.swift
//  Dino
//
//  Illustrated forest-waterfall backgrounds, generated in code — the same
//  Option 3 philosophy as the garden. One 512×512 image per mode (day /
//  night), cached. Sky on top, forest silhouette in the middle, water
//  below; sun/clouds/birds by day, moon/stars/Milky Way/fireflies by night.
//

import UIKit

enum AmbientBackground {

    private static var cache: [Bool: UIImage] = [:]

    static func image(isNight: Bool) -> UIImage {
        if let cached = cache[isNight] { return cached }
        let side: CGFloat = 512
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            if isNight {
                drawNight(cg, size: size)
            } else {
                drawDay(cg, size: size)
            }
        }
        cache[isNight] = image
        return image
    }

    // MARK: - Shared helpers

    private static func fillGradient(_ cg: CGContext, rect: CGRect,
                                     stops: [(UInt32, CGFloat, CGFloat)]) {
        // stops: (hex, alpha, location)
        let colors = stops.map {
            UIColor(hexRGB: $0.0).withAlphaComponent($0.1).cgColor
        } as CFArray
        let locations = stops.map { $0.2 }
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors, locations: locations
        ) else { return }
        cg.saveGState()
        cg.clip(to: rect)
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: rect.minY),
            end: CGPoint(x: 0, y: rect.maxY),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        cg.restoreGState()
    }

    private static func circle(_ cg: CGContext, _ center: CGPoint,
                               _ radius: CGFloat, _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                  width: radius * 2, height: radius * 2))
    }

    /// A row of overlapping tree-canopy humps across the forest band.
    private static func forestHumps(_ cg: CGContext, size: CGSize,
                                    baselineY: CGFloat, color: UIColor,
                                    seed: UInt64, count: Int,
                                    radiusRange: ClosedRange<Double>) {
        var rng = GardenSeededRandom(seed: seed)
        cg.setFillColor(color.cgColor)
        for i in 0..<count {
            let x = size.width * (CGFloat(i) + 0.5) / CGFloat(count)
                + CGFloat(rng.range(-14, 14))
            let r = CGFloat(rng.range(radiusRange.lowerBound, radiusRange.upperBound))
            cg.fillEllipse(in: CGRect(x: x - r, y: baselineY - r * 1.3,
                                      width: r * 2, height: r * 2))
        }
        // Solid base under the humps down to the water line.
        cg.fill(CGRect(x: 0, y: baselineY - 4, width: size.width,
                       height: size.height * 0.65 - baselineY + 4))
    }

    // MARK: - Day

    private static func drawDay(_ cg: CGContext, size: CGSize) {
        let w = size.width, h = size.height
        var rng = GardenSeededRandom(seed: 7)

        // Sky (top 35%).
        fillGradient(cg, rect: CGRect(x: 0, y: 0, width: w, height: h * 0.38),
                     stops: [(0x87CEEB, 1, 0), (0xB8E8FF, 1, 0.6), (0xD4F0D4, 1, 1)])

        // Sun upper-left with soft glow.
        circle(cg, CGPoint(x: w * 0.22, y: h * 0.1), h * 0.06,
               UIColor(hexRGB: 0xFFE8C0).withAlphaComponent(0.35))
        circle(cg, CGPoint(x: w * 0.22, y: h * 0.1), h * 0.03, UIColor(hexRGB: 0xFFD4A0))

        // Clouds.
        func cloud(_ c: CGPoint, _ s: CGFloat) {
            circle(cg, c, 20 * s, .white)
            circle(cg, CGPoint(x: c.x - 22 * s, y: c.y + 5 * s), 14 * s, .white)
            circle(cg, CGPoint(x: c.x + 22 * s, y: c.y + 5 * s), 15 * s, .white)
            circle(cg, CGPoint(x: c.x + 3 * s, y: c.y - 11 * s), 13 * s, .white)
        }
        cloud(CGPoint(x: w * 0.62, y: h * 0.1), 1.0)
        cloud(CGPoint(x: w * 0.82, y: h * 0.2), 0.7)

        // Birds: tiny strokes.
        cg.setStrokeColor(UIColor(hexRGB: 0x2D3142).withAlphaComponent(0.6).cgColor)
        cg.setLineWidth(1.6)
        cg.setLineCap(.round)
        for bird in [CGPoint(x: w * 0.42, y: h * 0.08), CGPoint(x: w * 0.5, y: h * 0.13)] {
            cg.move(to: CGPoint(x: bird.x - 6, y: bird.y))
            cg.addQuadCurve(to: bird, control: CGPoint(x: bird.x - 3, y: bird.y - 4))
            cg.addQuadCurve(to: CGPoint(x: bird.x + 6, y: bird.y),
                            control: CGPoint(x: bird.x + 3, y: bird.y - 4))
            cg.strokePath()
        }

        // Forest band (mid ≈30%): two silhouette layers + mist.
        forestHumps(cg, size: size, baselineY: h * 0.46,
                    color: UIColor(hexRGB: 0x2D5A2D), seed: 21, count: 7,
                    radiusRange: 26...42)
        forestHumps(cg, size: size, baselineY: h * 0.52,
                    color: UIColor(hexRGB: 0x1A3A1A), seed: 22, count: 6,
                    radiusRange: 30...50)
        // Mist over the forest.
        cg.setFillColor(UIColor(hexRGB: 0xF0F8F0).withAlphaComponent(0.4).cgColor)
        for _ in 0..<4 {
            let mx = CGFloat(rng.range(0, 1)) * w
            let my = h * CGFloat(rng.range(0.42, 0.58))
            cg.fillEllipse(in: CGRect(x: mx - 70, y: my - 12, width: 140, height: 24))
        }

        // God rays: 5 diagonal shafts from top-left.
        for i in 0..<5 {
            let alpha = CGFloat(rng.range(0.1, 0.2))
            cg.setFillColor(UIColor(hexRGB: 0xFFF8E0).withAlphaComponent(alpha).cgColor)
            cg.saveGState()
            cg.translateBy(x: w * (0.1 + 0.16 * CGFloat(i)), y: 0)
            cg.rotate(by: 0.32)
            cg.fill(CGRect(x: 0, y: -20, width: 22 + CGFloat(i) * 4, height: h * 0.8))
            cg.restoreGState()
        }

        // Butterflies near the forest edge.
        for (color, p) in [(UInt32(0xFF8C42), CGPoint(x: w * 0.3, y: h * 0.42)),
                           (0xC4A8D4, CGPoint(x: w * 0.7, y: h * 0.4)),
                           (0xFFD700, CGPoint(x: w * 0.55, y: h * 0.46))] {
            circle(cg, CGPoint(x: p.x - 2.4, y: p.y), 2.6, UIColor(hexRGB: color))
            circle(cg, CGPoint(x: p.x + 2.4, y: p.y), 2.6, UIColor(hexRGB: color))
        }

        // Water (bottom 35%).
        fillGradient(cg, rect: CGRect(x: 0, y: h * 0.65, width: w, height: h * 0.35),
                     stops: [(0x4ECDC4, 1, 0), (0x2E9B85, 1, 0.5), (0x1A6B5A, 1, 1)])
        // Sparkles.
        for _ in 0..<22 {
            let p = CGPoint(x: CGFloat(rng.range(0.03, 0.97)) * w,
                            y: h * CGFloat(rng.range(0.67, 0.95)))
            circle(cg, p, CGFloat(rng.range(0.8, 1.8)),
                   UIColor.white.withAlphaComponent(CGFloat(rng.range(0.3, 0.7))))
        }
        // Lily pad color areas.
        cg.setFillColor(UIColor(hexRGB: 0x4E8C49).withAlphaComponent(0.85).cgColor)
        for _ in 0..<4 {
            let p = CGPoint(x: CGFloat(rng.range(0.1, 0.9)) * w,
                            y: h * CGFloat(rng.range(0.72, 0.92)))
            cg.fillEllipse(in: CGRect(x: p.x - 14, y: p.y - 5, width: 28, height: 10))
        }
        // Surface mist wisps.
        cg.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
        for _ in 0..<3 {
            let p = CGPoint(x: CGFloat(rng.range(0, 1)) * w,
                            y: h * CGFloat(rng.range(0.66, 0.72)))
            cg.fillEllipse(in: CGRect(x: p.x - 60, y: p.y - 8, width: 120, height: 16))
        }
    }

    // MARK: - Night

    private static func drawNight(_ cg: CGContext, size: CGSize) {
        let w = size.width, h = size.height
        var rng = GardenSeededRandom(seed: 9)

        // Sky (top 35%).
        fillGradient(cg, rect: CGRect(x: 0, y: 0, width: w, height: h * 0.38),
                     stops: [(0x050818, 1, 0), (0x0A0A1E, 1, 0.55), (0x0D2035, 1, 1)])

        // Milky Way: soft diagonal band across the sky.
        cg.saveGState()
        cg.clip(to: CGRect(x: 0, y: 0, width: w, height: h * 0.38))
        cg.translateBy(x: w / 2, y: h * 0.17)
        cg.rotate(by: -.pi / 5)
        let bandColors = [UIColor.clear.cgColor,
                          UIColor(hexRGB: 0x1A2040).withAlphaComponent(0.25).cgColor,
                          UIColor.clear.cgColor] as CFArray
        if let band = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: bandColors, locations: [0, 0.5, 1]) {
            cg.clip(to: CGRect(x: -w, y: -34, width: w * 2, height: 68))
            cg.drawLinearGradient(band, start: CGPoint(x: 0, y: -34),
                                  end: CGPoint(x: 0, y: 34), options: [])
        }
        cg.restoreGState()

        // 50 stars in the upper sky.
        for i in 0..<50 {
            let p = CGPoint(x: CGFloat(rng.range(0.02, 0.98)) * w,
                            y: CGFloat(rng.range(0.01, 0.22)) * h)
            let r = CGFloat(rng.range(0.6, 1.7))
            if i % 5 == 0 {
                circle(cg, p, r + 2.2, UIColor.white.withAlphaComponent(0.18))
            }
            circle(cg, p, r, UIColor.white.withAlphaComponent(CGFloat(rng.range(0.55, 1.0))))
        }

        // Moon upper right: clean white circle with golden glow.
        let moonCenter = CGPoint(x: w * 0.76, y: h * 0.1)
        circle(cg, moonCenter, w * 0.06, UIColor(hexRGB: 0xFFFACD).withAlphaComponent(0.2))
        circle(cg, moonCenter, w * 0.04, UIColor(hexRGB: 0xFFFFF0))

        // Forest band: almost-black silhouettes, mystery.
        forestHumps(cg, size: size, baselineY: h * 0.47,
                    color: UIColor(hexRGB: 0x0D1F0D), seed: 31, count: 7,
                    radiusRange: 26...42)
        forestHumps(cg, size: size, baselineY: h * 0.53,
                    color: UIColor(hexRGB: 0x0A1A0A), seed: 32, count: 6,
                    radiusRange: 30...50)

        // Faint teal bioluminescence at tree bases.
        cg.setFillColor(UIColor(hexRGB: 0x1A4A3A).withAlphaComponent(0.15).cgColor)
        for _ in 0..<5 {
            let p = CGPoint(x: CGFloat(rng.range(0.05, 0.95)) * w, y: h * 0.62)
            cg.fillEllipse(in: CGRect(x: p.x - 28, y: p.y - 8, width: 56, height: 16))
        }
        // Fireflies embedded in the forest.
        for _ in 0..<7 {
            let p = CGPoint(x: CGFloat(rng.range(0.05, 0.95)) * w,
                            y: h * CGFloat(rng.range(0.48, 0.62)))
            circle(cg, p, 2.6, UIColor(hexRGB: 0xFFE066).withAlphaComponent(0.25))
            circle(cg, p, 1.1, UIColor(hexRGB: 0xFFE066).withAlphaComponent(0.85))
        }

        // Water: dark reflective pool.
        fillGradient(cg, rect: CGRect(x: 0, y: h * 0.65, width: w, height: h * 0.35),
                     stops: [(0x0E3434, 1, 0), (0x0A2A2A, 1, 0.5), (0x061C1C, 1, 1)])

        // Moon reflection: vertical white shimmer at center-right.
        cg.saveGState()
        cg.clip(to: CGRect(x: 0, y: h * 0.65, width: w, height: h * 0.35))
        for i in 0..<8 {
            let y = h * 0.67 + CGFloat(i) * h * 0.035
            let width = CGFloat(rng.range(20, 44)) - CGFloat(i)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            cg.fillEllipse(in: CGRect(x: moonCenter.x - width / 2, y: y,
                                      width: width, height: 4))
        }
        cg.restoreGState()

        // Star reflections.
        for _ in 0..<12 {
            let p = CGPoint(x: CGFloat(rng.range(0.05, 0.95)) * w,
                            y: h * CGFloat(rng.range(0.68, 0.96)))
            circle(cg, p, 0.9, UIColor.white.withAlphaComponent(0.25))
        }
        // Firefly reflections: golden spots.
        for _ in 0..<4 {
            let p = CGPoint(x: CGFloat(rng.range(0.1, 0.9)) * w,
                            y: h * CGFloat(rng.range(0.7, 0.85)))
            circle(cg, p, 1.6, UIColor(hexRGB: 0xFFE066).withAlphaComponent(0.3))
        }
        // Lily pad silhouettes.
        cg.setFillColor(UIColor(hexRGB: 0x14301F).cgColor)
        for _ in 0..<4 {
            let p = CGPoint(x: CGFloat(rng.range(0.1, 0.9)) * w,
                            y: h * CGFloat(rng.range(0.74, 0.92)))
            cg.fillEllipse(in: CGRect(x: p.x - 13, y: p.y - 4.5, width: 26, height: 9))
        }
    }
}
