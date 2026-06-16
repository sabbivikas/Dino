//
//  GardenLighting.swift
//  Dino
//
//  Option 3 background: the sky + landscape is a programmatically illustrated
//  CGImage set as scene.background — zero geometry, no clipping, always fills
//  the frame. Repainted to match the design-system Growth art
//  (profile_growth/growth-sunflower.jsx): a warm peach-gold sky brightest at
//  the horizon, a low sun with a soft glow, rolling green hills receding
//  behind a band of small distant sunflowers (smaller + hazier toward the
//  back for depth), over rich brown soil. One directional light + ambient
//  grade the 3D layer (the hero sunflower) to match.
//

import SceneKit
import UIKit

enum GardenLighting {

    struct Rig {
        let sunNode: SCNNode
        let ambientNode: SCNNode
    }

    enum Period: CaseIterable {
        case dawn            // 5–7
        case morning         // 7–10
        case day             // 10–15
        case lateAfternoon   // 15–18
        case sunset          // 18–19
        case dusk            // 19–20
        case night           // 20–5

        static func current(hour: Int) -> Period {
            switch hour {
            case 5..<7:   return .dawn
            case 7..<10:  return .morning
            case 10..<15: return .day
            case 15..<18: return .lateAfternoon
            case 18..<19: return .sunset
            case 19..<20: return .dusk
            default:      return .night
            }
        }
    }

    // MARK: - Light grading (the 3D sunflower matches the painted sky)

    private struct Grade {
        let sunColor: UIColor
        let sunEuler: SCNVector3
        let ambientColor: UIColor
        let ambientIntensity: CGFloat
    }

    private static func grade(for period: Period) -> Grade {
        switch period {
        case .dawn:
            return Grade(sunColor: UIColor(hexRGB: 0xFF9B60),
                         sunEuler: SCNVector3(-0.3, 1.1, 0),
                         ambientColor: UIColor(hexRGB: 0xF6D7B0), ambientIntensity: 480)
        case .morning:
            return Grade(sunColor: UIColor(hexRGB: 0xFFD4A0),
                         sunEuler: SCNVector3(-0.7, 0.8, 0),
                         ambientColor: UIColor(hexRGB: 0xFFF0D8), ambientIntensity: 560)
        case .day:
            return Grade(sunColor: UIColor(hexRGB: 0xFFEFC8),
                         sunEuler: SCNVector3(-1.2, 0.2, 0),
                         ambientColor: UIColor(hexRGB: 0xFFF6E8), ambientIntensity: 600)
        case .lateAfternoon:
            return Grade(sunColor: UIColor(hexRGB: 0xFFB347),
                         sunEuler: SCNVector3(-0.55, -0.85, 0),
                         ambientColor: UIColor(hexRGB: 0xFFE2B8), ambientIntensity: 540)
        case .sunset:
            return Grade(sunColor: UIColor(hexRGB: 0xFF6040),
                         sunEuler: SCNVector3(-0.25, -1.2, 0),
                         ambientColor: UIColor(hexRGB: 0xF0A088), ambientIntensity: 480)
        case .dusk:
            return Grade(sunColor: UIColor(hexRGB: 0x8088B8),
                         sunEuler: SCNVector3(-0.5, 0.6, 0),
                         ambientColor: UIColor(hexRGB: 0x9898C0), ambientIntensity: 420)
        case .night:
            return Grade(sunColor: UIColor(hexRGB: 0x8090C0),
                         sunEuler: SCNVector3(-0.8, 0.5, 0),
                         ambientColor: UIColor(hexRGB: 0x7878A8), ambientIntensity: 380)
        }
    }

    static func makeRig() -> Rig {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 800
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 1024, height: 1024)
        sun.shadowRadius = 6
        sun.shadowColor = UIColor(white: 0, alpha: 0.3)
        sun.shadowMode = .deferred
        sun.orthographicScale = 10
        let sunNode = SCNNode()
        sunNode.light = sun

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 500
        ambient.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambient

        return Rig(sunNode: sunNode, ambientNode: ambientNode)
    }

    static func apply(period: Period, rig: Rig, scene: SCNScene, animated: Bool) {
        let g = grade(for: period)
        let image = makeBackgroundImage(period: period)

        let work = {
            scene.background.contents = image
            rig.sunNode.light?.color = g.sunColor
            rig.sunNode.eulerAngles = g.sunEuler
            rig.ambientNode.light?.color = g.ambientColor
            rig.ambientNode.light?.intensity = g.ambientIntensity
        }

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 3.0
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            work()
            SCNTransaction.commit()
        } else {
            work()
        }
    }

    // MARK: - Illustrated background images

    private static var backgroundCache: [Period: UIImage] = [:]

    static func makeBackgroundImage(period: Period) -> UIImage {
        if let cached = backgroundCache[period] { return cached }
        let side: CGFloat = 512
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            drawSkyBands(cg, size: size, period: period)
            drawScene(cg, size: size, period: period)
        }
        backgroundCache[period] = image
        return image
    }

    /// Warm illustrated sky per period — peach-gold by day (brightest at the
    /// horizon), warm amber late-day, mauve at dusk, navy at night. Stops are
    /// pulled straight from the design-system Growth scene
    /// (growth-sunflower.jsx `Scene` palettes: morning #FFE6B8/#F5C88A/#F5EFE0,
    /// evening #F5A060/#E48A4A/#6B4A5A, night #142850/#27416B/#3A4F6B).
    private static func drawSkyBands(_ cg: CGContext, size: CGSize, period: Period) {
        let stops: [(UInt32, CGFloat)]
        switch period {
        case .dawn:
            stops = [(0xF2B98A, 0.0), (0xF5C88A, 0.55), (0xFBEAD0, 1.0)]
        case .morning, .day:
            stops = [(0xFFE6B8, 0.0), (0xF5C88A, 0.6), (0xF5EFE0, 1.0)]
        case .lateAfternoon:
            stops = [(0xF5C07A, 0.0), (0xF0A560, 0.55), (0xE8C9A8, 1.0)]
        case .sunset:
            stops = [(0xF5A060, 0.0), (0xE48A4A, 0.55), (0x6B4A5A, 1.0)]
        case .dusk:
            stops = [(0x9A5A6A, 0.0), (0x5A4A66, 0.5), (0x3A4F6B, 1.0)]
        case .night:
            stops = [(0x142850, 0.0), (0x27416B, 0.6), (0x3A4F6B, 1.0)]
        }

        let colors = stops.map { UIColor(hexRGB: $0.0).cgColor } as CFArray
        let locations = stops.map { $0.1 }
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors, locations: locations
        ) else { return }
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: size.height),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    // MARK: - Landscape palette per period (from growth-sunflower.jsx)

    private struct ScenePalette {
        let hillBack: UInt32, hillFront: UInt32
        let fieldGreen: UInt32, petal: UInt32, petalEdge: UInt32, center: UInt32
        let haze: UInt32          // depth fade toward the sky
        let soilTop: UInt32, soilBottom: UInt32
        let warmSun: Bool
        let isNight: Bool, isDusk: Bool
    }

    private static func scenePalette(_ period: Period) -> ScenePalette {
        switch period {
        case .dawn, .morning, .day, .lateAfternoon:
            return ScenePalette(
                hillBack: 0xA8C5A0, hillFront: 0x7BA872,
                fieldGreen: 0x93B86B, petal: 0xEFC047, petalEdge: 0xC98E22, center: 0x6A3A18,
                haze: (period == .day || period == .lateAfternoon) ? 0xBBD9E6 : 0xF3D29A,
                soilTop: 0x9A7550, soilBottom: 0x5E4220,
                warmSun: !(period == .lateAfternoon), isNight: false, isDusk: false)
        case .sunset, .dusk:
            return ScenePalette(
                hillBack: 0x7A3F5A, hillFront: 0x8A4F6A,
                fieldGreen: 0x5E6B3E, petal: 0xDC9E54, petalEdge: 0xA86A30, center: 0x6A3A18,
                haze: 0xB57A66,
                soilTop: 0x7A4E28, soilBottom: 0x5E4220,
                warmSun: false, isNight: false, isDusk: period == .dusk)
        case .night:
            return ScenePalette(
                hillBack: 0x0F1F3A, hillFront: 0x1F2F50,
                fieldGreen: 0x33493A, petal: 0xBE9A4C, petalEdge: 0x7A5E26, center: 0x4A3018,
                haze: 0x27416B,
                soilTop: 0x4A3520, soilBottom: 0x2A1F10,
                warmSun: false, isNight: true, isDusk: false)
        }
    }

    // MARK: - Landscape painter

    /// Celestial body → rolling hills → brown soil → distant sunflower field.
    private static func drawScene(_ cg: CGContext, size: CGSize, period: Period) {
        let w = size.width, h = size.height
        let pal = scenePalette(period)
        let horizon = h * 0.585    // where the 3D ground plane's far edge meets sky
        var rng = GardenSeededRandom(seed: 31)

        func circle(_ c: CGPoint, _ r: CGFloat, _ color: UIColor) {
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }

        // ── Celestial: warm low sun + glow (day) or moon + stars (night/dusk).
        if pal.isNight || pal.isDusk {
            if pal.isNight {
                // Milky Way: soft diagonal band, top-left → bottom-right.
                cg.saveGState()
                cg.translateBy(x: w / 2, y: h * 0.28)
                cg.rotate(by: -.pi / 4)
                let bandHalf: CGFloat = w * 0.07
                cg.clip(to: CGRect(x: -w, y: -bandHalf, width: w * 2, height: bandHalf * 2))
                let bandColors = [UIColor.clear.cgColor,
                                  UIColor(hexRGB: 0x4A5A82).withAlphaComponent(0.3).cgColor,
                                  UIColor.clear.cgColor] as CFArray
                if let band = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: bandColors, locations: [0, 0.5, 1]) {
                    cg.drawLinearGradient(band, start: CGPoint(x: 0, y: -bandHalf),
                                          end: CGPoint(x: 0, y: bandHalf), options: [])
                }
                cg.restoreGState()
            }
            // Stars (more at night, a few at dusk), kept above the horizon.
            let starCount = pal.isNight ? 60 : 12
            for i in 0..<starCount {
                let p = CGPoint(x: CGFloat(rng.range(0.02, 0.98)) * w,
                                y: CGFloat(rng.range(0.02, 0.5)) * h)
                let r = CGFloat(rng.range(0.6, 1.6))
                if pal.isNight && i % 3 == 0 {
                    circle(p, r + 2.2, UIColor(hexRGB: 0xF5F0D8).withAlphaComponent(0.2))
                    circle(p, r + 0.4, UIColor(hexRGB: 0xF5F0D8))
                } else {
                    circle(p, r, UIColor(hexRGB: 0xF5F0D8).withAlphaComponent(0.85))
                }
            }
            // Moon (reference #F5F0D8 disc, #BFB88E craters), upper-right.
            let moonC = CGPoint(x: w * 0.74, y: h * 0.18)
            circle(moonC, w * 0.075, UIColor(hexRGB: 0xF5F0D8).withAlphaComponent(0.18))
            circle(moonC, w * 0.046, UIColor(hexRGB: 0xF5F0D8))
            let crater = UIColor(hexRGB: 0xBFB88E).withAlphaComponent(0.35)
            circle(CGPoint(x: moonC.x + w * 0.012, y: moonC.y - w * 0.008), w * 0.008, crater)
            circle(CGPoint(x: moonC.x - w * 0.010, y: moonC.y + w * 0.010), w * 0.006, crater)
            circle(CGPoint(x: moonC.x + w * 0.006, y: moonC.y + w * 0.014), w * 0.004, crater)
        } else {
            drawSun(cg, size: size, period: period, pal: pal)
        }

        // ── Rolling hills (two receding bands) sitting on the horizon.
        drawHillBand(cg, size: size, baseY: horizon - h * 0.005, amp: h * 0.055,
                     seed: 0.0, color: UIColor(hexRGB: pal.hillBack).withAlphaComponent(0.7))
        drawHillBand(cg, size: size, baseY: horizon + h * 0.012, amp: h * 0.04,
                     seed: 0.5, color: UIColor(hexRGB: pal.hillFront).withAlphaComponent(0.85))

        // ── Rich brown soil foreground (fills below the horizon line).
        let soilColors = [UIColor(hexRGB: pal.soilTop).cgColor,
                          UIColor(hexRGB: pal.soilBottom).cgColor] as CFArray
        if let soil = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: soilColors, locations: [0, 1]) {
            cg.saveGState()
            cg.clip(to: CGRect(x: 0, y: horizon, width: w, height: h - horizon))
            cg.drawLinearGradient(soil, start: CGPoint(x: 0, y: horizon),
                                  end: CGPoint(x: 0, y: h), options: [])
            cg.restoreGState()
        }
        // Soil speckles (reference #3F2A1C @0.35).
        for _ in 0..<24 {
            let p = CGPoint(x: CGFloat(rng.range(0, 1)) * w,
                            y: horizon + CGFloat(rng.range(0.02, 1.0)) * (h - horizon))
            circle(p, 1.4, UIColor(hexRGB: 0x3F2A1C).withAlphaComponent(0.35))
        }

        // ── Distant sunflower field at the horizon: smaller + hazier toward
        //    the back, opening as a depth cue.
        drawField(cg, size: size, horizon: horizon, pal: pal, rng: &rng)
    }

    /// Cheerful low sun: soft radial glow, warm core, bright highlight.
    /// Colors from growth-sunflower.jsx (core #FFF0B8→sunFill→sunEdge, glow).
    private static func drawSun(_ cg: CGContext, size: CGSize, period: Period, pal: ScenePalette) {
        let w = size.width, h = size.height
        let pos: (x: CGFloat, y: CGFloat, glow: CGFloat)
        switch period {
        case .dawn:          pos = (0.28, 0.42, 0.13)
        case .morning:       pos = (0.70, 0.26, 0.14)
        case .day:           pos = (0.50, 0.17, 0.15)
        case .lateAfternoon: pos = (0.74, 0.40, 0.15)
        case .sunset:        pos = (0.50, 0.52, 0.20)
        default:             pos = (0.5, 0.2, 0.14)
        }
        let c = CGPoint(x: pos.x * w, y: pos.y * h)
        let glowR = pos.glow * h
        let glow: UInt32 = pal.warmSun ? 0xFFE39C : 0xFFB870
        let core: UInt32 = pal.warmSun ? 0xFFCE4A : 0xFFB258
        let edge: UInt32 = pal.warmSun ? 0xF2A92E : 0xF0902F

        func circle(_ cc: CGPoint, _ r: CGFloat, _ color: UIColor) {
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: cc.x - r, y: cc.y - r, width: r * 2, height: r * 2))
        }
        // Layered soft glow.
        circle(c, glowR, UIColor(hexRGB: glow).withAlphaComponent(0.16))
        circle(c, glowR * 0.62, UIColor(hexRGB: glow).withAlphaComponent(0.22))
        // Disc: edge ring → warm core → light center → highlight.
        let discR = glowR * 0.32
        circle(c, discR * 1.1, UIColor(hexRGB: edge))
        circle(c, discR, UIColor(hexRGB: core))
        circle(c, discR * 0.6, UIColor(hexRGB: 0xFFF0B8))
        circle(CGPoint(x: c.x - discR * 0.32, y: c.y - discR * 0.32),
               discR * 0.26, UIColor(hexRGB: 0xFFF7DA).withAlphaComponent(0.7))
    }

    /// A soft rolling hill band: a few quadratic crests, filled to the bottom.
    private static func drawHillBand(_ cg: CGContext, size: CGSize, baseY: CGFloat,
                                     amp: CGFloat, seed: CGFloat, color: UIColor) {
        let w = size.width, h = size.height
        cg.beginPath()
        cg.move(to: CGPoint(x: 0, y: baseY - amp * 0.3))
        cg.addQuadCurve(to: CGPoint(x: w * 0.38, y: baseY - amp * 0.15),
                        control: CGPoint(x: w * (0.18 + seed * 0.04), y: baseY - amp))
        cg.addQuadCurve(to: CGPoint(x: w * 0.72, y: baseY - amp * 0.2),
                        control: CGPoint(x: w * (0.55 - seed * 0.04), y: baseY - amp * 0.95))
        cg.addQuadCurve(to: CGPoint(x: w, y: baseY - amp * 0.1),
                        control: CGPoint(x: w * 0.88, y: baseY - amp * 0.8))
        cg.addLine(to: CGPoint(x: w, y: h))
        cg.addLine(to: CGPoint(x: 0, y: h))
        cg.closePath()
        cg.setFillColor(color.cgColor)
        cg.fillPath()
    }

    /// Linear color blend a→b (both 0xRRGGBB) at t (0..1), opaque.
    private static func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> UIColor {
        func comp(_ v: UInt32, _ s: UInt32) -> CGFloat { CGFloat((v >> s) & 0xFF) / 255 }
        let ar = comp(a, 16), ag = comp(a, 8), ab = comp(a, 0)
        let br = comp(b, 16), bg = comp(b, 8), bb = comp(b, 0)
        let k = max(0, min(1, t))
        return UIColor(red: ar + (br - ar) * k, green: ag + (bg - ag) * k,
                       blue: ab + (bb - ab) * k, alpha: 1)
    }

    /// A band of small distant sunflowers along the horizon. Flowers higher up
    /// (farther back) are smaller and mixed toward the sky haze for depth.
    private static func drawField(_ cg: CGContext, size: CGSize, horizon: CGFloat,
                                  pal: ScenePalette, rng: inout GardenSeededRandom) {
        let w = size.width, h = size.height
        let bandTop = horizon - h * 0.045
        let bandBottom = horizon - h * 0.004

        func circle(_ c: CGPoint, _ r: CGFloat, _ color: UIColor) {
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }

        // Soft green field strip the distant flowers stand in.
        cg.setFillColor(mix(pal.fieldGreen, pal.haze, 0.25).withAlphaComponent(0.85).cgColor)
        cg.fill(CGRect(x: 0, y: bandTop, width: w, height: bandBottom - bandTop + h * 0.02))

        // ~22 little sunflowers, depth by vertical position within the band.
        for _ in 0..<22 {
            let depth = CGFloat(rng.range(0, 1))           // 0 front → 1 back
            let cx = CGFloat(rng.range(0.02, 0.98)) * w
            let cy = bandBottom - depth * (bandBottom - bandTop)
            let s = (1.0 - 0.55 * depth) * (w * 0.012)     // smaller toward back
            let hazeT = 0.18 + 0.55 * depth                // hazier toward back
            let petalC = mix(pal.petal, pal.haze, hazeT)
            let centerC = mix(pal.center, pal.haze, hazeT * 0.7)
            let greenC = mix(pal.fieldGreen, pal.haze, hazeT)

            // tiny stem
            cg.setStrokeColor(greenC.cgColor)
            cg.setLineWidth(max(0.6, s * 0.35))
            cg.strokeLineSegments(between: [CGPoint(x: cx, y: cy),
                                            CGPoint(x: cx, y: cy + s * 2.2)])
            // 8 petals around the head
            for k in 0..<8 {
                let a = CGFloat(k) * .pi / 4
                circle(CGPoint(x: cx + cos(a) * s * 0.9, y: cy + sin(a) * s * 0.9),
                       s * 0.5, petalC)
            }
            circle(CGPoint(x: cx, y: cy), s * 0.55, centerC)
        }
    }
}
