//
//  WorldBuilder.swift
//  Dino
//
//  The organic onboarding world: multi-cluster tree canopies, volumetric
//  puffy clouds, living water with caustics, layered grass and pebbles,
//  three rows of smooth hills, realistic birds, and the glowing StarGuide
//  that travels with the user. No path strip, no rainbow — calm and
//  organic; everything belongs in nature. Fixed seed throughout.
//
//  Triangle budget ≈ 21k of the 25k cap (itemized per section).
//

import SceneKit
import UIKit

/// Deterministic xorshift RNG, fixed seed.
struct WorldSeededRandom {
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

/// Held by the representable's Coordinator — NOT static — so the world
/// releases fully when onboarding is dismissed.
final class WorldHandle {
    let scene: SCNScene
    let rig: WorldLighting.Rig
    let cameraRig: SCNNode
    let cameraNode: SCNNode
    let parallaxPivot: SCNNode
    let regionAnchors: [WorldRegion: SCNNode]
    let starGuide: StarGuide
    let builtForReduceMotion: Bool

    init(scene: SCNScene, rig: WorldLighting.Rig, cameraRig: SCNNode,
         cameraNode: SCNNode, parallaxPivot: SCNNode,
         regionAnchors: [WorldRegion: SCNNode], starGuide: StarGuide,
         builtForReduceMotion: Bool) {
        self.scene = scene
        self.rig = rig
        self.cameraRig = cameraRig
        self.cameraNode = cameraNode
        self.parallaxPivot = parallaxPivot
        self.regionAnchors = regionAnchors
        self.starGuide = starGuide
        self.builtForReduceMotion = builtForReduceMotion
    }
}

enum WorldBuilder {

    private static let seed: UInt64 = 11_2026

    private static let meadowCenter = SCNVector3(0, 0, 0)
    private static let pondCenter = SCNVector3(-5, 0, -9.5)
    private static let groveCenter = SCNVector3(4.5, 0, -18.5)
    private static let overlookCenter = SCNVector3(0, 0, -29)

    static func build(reduceMotion: Bool) -> WorldHandle {
        let scene = SCNScene()
        var rng = WorldSeededRandom(seed: seed)
        let animate = !reduceMotion

        // Three grass shades sharing the sway modifier (cheap, vertex-level).
        let grassMaterials = [
            WorldMaterials.swaying(WorldPalette.crown1, sway: animate),
            WorldMaterials.swaying(WorldPalette.crown2, sway: animate),
            WorldMaterials.swaying(WorldPalette.grassTip, sway: animate)
        ]
        // Four canopy shades, swaying at the crown.
        let crownMaterials = [
            WorldMaterials.swaying(WorldPalette.crown1, sway: animate),
            WorldMaterials.swaying(WorldPalette.crown2, sway: animate),
            WorldMaterials.swaying(WorldPalette.crown3, sway: animate),
            WorldMaterials.swaying(WorldPalette.crown4, sway: animate)
        ]

        // ── Ground: flat bright plane, the shadow receiver (2 tris).
        let groundGeo = SCNPlane(width: 70, height: 80)
        groundGeo.firstMaterial = WorldMaterials.flat(WorldPalette.grass)
        let ground = SCNNode(geometry: groundGeo)
        ground.eulerAngles.x = -.pi / 2
        ground.position = SCNVector3(0, 0, -13)
        ground.castsShadow = false
        scene.rootNode.addChildNode(ground)

        // ── Hills: three depth rows of smooth organic mounds (≈ 2.2k tris).
        let hillRows: [(specs: [(Float, Float, CGFloat)], color: UIColor)] = [
            // Far — soft mint, big and low.
            ([(-16, -36, 8.5), (-2, -40, 9.5), (12, -37, 8.0)], WorldPalette.hillFar),
            // Mid — main grass green.
            ([(-12, -22, 5.5), (10, -24, 6.0), (0, -26, 5.0)], WorldPalette.grass),
            // Near — rich green, smaller.
            ([(-8, -10, 3.0), (8, -8, 2.6), (-6, 3, 2.2), (7, 2, 2.4)], WorldPalette.hillNear)
        ]
        for row in hillRows {
            for spec in row.specs {
                let mound = SCNSphere(radius: spec.2)
                mound.segmentCount = 12
                mound.firstMaterial = WorldMaterials.flat(row.color)
                let node = SCNNode(geometry: mound)
                node.position = SCNVector3(spec.0, Float(-spec.2) * 0.6, spec.1)
                node.scale = SCNVector3(
                    Float(1.1 + rng.range(0, 0.4)),
                    Float(0.75 + rng.range(0, 0.2)),
                    1.0
                )
                node.castsShadow = false
                scene.rootNode.addChildNode(node)
            }
        }
        // Overlook crest.
        let crest = SCNSphere(radius: 9)
        crest.segmentCount = 14
        crest.firstMaterial = WorldMaterials.flat(WorldPalette.hillNear)
        let crestNode = SCNNode(geometry: crest)
        crestNode.position = SCNVector3(overlookCenter.x, -6.2, overlookCenter.z)
        crestNode.castsShadow = false
        scene.rootNode.addChildNode(crestNode)

        // ── Trees: organic multi-cluster canopies (≈ 9k tris).
        //    4 in the meadow + 6 in the grove.
        for angle in [0.8, 2.4, 4.0, 5.4] {
            let tree = makeOrganicTree(rng: &rng, crowns: crownMaterials)
            let radius = rng.range(4.2, 6.5)
            tree.position = SCNVector3(
                Float(cos(angle) * radius) + meadowCenter.x,
                0,
                Float(sin(angle) * radius) + meadowCenter.z - 1.0
            )
            scene.rootNode.addChildNode(tree)
            addSoilPatch(under: tree, into: scene.rootNode, rng: &rng)
        }
        for i in 0..<6 {
            let tree = makeOrganicTree(rng: &rng, crowns: crownMaterials)
            let a = Double(i) / 6.0 * 6.28 + rng.range(-0.3, 0.3)
            let r = rng.range(2.2, 5.0)
            tree.position = SCNVector3(
                groveCenter.x + Float(cos(a) * r),
                0,
                groveCenter.z + Float(sin(a) * r)
            )
            scene.rootNode.addChildNode(tree)
        }

        // ── Grass: ~90 crossed-blade tufts in 3 shades (≈ 1.1k tris).
        scatterGrass(into: scene.rootNode, around: meadowCenter, count: 46,
                     spread: 6.0, materials: grassMaterials, rng: &rng)
        scatterGrass(into: scene.rootNode, around: pondCenter, count: 16,
                     spread: 4.0, materials: grassMaterials, rng: &rng)
        scatterGrass(into: scene.rootNode, around: groveCenter, count: 18,
                     spread: 4.5, materials: grassMaterials, rng: &rng)
        scatterGrass(into: scene.rootNode, around: SCNVector3(0, 0, -26), count: 10,
                     spread: 3.0, materials: grassMaterials, rng: &rng)

        // ── Pebbles + rocks: natural scatter (≈ 1k tris).
        scatterPebbles(into: scene.rootNode, rng: &rng)

        // ── Flower dots: max 16, tiny, scattered naturally (≈ 32 tris).
        scatterFlowerDots(into: scene.rootNode, rng: &rng)

        // ── THE POND: living water + lilies + cattails + edge mist (≈ 900 tris).
        let waterGeo = SCNCylinder(radius: 2.6, height: 0.05)
        waterGeo.radialSegmentCount = 28
        waterGeo.firstMaterial = WorldMaterials.water(shimmer: animate)
        let water = SCNNode(geometry: waterGeo)
        water.position = SCNVector3(pondCenter.x, 0.05, pondCenter.z)
        water.castsShadow = false
        scene.rootNode.addChildNode(water)

        for _ in 0..<5 {
            let pad = SCNCylinder(radius: CGFloat(rng.range(0.18, 0.34)), height: 0.03)
            pad.radialSegmentCount = 12
            pad.firstMaterial = WorldMaterials.flat(WorldPalette.lily)
            let padNode = SCNNode(geometry: pad)
            let a = rng.range(0, 6.28)
            let r = rng.range(0.6, 2.0)
            padNode.position = SCNVector3(
                pondCenter.x + Float(cos(a) * r),
                0.1,
                pondCenter.z + Float(sin(a) * r)
            )
            padNode.castsShadow = false
            scene.rootNode.addChildNode(padNode)
        }

        for _ in 0..<7 {
            let stalk = SCNCylinder(radius: 0.02, height: CGFloat(rng.range(0.7, 1.1)))
            stalk.radialSegmentCount = 6
            stalk.firstMaterial = WorldMaterials.flat(WorldPalette.hillNear)
            let stalkNode = SCNNode(geometry: stalk)
            let a = rng.range(0, 6.28)
            let r = rng.range(2.7, 3.4)
            let h = Float(stalk.height)
            stalkNode.position = SCNVector3(
                pondCenter.x + Float(cos(a) * r),
                h / 2,
                pondCenter.z + Float(sin(a) * r)
            )
            let tip = SCNCapsule(capRadius: 0.05, height: 0.22)
            tip.firstMaterial = WorldMaterials.flat(WorldPalette.cattailTop)
            let tipNode = SCNNode(geometry: tip)
            tipNode.position = SCNVector3(0, h / 2 + 0.1, 0)
            stalkNode.addChildNode(tipNode)
            scene.rootNode.addChildNode(stalkNode)
        }

        // Edge mist: soft translucent spheres drifting very slowly.
        for i in 0..<5 {
            let mistGeo = SCNSphere(radius: CGFloat(rng.range(0.35, 0.6)))
            mistGeo.segmentCount = 8
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(white: 1.0, alpha: 0.18)
            m.lightingModel = .constant
            m.writesToDepthBuffer = false
            mistGeo.firstMaterial = m
            let mist = SCNNode(geometry: mistGeo)
            let a = Double(i) / 5.0 * 6.28
            mist.position = SCNVector3(
                pondCenter.x + Float(cos(a) * 2.9),
                0.25,
                pondCenter.z + Float(sin(a) * 2.9)
            )
            mist.castsShadow = false
            if animate {
                let drift = SCNAction.sequence([
                    .moveBy(x: 0.4, y: 0.08, z: 0, duration: 6),
                    .moveBy(x: -0.4, y: -0.08, z: 0, duration: 6)
                ])
                drift.timingMode = .easeInEaseOut
                mist.runAction(.repeatForever(drift))
            }
            scene.rootNode.addChildNode(mist)
        }

        // ── THE GROVE: god rays stay grove-only (≈ 150 tris).
        for i in 0..<3 {
            let cone = SCNCone(topRadius: 0.25, bottomRadius: 1.1, height: 7)
            cone.radialSegmentCount = 10
            cone.firstMaterial = WorldMaterials.ray(WorldPalette.skyDawnBottom, alpha: 0.08)
            let rayNode = SCNNode(geometry: cone)
            rayNode.position = SCNVector3(
                groveCenter.x - 1.5 + Float(i) * 1.6,
                3.4,
                groveCenter.z + Float(i - 1) * 1.2
            )
            rayNode.eulerAngles = SCNVector3(0.18, 0, -0.22)
            rayNode.castsShadow = false
            scene.rootNode.addChildNode(rayNode)
        }

        // ── Clouds: volumetric multi-sphere puffs with soft ground shadows
        //    (≈ 3.2k tris).
        let cloudSpecs: [(y: Float, z: Float, scale: Float, duration: TimeInterval)] = [
            (10.5, -20, 1.0, 70), (12.5, -28, 1.35, 95), (9.0, -8, 0.8, 60), (13.5, -36, 1.15, 110)
        ]
        for (i, spec) in cloudSpecs.enumerated() {
            let cloud = makeVolumetricCloud(rng: &rng, groundDrop: spec.y)
            cloud.scale = SCNVector3(spec.scale, spec.scale, spec.scale)
            cloud.position = SCNVector3(-18 + Float(i) * 9, spec.y, spec.z)
            if animate {
                let drift = SCNAction.sequence([
                    .moveBy(x: 36, y: 0, z: 0, duration: spec.duration),
                    .run { node in node.position.x = -18 }
                ])
                cloud.runAction(.repeatForever(drift))
            }
            scene.rootNode.addChildNode(cloud)
        }

        // ── Birds: realistic silhouettes, root-pivot wing rotation (≈ 200 tris).
        if animate {
            scene.rootNode.addChildNode(makeRealisticBird(height: 9.5, radius: 10, duration: 42, phase: 0))
            scene.rootNode.addChildNode(makeRealisticBird(height: 11.5, radius: 13, duration: 58, phase: .pi))
        }

        // ── The Star Guide.
        let star = StarGuide(reduceMotion: reduceMotion)
        star.position = SCNVector3(0, 1.5, 2.0)   // repositioned per step by the view
        scene.rootNode.addChildNode(star)

        // ── Lighting rig + domes + celestial.
        let rig = WorldLighting.makeRig()
        scene.rootNode.addChildNode(rig.sunNode)
        scene.rootNode.addChildNode(rig.ambientNode)
        scene.rootNode.addChildNode(rig.fillNode)
        for (_, dome) in rig.domes {
            scene.rootNode.addChildNode(dome)
        }
        scene.rootNode.addChildNode(rig.nightGroup)
        scene.rootNode.addChildNode(rig.sunDisc)

        // ── Camera (orthographic illustrated framing preserved).
        let cameraRig = SCNNode()
        let parallaxPivot = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 10.0
        camera.zNear = 0.1
        camera.zFar = 140
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        parallaxPivot.addChildNode(cameraNode)
        cameraRig.addChildNode(parallaxPivot)
        scene.rootNode.addChildNode(cameraRig)

        let start = CameraJourney.pose(for: 0)
        cameraRig.position = start.position
        cameraRig.eulerAngles = CameraJourney.eulerLooking(from: start.position, at: start.lookAt)
        camera.orthographicScale = start.orthoScale

        let meadowAnchor = SCNNode()
        meadowAnchor.position = SCNVector3(meadowCenter.x, 1.2, meadowCenter.z)
        scene.rootNode.addChildNode(meadowAnchor)
        let pondAnchor = SCNNode()
        pondAnchor.position = SCNVector3(pondCenter.x, 0.8, pondCenter.z)
        scene.rootNode.addChildNode(pondAnchor)
        let groveAnchor = SCNNode()
        groveAnchor.position = SCNVector3(groveCenter.x, 1.5, groveCenter.z)
        scene.rootNode.addChildNode(groveAnchor)
        let overlookAnchor = SCNNode()
        overlookAnchor.position = SCNVector3(overlookCenter.x, 3.4, overlookCenter.z)
        scene.rootNode.addChildNode(overlookAnchor)

        let anchors: [WorldRegion: SCNNode] = [
            .meadow: meadowAnchor,
            .pond: pondAnchor,
            .grove: groveAnchor,
            .overlook: overlookAnchor,
            .returnDawn: meadowAnchor
        ]

        return WorldHandle(
            scene: scene,
            rig: rig,
            cameraRig: cameraRig,
            cameraNode: cameraNode,
            parallaxPivot: parallaxPivot,
            regionAnchors: anchors,
            starGuide: star,
            builtForReduceMotion: reduceMotion
        )
    }

    // MARK: - Organic trees

    /// 5–7 overlapping crown spheres in four shades over a tapered trunk.
    private static func makeOrganicTree(rng: inout WorldSeededRandom,
                                        crowns: [SCNMaterial]) -> SCNNode {
        let root = SCNNode()
        let scale = Float(rng.range(0.85, 1.25))
        let trunkHeight = Float(rng.range(1.2, 1.8)) * scale

        // Tapered trunk: cone from 0.12 → 0.08.
        let trunk = SCNCone(topRadius: 0.08, bottomRadius: 0.12, height: CGFloat(trunkHeight))
        trunk.radialSegmentCount = 10
        trunk.firstMaterial = WorldMaterials.flat(WorldPalette.trunk)
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, trunkHeight / 2, 0)
        root.addChildNode(trunkNode)

        // Main crown.
        let crownBaseY = trunkHeight + 0.35 * scale
        let main = SCNSphere(radius: CGFloat(rng.range(0.9, 1.1)) * CGFloat(scale))
        main.segmentCount = 10
        main.firstMaterial = crowns[0]
        let mainNode = SCNNode(geometry: main)
        mainNode.position = SCNVector3(0, crownBaseY, 0)
        root.addChildNode(mainNode)

        // 4–6 sub-clusters at fixed seeded offsets, cycling the shades.
        let subCount = 4 + Int(rng.range(0, 2.99))
        for i in 0..<subCount {
            let sub = SCNSphere(radius: CGFloat(rng.range(0.4, 0.7)) * CGFloat(scale))
            sub.segmentCount = 8
            sub.firstMaterial = crowns[(i + 1) % crowns.count]
            let subNode = SCNNode(geometry: sub)
            let a = rng.range(0, 6.28)
            let d = Float(rng.range(0.3, 0.7)) * scale
            subNode.position = SCNVector3(
                cos(Float(a)) * d,
                crownBaseY + Float(rng.range(-0.25, 0.45)) * scale,
                sin(Float(a)) * d
            )
            root.addChildNode(subNode)
        }
        return root
    }

    private static func addSoilPatch(under tree: SCNNode, into parent: SCNNode,
                                     rng: inout WorldSeededRandom) {
        let patch = SCNCylinder(radius: CGFloat(rng.range(0.4, 0.6)), height: 0.02)
        patch.radialSegmentCount = 12
        patch.firstMaterial = WorldMaterials.flat(WorldPalette.soil)
        let node = SCNNode(geometry: patch)
        node.position = SCNVector3(tree.position.x, 0.012, tree.position.z)
        node.castsShadow = false
        parent.addChildNode(node)
    }

    // MARK: - Ground detail

    private static func scatterGrass(into parent: SCNNode, around center: SCNVector3,
                                     count: Int, spread: Double,
                                     materials: [SCNMaterial], rng: inout WorldSeededRandom) {
        for i in 0..<count {
            let tuft = SCNNode()
            for k in 0..<2 {
                let blade = SCNPlane(width: 0.05, height: CGFloat(rng.range(0.12, 0.18)))
                blade.firstMaterial = materials[i % materials.count]
                let bladeNode = SCNNode(geometry: blade)
                bladeNode.position = SCNVector3(0, Float(blade.height) / 2, 0)
                bladeNode.eulerAngles.y = Float(k) * .pi / 2 + Float(rng.range(-0.3, 0.3))
                bladeNode.castsShadow = false
                tuft.addChildNode(bladeNode)
            }
            // Clustered placement — tufts gather in patches, not a grid.
            let clusterA = rng.range(0, 6.28)
            let clusterR = rng.range(0.5, spread)
            tuft.position = SCNVector3(
                center.x + Float(cos(clusterA) * clusterR + rng.range(-0.3, 0.3)),
                0,
                center.z + Float(sin(clusterA) * clusterR + rng.range(-0.3, 0.3))
            )
            parent.addChildNode(tuft)
        }
    }

    private static func scatterPebbles(into parent: SCNNode, rng: inout WorldSeededRandom) {
        let centers = [meadowCenter, pondCenter, groveCenter]
        for center in centers {
            for _ in 0..<8 {
                let pebble = SCNSphere(radius: CGFloat(rng.range(0.04, 0.08)))
                pebble.segmentCount = 6
                pebble.firstMaterial = WorldMaterials.flat(
                    rng.next() > 0.5 ? WorldPalette.rock : WorldPalette.rockShade
                )
                let node = SCNNode(geometry: pebble)
                node.scale = SCNVector3(1.2, 0.7, 1.0)
                let a = rng.range(0, 6.28)
                let r = rng.range(1.0, 5.0)
                node.position = SCNVector3(
                    center.x + Float(cos(a) * r),
                    0.03,
                    center.z + Float(sin(a) * r)
                )
                node.castsShadow = false
                parent.addChildNode(node)
            }
        }
    }

    /// Max 16 tiny flower dots, scattered naturally across the regions.
    private static func scatterFlowerDots(into parent: SCNNode, rng: inout WorldSeededRandom) {
        let colors: [UIColor] = [
            WorldPalette.flowerPeach, WorldPalette.flowerLavender,
            WorldPalette.flowerYellow, WorldPalette.flowerWhite
        ]
        let centers = [meadowCenter, meadowCenter, pondCenter, groveCenter]
        for i in 0..<16 {
            let dot = SCNPlane(width: 0.08, height: 0.08)
            dot.cornerRadius = 0.04
            dot.firstMaterial = WorldMaterials.unlit(colors[i % colors.count])
            let node = SCNNode(geometry: dot)
            let center = centers[i % centers.count]
            let a = rng.range(0, 6.28)
            let r = rng.range(1.0, 5.5)
            node.position = SCNVector3(
                center.x + Float(cos(a) * r),
                Float(rng.range(0.05, 0.1)),
                center.z + Float(sin(a) * r)
            )
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            node.constraints = [billboard]
            node.castsShadow = false
            parent.addChildNode(node)
        }
    }

    // MARK: - Volumetric clouds

    /// 6–9 overlapping white spheres: a 3-sphere body row + 3–4 top puffs,
    /// with a faint shadow ellipse dropped to the ground below.
    private static func makeVolumetricCloud(rng: inout WorldSeededRandom,
                                            groundDrop: Float) -> SCNNode {
        let cloud = SCNNode()
        let material = WorldMaterials.unlit(WorldPalette.cloud)

        // Body row.
        for i in 0..<3 {
            let geo = SCNSphere(radius: CGFloat(rng.range(0.6, 0.9)))
            geo.segmentCount = 8
            geo.firstMaterial = material
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(Float(i - 1) * 0.85, 0, Float(rng.range(-0.1, 0.1)))
            node.castsShadow = false
            cloud.addChildNode(node)
        }
        // Top puffs.
        let puffCount = 3 + Int(rng.range(0, 1.99))
        for _ in 0..<puffCount {
            let geo = SCNSphere(radius: CGFloat(rng.range(0.35, 0.55)))
            geo.segmentCount = 8
            geo.firstMaterial = material
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float(rng.range(-0.8, 0.8)),
                Float(rng.range(0.35, 0.6)),
                Float(rng.range(-0.15, 0.15))
            )
            node.castsShadow = false
            cloud.addChildNode(node)
        }

        // Faint ground shadow that travels with the cloud.
        let shadowGeo = SCNPlane(width: 2.6, height: 1.4)
        shadowGeo.cornerRadius = 0.7
        let shadowM = SCNMaterial()
        shadowM.diffuse.contents = UIColor(white: 0, alpha: 0.06)
        shadowM.lightingModel = .constant
        shadowM.writesToDepthBuffer = false
        shadowGeo.firstMaterial = shadowM
        let shadow = SCNNode(geometry: shadowGeo)
        shadow.eulerAngles.x = -.pi / 2
        shadow.position = SCNVector3(0, -groundDrop + 0.02, 0)
        shadow.castsShadow = false
        cloud.addChildNode(shadow)

        cloud.castsShadow = false
        return cloud
    }

    // MARK: - Realistic birds

    /// Elongated charcoal body, thin wings hinged at the root — they sweep
    /// UP above the body then DOWN, a real flap, not a scale trick.
    private static func makeRealisticBird(height: Float, radius: Float,
                                          duration: TimeInterval, phase: Float) -> SCNNode {
        let orbit = SCNNode()
        orbit.position = SCNVector3(0, height, -6)
        orbit.eulerAngles.y = phase

        let bird = SCNNode()
        bird.position = SCNVector3(radius, 0, 0)
        bird.eulerAngles.y = .pi / 2

        let bodyGeo = SCNSphere(radius: 0.1)
        bodyGeo.segmentCount = 8
        bodyGeo.firstMaterial = WorldMaterials.flat(WorldPalette.birdInk)
        let body = SCNNode(geometry: bodyGeo)
        body.scale = SCNVector3(2.5, 0.4, 0.6)
        bird.addChildNode(body)

        for side in [Float(-1), Float(1)] {
            let wingGeo = SCNBox(width: 0.42, height: 0.012, length: 0.15, chamferRadius: 0.005)
            wingGeo.firstMaterial = WorldMaterials.flat(WorldPalette.birdInk)
            let wing = SCNNode(geometry: wingGeo)
            // Hinge at the wing root, beside the body.
            wing.pivot = SCNMatrix4MakeTranslation(side * -0.21, 0, 0)
            wing.position = SCNVector3(side * 0.05, 0.02, 0)

            // Real flap: sweep up past the body, then down and back.
            let upAngle = CGFloat(side) * 0.9     // wings rise ABOVE the body
            let downAngle = CGFloat(side) * -0.55
            let up = SCNAction.rotateTo(x: 0, y: 0, z: upAngle, duration: 0.22, usesShortestUnitArc: true)
            up.timingMode = .easeOut
            let down = SCNAction.rotateTo(x: 0, y: 0, z: downAngle, duration: 0.3, usesShortestUnitArc: true)
            down.timingMode = .easeIn
            wing.runAction(.repeatForever(.sequence([up, down])))
            bird.addChildNode(wing)
        }

        orbit.addChildNode(bird)
        orbit.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: duration)))
        return orbit
    }
}
