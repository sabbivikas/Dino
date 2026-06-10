//
//  GardenSceneBuilder.swift
//  Dino
//
//  Builds the illustrated personal garden: flat bright ground + smooth
//  hill mounds, 4 round trees, billboarded flower dots, turquoise pond,
//  egg rocks, drifting clouds, birds, a butterfly that keeps the bloom
//  company. Orthographic camera, fixed — an intimate still view, the
//  sunflower always center frame. Fixed seed: the same garden every launch.
//
//  Triangle budget ≈ 11k of the 15k cap (itemized at each section).
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
    let cameraPivot: SCNNode
    let particleAnchor: SCNNode
    let butterfly: SCNNode
    let builtForReduceMotion: Bool

    init(scene: SCNScene, sunflower: SunflowerNode, rig: GardenLighting.Rig,
         cameraPivot: SCNNode, particleAnchor: SCNNode, butterfly: SCNNode,
         builtForReduceMotion: Bool) {
        self.scene = scene
        self.sunflower = sunflower
        self.rig = rig
        self.cameraPivot = cameraPivot
        self.particleAnchor = particleAnchor
        self.butterfly = butterfly
        self.builtForReduceMotion = builtForReduceMotion
    }
}

enum GardenSceneBuilder {

    private static let seed: UInt64 = 20_260_610

    static func build(reduceMotion: Bool) -> GardenSceneHandle {
        let scene = SCNScene()
        var rng = GardenSeededRandom(seed: seed)
        let animate = !reduceMotion

        let crownMaterials = [
            GardenMaterials.swaying(GardenPalette.crown1, sway: animate),
            GardenMaterials.swaying(GardenPalette.crown2, sway: animate),
            GardenMaterials.swaying(GardenPalette.crown3, sway: animate)
        ]
        let grassMaterial = GardenMaterials.swaying(GardenPalette.grassTip, sway: animate)

        // ── Ground: flat bright plane (2 tris) — the only shadow receiver.
        let groundGeo = SCNPlane(width: 44, height: 44)
        groundGeo.firstMaterial = GardenMaterials.flat(GardenPalette.ground)
        let ground = SCNNode(geometry: groundGeo)
        ground.eulerAngles.x = -.pi / 2
        ground.castsShadow = false
        scene.rootNode.addChildNode(ground)

        // ── Hills: smooth sphere halves — far mint, near rich (≈ 1k tris).
        let hillSpecs: [(x: Float, z: Float, r: CGFloat, far: Bool)] = [
            (-9, -12, 4.5, true), (10, -14, 5.0, true), (0, -18, 6.0, true),
            (-6, -6, 2.2, false), (7, -7, 2.5, false)
        ]
        for spec in hillSpecs {
            let mound = SCNSphere(radius: spec.r)
            mound.segmentCount = 12
            mound.firstMaterial = GardenMaterials.flat(
                spec.far ? GardenPalette.hillFar : GardenPalette.hillNear
            )
            let node = SCNNode(geometry: mound)
            node.position = SCNVector3(spec.x, Float(-spec.r) * 0.62, spec.z)
            node.scale = SCNVector3(1.0, 0.85, 1.0)
            node.castsShadow = false
            scene.rootNode.addChildNode(node)
        }

        // ── Trees: 4 around the garden rim, 12-seg round crowns (≈ 3.6k tris).
        for (i, angle) in [0.9, 2.5, 3.9, 5.5].enumerated() {
            let tree = makeTree(rng: &rng, crown: crownMaterials[i % crownMaterials.count])
            let radius = rng.range(4.0, 6.0)
            tree.position = SCNVector3(
                Float(cos(angle) * radius),
                0,
                Float(sin(angle) * radius) - 1.5
            )
            scene.rootNode.addChildNode(tree)
        }

        // ── Flower dots: bright billboarded discs (≈ 60 tris) + grass blades.
        scatterFlowerDots(into: scene.rootNode, count: 26, rng: &rng)
        scatterGrassBlades(into: scene.rootNode, count: 14, material: grassMaterial, rng: &rng)

        // ── Pond: small turquoise disc with shimmer, one side (≈ 100 tris).
        let pondGeo = SCNCylinder(radius: 1.3, height: 0.05)
        pondGeo.radialSegmentCount = 20
        pondGeo.firstMaterial = GardenMaterials.water(shimmer: animate)
        let pond = SCNNode(geometry: pondGeo)
        pond.position = SCNVector3(2.6, 0.04, 1.2)
        pond.castsShadow = false
        scene.rootNode.addChildNode(pond)

        // ── Rocks: smooth eggs (≈ 700 tris).
        for _ in 0..<4 {
            let rock = SCNSphere(radius: CGFloat(rng.range(0.15, 0.3)))
            rock.segmentCount = 12
            rock.firstMaterial = GardenMaterials.flat(
                rng.next() > 0.5 ? GardenPalette.rock : GardenPalette.rockShade
            )
            let node = SCNNode(geometry: rock)
            node.scale = SCNVector3(1.25, 0.8, 1.0)
            let a = rng.range(0, 6.28)
            let r = rng.range(1.8, 4.5)
            node.position = SCNVector3(Float(cos(a) * r), 0.05, Float(sin(a) * r) - 0.8)
            scene.rootNode.addChildNode(node)
        }

        // ── Clouds: 3 white clusters drifting slowly (≈ 1.2k tris).
        let cloudGroup = SCNNode()
        cloudGroup.castsShadow = false
        let cloudSpecs: [(y: Float, z: Float, scale: Float, duration: TimeInterval)] = [
            (8.0, -16, 0.9, 70), (9.5, -20, 1.2, 95), (7.0, -12, 0.7, 60)
        ]
        for (i, spec) in cloudSpecs.enumerated() {
            let cloud = makeCloud(rng: &rng)
            cloud.scale = SCNVector3(spec.scale, spec.scale, spec.scale)
            cloud.position = SCNVector3(-12 + Float(i) * 8, spec.y, spec.z)
            if animate {
                let drift = SCNAction.sequence([
                    .moveBy(x: 24, y: 0, z: 0, duration: spec.duration),
                    .run { node in node.position.x = -12 }
                ])
                cloud.runAction(.repeatForever(drift))
            }
            cloudGroup.addChildNode(cloud)
        }
        scene.rootNode.addChildNode(cloudGroup)

        // ── Birds: 1-2 crossing the sky, morning/day only (≈ 80 tris).
        let birdGroup = SCNNode()
        birdGroup.castsShadow = false
        if animate {
            birdGroup.addChildNode(makeBirdOrbit(height: 6.5, radius: 8, duration: 40, phase: 0))
            birdGroup.addChildNode(makeBirdOrbit(height: 5.5, radius: 10, duration: 55, phase: .pi))
        }
        scene.rootNode.addChildNode(birdGroup)

        // ── Butterfly: keeps the bloom company (visibility set by SceneView).
        let butterfly = makeButterfly(wingColor: GardenPalette.flowerPeach, animate: animate)
        butterfly.position = SCNVector3(0.8, 1.4, 0.6)
        scene.rootNode.addChildNode(butterfly)

        // ── Sunflower at center.
        let sunflower = SunflowerNode()
        sunflower.position = SCNVector3(0, 0.02, 0)
        scene.rootNode.addChildNode(sunflower)

        // ── Lighting rig + domes + celestial.
        let rig = GardenLighting.makeRig(cloudGroup: cloudGroup, birdGroup: birdGroup)
        scene.rootNode.addChildNode(rig.sunNode)
        scene.rootNode.addChildNode(rig.ambientNode)
        for (_, dome) in rig.domes {
            scene.rootNode.addChildNode(dome)
        }
        scene.rootNode.addChildNode(rig.sunDisc)
        scene.rootNode.addChildNode(rig.nightGroup)

        // ── Camera: orthographic, fixed, ≈11° down-tilt, sunflower centered.
        let cameraPivot = SCNNode()
        cameraPivot.position = SCNVector3(0, 1.0, 0)

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 7.0
        camera.zNear = 0.1
        camera.zFar = 90
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2.6, 9.0)
        // ≈11° down from horizontal — just enough ground to feel depth.
        cameraNode.eulerAngles.x = -0.19
        cameraPivot.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraPivot)

        // Particle anchor near the sunflower.
        let particleAnchor = SCNNode()
        particleAnchor.position = SCNVector3(0, 1.0, 0)
        scene.rootNode.addChildNode(particleAnchor)

        return GardenSceneHandle(
            scene: scene,
            sunflower: sunflower,
            rig: rig,
            cameraPivot: cameraPivot,
            particleAnchor: particleAnchor,
            butterfly: butterfly,
            builtForReduceMotion: reduceMotion
        )
    }

    // MARK: - Props

    private static func makeTree(rng: inout GardenSeededRandom, crown: SCNMaterial) -> SCNNode {
        let root = SCNNode()
        let scale = Float(rng.range(0.8, 1.2))

        let trunkHeight = CGFloat(1.0 * scale)
        let trunk = SCNCylinder(radius: 0.13, height: trunkHeight)
        trunk.radialSegmentCount = 10
        trunk.firstMaterial = GardenMaterials.flat(GardenPalette.trunk)
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, Float(trunkHeight) / 2, 0)
        root.addChildNode(trunkNode)

        let blobCount = 2 + Int(rng.range(0, 1.99))
        for _ in 0..<blobCount {
            let blob = SCNSphere(radius: CGFloat(rng.range(0.5, 0.8)) * CGFloat(scale))
            blob.segmentCount = 12
            blob.firstMaterial = crown
            let blobNode = SCNNode(geometry: blob)
            blobNode.position = SCNVector3(
                Float(rng.range(-0.3, 0.3)),
                Float(trunkHeight) + Float(rng.range(0.1, 0.55)) * scale,
                Float(rng.range(-0.3, 0.3))
            )
            root.addChildNode(blobNode)
        }
        return root
    }

    private static func scatterFlowerDots(into parent: SCNNode, count: Int,
                                          rng: inout GardenSeededRandom) {
        let colors: [UIColor] = [
            GardenPalette.flowerPeach, GardenPalette.flowerLavender,
            GardenPalette.flowerYellow, GardenPalette.flowerWhite
        ]
        for i in 0..<count {
            let dot = SCNPlane(width: 0.13, height: 0.13)
            dot.cornerRadius = 0.065
            dot.firstMaterial = GardenMaterials.unlit(colors[i % colors.count])
            let node = SCNNode(geometry: dot)
            let a = rng.range(0, 6.28)
            let r = rng.range(1.2, 5.0)
            node.position = SCNVector3(
                Float(cos(a) * r),
                Float(rng.range(0.06, 0.14)),
                Float(sin(a) * r) - 0.8
            )
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            node.constraints = [billboard]
            node.castsShadow = false
            parent.addChildNode(node)
        }
    }

    private static func scatterGrassBlades(into parent: SCNNode, count: Int,
                                           material: SCNMaterial, rng: inout GardenSeededRandom) {
        for _ in 0..<count {
            let tuft = SCNNode()
            for k in 0..<2 {
                let blade = SCNPlane(width: 0.18, height: CGFloat(rng.range(0.25, 0.4)))
                blade.firstMaterial = material
                let bladeNode = SCNNode(geometry: blade)
                bladeNode.position = SCNVector3(0, Float(blade.height) / 2, 0)
                bladeNode.eulerAngles.y = Float(k) * .pi / 2 + Float(rng.range(-0.3, 0.3))
                bladeNode.castsShadow = false
                tuft.addChildNode(bladeNode)
            }
            let a = rng.range(0, 6.28)
            let r = rng.range(1.0, 4.5)
            tuft.position = SCNVector3(Float(cos(a) * r), 0, Float(sin(a) * r) - 0.8)
            parent.addChildNode(tuft)
        }
    }

    private static func makeCloud(rng: inout GardenSeededRandom) -> SCNNode {
        let cloud = SCNNode()
        let material = GardenMaterials.unlit(GardenPalette.cloud)
        let blobs: [(Float, Float, CGFloat)] = [
            (0, 0, 0.8), (-0.8, -0.1, 0.55), (0.8, -0.1, 0.6), (0.15, 0.35, 0.5)
        ]
        for blob in blobs {
            let geo = SCNSphere(radius: blob.2)
            geo.segmentCount = 10
            geo.firstMaterial = material
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(blob.0 + Float(rng.range(-0.1, 0.1)), blob.1, 0)
            node.castsShadow = false
            cloud.addChildNode(node)
        }
        cloud.castsShadow = false
        return cloud
    }

    private static func makeBirdOrbit(height: Float, radius: Float,
                                      duration: TimeInterval, phase: Float) -> SCNNode {
        let orbit = SCNNode()
        orbit.position = SCNVector3(0, height, -3)
        orbit.eulerAngles.y = phase

        let bird = SCNNode()
        bird.position = SCNVector3(radius, 0, 0)
        bird.eulerAngles.y = .pi / 2

        let bodyGeo = SCNCapsule(capRadius: 0.05, height: 0.24)
        bodyGeo.firstMaterial = GardenMaterials.flat(UIColor(white: 0.25, alpha: 1))
        let body = SCNNode(geometry: bodyGeo)
        body.eulerAngles.x = .pi / 2
        bird.addChildNode(body)

        for side in [Float(-1), Float(1)] {
            let wingGeo = SCNPlane(width: 0.3, height: 0.14)
            wingGeo.firstMaterial = GardenMaterials.flat(UIColor(white: 0.3, alpha: 1))
            let wing = SCNNode(geometry: wingGeo)
            wing.pivot = SCNMatrix4MakeTranslation(side * -0.15, 0, 0)
            wing.position = SCNVector3(side * 0.04, 0.02, 0)
            wing.eulerAngles.x = -.pi / 2
            bird.addChildNode(wing)

            let flap = SCNAction.customAction(duration: 0.9) { node, elapsed in
                let f = 0.35 + 0.65 * abs(sin(Float(elapsed) * 2 * .pi / 0.9))
                node.scale = SCNVector3(1, f, 1)
            }
            wing.runAction(.repeatForever(flap))
        }

        orbit.addChildNode(bird)
        orbit.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: duration)))
        return orbit
    }

    private static func makeButterfly(wingColor: UIColor, animate: Bool) -> SCNNode {
        let outer = SCNNode()
        let inner = SCNNode()
        inner.position = SCNVector3(0.5, 0, 0)
        outer.addChildNode(inner)

        let butterfly = SCNNode()
        inner.addChildNode(butterfly)

        let bodyGeo = SCNCapsule(capRadius: 0.016, height: 0.1)
        bodyGeo.firstMaterial = GardenMaterials.flat(UIColor(white: 0.25, alpha: 1))
        butterfly.addChildNode(SCNNode(geometry: bodyGeo))

        for side in [Float(-1), Float(1)] {
            let wingGeo = SCNPlane(width: 0.12, height: 0.1)
            wingGeo.cornerRadius = 0.045
            wingGeo.firstMaterial = GardenMaterials.unlit(wingColor)
            let wing = SCNNode(geometry: wingGeo)
            wing.pivot = SCNMatrix4MakeTranslation(side * -0.06, 0, 0)
            wing.position = SCNVector3(side * 0.018, 0.02, 0)
            wing.eulerAngles.x = -.pi / 2.4
            butterfly.addChildNode(wing)

            if animate {
                let flap = SCNAction.customAction(duration: 0.45) { node, elapsed in
                    let f = 0.3 + 0.7 * abs(sin(Float(elapsed) * 2 * .pi / 0.45))
                    node.scale = SCNVector3(1, f, 1)
                }
                wing.runAction(.repeatForever(flap))
            }
        }

        if animate {
            outer.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 11)))
            inner.runAction(.repeatForever(.rotateBy(x: 0, y: -4 * .pi, z: 0, duration: 11)))
            let bob = SCNAction.sequence([
                .moveBy(x: 0, y: 0.2, z: 0, duration: 1.2),
                .moveBy(x: 0, y: -0.2, z: 0, duration: 1.2)
            ])
            bob.timingMode = .easeInEaseOut
            butterfly.runAction(.repeatForever(bob))
        }

        return outer
    }
}
