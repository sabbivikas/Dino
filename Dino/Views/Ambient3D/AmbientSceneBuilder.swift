//
//  AmbientSceneBuilder.swift
//  Dino
//
//  Assembles the ambient diorama: painted background, billboard forest
//  framing a 3D waterfall, the tappable lily pad, the star companion, and
//  a fixed orthographic camera. Built once and cached.
//

import SceneKit
import UIKit

final class AmbientSceneHandle {
    let scene: SCNScene
    let rig: AmbientLighting.Rig
    let waterfall: WaterfallNode
    let lilyPad: SCNNode
    let star: AmbientStarGuide
    let particleAnchor: SCNNode
    let treeMaterials: [SCNMaterial]
    let builtForReduceMotion: Bool

    init(scene: SCNScene, rig: AmbientLighting.Rig, waterfall: WaterfallNode,
         lilyPad: SCNNode, star: AmbientStarGuide, particleAnchor: SCNNode,
         treeMaterials: [SCNMaterial], builtForReduceMotion: Bool) {
        self.scene = scene
        self.rig = rig
        self.waterfall = waterfall
        self.lilyPad = lilyPad
        self.star = star
        self.particleAnchor = particleAnchor
        self.treeMaterials = treeMaterials
        self.builtForReduceMotion = builtForReduceMotion
    }
}

enum AmbientSceneBuilder {

    static func build(reduceMotion: Bool) -> AmbientSceneHandle {
        let scene = SCNScene()
        var treeMaterials: [SCNMaterial] = []

        // ── Ground: dark forest floor, the shadow catcher.
        let groundGeo = SCNPlane(width: 20, height: 20)
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = UIColor(hexRGB: 0x1A2A1A)
        groundMaterial.lightingModel = .lambert
        groundMaterial.specular.contents = UIColor.black
        groundMaterial.isDoubleSided = true
        groundGeo.firstMaterial = groundMaterial
        let ground = SCNNode(geometry: groundGeo)
        ground.eulerAngles.x = -Float.pi / 2
        ground.castsShadow = false
        scene.rootNode.addChildNode(ground)

        // ── Far forest billboards behind the waterfall.
        let farSpecs: [(x: Float, z: Float, h: CGFloat, variant: Int)] = [
            (-2.5, -6, 4.4, 0), (2.5, -6.5, 4.8, 1), (-4.5, -5.5, 4.0, 2), (4.5, -5, 3.8, 0)
        ]
        for spec in farSpecs {
            let (tree, material) = makeTreeBillboard(height: spec.h, variant: spec.variant)
            tree.position = SCNVector3(spec.x, Float(spec.h) / 2 - 0.05, spec.z)
            scene.rootNode.addChildNode(tree)
            treeMaterials.append(material)
        }
        // ── Near framing trees flanking the falls.
        for (x, variant) in [(Float(-4), 1), (4, 2)] {
            let height: CGFloat = 5.6
            let (tree, material) = makeTreeBillboard(height: height, variant: variant)
            tree.position = SCNVector3(x, Float(height) / 2 - 0.05, -1.5)
            scene.rootNode.addChildNode(tree)
            treeMaterials.append(material)
        }

        // ── The waterfall.
        let waterfall = WaterfallNode(reduceMotion: reduceMotion)
        scene.rootNode.addChildNode(waterfall)

        // ── The lily pad (the forest-letter tap target lives here).
        let padGeo = SCNPlane(width: 0.8, height: 0.8)
        padGeo.cornerRadius = 0.4
        let padMaterial = SCNMaterial()
        padMaterial.diffuse.contents = UIColor(hexRGB: 0x5CBF5C)
        padMaterial.lightingModel = .lambert
        padMaterial.specular.contents = UIColor.black
        padMaterial.isDoubleSided = true
        padGeo.firstMaterial = padMaterial
        let lilyPad = SCNNode(geometry: padGeo)
        lilyPad.eulerAngles.x = -Float.pi / 2
        lilyPad.position = SCNVector3(0, 0.1, 1)
        lilyPad.scale = SCNVector3(1, 0.85, 1)   // slight oval
        if !reduceMotion {
            let up = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 1.5)
            up.timingMode = .easeInEaseOut
            let down = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 1.5)
            down.timingMode = .easeInEaseOut
            lilyPad.runAction(.repeatForever(.sequence([up, down])))
        }
        scene.rootNode.addChildNode(lilyPad)

        // ── The star companion, hovering left of the falls.
        let star = AmbientStarGuide(reduceMotion: reduceMotion)
        star.position = SCNVector3(-2.6, 2.4, -1.5)
        scene.rootNode.addChildNode(star)

        // ── Lighting.
        let rig = AmbientLighting.makeRig()
        scene.rootNode.addChildNode(rig.sunNode)
        scene.rootNode.addChildNode(rig.ambientNode)

        // ── Camera: fixed framing — falls center-back, pool low, sky high.
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 5.0
        camera.zNear = 0.1
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2, 10)
        let dy: Float = 1.5 - 2, dz: Float = 0 - 10
        cameraNode.eulerAngles.x = atan2(dy, sqrt(dz * dz))   // looks at (0, 1.5, 0)
        scene.rootNode.addChildNode(cameraNode)

        // ── Ambient particles anchor.
        let particleAnchor = SCNNode()
        particleAnchor.position = SCNVector3(0, 1.0, 0)
        scene.rootNode.addChildNode(particleAnchor)

        return AmbientSceneHandle(
            scene: scene, rig: rig, waterfall: waterfall, lilyPad: lilyPad,
            star: star, particleAnchor: particleAnchor,
            treeMaterials: treeMaterials, builtForReduceMotion: reduceMotion
        )
    }

    // MARK: - Billboard forest trees (drawn in CGContext)

    private static func makeTreeBillboard(height: CGFloat, variant: Int)
        -> (node: SCNNode, material: SCNMaterial) {
        let plane = SCNPlane(width: height * 0.62, height: height)
        let m = SCNMaterial()
        m.diffuse.contents = treeImage(variant: variant)
        m.lightingModel = .constant
        m.isDoubleSided = true
        m.transparencyMode = .aOne
        plane.firstMaterial = m
        let node = SCNNode(geometry: plane)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        node.constraints = [billboard]
        node.castsShadow = false
        return (node, m)
    }

    private static var treeImageCache: [Int: UIImage] = [:]

    private static func treeImage(variant: Int) -> UIImage {
        if let cached = treeImageCache[variant] { return cached }
        let size = CGSize(width: 100, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        var rng = GardenSeededRandom(seed: UInt64(variant) * 13 + 3)

        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            // Trunk.
            cg.setFillColor(UIColor(hexRGB: 0x3A2E22).cgColor)
            cg.fill(CGRect(x: 44, y: 100, width: 12, height: 60))
            // Deep forest canopy — stacked dark-green blobs.
            let greens: [UInt32] = [0x2D5A2D, 0x1F4520, 0x3A6B38]
            let blobs: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
                (50, 55, 38), (28, 72, 26), (72, 70, 25),
                (38, 34, 22), (64, 36, 21), (50, 86, 24)
            ]
            for (i, blob) in blobs.enumerated() {
                cg.setFillColor(UIColor(hexRGB: greens[(i + variant) % greens.count]).cgColor)
                let jx = CGFloat(rng.range(-4, 4))
                let jy = CGFloat(rng.range(-3, 3))
                cg.fillEllipse(in: CGRect(x: blob.x - blob.r + jx, y: blob.y - blob.r + jy,
                                          width: blob.r * 2, height: blob.r * 2))
            }
        }
        treeImageCache[variant] = image
        return image
    }
}
