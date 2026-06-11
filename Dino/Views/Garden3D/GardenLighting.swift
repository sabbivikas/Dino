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
        let domes: [Period: SCNNode]
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
                discPosition: SCNVector3(16, 2.2, -30), discScale: 1.5,
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
                discPosition: SCNVector3(12, 8, -30), discScale: 1.1,
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
                discPosition: SCNVector3(4, 15, -28), discScale: 0.85,
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
                discPosition: SCNVector3(-12, 7, -30), discScale: 1.2,
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
                discPosition: SCNVector3(-16, 2.4, -30), discScale: 1.7,
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
                discPosition: SCNVector3(-16, 1.0, -30), discScale: 1.0,
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
                discPosition: SCNVector3(16, 2, -30), discScale: 1.0,
                discColor: UIColor(hexRGB: 0xFFE066),
                discVisible: false, moonVisible: true, starsOpacity: 1.0,
                cloudsVisible: false
            )
        }
    }

    /// Multi-stop sky per period.
    private static func skyStops(for period: Period) -> [(UIColor, CGFloat)] {
        switch period {
        case .dawn:
            return [(UIColor(hexRGB: 0x1A0A2E), 0.0), (UIColor(hexRGB: 0x6B2D8B), 0.45),
                    (UIColor(hexRGB: 0xFF6B35), 0.78), (UIColor(hexRGB: 0xFFE4A0), 1.0)]
        case .morning:
            return [(UIColor(hexRGB: 0x4A90D9), 0.0), (UIColor(hexRGB: 0x8FC0E8), 0.6),
                    (UIColor(hexRGB: 0xFFF2D0), 1.0)]
        case .midday:
            return [(UIColor(hexRGB: 0x1565C0), 0.0), (UIColor(hexRGB: 0x42A5F5), 0.5),
                    (UIColor(hexRGB: 0xBBDEFB), 1.0)]
        case .lateAfternoon:
            return [(UIColor(hexRGB: 0x3A7BC0), 0.0), (UIColor(hexRGB: 0x7FAED8), 0.55),
                    (UIColor(hexRGB: 0xFFD9A0), 1.0)]
        case .sunset:
            return [(UIColor(hexRGB: 0x0D47A1), 0.0), (UIColor(hexRGB: 0x7B1FA2), 0.35),
                    (UIColor(hexRGB: 0xE91E63), 0.6), (UIColor(hexRGB: 0xFF6F00), 0.82),
                    (UIColor(hexRGB: 0xFFD700), 1.0)]
        case .dusk:
            return [(UIColor(hexRGB: 0x0A0A24), 0.0), (UIColor(hexRGB: 0x1C1A4A), 0.6),
                    (UIColor(hexRGB: 0x4A3A6A), 0.88), (UIColor(hexRGB: 0x8A5A50), 1.0)]
        case .night:
            return [(UIColor(hexRGB: 0x0A0A1E), 0.0), (UIColor(hexRGB: 0x0D1B3E), 0.6),
                    (UIColor(hexRGB: 0x162040), 1.0)]
        }
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

        var domes: [Period: SCNNode] = [:]
        for period in Period.allCases {
            let dome = makeDome(stops: skyStops(for: period))
            dome.opacity = (period == .midday) ? 1 : 0
            domes[period] = dome
        }

        let (disc, corona) = makeSun()
        let moonGroup = makeMoonGroup()
        moonGroup.opacity = 0
        let starGroup = makeStarGroup()
        starGroup.opacity = 0

        return Rig(sunNode: sunNode, ambientNode: ambientNode, domes: domes,
                   sunDisc: disc, sunCorona: corona, moonGroup: moonGroup,
                   starGroup: starGroup, cloudGroup: cloudGroup)
    }

    private static func makeDome(stops: [(UIColor, CGFloat)]) -> SCNNode {
        let sphere = SCNSphere(radius: 42)
        sphere.segmentCount = 14
        let m = SCNMaterial()
        m.diffuse.contents = GardenMaterials.gradientImage(
            stops: stops.map { (color: $0.0, location: $0.1) }
        )
        m.lightingModel = .constant
        m.cullMode = .front
        m.writesToDepthBuffer = false
        sphere.firstMaterial = m
        let node = SCNNode(geometry: sphere)
        node.renderingOrder = -100
        node.castsShadow = false
        return node
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

    /// Moon with phase-accurate occluder + procedural crater patches + halo.
    private static func makeMoonGroup() -> SCNNode {
        let group = SCNNode()
        group.castsShadow = false
        group.position = SCNVector3(-13, 11, -28)

        let moonGeo = SCNSphere(radius: 1.1)
        moonGeo.segmentCount = 18
        moonGeo.firstMaterial = GardenMaterials.glow(GardenPalette.moon)
        let moon = SCNNode(geometry: moonGeo)
        moon.castsShadow = false
        group.addChildNode(moon)

        // Procedural craters — subtle darker patches on the face.
        var rng = GardenSeededRandom(seed: 1969)
        for _ in 0..<6 {
            let craterGeo = SCNSphere(radius: CGFloat(rng.range(0.08, 0.2)))
            craterGeo.segmentCount = 8
            craterGeo.firstMaterial = GardenMaterials.glow(
                UIColor(hexRGB: 0xD8D2BE).withAlphaComponent(0.85)
            )
            let crater = SCNNode(geometry: craterGeo)
            let a = rng.range(0, 6.28)
            let r = rng.range(0.15, 0.7)
            crater.position = SCNVector3(
                Float(cos(a) * r), Float(sin(a) * r), 0.95
            )
            crater.scale = SCNVector3(1, 1, 0.15)
            crater.castsShadow = false
            group.addChildNode(crater)
        }

        // Halo.
        let haloGeo = SCNSphere(radius: 1.9)
        haloGeo.segmentCount = 12
        let hm = SCNMaterial()
        hm.diffuse.contents = GardenPalette.moon.withAlphaComponent(0.12)
        hm.emission.contents = GardenPalette.moon.withAlphaComponent(0.12)
        hm.lightingModel = .constant
        hm.blendMode = .add
        hm.writesToDepthBuffer = false
        haloGeo.firstMaterial = hm
        let halo = SCNNode(geometry: haloGeo)
        halo.castsShadow = false
        group.addChildNode(halo)

        // Phase occluder: night-sky-colored sphere offset by illumination.
        let phase = moonPhase(on: Date())
        let illumination = sin(phase * .pi)            // 0 new → 1 full
        let waxing = phase < 0.5
        let occluderGeo = SCNSphere(radius: 1.06)
        occluderGeo.segmentCount = 16
        occluderGeo.firstMaterial = GardenMaterials.unlit(UIColor(hexRGB: 0x0A0A1E))
        let occluder = SCNNode(geometry: occluderGeo)
        let offset = Float(0.12 + 2.3 * illumination)  // full → occluder fully off-disc
        occluder.position = SCNVector3(waxing ? -offset : offset, 0, 0.12)
        occluder.castsShadow = false
        group.addChildNode(occluder)

        return group
    }

    /// 90 varied stars (some twinkling) + a faint Milky Way band of 120 dots.
    private static func makeStarGroup() -> SCNNode {
        let group = SCNNode()
        group.castsShadow = false
        var rng = GardenSeededRandom(seed: 88)

        let tiers: [(count: Int, radius: CGFloat, color: UIColor)] = [
            (18, 0.1, UIColor(hexRGB: 0xFFFFFF)),
            (32, 0.07, UIColor(hexRGB: 0xE8E8FF)),
            (40, 0.05, UIColor(hexRGB: 0xC8C8F0))
        ]
        for tier in tiers {
            for i in 0..<tier.count {
                let plane = SCNPlane(width: tier.radius * 2, height: tier.radius * 2)
                plane.cornerRadius = tier.radius
                plane.firstMaterial = GardenMaterials.glow(tier.color)
                let star = SCNNode(geometry: plane)
                star.position = SCNVector3(
                    Float(rng.range(-26, 26)),
                    Float(rng.range(5, 24)),
                    Float(rng.range(-36, -28))
                )
                let billboard = SCNBillboardConstraint()
                billboard.freeAxes = .all
                star.constraints = [billboard]
                star.opacity = CGFloat(rng.range(0.5, 1.0))
                star.castsShadow = false
                // Twinkle a third of them.
                if i % 3 == 0 {
                    let dim = SCNAction.fadeOpacity(to: 0.25, duration: rng.range(0.8, 1.8))
                    dim.timingMode = .easeInEaseOut
                    let bright = SCNAction.fadeOpacity(to: 1.0, duration: rng.range(0.8, 1.8))
                    bright.timingMode = .easeInEaseOut
                    star.runAction(.sequence([
                        .wait(duration: rng.range(0, 2)),
                        .repeatForever(.sequence([dim, bright]))
                    ]))
                }
                group.addChildNode(star)
            }
        }

        // Milky Way: faint diagonal band of tiny dim dots.
        for _ in 0..<120 {
            let t = rng.range(0, 1)
            let plane = SCNPlane(width: 0.05, height: 0.05)
            plane.cornerRadius = 0.025
            plane.firstMaterial = GardenMaterials.glow(UIColor(hexRGB: 0xB8B8E0))
            let dot = SCNNode(geometry: plane)
            dot.position = SCNVector3(
                Float(-24 + 48 * t + rng.range(-2.5, 2.5)),
                Float(8 + 14 * t + rng.range(-2.0, 2.0)),
                Float(rng.range(-37, -33))
            )
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .all
            dot.constraints = [billboard]
            dot.opacity = CGFloat(rng.range(0.1, 0.32))
            dot.castsShadow = false
            group.addChildNode(dot)
        }

        // Venus — one bright low star.
        let venusGeo = SCNPlane(width: 0.26, height: 0.26)
        venusGeo.cornerRadius = 0.13
        venusGeo.firstMaterial = GardenMaterials.glow(UIColor.white)
        let venus = SCNNode(geometry: venusGeo)
        venus.position = SCNVector3(-18, 4.5, -32)
        let vb = SCNBillboardConstraint()
        vb.freeAxes = .all
        venus.constraints = [vb]
        venus.castsShadow = false
        group.addChildNode(venus)

        return group
    }

    // MARK: - Period application

    static func apply(period: Period, rig: Rig, scene: SCNScene, animated: Bool) {
        let g = grade(for: period)

        let work = {
            rig.sunNode.light?.color = g.sunColor
            rig.sunNode.light?.intensity = g.sunIntensity
            rig.sunNode.eulerAngles = g.sunEuler
            rig.ambientNode.light?.color = g.ambientColor
            rig.ambientNode.light?.intensity = g.ambientIntensity
            for (domePeriod, dome) in rig.domes {
                dome.opacity = (domePeriod == period) ? 1 : 0
            }
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
            scene.fogColor = g.fogColor
            scene.fogStartDistance = g.fogStart
            scene.fogEndDistance = 52
            scene.fogDensityExponent = 1.5
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
