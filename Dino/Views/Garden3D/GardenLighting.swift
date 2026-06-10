//
//  GardenLighting.swift
//  Dino
//
//  Illustrated-style time-of-day lighting: bright flat ambient (850) carries
//  the look; a gentle sun (400) exists only for the single soft ground
//  shadow. One crossfading sky dome per period, sun disc by day, crescent
//  moon + stars at night. Periods come from the device clock.
//

import SceneKit
import UIKit

enum GardenLighting {

    struct Rig {
        let sunNode: SCNNode
        let ambientNode: SCNNode
        let domes: [Period: SCNNode]
        let sunDisc: SCNNode
        let nightGroup: SCNNode      // crescent moon + stars + fireflى ambience
        let cloudGroup: SCNNode      // day clouds, faded out at night
        let birdGroup: SCNNode       // morning/day birds
    }

    enum Period: CaseIterable {
        case morning   // 5am-10am  peach → gold
        case day       // 10am-5pm  blue → mint
        case evening   // 5pm-8pm   amber → rose
        case night     // 8pm-5am   navy → purple + crescent moon

        static func current(hour: Int) -> Period {
            switch hour {
            case 5..<10:  return .morning
            case 10..<17: return .day
            case 17..<20: return .evening
            default:      return .night
            }
        }
    }

    private struct Grade {
        let ambientColor: UIColor
        let sunEuler: SCNVector3
        let fogColor: UIColor
        let sunDiscVisible: Bool
        let nightVisible: Bool
        let cloudsVisible: Bool
        let birdsVisible: Bool
    }

    private static func grade(for period: Period) -> Grade {
        switch period {
        case .morning:
            return Grade(
                ambientColor: UIColor(red: 1.0, green: 0.95, blue: 0.86, alpha: 1),
                sunEuler: SCNVector3(-0.55, 0.7, 0),
                fogColor: GardenPalette.fogMorning,
                sunDiscVisible: true, nightVisible: false,
                cloudsVisible: true, birdsVisible: true
            )
        case .day:
            return Grade(
                ambientColor: UIColor(red: 1.0, green: 0.99, blue: 0.95, alpha: 1),
                sunEuler: SCNVector3(-1.1, 0.3, 0),
                fogColor: GardenPalette.fogDay,
                sunDiscVisible: true, nightVisible: false,
                cloudsVisible: true, birdsVisible: true
            )
        case .evening:
            return Grade(
                ambientColor: UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1),
                sunEuler: SCNVector3(-0.4, -0.85, 0),
                fogColor: GardenPalette.fogEvening,
                sunDiscVisible: true, nightVisible: false,
                cloudsVisible: false, birdsVisible: false
            )
        case .night:
            return Grade(
                ambientColor: UIColor(red: 0.62, green: 0.62, blue: 0.80, alpha: 1),
                sunEuler: SCNVector3(-0.8, 0.4, 0),
                fogColor: GardenPalette.fogNight,
                sunDiscVisible: false, nightVisible: true,
                cloudsVisible: false, birdsVisible: false
            )
        }
    }

    // MARK: - Rig construction (once)

    static func makeRig(cloudGroup: SCNNode, birdGroup: SCNNode) -> Rig {
        // Bright flat ambient — the illustrated base (≈0.85 of a 1000 key).
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 850
        let ambientNode = SCNNode()
        ambientNode.light = ambient

        // Gentle sun — exists for one soft ground shadow only.
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 400
        sun.color = UIColor(red: 1.0, green: 0.97, blue: 0.9, alpha: 1)
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 512, height: 512)
        sun.shadowRadius = 3
        sun.shadowColor = UIColor(white: 0, alpha: 0.2)
        sun.orthographicScale = 12
        let sunNode = SCNNode()
        sunNode.light = sun

        var domes: [Period: SCNNode] = [:]
        let skies: [Period: (UIColor, UIColor)] = [
            .morning: (GardenPalette.skyMorningTop, GardenPalette.skyMorningBottom),
            .day: (GardenPalette.skyDayTop, GardenPalette.skyDayBottom),
            .evening: (GardenPalette.skyEveningTop, GardenPalette.skyEveningBottom),
            .night: (GardenPalette.skyNightTop, GardenPalette.skyNightBottom)
        ]
        for (period, colors) in skies {
            let dome = makeDome(top: colors.0, bottom: colors.1)
            dome.opacity = (period == .day) ? 1 : 0
            domes[period] = dome
        }

        let sunDisc = makeSunDisc()
        let nightGroup = makeNightGroup()
        nightGroup.opacity = 0

        return Rig(
            sunNode: sunNode,
            ambientNode: ambientNode,
            domes: domes,
            sunDisc: sunDisc,
            nightGroup: nightGroup,
            cloudGroup: cloudGroup,
            birdGroup: birdGroup
        )
    }

    private static func makeDome(top: UIColor, bottom: UIColor) -> SCNNode {
        let sphere = SCNSphere(radius: 34)
        sphere.segmentCount = 14
        let m = SCNMaterial()
        m.diffuse.contents = GardenMaterials.gradientImage(top: top, bottom: bottom)
        m.lightingModel = .constant
        m.cullMode = .front
        m.writesToDepthBuffer = false
        sphere.firstMaterial = m
        let node = SCNNode(geometry: sphere)
        node.renderingOrder = -100
        node.castsShadow = false
        return node
    }

    private static func makeSunDisc() -> SCNNode {
        let group = SCNNode()
        let halo = SCNPlane(width: 4.0, height: 4.0)
        halo.firstMaterial = GardenMaterials.ray(GardenPalette.sunDisc, alpha: 0.25)
        let haloNode = SCNNode(geometry: halo)
        group.addChildNode(haloNode)

        let discGeo = SCNSphere(radius: 0.8)
        discGeo.segmentCount = 14
        discGeo.firstMaterial = GardenMaterials.glow(GardenPalette.sunDisc)
        group.addChildNode(SCNNode(geometry: discGeo))

        group.position = SCNVector3(5, 9.5, -26)
        group.castsShadow = false
        return group
    }

    /// Crescent moon (bright disc + night-sky occluder) and a scatter of stars.
    private static func makeNightGroup() -> SCNNode {
        let group = SCNNode()
        group.castsShadow = false
        var rng = GardenSeededRandom(seed: 88)

        for _ in 0..<26 {
            let plane = SCNPlane(width: 0.13, height: 0.13)
            plane.firstMaterial = GardenMaterials.glow(GardenPalette.star)
            let star = SCNNode(geometry: plane)
            star.position = SCNVector3(
                Float(rng.range(-12, 12)),
                Float(rng.range(4, 14)),
                Float(rng.range(-30, -24))
            )
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .all
            star.constraints = [billboard]
            star.opacity = CGFloat(rng.range(0.45, 1.0))
            star.castsShadow = false
            group.addChildNode(star)
        }

        let moonGeo = SCNSphere(radius: 0.85)
        moonGeo.segmentCount = 14
        moonGeo.firstMaterial = GardenMaterials.glow(GardenPalette.moon)
        let moon = SCNNode(geometry: moonGeo)
        moon.position = SCNVector3(-4.5, 9.5, -26)
        moon.castsShadow = false
        group.addChildNode(moon)

        let biteGeo = SCNSphere(radius: 0.82)
        biteGeo.segmentCount = 14
        biteGeo.firstMaterial = GardenMaterials.unlit(GardenPalette.skyNightTop)
        let bite = SCNNode(geometry: biteGeo)
        bite.position = SCNVector3(-4.1, 9.9, -25.6)
        bite.castsShadow = false
        group.addChildNode(bite)

        return group
    }

    // MARK: - Period application

    static func apply(period: Period, rig: Rig, scene: SCNScene, animated: Bool) {
        let g = grade(for: period)

        let work = {
            rig.ambientNode.light?.color = g.ambientColor
            rig.sunNode.eulerAngles = g.sunEuler
            for (domePeriod, dome) in rig.domes {
                dome.opacity = (domePeriod == period) ? 1 : 0
            }
            rig.sunDisc.opacity = g.sunDiscVisible ? 1 : 0
            rig.nightGroup.opacity = g.nightVisible ? 1 : 0
            rig.cloudGroup.opacity = g.cloudsVisible ? 1 : 0
            rig.birdGroup.opacity = g.birdsVisible ? 1 : 0
            scene.fogColor = g.fogColor
            scene.fogStartDistance = 12
            scene.fogEndDistance = 40
            scene.fogDensityExponent = 1.4
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
