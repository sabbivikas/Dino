//
//  GardenSceneBuilder.swift
//  Dino
//
//  Option 3: a small, perfect diorama. The illustrated gradient background
//  (GardenLighting) is the sky and the world; the 3D layer holds only the
//  hero sunflower, a soft shadow-catching ground, and 3–4 illustrated
//  billboard trees framing the flower. Fixed camera — no pan, no gyro,
//  no clipping, always beautiful.
//

import SceneKit
import UIKit

/// Deterministic xorshift RNG — fixed seed.
struct GardenSeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed | 1 }
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000.0
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double {
        lo + (hi - lo) * next()
    }
}

/// Everything GardenSceneView needs to drive the cached scene.
final class GardenSceneHandle {
    let scene: SCNScene
    let sunflower: SunflowerNode
    let rig: GardenLighting.Rig
    let particleAnchor: SCNNode
    let builtForReduceMotion: Bool

    init(scene: SCNScene, sunflower: SunflowerNode, rig: GardenLighting.Rig,
         particleAnchor: SCNNode, builtForReduceMotion: Bool) {
        self.scene = scene
        self.sunflower = sunflower
        self.rig = rig
        self.particleAnchor = particleAnchor
        self.builtForReduceMotion = builtForReduceMotion
    }
}

enum GardenSceneBuilder {

    static func build(reduceMotion: Bool) -> GardenSceneHandle {
        let scene = SCNScene()

        // ── Ground: a soft sage plane that mostly catches the sunflower's
        //    shadow — the background image paints the horizon above it.
        let groundGeo = SCNPlane(width: 20, height: 20)
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = UIColor(hexRGB: 0x7EC86A).withAlphaComponent(0.8)
        groundMaterial.lightingModel = .lambert
        groundMaterial.specular.contents = UIColor.black
        groundMaterial.isDoubleSided = true
        groundGeo.firstMaterial = groundMaterial
        let ground = SCNNode(geometry: groundGeo)
        ground.eulerAngles.x = -Float.pi / 2
        ground.castsShadow = false
        scene.rootNode.addChildNode(ground)

        // ── The hero.
        let sunflower = SunflowerNode(reduceMotion: reduceMotion)
        sunflower.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(sunflower)

        // ── Illustrated billboard trees framing the flower.
        let treeSpecs: [(x: Float, z: Float, scale: Float, variant: Int)] = [
            (-3.5, -2.0, 1.0, 0),
            (3.5, -2.5, 1.1, 1),
            (-5.0, -4.0, 1.25, 2),
            (5.0, -3.5, 1.2, 0)
        ]
        for spec in treeSpecs {
            let height: CGFloat = 3.2 * CGFloat(spec.scale)
            let width = height * 0.75
            let plane = SCNPlane(width: width, height: height)
            let m = SCNMaterial()
            m.diffuse.contents = makeTreeImage(variant: spec.variant)
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.transparencyMode = .aOne
            plane.firstMaterial = m
            let tree = SCNNode(geometry: plane)
            tree.position = SCNVector3(spec.x, Float(height) / 2, spec.z)
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            tree.constraints = [billboard]
            tree.castsShadow = false
            scene.rootNode.addChildNode(tree)
        }

        // ── Lighting.
        let rig = GardenLighting.makeRig()
        scene.rootNode.addChildNode(rig.sunNode)
        scene.rootNode.addChildNode(rig.ambientNode)

        // ── Camera: fixed, tight on the sunflower, slightly low — the
        //    flower feels tall and proud.
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 4.0
        camera.zNear = 0.1
        camera.zFar = 50
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 3, 8)
        let dy: Float = 2 - 3, dz: Float = 0 - 8
        cameraNode.eulerAngles.x = atan2(dy, sqrt(dz * dz))   // looks at (0, 2, 0)
        scene.rootNode.addChildNode(cameraNode)

        // ── Particles anchor near the flower.
        let particleAnchor = SCNNode()
        particleAnchor.position = SCNVector3(0, 1.2, 0)
        scene.rootNode.addChildNode(particleAnchor)

        return GardenSceneHandle(
            scene: scene, sunflower: sunflower, rig: rig,
            particleAnchor: particleAnchor,
            builtForReduceMotion: reduceMotion
        )
    }

    // MARK: - Illustrated tree images (120×160, drawn in CGContext)

    private static var treeImageCache: [Int: UIImage] = [:]

    private static func makeTreeImage(variant: Int) -> UIImage {
        if let cached = treeImageCache[variant] { return cached }
        let size = CGSize(width: 120, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        var rng = GardenSeededRandom(seed: UInt64(variant) * 17 + 5)

        let image = renderer.image { ctx in
            let cg = ctx.cgContext

            // Trunk.
            cg.setFillColor(UIColor(hexRGB: 0x8B5E3C).cgColor)
            cg.fill(CGRect(x: 52, y: 95, width: 16, height: 65))

            // Crown: overlapping circles in three greens.
            let greens: [UInt32] = [0x6BBF59, 0x4A9A4A, 0x85CF6B]
            let blobs: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
                (60, 60, 42), (32, 75, 28), (88, 75, 27),
                (45, 38, 24), (76, 40, 23), (60, 88, 26)
            ]
            for (i, blob) in blobs.enumerated() {
                cg.setFillColor(UIColor(hexRGB: greens[i % greens.count]).cgColor)
                let jx = CGFloat(rng.range(-4, 4))
                let jy = CGFloat(rng.range(-3, 3))
                cg.fillEllipse(in: CGRect(x: blob.x - blob.r + jx,
                                          y: blob.y - blob.r + jy,
                                          width: blob.r * 2, height: blob.r * 2))
            }
        }
        treeImageCache[variant] = image
        return image
    }
}
