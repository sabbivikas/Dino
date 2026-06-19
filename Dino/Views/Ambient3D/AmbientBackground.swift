//
//  AmbientBackground.swift
//  Dino
//
//  Illustrated forest-waterfall scene, painted in code to match the design
//  system reference (Ambient Sounds.html / waterfall-final.png): symmetric
//  dark-green forest walls arching around a center sky gap, a dark cloud, a
//  grey rock cliff with rounded boulders flanking a single waterfall, a teal
//  pool with a foam cloud at the plunge, lily pads, sandy islands and reeds.
//  Four clock periods (dawn / day / dusk / night); day = golden hour, night =
//  moonlit, both pulled straight from the reference palette. One portrait
//  768×1536 image per period, generated lazily and cached.
//

import UIKit

enum AmbientPeriod: CaseIterable {
    case dawn, day, dusk, night

    static func current(hour: Int) -> AmbientPeriod {
        switch hour {
        case 5..<8:   return .dawn
        case 8..<17:  return .day
        case 17..<20: return .dusk
        default:      return .night
        }
    }

    var isNight: Bool { self == .night }
}

enum AmbientBackground {

    // MARK: - Palette (from Ambient Sounds.html — day/night exact, dawn/dusk blended)

    private struct Palette {
        let sky1, sky2, sky3: UInt32
        let canopy1, canopy2, canopy3: UInt32
        let rock1, rock2, rock3, rockSh: UInt32
        let moss1, moss2: UInt32
        let water1, water2, water3, waterDeep: UInt32
        let lily, lily2, lilyHL: UInt32
        let flowerA, flowerC, flowerCore: UInt32
        let cattail: UInt32
        let foam: UInt32
        let fallCore: UInt32
        let isNight: Bool
        let moon: Bool
    }

    private static let dayPalette = Palette(
        sky1: 0xFDE8D0, sky2: 0xFBD79C, sky3: 0xF7C079,
        canopy1: 0x1B3322, canopy2: 0x27482B, canopy3: 0x356039,
        rock1: 0xA6A491, rock2: 0x8E8E7C, rock3: 0x6E6E5E, rockSh: 0x52524A,
        moss1: 0xA8C5A0, moss2: 0x79A86A,
        water1: 0xBFE2EF, water2: 0x9CCBDC, water3: 0x76B2C9, waterDeep: 0x5896B1,
        lily: 0x4E8C49, lily2: 0x3C6F3A, lilyHL: 0x82BD70,
        flowerA: 0xFDDCB5, flowerC: 0xF4D58A, flowerCore: 0xFFF6E2,
        cattail: 0x8A6A42, foam: 0xFFFFFF, fallCore: 0xF4FBFC,
        isNight: false, moon: false)

    private static let nightPalette = Palette(
        sky1: 0x0B1120, sky2: 0x121E37, sky3: 0x1B2C4C,
        canopy1: 0x060B0F, canopy2: 0x0A1511, canopy3: 0x102219,
        rock1: 0x525C68, rock2: 0x404A56, rock3: 0x2C343E, rockSh: 0x1E252E,
        moss1: 0x3C5A4A, moss2: 0x284036,
        water1: 0x1A3445, water2: 0x142B3A, water3: 0x0E2230, waterDeep: 0x091A24,
        lily: 0x244639, lily2: 0x1B362C, lilyHL: 0x3A5E49,
        flowerA: 0xC7B58A, flowerC: 0xB6A878, flowerCore: 0xE6EEF4,
        cattail: 0x36444C, foam: 0xCFDBE8, fallCore: 0xD2E2F0,
        isNight: true, moon: true)

    private static func palette(_ period: AmbientPeriod) -> Palette {
        switch period {
        case .day:   return dayPalette
        case .night: return nightPalette
        case .dawn:  return blended(nightPalette, dayPalette, 0.55,
                                    skyOverride: (0x33324E, 0x8A6F88, 0xE8B48E))
        case .dusk:  return blended(dayPalette, nightPalette, 0.5,
                                    skyOverride: (0x243049, 0x7A5462, 0xE0894E))
        }
    }

    /// Blend two palettes; sky stops overridden for a distinct dawn/dusk horizon.
    private static func blended(_ a: Palette, _ b: Palette, _ t: CGFloat,
                               skyOverride: (UInt32, UInt32, UInt32)) -> Palette {
        func m(_ x: UInt32, _ y: UInt32) -> UInt32 { mixHex(x, y, t) }
        return Palette(
            sky1: skyOverride.0, sky2: skyOverride.1, sky3: skyOverride.2,
            canopy1: m(a.canopy1, b.canopy1), canopy2: m(a.canopy2, b.canopy2), canopy3: m(a.canopy3, b.canopy3),
            rock1: m(a.rock1, b.rock1), rock2: m(a.rock2, b.rock2), rock3: m(a.rock3, b.rock3), rockSh: m(a.rockSh, b.rockSh),
            moss1: m(a.moss1, b.moss1), moss2: m(a.moss2, b.moss2),
            water1: m(a.water1, b.water1), water2: m(a.water2, b.water2), water3: m(a.water3, b.water3), waterDeep: m(a.waterDeep, b.waterDeep),
            lily: m(a.lily, b.lily), lily2: m(a.lily2, b.lily2), lilyHL: m(a.lilyHL, b.lilyHL),
            flowerA: m(a.flowerA, b.flowerA), flowerC: m(a.flowerC, b.flowerC), flowerCore: m(a.flowerCore, b.flowerCore),
            cattail: m(a.cattail, b.cattail), foam: m(a.foam, b.foam), fallCore: m(a.fallCore, b.fallCore),
            isNight: t > 0.5 ? a.isNight : b.isNight,
            moon: a.moon || b.moon ? (t < 0.5) == b.moon : false)
    }

    // MARK: - Cache + entry

    private static var cache: [AmbientPeriod: UIImage] = [:]

    static func image(period: AmbientPeriod) -> UIImage {
        if let cached = cache[period] { return cached }
        let size = CGSize(width: 768, height: 1536)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            draw(ctx.cgContext, size: size, pal: palette(period), period: period)
        }
        cache[period] = img
        return img
    }

    // MARK: - Composition

    private static func draw(_ cg: CGContext, size: CGSize, pal: Palette, period: AmbientPeriod) {
        let w = size.width, h = size.height
        let cx = w / 2
        let waterline = h * 0.62
        let ledgeY = h * 0.30
        var rng = GardenSeededRandom(seed: 4242)

        // 1) Sky gradient across the upper region (revealed by the center arch).
        vGradient(cg, rect: CGRect(x: 0, y: 0, width: w, height: waterline),
                  stops: [(pal.sky1, 0.0), (pal.sky2, 0.16), (pal.sky3, 0.34), (pal.sky3, 0.62)])

        // 2) Warm/cool backlight glow behind the falls gap.
        let glow = pal.isNight ? UIColor(hexRGB: 0xB0C6E8) : UIColor(hexRGB: 0xFFE7B2)
        radial(cg, center: CGPoint(x: cx, y: h * 0.22), radius: w * 0.55,
               inner: glow.withAlphaComponent(pal.isNight ? 0.34 : 0.72), outer: glow.withAlphaComponent(0))

        // 3) Moon + stars (night) in the sky gap.
        if pal.moon {
            for _ in 0..<70 {
                let p = CGPoint(x: CGFloat(rng.range(0.04, 0.96)) * w,
                                y: CGFloat(rng.range(0.02, 0.34)) * h)
                circle(cg, p, CGFloat(rng.range(0.8, 2.2)),
                       UIColor(hexRGB: 0xF4EFE0).withAlphaComponent(CGFloat(rng.range(0.4, 0.95))))
            }
            let moonC = CGPoint(x: w * 0.70, y: h * 0.13)
            radial(cg, center: moonC, radius: w * 0.18,
                   inner: UIColor(hexRGB: 0xCEDEF2).withAlphaComponent(0.45), outer: UIColor(hexRGB: 0xCEDEF2).withAlphaComponent(0))
            radial(cg, center: moonC, radius: w * 0.052,
                   inner: UIColor(hexRGB: 0xFBF6E8), outer: UIColor(hexRGB: 0xDAD1B9))
            let crater = UIColor(hexRGB: 0xC4BA9C).withAlphaComponent(0.5)
            circle(cg, CGPoint(x: moonC.x + 12, y: moonC.y - 10), 5, crater)
            circle(cg, CGPoint(x: moonC.x - 9, y: moonC.y + 12), 6, crater)
            circle(cg, CGPoint(x: moonC.x + 8, y: moonC.y + 16), 4, crater)
        }

        // 4) Pool gradient (lower region).
        vGradient(cg, rect: CGRect(x: 0, y: waterline, width: w, height: h - waterline),
                  stops: [(pal.water1, 0.0), (pal.water2, 0.4), (pal.water3, 0.76), (pal.waterDeep, 1.0)])

        // 5) Symmetric forest walls framing a center sky-gap arch.
        forestWall(cg, size: size, side: -1, pal: pal, rng: &rng)
        forestWall(cg, size: size, side: 1, pal: pal, rng: &rng)

        // 6) Dark cloud floating in the gap, center-top.
        cloudShape(cg, center: CGPoint(x: cx, y: h * 0.115), scale: 1.0,
                   color: UIColor(hexRGB: pal.canopy1).withAlphaComponent(0.92))

        // 7) Grey rock cliff: vertical walls flanking the falls column.
        let columnHalf = w * 0.075
        cg.setFillColor(UIColor(hexRGB: pal.rock3).cgColor)
        cg.fill(CGRect(x: cx - columnHalf - w * 0.16, y: ledgeY, width: w * 0.16, height: waterline - ledgeY))
        cg.fill(CGRect(x: cx + columnHalf, y: ledgeY, width: w * 0.16, height: waterline - ledgeY))
        cg.setFillColor(UIColor(hexRGB: pal.rockSh).withAlphaComponent(0.6).cgColor)
        cg.fill(CGRect(x: cx - columnHalf, y: ledgeY, width: columnHalf * 2, height: waterline - ledgeY))

        // 8) Static waterfall ribbon (the animated 3D ribbon overlays this;
        //    painted so the composition reads under reduce-motion too).
        ribbon(cg, cx: cx, top: ledgeY, bottom: waterline, halfWidth: columnHalf, pal: pal)

        // 9) Rounded boulders flanking the falls (ledge, mid, splash base).
        let boulderSpecs: [(x: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat)] = [
            (cx - 96, ledgeY - 6, 58, 34), (cx + 96, ledgeY - 6, 58, 34),
            (cx - 120, h * 0.43, 46, 30), (cx + 120, h * 0.43, 46, 30),
            (cx - 132, waterline - 22, 60, 34), (cx + 132, waterline - 22, 60, 34)
        ]
        for b in boulderSpecs {
            boulder(cg, cx: b.x, cy: b.y, rx: b.rx, ry: b.ry, pal: pal)
        }

        // 10) Foam cloud where the falls plunges into the pool.
        cloudShape(cg, center: CGPoint(x: cx, y: waterline + h * 0.012), scale: 0.62,
                   color: UIColor(hexRGB: pal.foam).withAlphaComponent(pal.isNight ? 0.8 : 0.95))

        // 11) Foreground: sandy islands with reeds, then lily pads.
        for sx: CGFloat in [w * 0.16, w * 0.84] {
            let iy = h * 0.79
            ellipseFill(cg, cx: sx, cy: iy, rx: w * 0.13, ry: h * 0.028,
                        color: mix(pal.rock2, pal.water3, 0.35))
            reedCluster(cg, cx: sx + (sx < cx ? 6 : -6), baseY: iy - 4, pal: pal, rng: &rng)
        }
        lilyPad(cg, cx: w * 0.30, cy: h * 0.80, rx: 46, ry: 18, pal: pal)
        lilyPad(cg, cx: w * 0.62, cy: h * 0.855, rx: 52, ry: 20, pal: pal)
        lilyPad(cg, cx: w * 0.50, cy: h * 0.92, rx: 40, ry: 16, pal: pal)

        // 12) Night life: fireflies glow + moon reflection in the pool.
        if pal.isNight {
            for _ in 0..<10 {
                let p = CGPoint(x: CGFloat(rng.range(0.1, 0.9)) * w,
                                y: CGFloat(rng.range(0.66, 0.9)) * h)
                circle(cg, p, 5, UIColor(hexRGB: 0xFFE066).withAlphaComponent(0.28))
                circle(cg, p, 1.8, UIColor(hexRGB: 0xFFE066).withAlphaComponent(0.9))
            }
            cg.saveGState()
            cg.clip(to: CGRect(x: 0, y: waterline, width: w, height: h - waterline))
            for i in 0..<7 {
                let y = waterline + h * 0.02 + CGFloat(i) * h * 0.02
                let bw = CGFloat(70 - i * 6)
                circle(cg, CGPoint(x: cx, y: y), 0, .clear)
                cg.setFillColor(UIColor(hexRGB: 0xCEDEF2).withAlphaComponent(0.10).cgColor)
                cg.fillEllipse(in: CGRect(x: cx - bw / 2, y: y, width: bw, height: 5))
            }
            cg.restoreGState()
        }
    }

    // MARK: - Shape helpers

    private static func forestWall(_ cg: CGContext, size: CGSize, side: CGFloat,
                                   pal: Palette, rng: inout GardenSeededRandom) {
        let w = size.width, h = size.height
        let edge: CGFloat = side < 0 ? 0 : w
        let inward: CGFloat = side < 0 ? 1 : -1
        let canopies = [pal.canopy3, pal.canopy2, pal.canopy1]
        // Big rounded mass hugging the edge, curving toward the center arch.
        cg.setFillColor(UIColor(hexRGB: pal.canopy1).cgColor)
        cg.fill(CGRect(x: side < 0 ? 0 : w * 0.62, y: 0, width: w * 0.38, height: h * 0.62))
        // Scattered round canopy blobs filling the wall + softening the arch.
        for i in 0..<26 {
            let t = CGFloat(i) / 26
            let bx = edge + inward * CGFloat(rng.range(20, Double(w) * 0.46))
            let by = t * h * 0.60 + CGFloat(rng.range(-30, 30))
            let r = CGFloat(rng.range(34, 72))
            cg.setFillColor(UIColor(hexRGB: canopies[i % 3]).cgColor)
            cg.fillEllipse(in: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2))
        }
    }

    private static func cloudShape(_ cg: CGContext, center: CGPoint, scale: CGFloat, color: UIColor) {
        cg.setFillColor(color.cgColor)
        let blobs: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 54), (-46, 10, 38), (46, 10, 40), (-20, -16, 34), (24, -14, 32), (78, 14, 26), (-78, 14, 24)
        ]
        for b in blobs {
            let r = b.2 * scale
            cg.fillEllipse(in: CGRect(x: center.x + b.0 * scale - r, y: center.y + b.1 * scale - r,
                                      width: r * 2, height: r * 2))
        }
    }

    private static func ribbon(_ cg: CGContext, cx: CGFloat, top: CGFloat, bottom: CGFloat,
                               halfWidth: CGFloat, pal: Palette) {
        let colors = [UIColor(hexRGB: pal.fallCore).withAlphaComponent(0).cgColor,
                      UIColor(hexRGB: pal.fallCore).withAlphaComponent(0.9).cgColor,
                      UIColor(hexRGB: pal.fallCore).withAlphaComponent(0.9).cgColor,
                      UIColor(hexRGB: pal.fallCore).withAlphaComponent(0).cgColor] as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors, locations: [0, 0.16, 0.84, 1]) else { return }
        cg.saveGState()
        cg.clip(to: CGRect(x: cx - halfWidth, y: top, width: halfWidth * 2, height: bottom - top))
        cg.drawLinearGradient(g, start: CGPoint(x: cx - halfWidth, y: top),
                              end: CGPoint(x: cx + halfWidth, y: top), options: [])
        cg.restoreGState()
    }

    private static func boulder(_ cg: CGContext, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, pal: Palette) {
        ellipseFill(cg, cx: cx, cy: cy, rx: rx, ry: ry, color: UIColor(hexRGB: pal.rock2))
        ellipseFill(cg, cx: cx, cy: cy + ry * 0.3, rx: rx, ry: ry * 0.7, color: UIColor(hexRGB: pal.rock3).withAlphaComponent(0.5))
        // mossy top
        ellipseFill(cg, cx: cx, cy: cy - ry * 0.4, rx: rx * 0.7, ry: ry * 0.5, color: UIColor(hexRGB: pal.moss2).withAlphaComponent(0.85))
        ellipseFill(cg, cx: cx - rx * 0.2, cy: cy - ry * 0.5, rx: rx * 0.35, ry: ry * 0.3, color: UIColor(hexRGB: pal.moss1).withAlphaComponent(0.7))
    }

    private static func lilyPad(_ cg: CGContext, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, pal: Palette) {
        ellipseFill(cg, cx: cx, cy: cy, rx: rx, ry: ry, color: UIColor(hexRGB: pal.lily))
        ellipseFill(cg, cx: cx, cy: cy + ry * 0.22, rx: rx, ry: ry, color: UIColor(hexRGB: pal.lily2).withAlphaComponent(0.4))
        ellipseFill(cg, cx: cx - rx * 0.34, cy: cy - ry * 0.25, rx: rx * 0.4, ry: ry * 0.4, color: UIColor(hexRGB: pal.lilyHL).withAlphaComponent(0.7))
        // notch (wedge cut)
        cg.setFillColor(UIColor(hexRGB: pal.water2).cgColor)
        cg.beginPath()
        cg.move(to: CGPoint(x: cx, y: cy))
        cg.addLine(to: CGPoint(x: cx + rx * 0.9, y: cy - ry * 0.5))
        cg.addLine(to: CGPoint(x: cx + rx * 0.9, y: cy + ry * 0.5))
        cg.closePath()
        cg.fillPath()
    }

    private static func reedCluster(_ cg: CGContext, cx: CGFloat, baseY: CGFloat,
                                    pal: Palette, rng: inout GardenSeededRandom) {
        for k in 0..<4 {
            let dx = CGFloat(k - 2) * 9 + CGFloat(rng.range(-3, 3))
            let len = CGFloat(rng.range(52, 86))
            let topX = cx + dx + CGFloat(rng.range(-6, 6))
            cg.setStrokeColor(UIColor(hexRGB: pal.moss2).cgColor)
            cg.setLineWidth(3)
            cg.setLineCap(.round)
            cg.beginPath()
            cg.move(to: CGPoint(x: cx + dx, y: baseY))
            cg.addQuadCurve(to: CGPoint(x: topX, y: baseY - len), control: CGPoint(x: cx + dx, y: baseY - len * 0.6))
            cg.strokePath()
            // glowing tip / cattail
            let tip = CGPoint(x: topX, y: baseY - len)
            if k % 2 == 0 {
                circle(cg, tip, 5, UIColor(hexRGB: pal.flowerCore).withAlphaComponent(pal.isNight ? 0.5 : 0.3))
                circle(cg, tip, 2.4, UIColor(hexRGB: pal.flowerA))
            } else {
                cg.setFillColor(UIColor(hexRGB: pal.cattail).cgColor)
                cg.fillEllipse(in: CGRect(x: tip.x - 2.4, y: tip.y - 7, width: 4.8, height: 14))
            }
        }
    }

    // MARK: - Primitive helpers

    private static func vGradient(_ cg: CGContext, rect: CGRect, stops: [(UInt32, CGFloat)]) {
        let colors = stops.map { UIColor(hexRGB: $0.0).cgColor } as CFArray
        let locs = stops.map { $0.1 }
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) else { return }
        cg.saveGState()
        cg.clip(to: rect)
        cg.drawLinearGradient(g, start: CGPoint(x: rect.midX, y: rect.minY),
                              end: CGPoint(x: rect.midX, y: rect.maxY),
                              options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        cg.restoreGState()
    }

    private static func radial(_ cg: CGContext, center: CGPoint, radius: CGFloat, inner: UIColor, outer: UIColor) {
        let colors = [inner.cgColor, outer.cgColor] as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        cg.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    private static func circle(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private static func ellipseFill(_ cg: CGContext, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private static func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> UIColor {
        UIColor(hexRGB: mixHex(a, b, t))
    }

    private static func mixHex(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> UInt32 {
        func comp(_ v: UInt32, _ s: UInt32) -> CGFloat { CGFloat((v >> s) & 0xFF) }
        let k = max(0, min(1, t))
        let r = UInt32(comp(a, 16) + (comp(b, 16) - comp(a, 16)) * k)
        let g = UInt32(comp(a, 8) + (comp(b, 8) - comp(a, 8)) * k)
        let bl = UInt32(comp(a, 0) + (comp(b, 0) - comp(a, 0)) * k)
        return (r << 16) | (g << 8) | bl
    }
}
