//
//  WorldLighting.swift
//  Dino
//
//  Dramatic-but-warm lighting for the organic world: a real directional sun
//  with soft deferred shadows, a moodier ambient that shifts color per
//  region, and a low fill light opposite the sun so shadows never go muddy.
//  Sky domes crossfade per region; the overlook is always night.
//

import SceneKit
import UIKit

enum WorldRegion: CaseIterable {
    case meadow      // bright day
    case pond        // soft lavender daylight
    case grove       // amber dusk + god rays
    case overlook    // night: stars, aurora, crescent moon
    case returnDawn  // the loop home: coral → gold
}

enum WorldLighting {

    struct Rig {
        let sunNode: SCNNode
        let ambientNode: SCNNode
        let fillNode: SCNNode
        let domes: [WorldRegion: SCNNode]
        let nightGroup: SCNNode
        let sunDisc: SCNNode
    }

    private struct Grade {
        let sunColor: UIColor
        let sunIntensity: CGFloat
        let sunEuler: SCNVector3
        let ambientColor: UIColor
        let ambientIntensity: CGFloat
        let fogColor: UIColor
        let sunDiscVisible: Bool
        let nightGroupOpacity: CGFloat
    }

    private static func grade(for region: WorldRegion) -> Grade {
        switch region {
        case .meadow:
            return Grade(
                sunColor: UIColor(red: 1.0, green: 0.973, blue: 0.941, alpha: 1),   // #FFF8F0
                sunIntensity: 800,
                sunEuler: SCNVector3(-1.0, 0.45, 0),
                ambientColor: UIColor.white,
                ambientIntensity: 600,
                fogColor: WorldPalette.fogMeadow,
                sunDiscVisible: true, nightGroupOpacity: 0
            )
        case .pond:
            return Grade(
                sunColor: UIColor(red: 1.0, green: 0.973, blue: 0.941, alpha: 1),
                sunIntensity: 760,
                sunEuler: SCNVector3(-1.05, 0.2, 0),
                ambientColor: UIColor(red: 0.95, green: 0.96, blue: 1.0, alpha: 1),
                ambientIntensity: 580,
                fogColor: WorldPalette.fogPond,
                sunDiscVisible: true, nightGroupOpacity: 0
            )
        case .grove:
            return Grade(
                sunColor: UIColor(red: 1.0, green: 0.565, blue: 0.251, alpha: 1),   // #FF9040
                sunIntensity: 800,
                sunEuler: SCNVector3(-0.42, -0.85, 0),
                ambientColor: UIColor(red: 1.0, green: 0.502, blue: 0.251, alpha: 1), // #FF8040
                ambientIntensity: 500,
                fogColor: WorldPalette.fogGrove,
                sunDiscVisible: true, nightGroupOpacity: 0
            )
        case .overlook:
            return Grade(
                sunColor: UIColor(red: 0.251, green: 0.376, blue: 0.627, alpha: 1), // #4060A0
                sunIntensity: 800,
                sunEuler: SCNVector3(-0.8, 0.4, 0),
                ambientColor: UIColor(red: 0.125, green: 0.251, blue: 0.627, alpha: 1), // #2040A0
                ambientIntensity: 400,
                fogColor: WorldPalette.fogNight,
                sunDiscVisible: false, nightGroupOpacity: 1
            )
        case .returnDawn:
            return Grade(
                sunColor: UIColor(red: 1.0, green: 0.831, blue: 0.627, alpha: 1),   // #FFD4A0
                sunIntensity: 800,
                sunEuler: SCNVector3(-0.55, 0.7, 0),
                ambientColor: UIColor(red: 1.0, green: 0.878, blue: 0.627, alpha: 1), // #FFE0A0
                ambientIntensity: 500,
                fogColor: WorldPalette.fogDawn,
                sunDiscVisible: true, nightGroupOpacity: 0
            )
        }
    }

    // MARK: - Rig construction (once)

    static func makeRig() -> Rig {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 800
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 1024, height: 1024)
        sun.shadowRadius = 8                                   // soft
        sun.shadowColor = UIColor(white: 0, alpha: 0.35)
        sun.shadowMode = .deferred
        sun.orthographicScale = 22
        let sunNode = SCNNode()
        sunNode.light = sun

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 600
        let ambientNode = SCNNode()
        ambientNode.light = ambient

        // Low fill opposite the sun — keeps shadow sides readable.
        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 200
        fill.color = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1)
        fill.attenuationStartDistance = 10
        fill.attenuationEndDistance = 60
        fill.castsShadow = false
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(-8, 7, 6)

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
            fillNode: fillNode,
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

    private static func makeSunDisc() -> SCNNode {
        let group = SCNNode()
        let halo = SCNPlane(width: 5.5, height: 5.5)
        halo.firstMaterial = WorldMaterials.ray(WorldPalette.sunDisc, alpha: 0.25)
        group.addChildNode(SCNNode(geometry: halo))

        let discGeo = SCNSphere(radius: 1.1)
        discGeo.segmentCount = 14
        discGeo.firstMaterial = WorldMaterials.glow(WorldPalette.sunDisc)
        group.addChildNode(SCNNode(geometry: discGeo))

        group.position = SCNVector3(7, 13, -38)
        group.castsShadow = false
        return group
    }

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

    static func apply(region: WorldRegion, rig: Rig, scene: SCNScene, animated: Bool) {
        let g = grade(for: region)

        let work = {
            rig.sunNode.light?.color = g.sunColor
            rig.sunNode.light?.intensity = g.sunIntensity
            rig.sunNode.eulerAngles = g.sunEuler
            rig.ambientNode.light?.color = g.ambientColor
            rig.ambientNode.light?.intensity = g.ambientIntensity
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
