//
//  AmbientSceneBuilder.swift
//  Dino
//
//  Assembles the ambient diorama. The entire still scene (forest, cliff,
//  boulders, pool, lily pads, reeds) is painted in AmbientBackground; the 3D
//  layer adds motion only: the waterfall ribbon, foam, fireflies, and two
//  jumping fish. No box rock, no billboard trees, no character. A centered
//  orthographic camera (looking straight down -Z) keeps the ribbon aligned
//  over the painted falls. Built once and cached.
//

import SceneKit
import UIKit

final class AmbientSceneHandle {
    let scene: SCNScene
    let waterfall: WaterfallNode
    let lilyMarker: SCNNode          // invisible — drives the tap-zone projection
    let fish: [AmbientFish]
    let particleAnchor: SCNNode      // fireflies / mist over the pool
    let builtForReduceMotion: Bool

    init(scene: SCNScene, waterfall: WaterfallNode, lilyMarker: SCNNode,
         fish: [AmbientFish], particleAnchor: SCNNode, builtForReduceMotion: Bool) {
        self.scene = scene
        self.waterfall = waterfall
        self.lilyMarker = lilyMarker
        self.fish = fish
        self.particleAnchor = particleAnchor
        self.builtForReduceMotion = builtForReduceMotion
    }
}

enum AmbientSceneBuilder {

    static func build(reduceMotion: Bool) -> AmbientSceneHandle {
        let scene = SCNScene()

        // ── Waterfall ribbon (centered over the painted falls).
        let waterfall = WaterfallNode(reduceMotion: reduceMotion)
        scene.rootNode.addChildNode(waterfall)

        // ── Two jumping fish from the pool (alternating ~9s).
        var fish: [AmbientFish] = []
        let fishSpecs: [(x: Float, tint: UInt32, delay: TimeInterval)] = [
            (-1.6, 0xE59A60, 0.0),   // warm
            (1.9, 0x9AA86A, 4.5)     // olive
        ]
        for spec in fishSpecs {
            let f = AmbientFish(tint: spec.tint, startDelay: spec.delay, reduceMotion: reduceMotion)
            f.position = SCNVector3(spec.x, -3.4, 0.1)
            scene.rootNode.addChildNode(f)
            fish.append(f)
        }

        // ── Invisible lily marker over the painted front pad (center, low).
        let lilyMarker = SCNNode()
        lilyMarker.position = SCNVector3(0, -6.7, 0)
        scene.rootNode.addChildNode(lilyMarker)

        // ── Particle anchor over the pool (fireflies / mist at night).
        let particleAnchor = SCNNode()
        particleAnchor.position = SCNVector3(0, -3.0, 0)
        scene.rootNode.addChildNode(particleAnchor)

        // ── Camera: centered orthographic, straight down -Z, no tilt — so the
        //    vertical ribbon stays aligned with the painted falls. Half-height
        //    8 maps to the full (uncropped) image height.
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 8.0
        camera.zNear = 0.1
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 12)
        scene.rootNode.addChildNode(cameraNode)

        return AmbientSceneHandle(
            scene: scene, waterfall: waterfall, lilyMarker: lilyMarker,
            fish: fish, particleAnchor: particleAnchor,
            builtForReduceMotion: reduceMotion
        )
    }
}
