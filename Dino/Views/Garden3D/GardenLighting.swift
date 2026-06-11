//
//  GardenLighting.swift
//  Dino
//
//  Photoreal day/night for the explorable garden: seven clock-driven
//  periods with multi-stop skies, a sun whose size/color/elevation track
//  the hour, a moon with a real phase calculation (days since the
//  2000-01-06 new moon mod 29.53) and procedural craters, 90 twinkling
//  stars plus a faint Milky Way band, and period fog matched to the sky.
//

import SceneKit
import UIKit

enum GardenLighting {

    struct Rig {
        let sunNode: SCNNode          // directional key + shadows
        let ambientNode: SCNNode
        let sunDisc: SCNNode
        let sunCorona: SCNNode
        let moonGroup: SCNNode
        let starGroup: SCNNode
        let cloudGroup: SCNNode
    }

    enum Period: CaseIterable {
        case dawn            // 5–7
        case morning         // 7–10
        case midday          // 10–15
        case lateAfternoon   // 15–18
        case sunset          // 18–19 (spec 18:00–19:30, hour-granular)
        case dusk            // 19–20 (spec 19:30–20:30, hour-granular)
        case night           // 20–5

        static func current(hour: Int) -> Period {
            switch hour {
            case 5..<7:   return .dawn
            case 7..<10:  return .morning
            case 10..<15: return .midday
            case 15..<18: return .lateAfternoon
            case 18..<19: return .sunset
            case 19..<20: return .dusk
            default:      return .night
            }
        }
    }

    private struct Grade {
        let sunColor: UIColor
        let sunIntensity: CGFloat
        let sunEuler: SCNVector3
        let ambientColor: UIColor
        let ambientIntensity: CGFloat
        let fogColor: UIColor
        let fogStart: CGFloat
        let discPosition: SCNVector3
        let discScale: Float          // larger near horizon
        let discColor: UIColor
        let discVisible: Bool
        let moonVisible: Bool
        let starsOpacity: CGFloat
        let cloudsVisible: Bool
    }

    private static func grade(for period: Period) -> Grade {
        switch period {
        case .dawn:
            return Grade(
                sunColor: UIColor(hexRGB: 0xFF7B35), sunIntensity: 600,
                sunEuler: SCNVector3(-0.18, 1.35, 0),
                ambientColor: UIColor(hexRGB: 0xFFD9B0), ambientIntensity: 520,
                fogColor: UIColor(hexRGB: 0xF0C9A8), fogStart: 14,
                discPosition: SCNVector3(7, 4.8, -14), discScale: 1.4,
                discColor: UIColor(hexRGB: 0xFF7B35),
                discVisible: true, moonVisible: false, starsOpacity: 0,
                cloudsVisible: true
            )
        case .morning:
            return Grade(
                sunColor: UIColor(hexRGB: 0xFFD4A0), sunIntensity: 750,
                sunEuler: SCNVector3(-0.7, 0.9, 0),
                ambientColor: UIColor(hexRGB: 0xFFF3DE), ambientIntensity: 620,
                fogColor: UIColor(hexRGB: 0xE9E2C8), fogStart: 18,
                discPosition: SCNVector3(5, 6, -14), discScale: 1.0,
                discColor: UIColor(hexRGB: 0xFFE08A),
                discVisible: true, moonVisible: false, starsOpacity: 0,
                cloudsVisible: true
            )
        case .midday:
            return Grade(
                sunColor: UIColor(hexRGB: 0xFFF8F0), sunIntensity: 850,
                sunEuler: SCNVector3(-1.35, 0.2, 0),
                ambientColor: UIColor.white, ambientIntensity: 650,
                fogColor: UIColor(hexRGB: 0xCDE8F5), fogStart: 24,
                discPosition: SCNVector3(2, 7, -12), discScale: 0.8,
                discColor: UIColor(hexRGB: 0xFFF6D8),
                discVisible: true, moonVisible: false, starsOpacity: 0,
                cloudsVisible: true
            )
        case .lateAfternoon:
            return Grade(
                sunColor: UIColor(hexRGB: 0xFFB347), sunIntensity: 750,
                sunEuler: SCNVector3(-0.6, -0.9, 0),
                ambientColor: UIColor(hexRGB: 0xFFE6BE), ambientIntensity: 560,
                fogColor: UIColor(hexRGB: 0xF0D8A8), fogStart: 18,
                discPosition: SCNVector3(-5, 6, -14), discScale: 1.1,
                discColor: UIColor(hexRGB: 0xFFC25E),
                discVisible: true, moonVisible: false, starsOpacity: 0,
                cloudsVisible: true
            )
        case .sunset:
            return Grade(
                sunColor: UIColor(hexRGB: 0xFF4500), sunIntensity: 620,
                sunEuler: SCNVector3(-0.16, -1.35, 0),
                ambientColor: UIColor(hexRGB: 0xFFAE85), ambientIntensity: 480,
                fogColor: UIColor(hexRGB: 0xE89070), fogStart: 14,
                discPosition: SCNVector3(-7, 4.8, -14), discScale: 1.5,
                discColor: UIColor(hexRGB: 0xFF4500),
                discVisible: true, moonVisible: false, starsOpacity: 0,
                cloudsVisible: true
            )
        case .dusk:
            return Grade(
                sunColor: UIColor(hexRGB: 0x6070B0), sunIntensity: 420,
                sunEuler: SCNVector3(-0.5, 0.5, 0),
                ambientColor: UIColor(hexRGB: 0x9FA0C8), ambientIntensity: 420,
                fogColor: UIColor(hexRGB: 0x4A4670), fogStart: 14,
                discPosition: SCNVector3(-7, 4.0, -14), discScale: 1.0,
                discColor: UIColor(hexRGB: 0xFF6F40),
                discVisible: false, moonVisible: true, starsOpacity: 0.35,
                cloudsVisible: false
            )
        case .night:
            return Grade(
                sunColor: UIColor(hexRGB: 0xA8B8E8), sunIntensity: 380,   // moonlight
                sunEuler: SCNVector3(-0.9, 0.5, 0),
                ambientColor: UIColor(hexRGB: 0x6A6A9A), ambientIntensity: 360,
                fogColor: UIColor(hexRGB: 0x10142E), fogStart: 12,
                discPosition: SCNVector3(7, 4.0, -14), discScale: 1.0,
                discColor: UIColor(hexRGB: 0xFFE066),
                discVisible: false, moonVisible: true, starsOpacity: 1.0,
                cloudsVisible: false
            )
        }
    }

    // MARK: - Gradient sky background (bulletproof: no dome, no clipping —
    // scene.background always fills the whole frame behind the geometry)

    private static var backgroundCache: [Period: UIImage] = [:]

    static func background(for period: Period) -> UIImage {
        if let cached = backgroundCache[period] { return cached }
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image: UIImage

        if period == .night {
            // Natural night: darkest at zenith, faintly lighter at the
            // horizon, with a soft diagonal Milky Way smear.
            image = renderer.image { ctx in
                let cg = ctx.cgContext
                let colors = [UIColor(hexRGB: 0x050818).cgColor,   // deep space
                              UIColor(hexRGB: 0x0A0A1E).cgColor,   // navy
                              UIColor(hexRGB: 0x0D1535).cgColor]   // horizon glow
                    as CFArray
                let locations: [CGFloat] = [0.0, 0.4, 0.7]
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors, locations: locations
                ) {
                    cg.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: 0, y: 0),
                        end: CGPoint(x: 0, y: size.height),
                        options: [.drawsAfterEndLocation]
                    )
                }

                // Milky Way: subtle diagonal band, top-left → bottom-right,
                // ~15% of the image wide, fading to clear at both edges.
                cg.saveGState()
                cg.translateBy(x: size.width / 2, y: size.height / 2)
                cg.rotate(by: -.pi / 4)
                let bandHalf: CGFloat = 38   // ≈15% of 512
                cg.clip(to: CGRect(x: -420, y: -bandHalf, width: 840, height: bandHalf * 2))
                let bandColor = UIColor(hexRGB: 0x1A2040).withAlphaComponent(0.3)
                let bandColors = [UIColor.clear.cgColor,
                                  bandColor.cgColor,
                                  UIColor.clear.cgColor] as CFArray
                if let bandGradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: bandColors, locations: [0.0, 0.5, 1.0]
                ) {
                    cg.drawLinearGradient(
                        bandGradient,
                        start: CGPoint(x: 0, y: -bandHalf),
                        end: CGPoint(x: 0, y: bandHalf),
                        options: []
                    )
                }
                cg.restoreGState()
            }
        } else {
            let stops: (top: UInt32, bottom: UInt32)
            switch period {
            case .dawn:          stops = (0x1A0A2E, 0xFF6B35)
            case .morning:       stops = (0x4A90D9, 0xFFE4A0)
            case .midday:        stops = (0x1565C0, 0xBBDEFB)
            case .lateAfternoon: stops = (0x3A7BC0, 0xFFB347)
            case .sunset:        stops = (0x7B1FA2, 0xFF6F00)
            case .dusk:          stops = (0x0D1B3E, 0x050510)
            case .night:         stops = (0x0A0A1E, 0x1A2A4A)   // unreachable
            }
            image = renderer.image { ctx in
                let colors = [UIColor(hexRGB: stops.top).cgColor,
                              UIColor(hexRGB: stops.bottom).cgColor] as CFArray
                let locations: [CGFloat] = [0.0, 1.0]
                guard let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors, locations: locations
                ) else { return }
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }
        }
        backgroundCache[period] = image
        return image
    }

    // MARK: - Moon phase

    /// 0 = new, 0.5 = full (days since the 2000-01-06 new moon, mod 29.53).
    static func moonPhase(on date: Date) -> Double {
        var components = DateComponents()
        components.year = 2000; components.month = 1; components.day = 6
        components.hour = 18
        let calendar = Calendar(identifier: .gregorian)
        guard let knownNewMoon = calendar.date(from: components) else { return 0.5 }
        let days = date.timeIntervalSince(knownNewMoon) / 86_400
        let cycle = days.truncatingRemainder(dividingBy: 29.53)
        return (cycle < 0 ? cycle + 29.53 : cycle) / 29.53
    }

    // MARK: - Rig construction

    static func makeRig(cloudGroup: SCNNode) -> Rig {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 850
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 1024, height: 1024)
        sun.shadowRadius = 5
        sun.shadowColor = UIColor(white: 0, alpha: 0.3)
        sun.shadowMode = .deferred
        sun.orthographicScale = 24
        let sunNode = SCNNode()
        sunNode.light = sun

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 650
        let ambientNode = SCNNode()
        ambientNode.light = ambient

        let (disc, corona) = makeSun()
        let moonGroup = makeMoonGroup()
        moonGroup.opacity = 0
        let starGroup = makeStarGroup()
        starGroup.opacity = 0

        return Rig(sunNode: sunNode, ambientNode: ambientNode,
                   sunDisc: disc, sunCorona: corona, moonGroup: moonGroup,
                   starGroup: starGroup, cloudGroup: cloudGroup)
    }

    private static func makeSun() -> (disc: SCNNode, corona: SCNNode) {
        let discGeo = SCNSphere(radius: 1.0)
        discGeo.segmentCount = 16
        discGeo.firstMaterial = GardenMaterials.glow(GardenPalette.sunDisc)
        let disc = SCNNode(geometry: discGeo)
        disc.castsShadow = false

        let coronaGeo = SCNSphere(radius: 1.9)
        coronaGeo.segmentCount = 14
        let m = SCNMaterial()
        m.diffuse.contents = GardenPalette.sunDisc.withAlphaComponent(0.22)
        m.emission.contents = GardenPalette.sunDisc.withAlphaComponent(0.22)
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        coronaGeo.firstMaterial = m
        let corona = SCNNode(geometry: coronaGeo)
        corona.castsShadow = false
        disc.addChildNode(corona)
        return (disc, corona)
    }

    /// Moon with phase-accurate occluder + procedural crater patches + glow.
    /// Positioned inside the camera frustum: camera at (0,5,18) looking just
    /// above the ground sees X ±15-ish, Y up to ~25, Z 0…-60.
    private static func makeMoonGroup() -> SCNNode {
        let group = SCNNode()
        group.castsShadow = false
        // Frustum math (camera (0,5,18), 12.5° down, ortho half-height 10):
        // v ≈ 0.976(y-5) + 0.216(18-z). (4, 6.5, -12) → v ≈ 7.9 with the
        // 1.8 disc topping out ≈ 9.7 — fully inside the frame, clearly in
        // the sky band. (Spec y 7 would push the disc top past the frame
        // edge; lowered 0.5 so the moon is never cut off.)
        group.position = SCNVector3(4, 6.5, -12)

        let moonGeo = SCNSphere(radius: 1.8)
        moonGeo.segmentCount = 20
        moonGeo.firstMaterial = GardenMaterials.glow(UIColor(hexRGB: 0xFFFFF0))
        let moon = SCNNode(geometry: moonGeo)
        moon.castsShadow = false
        group.addChildNode(moon)

        // Procedural craters — subtle darker patches on the face.
        var rng = GardenSeededRandom(seed: 1969)
        for _ in 0..<6 {
            let craterGeo = SCNSphere(radius: CGFloat(rng.range(0.11, 0.27)))
            craterGeo.segmentCount = 8
            craterGeo.firstMaterial = GardenMaterials.glow(
                UIColor(hexRGB: 0xD8D2BE).withAlphaComponent(0.85)
            )
            let crater = SCNNode(geometry: craterGeo)
            let a = rng.range(0, 6.28)
            let r = rng.range(0.25, 1.15)
            crater.position = SCNVector3(
                Float(cos(a) * r), Float(sin(a) * r), 1.56
            )
            crater.scale = SCNVector3(1, 1, 0.15)
            crater.castsShadow = false
            group.addChildNode(crater)
        }

        // Glow sphere — white at 20%, always bright.
        let glowGeo = SCNSphere(radius: 2.5)
        glowGeo.segmentCount = 14
        let gm = SCNMaterial()
        gm.diffuse.contents = UIColor.white.withAlphaComponent(0.2)
        gm.emission.contents = UIColor.white.withAlphaComponent(0.2)
        gm.lightingModel = .constant
        gm.blendMode = .add
        gm.writesToDepthBuffer = false
        glowGeo.firstMaterial = gm
        let glow = SCNNode(geometry: glowGeo)
        glow.castsShadow = false
        group.addChildNode(glow)

        // Phase occluder: night-sky-colored sphere offset by illumination.
        let phase = moonPhase(on: Date())
        let illumination = sin(phase * .pi)            // 0 new → 1 full
        let waxing = phase < 0.5
        let occluderGeo = SCNSphere(radius: 1.74)
        occluderGeo.segmentCount = 18
        occluderGeo.firstMaterial = GardenMaterials.unlit(UIColor(hexRGB: 0x0A0A1E))
        let occluder = SCNNode(geometry: occluderGeo)
        let offset = Float(0.19 + 3.75 * illumination)  // full → occluder fully off-disc
        occluder.position = SCNVector3(waxing ? -offset : offset, 0, 0.19)
        occluder.castsShadow = false
        group.addChildNode(occluder)

        return group
    }

    /// 60 stars, every one inside the camera frustum AND above the horizon
    /// line (ground far edge → v ≈ 5.5): X ±9, Y 6–8, Z -6…-14 puts them at
    /// v ≈ 6–10, the sky band of the frame. White constant spheres; a third
    /// twinkle.
    private static func makeStarGroup() -> SCNNode {
        let group = SCNNode()
        group.castsShadow = false
        var rng = GardenSeededRandom(seed: 88)

        let sizeMix: [CGFloat] = [0.03, 0.05, 0.08, 0.12]
        for i in 0..<60 {
            let radius = sizeMix[Int(rng.range(0, 3.99))]
            let starGeo = SCNSphere(radius: radius)
            starGeo.segmentCount = 6
            starGeo.firstMaterial = GardenMaterials.glow(UIColor(hexRGB: 0xFFFFFF))
            let star = SCNNode(geometry: starGeo)
            star.position = SCNVector3(
                Float(rng.range(-9, 9)),
                Float(rng.range(6, 8)),
                Float(rng.range(-14, -6))
            )
            star.opacity = CGFloat(rng.range(0.6, 1.0))
            star.castsShadow = false
            // 20 shimmer via SCALE (not opacity): 0.5 → 1.2 → 0.5, each with
            // its own random period and start delay — a natural sparkle.
            if i % 3 == 0 {
                let half = rng.range(0.5, 2.0)        // full cycle 1–4s
                star.scale = SCNVector3(0.5, 0.5, 0.5)
                let grow = SCNAction.scale(to: 1.2, duration: half)
                grow.timingMode = .easeInEaseOut
                let shrink = SCNAction.scale(to: 0.5, duration: half)
                shrink.timingMode = .easeInEaseOut
                star.runAction(.sequence([
                    .wait(duration: rng.range(0, 3)),
                    .repeatForever(.sequence([grow, shrink]))
                ]))
            }
            group.addChildNode(star)
        }

        // 5 "named" stars — larger, white with a blue cast, steady.
        for _ in 0..<5 {
            let brightGeo = SCNSphere(radius: 0.15)
            brightGeo.segmentCount = 8
            brightGeo.firstMaterial = GardenMaterials.glow(UIColor(hexRGB: 0xE8F0FF))
            let bright = SCNNode(geometry: brightGeo)
            bright.position = SCNVector3(
                Float(rng.range(-8, 8)),
                Float(rng.range(6.3, 7.8)),
                Float(rng.range(-13, -7))
            )
            bright.castsShadow = false
            group.addChildNode(bright)
        }
        return group
    }

    // MARK: - Period application

    static func apply(period: Period, rig: Rig, scene: SCNScene, animated: Bool) {
        let g = grade(for: period)

        let work = {
            // Bulletproof sky: a screen-space gradient image always fills
            // the frame behind the geometry — no dome, no clipping.
            scene.background.contents = background(for: period)
            rig.sunNode.light?.color = g.sunColor
            rig.sunNode.light?.intensity = g.sunIntensity
            rig.sunNode.eulerAngles = g.sunEuler
            rig.ambientNode.light?.color = g.ambientColor
            rig.ambientNode.light?.intensity = g.ambientIntensity
            rig.sunDisc.position = g.discPosition
            rig.sunDisc.scale = SCNVector3(g.discScale, g.discScale, g.discScale)
            if let m = rig.sunDisc.geometry?.firstMaterial {
                m.diffuse.contents = g.discColor
                m.emission.contents = g.discColor
            }
            rig.sunDisc.opacity = g.discVisible ? 1 : 0
            rig.moonGroup.opacity = g.moonVisible ? 1 : 0
            rig.starGroup.opacity = g.starsOpacity
            rig.cloudGroup.opacity = g.cloudsVisible ? 1 : 0
            // Fog disabled entirely — it tinted the gradient background and
            // swallowed celestial bodies. (1000/1001 ≈ off.)
            scene.fogStartDistance = 1000
            scene.fogEndDistance = 1001
        }

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.5
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            work()
            SCNTransaction.commit()
        } else {
            work()
        }
    }
}
