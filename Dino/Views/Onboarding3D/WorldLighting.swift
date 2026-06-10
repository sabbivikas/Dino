//
//  WorldLighting.swift
//  Dino
//
//  Illustrated-style lighting: bright flat ambient (the heart of the look),
//  a gentle directional sun whose only job is the soft ground shadow, and
//  one crossfading sky dome per region grade. Geometry keeps its bright
//  palette at all times — only sky, fog, and a subtle ambient tint shift
//  between regions. The overlook is always night.
//

import SceneKit
import UIKit

enum WorldRegion: CaseIterable {
    case meadow      // bright day: sky blue → mint
    case pond        // soft lavender → pale blue
    case grove       // amber dusk → rose
    case overlook    // night: navy → purple, stars + aurora + crescent moon
    case returnDawn  // the loop home: warm coral → gold
}

enum WorldLighting {

    struct Rig {
        let sunNode: SCNNode            // directional — soft ground shadow only
        let ambientNode: SCNNode        // bright flat illustrated base light
        let domes: [WorldRegion: SCNNode]
        let nightGroup: SCNNode         // stars + crescent moon + aurora
        let sunDisc: SCNNode            // visible sun in day skies
    }

    private struct Grade {
        let ambientColor: UIColor
        let fogColor: UIColor
        let sunDiscVisible: Bool
        let nightGroupOpacity: CGFloat
    }

    private static func grade(for region: WorldRegion) -> Grade {
        switch region {
        case .meadow:
            return Grade(
                ambientColor: UIColor(red: 1.0, green: 0.99, blue: 0.95, alpha: 1),
                fogColor: WorldPalette.fogMeadow,
                sunDiscVisible: true, nightGroupOpacity: 0
            )
        case .pond:
            return Grade(
                ambientColor: UIColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 1),
                fogColor: WorldPalette.fogPond,
                sunDiscVisible: true, nightGroupOpacity: 0
            )
        case .grove:
            return Grade(
                ambientColor: UIColor(red: 1.0, green: 0.92, blue: 0.82, alpha: 1),
                fogColor: WorldPalette.fogGrove,
                sunDiscVisible: true, nightGroupOpacity: 0
            )
        case .overlook:
            return Grade(
                ambientColor: UIColor(red: 0.62, green: 0.62, blue: 0.80, alpha: 1),
                fogColor: WorldPalette.fogNight,
                sunDiscVisible: false, nightGroupOpacity: 1
            )
        case .returnDawn:
            return Grade(
                ambientColor: UIColor(red: 1.0, green: 0.94, blue: 0.84, alpha: 1),
                fogColor: WorldPalette.fogDawn,
                sunDiscVisible: true, nightGroupOpacity: 0
            )
        }
    }

    // MARK: - Rig construction (once)

    static func makeRig() -> Rig {
        // Bright flat ambient carries the illustrated look (≈0.85 of a
        // standard 1000-lumen key).
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 850
        let ambientNode = SCNNode()
        ambientNode.light = ambient

        // Gentle sun — exists for the one soft ground shadow, nothing more.
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 400
        sun.color = UIColor(red: 1.0, green: 0.97, blue: 0.9, alpha: 1)
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 512, height: 512)
        sun.shadowRadius = 3
        sun.shadowColor = UIColor(white: 0, alpha: 0.2)
        sun.orthographicScale = 18
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-1.1, 0.4, 0)

        // One sky dome per region grade, crossfaded by opacity.
        var domes: [WorldRegion: SCNNode] = [:]
        let skies: [WorldRegion: (UIColor, UIColor)] = [
            .meadow: (WorldPalette.skyMeadowTop, WorldPalette.skyMeadowBottom),
            .pond: (WorldPalette.skyPondTop, WorldPalette.skyPondBottom),
            .grove: (WorldPalette.skyGroveTop, WorldPalette.skyGroveBottom),
            .overlook: (WorldPalette.skyNightTop, WorldPalette.skyNightBottom),
            .returnDawn: (WorldPalette.skyDawnTop, WorldPalette.skyDawnBottom)
        ]
        for (region, colors) in skies {
            let dome = makeDome(top: colors.0, bottom: colors.1)
            dome.opacity = (region == .meadow) ? 1 : 0
            domes[region] = dome
        }

        let nightGroup = makeNightGroup()
        nightGroup.opacity = 0

        let sunDisc = makeSunDisc()

        return Rig(
            sunNode: sunNode,
            ambientNode: ambientNode,
            domes: domes,
            nightGroup: nightGroup,
            sunDisc: sunDisc
        )
    }

    private static func makeDome(top: UIColor, bottom: UIColor) -> SCNNode {
        let sphere = SCNSphere(radius: 46)
        sphere.segmentCount = 14
        let m = SCNMaterial()
        m.diffuse.contents = WorldMaterials.gradientImage(top: top, bottom: bottom)
        m.lightingModel = .constant
        m.cullMode = .front
        m.writesToDepthBuffer = false
        sphere.firstMaterial = m
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(0, 0, -13)
        node.renderingOrder = -100
        node.castsShadow = false
        return node
    }

    /// Bright sun disc with a soft halo — visible in all day skies.
    private static func makeSunDisc() -> SCNNode {
        let group = SCNNode()

        let halo = SCNPlane(width: 5.5, height: 5.5)
        halo.firstMaterial = WorldMaterials.ray(WorldPalette.sunDisc, alpha: 0.25)
        let haloNode = SCNNode(geometry: halo)
        group.addChildNode(haloNode)

        let discGeo = SCNSphere(radius: 1.1)
        discGeo.segmentCount = 14
        discGeo.firstMaterial = WorldMaterials.glow(WorldPalette.sunDisc)
        let disc = SCNNode(geometry: discGeo)
        group.addChildNode(disc)

        group.position = SCNVector3(7, 13, -38)
        group.castsShadow = false
        return group
    }

    /// Stars, crescent moon (two overlapping spheres — the occluder matches
    /// the night sky so it bites a crescent out of the disc), and three
    /// soft aurora bands.
    private static func makeNightGroup() -> SCNNode {
        let group = SCNNode()
        group.castsShadow = false
        var rng = WorldSeededRandom(seed: 77_2026)

        for _ in 0..<40 {
            let plane = SCNPlane(width: 0.16, height: 0.16)
            plane.firstMaterial = WorldMaterials.glow(WorldPalette.star)
            let star = SCNNode(geometry: plane)
            star.position = SCNVector3(
                Float(rng.range(-15, 15)),
                Float(rng.range(5, 21)),
                Float(rng.range(-44, -36))
            )
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .all
            star.constraints = [billboard]
            star.opacity = CGFloat(rng.range(0.45, 1.0))
            star.castsShadow = false
            group.addChildNode(star)
        }

        // Crescent moon: bright disc + night-colored occluder sphere offset
        // to imply the crescent.
        let moonGeo = SCNSphere(radius: 1.2)
        moonGeo.segmentCount = 14
        moonGeo.firstMaterial = WorldMaterials.glow(WorldPalette.moon)
        let moon = SCNNode(geometry: moonGeo)
        moon.position = SCNVector3(-5.5, 13.5, -40)
        moon.castsShadow = false
        group.addChildNode(moon)

        let biteGeo = SCNSphere(radius: 1.15)
        biteGeo.segmentCount = 14
        biteGeo.firstMaterial = WorldMaterials.unlit(WorldPalette.skyNightTop)
        let bite = SCNNode(geometry: biteGeo)
        bite.position = SCNVector3(-4.9, 14.0, -39.4)
        bite.castsShadow = false
        group.addChildNode(bite)

        let auroraColors: [UIColor] = [
            WorldPalette.auroraSage, WorldPalette.auroraLavender, WorldPalette.auroraPeach
        ]
        for (i, color) in auroraColors.enumerated() {
            let plane = SCNPlane(width: 17, height: 4.8)
            plane.firstMaterial = WorldMaterials.ray(color, alpha: 0.18)
            let band = SCNNode(geometry: plane)
            band.position = SCNVector3(
                Float(i - 1) * 3.2,
                10.0 + Float(i) * 2.3,
                -38.5 - Float(i)
            )
            band.eulerAngles.z = Float(i - 1) * 0.12
            band.castsShadow = false
            group.addChildNode(band)
        }

        return group
    }

    // MARK: - Region application

    /// Crossfade to a region grade. Geometry colors never change — only the
    /// sky dome, fog, sun/moon visibility, and a gentle ambient tint.
    static func apply(region: WorldRegion, rig: Rig, scene: SCNScene, animated: Bool) {
        let g = grade(for: region)

        let work = {
            rig.ambientNode.light?.color = g.ambientColor
            for (domeRegion, dome) in rig.domes {
                dome.opacity = (domeRegion == region) ? 1 : 0
            }
            rig.nightGroup.opacity = g.nightGroupOpacity
            rig.sunDisc.opacity = g.sunDiscVisible ? 1 : 0
            scene.fogColor = g.fogColor
            scene.fogStartDistance = 16
            scene.fogEndDistance = 58
            scene.fogDensityExponent = 1.4
        }

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = CameraJourney.transitionDuration
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            work()
            SCNTransaction.commit()
        } else {
            work()
        }
    }
}
