//
//  GardenLighting.swift
//  Dino
//
//  Time-of-day lighting for the 3D garden: one directional sun/moon light,
//  one ambient light, a moon disc visible at night, sky + fog colors.
//  Period chosen from the device clock.
//

import SceneKit
import UIKit

enum GardenLighting {

    struct Rig {
        let sunNode: SCNNode
        let ambientNode: SCNNode
        let moonNode: SCNNode
    }

    enum Period {
        case morning   // 5am-10am  golden
        case midday    // 10am-5pm  bright
        case evening   // 5pm-8pm   amber
        case night     // 8pm-5am   deep blue + moon

        static func current(hour: Int) -> Period {
            switch hour {
            case 5..<10:  return .morning
            case 10..<17: return .midday
            case 17..<20: return .evening
            default:      return .night
            }
        }
    }

    // MARK: - Rig construction (once per scene)

    static func makeRig() -> Rig {
        let sun = SCNLight()
        sun.type = .directional
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 512, height: 512)   // small map for perf
        sun.shadowRadius = 6
        sun.shadowColor = UIColor(white: 0, alpha: 0.25)
        sun.orthographicScale = 12
        let sunNode = SCNNode()
        sunNode.light = sun

        let ambient = SCNLight()
        ambient.type = .ambient
        let ambientNode = SCNNode()
        ambientNode.light = ambient

        let moonGeo = SCNSphere(radius: 0.9)
        moonGeo.segmentCount = 10
        moonGeo.firstMaterial = GardenMaterials.glow(
            GardenPalette.moon,
            emission: GardenPalette.moon
        )
        let moonNode = SCNNode(geometry: moonGeo)
        moonNode.position = SCNVector3(-6, 9, -14)
        moonNode.isHidden = true

        return Rig(sunNode: sunNode, ambientNode: ambientNode, moonNode: moonNode)
    }

    // MARK: - Period application

    static func apply(period: Period, rig: Rig, scene: SCNScene) {
        let sunColor: UIColor
        let sunIntensity: CGFloat
        let sunEuler: SCNVector3
        let ambientColor: UIColor
        let ambientIntensity: CGFloat
        let sky: UIColor

        switch period {
        case .morning:
            sunColor = UIColor(hexRGB: 0xFFE3B8)
            sunIntensity = 900
            sunEuler = SCNVector3(-0.6, 0.7, 0)      // low, from the east
            ambientColor = UIColor(hexRGB: 0xFFEFD8)
            ambientIntensity = 420
            sky = GardenPalette.skyMorning
        case .midday:
            sunColor = UIColor(hexRGB: 0xFFF6E8)
            sunIntensity = 1100
            sunEuler = SCNVector3(-1.15, 0.25, 0)    // high overhead
            ambientColor = UIColor(hexRGB: 0xEAF4FA)
            ambientIntensity = 500
            sky = GardenPalette.skyMidday
        case .evening:
            sunColor = UIColor(hexRGB: 0xFFC98A)
            sunIntensity = 750
            sunEuler = SCNVector3(-0.45, -0.9, 0)    // low, from the west
            ambientColor = UIColor(hexRGB: 0xF5D9B8)
            ambientIntensity = 380
            sky = GardenPalette.skyEvening
        case .night:
            sunColor = UIColor(hexRGB: 0xBCCCE8)     // moonlight
            sunIntensity = 320
            sunEuler = SCNVector3(-0.9, 0.5, 0)
            ambientColor = UIColor(hexRGB: 0x32405E)
            ambientIntensity = 260
            sky = GardenPalette.skyNight
        }

        if let sun = rig.sunNode.light {
            sun.color = sunColor
            sun.intensity = sunIntensity
        }
        rig.sunNode.eulerAngles = sunEuler

        if let amb = rig.ambientNode.light {
            amb.color = ambientColor
            amb.intensity = ambientIntensity
        }

        rig.moonNode.isHidden = (period != .night)

        scene.background.contents = sky
        scene.fogColor = sky
        scene.fogStartDistance = 9
        scene.fogEndDistance = 26
        scene.fogDensityExponent = 1.6
    }
}
