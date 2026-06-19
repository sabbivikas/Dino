//
//  AmbientLighting.swift
//  Dino
//
//  Period background swapper for the ambient scene. The whole still scene is
//  a painted CGImage set as scene.background, so no SceneKit lights are
//  needed (the 3D ribbon/fish use constant materials). This just crossfades
//  the background image when the clock period changes.
//

import SceneKit
import UIKit

enum AmbientLighting {

    static func apply(period: AmbientPeriod, scene: SCNScene, animated: Bool) {
        let image = AmbientBackground.image(period: period)
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 4.0
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scene.background.contents = image
            SCNTransaction.commit()
        } else {
            scene.background.contents = image
        }
    }
}
