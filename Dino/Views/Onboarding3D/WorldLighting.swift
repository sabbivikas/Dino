//
//  WorldLighting.swift
//  Dino
//
//  Region-based lighting grades for the onboarding world. The overlook is
//  always night regardless of the device clock. Grades animate over the
//  same 2s window as the camera dolly via SCNTransaction.
//

import SceneKit
import UIKit

enum WorldRegion {
    case meadow      // warm daylight
    case pond        // soft cool daylight
    case grove       // amber dusk + god rays
    case overlook    // night: stars, aurora, moon
}

enum WorldLighting {

    struct Rig {
        let sunNode: SCNNode
        let ambientNode: SCNNode
        let dayDome: SCNNode
        let nightDome: SCNNode
        let nightGroup: SCNNode   // stars + moon + aurora, opacity-faded
    }

    private struct Grade {
        let sunColor: UIColor
        let sunIntensity: CGFloat
        let sunEuler: SCNVector3
        let ambientColor: UIColor
        let ambientIntensity: CGFloat
        let fogColor: UIColor
        let dayDomeOpacity: CGFloat
        let nightDomeOpacity: CGFloat
        let nightGroupOpacity: CGFloat
    }

    private static func grade(for region: WorldRegion) -> Grade {
        switch region {
        case .meadow:
            return Grade(
                sunColor: UIColor(red: 1.0, green: 0.95, blue: 0.86, alpha: 1),
                sunIntensity: 1000,
                sunEuler: SCNVector3(-0.95, 0.5, 0),
                ambientColor: UIColor(red: 0.96, green: 0.94, blue: 0.86, alpha: 1),
                ambientIntensity: 460,
                fogColor: WorldPalette.fogMeadow,
                dayDomeOpacity: 1.0, nightDomeOpacity: 0.0, nightGroupOpacity: 0.0
            )
        case .pond:
            return Grade(
                sunColor: UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1),
                sunIntensity: 900,
                sunEuler: SCNVector3(-1.05, 0.2, 0),
                ambientColor: UIColor(red: 0.88, green: 0.94, blue: 0.93, alpha: 1),
                ambientIntensity: 440,
                fogColor: WorldPalette.fogPond,
                dayDomeOpacity: 1.0, nightDomeOpacity: 0.0, nightGroupOpacity: 0.0
            )
        case .grove:
            return Grade(
                sunColor: UIColor(red: 1.0, green: 0.82, blue: 0.58, alpha: 1),
                sunIntensity: 760,
                sunEuler: SCNVector3(-0.45, -0.85, 0),
                ambientColor: UIColor(red: 0.94, green: 0.84, blue: 0.70, alpha: 1),
                ambientIntensity: 400,
                fogColor: WorldPalette.fogGrove,
                dayDomeOpacity: 0.72, nightDomeOpacity: 0.28, nightGroupOpacity: 0.0
            )
        case .overlook:
            return Grade(
                sunColor: UIColor(red: 0.74, green: 0.80, blue: 0.92, alpha: 1),
                sunIntensity: 340,
                sunEuler: SCNVector3(-0.8, 0.4, 0),
                ambientColor: UIColor(red: 0.22, green: 0.27, blue: 0.40, alpha: 1),
                ambientIntensity: 280,
                fogColor: WorldPalette.fogNight,
                dayDomeOpacity: 0.0, nightDomeOpacity: 1.0, nightGroupOpacity: 1.0
            )
        }
    }

    // MARK: - Rig construction (once)

    static func makeRig() -> Rig {
        let sun = SCNLight()
        sun.type = .directional
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 512, height: 512)
        sun.shadowRadius = 7
        sun.shadowColor = UIColor(white: 0, alpha: 0.22)
        sun.orthographicScale = 16
        let sunNode = SCNNode()
        sunNode.light = sun

        let ambient = SCNLight()
        ambient.type = .ambient
        let ambientNode = SCNNode()
        ambientNode.light = ambient

        let dayDome = makeDome(
            top: WorldPalette.skyDayTop,
            mid: WorldPalette.skyDayMid,
            bottom: WorldPalette.skyDayBottom
        )
        let nightDome = makeDome(
            top: WorldPalette.skyNightTop,
            mid: WorldPalette.skyNightMid,
            bottom: WorldPalette.skyNightBottom
        )
        nightDome.opacity = 0

        let nightGroup = makeNightGroup()
        nightGroup.opacity = 0

        return Rig(
            sunNode: sunNode,
            ambientNode: ambientNode,
            dayDome: dayDome,
            nightDome: nightDome,
            nightGroup: nightGroup
        )
    }

    private static func makeDome(top: UIColor, mid: UIColor, bottom: UIColor) -> SCNNode {
        let sphere = SCNSphere(radius: 46)
        sphere.segmentCount = 16
        let m = SCNMaterial()
        m.diffuse.contents = WorldMaterials.gradientImage(top: top, mid: mid, bottom: bottom)
        m.lightingModel = .constant
        m.cullMode = .front          // render the inside of the sphere
        m.writesToDepthBuffer = false
        sphere.firstMaterial = m
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(0, 0, -13)
        node.renderingOrder = -100   // draw behind everything
        return node
    }

    /// Stars (40 billboarded quads), moon, and three aurora planes behind
    /// the overlook. Faded in as one group when the region goes night.
    private static func makeNightGroup() -> SCNNode {
        let group = SCNNode()
        var rng = WorldSeededRandom(seed: 77_2026)

        for _ in 0..<40 {
            let plane = SCNPlane(width: 0.14, height: 0.14)
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
            group.addChildNode(star)
        }

        let moonGeo = SCNSphere(radius: 1.15)
        moonGeo.segmentCount = 10
        moonGeo.firstMaterial = WorldMaterials.glow(WorldPalette.moon)
        let moon = SCNNode(geometry: moonGeo)
        moon.position = SCNVector3(-5.5, 13, -40)
        group.addChildNode(moon)

        // Aurora: three soft additive bands (sage / lavender / peach).
        let auroraColors: [UIColor] = [WorldPalette.sage, WorldPalette.lavender, WorldPalette.peach]
        for (i, color) in auroraColors.enumerated() {
            let plane = SCNPlane(width: 16, height: 4.5)
            plane.firstMaterial = WorldMaterials.ray(color, alpha: 0.16)
            let band = SCNNode(geometry: plane)
            band.position = SCNVector3(
                Float(i - 1) * 3.0,
                10.0 + Float(i) * 2.2,
                -38.0 - Float(i)
            )
            band.eulerAngles.z = Float(i - 1) * 0.12
            group.addChildNode(band)
        }

        return group
    }

    // MARK: - Region application

    /// Apply a region grade. When `animated`, lights / fog / dome opacities
    /// ease over the same 2s window as the camera dolly.
    static func apply(region: WorldRegion, rig: Rig, scene: SCNScene, animated: Bool) {
        let g = grade(for: region)

        let work = {
            rig.sunNode.light?.color = g.sunColor
            rig.sunNode.light?.intensity = g.sunIntensity
            rig.sunNode.eulerAngles = g.sunEuler
            rig.ambientNode.light?.color = g.ambientColor
            rig.ambientNode.light?.intensity = g.ambientIntensity
            rig.dayDome.opacity = g.dayDomeOpacity
            rig.nightDome.opacity = g.nightDomeOpacity
            rig.nightGroup.opacity = g.nightGroupOpacity
            scene.fogColor = g.fogColor
            scene.fogStartDistance = 14
            scene.fogEndDistance = 55
            scene.fogDensityExponent = 1.5
        }

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 2.0
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            work()
            SCNTransaction.commit()
        } else {
            work()
        }
    }
}
