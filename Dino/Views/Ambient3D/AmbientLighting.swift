//
//  AmbientLighting.swift
//  Dino
//
//  Day/night lighting for the ambient waterfall world. The illustrated
//  background image carries the scenery; these lights grade the 3D layer
//  (waterfall, lily pad, star guide) to sit naturally inside it.
//

import SceneKit
import UIKit

enum AmbientLighting {

    struct Rig {
        let sunNode: SCNNode
        let ambientNode: SCNNode
    }

    static func makeRig() -> Rig {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 800
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 1024, height: 1024)
        sun.shadowRadius = 8
        sun.shadowColor = UIColor(white: 0, alpha: 0.25)
        sun.shadowMode = .deferred
        sun.orthographicScale = 12
        let sunNode = SCNNode()
        sunNode.light = sun

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 500
        let ambientNode = SCNNode()
        ambientNode.light = ambient

        return Rig(sunNode: sunNode, ambientNode: ambientNode)
    }

    /// Applies background + light grade + tree-billboard tint. 3s crossfade.
    static func apply(isNight: Bool, rig: Rig, scene: SCNScene,
                      treeMaterials: [SCNMaterial], animated: Bool) {
        let image = AmbientBackground.image(isNight: isNight)

        let work = {
            scene.background.contents = image
            if isNight {
                // Cool moonlight from the upper right.
                rig.sunNode.light?.color = UIColor(hexRGB: 0xB0C0E0)
                rig.sunNode.light?.intensity = 400
                rig.sunNode.eulerAngles = SCNVector3(-0.9, -0.6, 0)
                rig.ambientNode.light?.color = UIColor(hexRGB: 0x6080A0)
                rig.ambientNode.light?.intensity = 250
            } else {
                // Warm sun from the upper left.
                rig.sunNode.light?.color = UIColor(hexRGB: 0xFFD4A0)
                rig.sunNode.light?.intensity = 800
                rig.sunNode.eulerAngles = SCNVector3(-0.9, 0.7, 0)
                rig.ambientNode.light?.color = UIColor(red: 1, green: 0.97, blue: 0.92, alpha: 1)
                rig.ambientNode.light?.intensity = 500
            }
            // Billboard trees darken to silhouettes at night.
            for m in treeMaterials {
                m.multiply.contents = isNight
                    ? UIColor(hexRGB: 0x2A3640)
                    : UIColor.white
            }
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
}
