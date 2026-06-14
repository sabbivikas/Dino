//
//  GardenLighting.swift
//  Dino
//
//  Option 3: the sky is a programmatically illustrated CGImage — gradient
//  bands plus painted extras (sun, clouds, birds, stars, Milky Way, moon)
//  per time period — set as scene.background. Zero geometry, zero clipping;
//  it always fills the frame. One directional light + ambient grade the 3D
//  layer (the sunflower) to match.
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
        case sunset          // 18–19 (spec 18:00–19:30, hour-granular)
        case dusk            // 19–20 (spec 19:30–20:30, hour-granular)
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
                         ambientColor: UIColor(hexRGB: 0xC8A8D8), ambientIntensity: 480)
        case .morning:
            return Grade(sunColor: UIColor(hexRGB: 0xFFD4A0),
                         sunEuler: SCNVector3(-0.7, 0.8, 0),
                         ambientColor: UIColor(hexRGB: 0xFFF0D8), ambientIntensity: 560)
        case .day:
            return Grade(sunColor: UIColor(hexRGB: 0xFFF8F0),
                         sunEuler: SCNVector3(-1.2, 0.2, 0),
                         ambientColor: UIColor.white, ambientIntensity: 600)
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
            drawExtras(cg, size: size, period: period)
            drawGroundStrip(cg, size: size)
        }
        backgroundCache[period] = image
        return image
    }

    /// Vertical gradient bands per period (locations are fractions of height).
    private static func drawSkyBands(_ cg: CGContext, size: CGSize, period: Period) {
        let stops: [(UInt32, CGFloat)]
        switch period {
        case .dawn:
            stops = [(0x1A0A2E, 0.0), (0x6B2D8B, 0.4), (0xFF6B35, 0.7), (0xFFE4A0, 0.9)]
        case .morning:
            stops = [(0x4A90D9, 0.0), (0x9FC4E8, 0.5), (0xFFE4A0, 0.78), (0x7EC86A, 1.0)]
        case .day:
            stops = [(0x1565C0, 0.0), (0x42A5F5, 0.6), (0xBBDEFB, 0.82), (0x7EC86A, 1.0)]
        case .lateAfternoon:
            stops = [(0x1565C0, 0.0), (0x6FA0D0, 0.5), (0xFFB347, 0.8), (0xFF8C42, 1.0)]
        case .sunset:
            stops = [(0x0D47A1, 0.0), (0x7B1FA2, 0.3), (0xE91E63, 0.55), (0xFF6F00, 0.78), (0xFFD700, 0.9)]
        case .dusk:
            stops = [(0x0D1B3E, 0.0), (0x1A237E, 0.55), (0xFF6F00, 0.82), (0x1B2A1B, 1.0)]
        case .night:
            stops = [(0x050818, 0.0), (0x0A0A1E, 0.4), (0x0D1535, 0.7)]
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

    /// Painted extras: sun/moon, glow, stars, Milky Way. (Clouds and birds
    /// are animated SceneKit nodes now — see GardenSceneBuilder.)
    private static func drawExtras(_ cg: CGContext, size: CGSize, period: Period) {
        let w = size.width, h = size.height
        var rng = GardenSeededRandom(seed: 31)

        func circle(_ center: CGPoint, _ radius: CGFloat, _ color: UIColor) {
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                      width: radius * 2, height: radius * 2))
        }

        switch period {
        case .dawn:
            circle(CGPoint(x: w * 0.75, y: h * 0.65), h * 0.06,
                   UIColor(hexRGB: 0xFF9040).withAlphaComponent(0.3))
            circle(CGPoint(x: w * 0.75, y: h * 0.65), h * 0.03, UIColor(hexRGB: 0xFF7B35))

        case .morning:
            circle(CGPoint(x: w * 0.72, y: h * 0.22), h * 0.07,
                   UIColor(hexRGB: 0xFFE8C0).withAlphaComponent(0.35))
            circle(CGPoint(x: w * 0.72, y: h * 0.22), h * 0.04, UIColor(hexRGB: 0xFFD4A0))

        case .day:
            circle(CGPoint(x: w * 0.5, y: h * 0.12), h * 0.06,
                   UIColor.white.withAlphaComponent(0.3))
            circle(CGPoint(x: w * 0.5, y: h * 0.12), h * 0.035, UIColor(hexRGB: 0xFFF8F0))
            // Subtle horizon line where sky meets implied ground.
            cg.setFillColor(UIColor(hexRGB: 0xA8D4A0).withAlphaComponent(0.6).cgColor)
            cg.fill(CGRect(x: 0, y: h * 0.8, width: w, height: 2))

        case .lateAfternoon:
            circle(CGPoint(x: w * 0.3, y: h * 0.55), h * 0.09,
                   UIColor(hexRGB: 0xFFC870).withAlphaComponent(0.3))
            circle(CGPoint(x: w * 0.3, y: h * 0.55), h * 0.05, UIColor(hexRGB: 0xFFB347))
            // Warm haze at the horizon.
            cg.setFillColor(UIColor(hexRGB: 0xFFD9A0).withAlphaComponent(0.25).cgColor)
            cg.fill(CGRect(x: 0, y: h * 0.7, width: w, height: h * 0.15))

        case .sunset:
            circle(CGPoint(x: w * 0.5, y: h * 0.72), h * 0.12,
                   UIColor(hexRGB: 0xFF6F40).withAlphaComponent(0.35))
            circle(CGPoint(x: w * 0.5, y: h * 0.72), h * 0.06, UIColor(hexRGB: 0xFF4500))
            // Slight warm overlay over everything.
            cg.setFillColor(UIColor(hexRGB: 0xFF4500).withAlphaComponent(0.06).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: w, height: h))

        case .dusk:
            for _ in 0..<8 {
                let p = CGPoint(x: CGFloat(rng.range(0.05, 0.95)) * w,
                                y: CGFloat(rng.range(0.04, 0.45)) * h)
                circle(p, CGFloat(rng.range(1.0, 1.8)), UIColor.white.withAlphaComponent(0.8))
            }
            cg.setFillColor(UIColor(hexRGB: 0xFF8C50).withAlphaComponent(0.2).cgColor)
            cg.fill(CGRect(x: 0, y: h * 0.76, width: w, height: h * 0.08))

        case .night:
            // Milky Way: soft diagonal band, top-left → bottom-right.
            cg.saveGState()
            cg.translateBy(x: w / 2, y: h / 2)
            cg.rotate(by: -.pi / 4)
            let bandHalf: CGFloat = w * 0.075
            cg.clip(to: CGRect(x: -w, y: -bandHalf, width: w * 2, height: bandHalf * 2))
            let bandColors = [UIColor.clear.cgColor,
                              UIColor(hexRGB: 0x1A2040).withAlphaComponent(0.3).cgColor,
                              UIColor.clear.cgColor] as CFArray
            if let band = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: bandColors, locations: [0, 0.5, 1]) {
                cg.drawLinearGradient(band,
                                      start: CGPoint(x: 0, y: -bandHalf),
                                      end: CGPoint(x: 0, y: bandHalf), options: [])
            }
            cg.restoreGState()

            // 60 stars in the top 60%, 20 with a soft glow.
            for i in 0..<60 {
                let p = CGPoint(x: CGFloat(rng.range(0.02, 0.98)) * w,
                                y: CGFloat(rng.range(0.02, 0.6)) * h)
                let r = CGFloat(rng.range(0.6, 1.6))
                if i % 3 == 0 {
                    circle(p, r + 2.4, UIColor.white.withAlphaComponent(0.2))
                    circle(p, r + 0.5, UIColor.white)
                } else {
                    circle(p, r, UIColor.white.withAlphaComponent(0.9))
                }
            }

            // Moon: clean white circle with a soft golden glow, upper right.
            let moonCenter = CGPoint(x: w * 0.74, y: h * 0.2)
            circle(moonCenter, w * 0.06, UIColor(hexRGB: 0xFFFACD).withAlphaComponent(0.2))
            circle(moonCenter, w * 0.04, UIColor(hexRGB: 0xFFFFF0))
        }
    }

    /// Bottom ≈20%: green horizon strip fading out — the 3D ground takes
    /// over from here.
    private static func drawGroundStrip(_ cg: CGContext, size: CGSize) {
        let colors = [UIColor(hexRGB: 0x3D7024).cgColor,
                      UIColor(hexRGB: 0x5BAD5B).cgColor,
                      UIColor(hexRGB: 0x5BAD5B).withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors, locations: [0.0, 0.45, 1.0]
        ) else { return }
        cg.saveGState()
        let strip = CGRect(x: 0, y: size.height * 0.8,
                           width: size.width, height: size.height * 0.2)
        cg.clip(to: strip)
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: strip.minY),
            end: CGPoint(x: 0, y: strip.maxY),
            options: []
        )
        cg.restoreGState()
    }
}
