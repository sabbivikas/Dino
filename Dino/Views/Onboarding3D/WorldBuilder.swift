//
//  WorldBuilder.swift
//  Dino
//
//  Builds the illustrated onboarding world: a flat bright ground plane with
//  smooth sphere-half hill mounds (no faceted terrain), round 12-segment
//  tree crowns, dozens of flower dots, drifting clouds, a faint rainbow,
//  butterflies, birds, sun disc + crescent moon (in the lighting rig).
//  Fixed seed — the same world every launch.
//
//  Triangle budget ≈ 16k of the 25k cap, itemized at each section.
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
    let cameraNode: SCNNode          // exposed so orthographicScale can animate
    let parallaxPivot: SCNNode
    let regionAnchors: [WorldRegion: SCNNode]
    let builtForReduceMotion: Bool

    init(scene: SCNScene, rig: WorldLighting.Rig, cameraRig: SCNNode,
         cameraNode: SCNNode, parallaxPivot: SCNNode,
         regionAnchors: [WorldRegion: SCNNode], builtForReduceMotion: Bool) {
        self.scene = scene
        self.rig = rig
        self.cameraRig = cameraRig
        self.cameraNode = cameraNode
        self.parallaxPivot = parallaxPivot
        self.regionAnchors = regionAnchors
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

        let grassBladeMaterial = WorldMaterials.verticalGradient(
            top: WorldPalette.grassTip, bottom: WorldPalette.grass, sway: animate
        )
        let crownMaterials = [
            WorldMaterials.swaying(WorldPalette.crown1, sway: animate),
            WorldMaterials.swaying(WorldPalette.crown2, sway: animate),
            WorldMaterials.swaying(WorldPalette.crown3, sway: animate),
            WorldMaterials.swaying(WorldPalette.crown4, sway: animate)
        ]

        // ── Ground: one big flat bright plane (2 tris) — the shadow receiver.
        let groundGeo = SCNPlane(width: 70, height: 80)
        groundGeo.firstMaterial = WorldMaterials.flat(WorldPalette.grass)
        let ground = SCNNode(geometry: groundGeo)
        ground.eulerAngles.x = -.pi / 2
        ground.position = SCNVector3(0, 0, -13)
        ground.castsShadow = false
        scene.rootNode.addChildNode(ground)

        // ── Path: warm cream strip wandering down the world (≈10 tris).
        let pathGeo = SCNPlane(width: 1.6, height: 46)
        pathGeo.firstMaterial = WorldMaterials.flat(WorldPalette.path)
        let path = SCNNode(geometry: pathGeo)
        path.eulerAngles.x = -.pi / 2
        path.position = SCNVector3(0.3, 0.01, -12)
        path.castsShadow = false
        scene.rootNode.addChildNode(path)

        // ── Hills: smooth sphere halves, far mint / near rich green.
        //    10 mounds × 12-seg ≈ 1,500 tris.
        let hillSpecs: [(x: Float, z: Float, r: CGFloat, far: Bool)] = [
            (-12, -6, 5.0, true), (13, -10, 6.0, true), (-14, -24, 6.5, true),
            (14, -28, 5.5, true), (-9, -38, 7.0, true), (9, -40, 6.0, true),
            (-7, 3, 2.6, false), (8, -3, 3.0, false), (-9, -14, 2.8, false),
            (9, -22, 2.6, false)
        ]
        for spec in hillSpecs {
            let mound = SCNSphere(radius: spec.r)
            mound.segmentCount = 12
            mound.firstMaterial = WorldMaterials.flat(
                spec.far ? WorldPalette.hillFar : WorldPalette.hillNear
            )
            let node = SCNNode(geometry: mound)
            node.position = SCNVector3(spec.x, Float(-spec.r) * 0.62, spec.z)
            node.scale = SCNVector3(1.0, 0.85, 1.0)
            node.castsShadow = false
            scene.rootNode.addChildNode(node)
        }
        // The overlook crest itself — a big smooth mound under the camera path.
        let crest = SCNSphere(radius: 9)
        crest.segmentCount = 14
        crest.firstMaterial = WorldMaterials.flat(WorldPalette.hillNear)
        let crestNode = SCNNode(geometry: crest)
        crestNode.position = SCNVector3(overlookCenter.x, -6.2, overlookCenter.z)
        crestNode.castsShadow = false
        scene.rootNode.addChildNode(crestNode)

        // ── THE MEADOW (≈ 4.5k tris: 4 round trees, grass, flower dots, rocks)
        let meadowAnchor = SCNNode()
        meadowAnchor.position = SCNVector3(meadowCenter.x, 1.2, meadowCenter.z)
        scene.rootNode.addChildNode(meadowAnchor)

        for (i, angle) in [0.8, 2.4, 4.0, 5.4].enumerated() {
            let tree = makeTree(rng: &rng, crown: crownMaterials[i % crownMaterials.count])
            let radius = rng.range(4.2, 6.5)
            tree.position = SCNVector3(
                Float(cos(angle) * radius) + meadowCenter.x,
                0,
                Float(sin(angle) * radius) + meadowCenter.z - 1.0
            )
            scene.rootNode.addChildNode(tree)
        }
        scatterGrassBlades(into: scene.rootNode, around: meadowCenter, count: 22,
                           spread: 5.5, material: grassBladeMaterial, rng: &rng)
        scatterFlowerDots(into: scene.rootNode, around: meadowCenter, count: 36,
                          spread: 6.5, rng: &rng)
        scatterRocks(into: scene.rootNode, around: meadowCenter, count: 3, rng: &rng)

        // Rainbow: three nested translucent arcs (lower halves under ground).
        // 3 tori × ≈ 288 tris ≈ 0.9k.
        let rainbowColors: [UIColor] = [
            WorldPalette.flowerPeach, WorldPalette.flowerYellow, WorldPalette.skyMeadowTop
        ]
        for (i, color) in rainbowColors.enumerated() {
            let torus = SCNTorus(ringRadius: CGFloat(6.5 + Double(i) * 0.45), pipeRadius: 0.18)
            torus.ringSegmentCount = 24
            torus.pipeSegmentCount = 6
            torus.firstMaterial = WorldMaterials.tint(color, alpha: 0.3)
            let arc = SCNNode(geometry: torus)
            arc.position = SCNVector3(-2, 0, -8)            // center at ground → arc above
            arc.eulerAngles.x = .pi / 2                      // stand the ring upright
            arc.castsShadow = false
            scene.rootNode.addChildNode(arc)
        }

        // ── THE POND (≈ 800 tris)
        let pondAnchor = SCNNode()
        pondAnchor.position = SCNVector3(pondCenter.x, 0.8, pondCenter.z)
        scene.rootNode.addChildNode(pondAnchor)

        let waterGeo = SCNCylinder(radius: 2.6, height: 0.05)
        waterGeo.radialSegmentCount = 24
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
                0.09,
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
            stalkNode.castsShadow = false
            scene.rootNode.addChildNode(stalkNode)
        }

        // ── THE GROVE (≈ 5.5k tris: 6 round trees, warm god rays, bushes, dots)
        let groveAnchor = SCNNode()
        groveAnchor.position = SCNVector3(groveCenter.x, 1.5, groveCenter.z)
        scene.rootNode.addChildNode(groveAnchor)

        for i in 0..<6 {
            let tree = makeTree(rng: &rng, crown: crownMaterials[i % crownMaterials.count])
            let a = Double(i) / 6.0 * 6.28 + rng.range(-0.3, 0.3)
            let r = rng.range(2.2, 5.0)
            tree.position = SCNVector3(
                groveCenter.x + Float(cos(a) * r),
                0,
                groveCenter.z + Float(sin(a) * r)
            )
            scene.rootNode.addChildNode(tree)
        }

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
        scatterBushes(into: scene.rootNode, around: groveCenter, count: 3, rng: &rng)
        scatterFlowerDots(into: scene.rootNode, around: groveCenter, count: 14,
                          spread: 5.0, rng: &rng)

        // ── THE OVERLOOK (ground props only — the night sky lives in the rig)
        let overlookAnchor = SCNNode()
        overlookAnchor.position = SCNVector3(overlookCenter.x, 3.4, overlookCenter.z)
        scene.rootNode.addChildNode(overlookAnchor)
        scatterGrassBlades(into: scene.rootNode, around: SCNVector3(0, 0, -26), count: 8,
                           spread: 3.0, material: grassBladeMaterial, rng: &rng)

        // ── Clouds: 4 flat white sphere-clusters drifting at different
        //    heights/speeds (≈ 1.6k tris). Static under reduce-motion.
        let cloudSpecs: [(y: Float, z: Float, scale: Float, duration: TimeInterval)] = [
            (10.5, -20, 1.0, 70), (12.5, -28, 1.4, 95), (9.0, -8, 0.8, 60), (13.5, -36, 1.2, 110)
        ]
        for (i, spec) in cloudSpecs.enumerated() {
            let cloud = makeCloud(rng: &rng)
            cloud.scale = SCNVector3(spec.scale, spec.scale, spec.scale)
            let startX: Float = -18 + Float(i) * 9
            cloud.position = SCNVector3(startX, spec.y, spec.z)
            if animate {
                let drift = SCNAction.sequence([
                    .moveBy(x: 36, y: 0, z: 0, duration: spec.duration),
                    .run { node in node.position.x = -18 }
                ])
                cloud.runAction(.repeatForever(drift))
            }
            scene.rootNode.addChildNode(cloud)
        }

        // ── Life: birds over the meadow, butterflies among the flowers.
        if animate {
            scene.rootNode.addChildNode(makeBirdOrbit(height: 7.5, radius: 9, duration: 38, phase: 0))
            scene.rootNode.addChildNode(makeBirdOrbit(height: 6.2, radius: 11, duration: 47, phase: .pi))
            scene.rootNode.addChildNode(makeButterfly(around: SCNVector3(1.5, 1.0, 1.0),
                                                      wingColor: WorldPalette.flowerPeach))
            scene.rootNode.addChildNode(makeButterfly(around: SCNVector3(-2.0, 0.8, -1.5),
                                                      wingColor: WorldPalette.flowerLavender))
        }

        // ── Lighting rig: ambient, sun, 5 sky domes, night group, sun disc.
        let rig = WorldLighting.makeRig()
        scene.rootNode.addChildNode(rig.sunNode)
        scene.rootNode.addChildNode(rig.ambientNode)
        for (_, dome) in rig.domes {
            scene.rootNode.addChildNode(dome)
        }
        scene.rootNode.addChildNode(rig.nightGroup)
        scene.rootNode.addChildNode(rig.sunDisc)

        // ── Camera: orthographic, slight down-tilt — the illustrated flattener.
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

        let anchors: [WorldRegion: SCNNode] = [
            .meadow: meadowAnchor,
            .pond: pondAnchor,
            .grove: groveAnchor,
            .overlook: overlookAnchor,
            .returnDawn: meadowAnchor   // the dawn return reuses the meadow anchor
        ]

        return WorldHandle(
            scene: scene,
            rig: rig,
            cameraRig: cameraRig,
            cameraNode: cameraNode,
            parallaxPivot: parallaxPivot,
            regionAnchors: anchors,
            builtForReduceMotion: reduceMotion
        )
    }

    // MARK: - Props

    /// Round illustrated tree: 12-segment crowns (smooth, not faceted),
    /// warm trunk. ≈ 900 tris each.
    private static func makeTree(rng: inout WorldSeededRandom, crown: SCNMaterial) -> SCNNode {
        let root = SCNNode()
        let scale = Float(rng.range(0.8, 1.3))

        let trunkHeight = CGFloat(1.1 * scale)
        let trunk = SCNCylinder(radius: 0.14, height: trunkHeight)
        trunk.radialSegmentCount = 10
        trunk.firstMaterial = WorldMaterials.flat(WorldPalette.trunk)
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, Float(trunkHeight) / 2, 0)
        root.addChildNode(trunkNode)

        let blobCount = 2 + Int(rng.range(0, 1.99))
        for _ in 0..<blobCount {
            let blob = SCNSphere(radius: CGFloat(rng.range(0.55, 0.9)) * CGFloat(scale))
            blob.segmentCount = 12
            blob.firstMaterial = crown
            let blobNode = SCNNode(geometry: blob)
            blobNode.position = SCNVector3(
                Float(rng.range(-0.35, 0.35)),
                Float(trunkHeight) + Float(rng.range(0.15, 0.65)) * scale,
                Float(rng.range(-0.35, 0.35))
            )
            root.addChildNode(blobNode)
        }
        return root
    }

    /// Thin flat grass blades with lighter tips — crossed plane pairs.
    private static func scatterGrassBlades(into parent: SCNNode, around center: SCNVector3,
                                           count: Int, spread: Double,
                                           material: SCNMaterial, rng: inout WorldSeededRandom) {
        for _ in 0..<count {
            let tuft = SCNNode()
            for k in 0..<2 {
                let blade = SCNPlane(width: 0.22, height: CGFloat(rng.range(0.3, 0.5)))
                blade.firstMaterial = material
                let bladeNode = SCNNode(geometry: blade)
                bladeNode.position = SCNVector3(0, Float(blade.height) / 2, 0)
                bladeNode.eulerAngles.y = Float(k) * .pi / 2 + Float(rng.range(-0.3, 0.3))
                bladeNode.castsShadow = false
                tuft.addChildNode(bladeNode)
            }
            let a = rng.range(0, 6.28)
            let r = rng.range(0.8, spread)
            tuft.position = SCNVector3(
                center.x + Float(cos(a) * r),
                0,
                center.z + Float(sin(a) * r)
            )
            parent.addChildNode(tuft)
        }
    }

    /// Dozens of bright flower dots — flat billboarded discs, no geometry
    /// detail. The cheap richness that makes the world read illustrated.
    private static func scatterFlowerDots(into parent: SCNNode, around center: SCNVector3,
                                          count: Int, spread: Double,
                                          rng: inout WorldSeededRandom) {
        let colors: [UIColor] = [
            WorldPalette.flowerPeach, WorldPalette.flowerLavender,
            WorldPalette.flowerYellow, WorldPalette.flowerWhite
        ]
        for i in 0..<count {
            let dot = SCNPlane(width: 0.14, height: 0.14)
            dot.cornerRadius = 0.07   // circular disc
            dot.firstMaterial = WorldMaterials.unlit(colors[i % colors.count])
            let node = SCNNode(geometry: dot)
            let a = rng.range(0, 6.28)
            let r = rng.range(0.8, spread)
            node.position = SCNVector3(
                center.x + Float(cos(a) * r),
                Float(rng.range(0.06, 0.16)),
                center.z + Float(sin(a) * r)
            )
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            node.constraints = [billboard]
            node.castsShadow = false
            parent.addChildNode(node)
        }
    }

    private static func scatterRocks(into parent: SCNNode, around center: SCNVector3,
                                     count: Int, rng: inout WorldSeededRandom) {
        for _ in 0..<count {
            let rock = SCNSphere(radius: CGFloat(rng.range(0.18, 0.36)))
            rock.segmentCount = 12   // smooth egg, not faceted
            rock.firstMaterial = WorldMaterials.flat(
                rng.next() > 0.5 ? WorldPalette.rock : WorldPalette.rockShade
            )
            let node = SCNNode(geometry: rock)
            node.scale = SCNVector3(1.25, 0.8, 1.0)
            let a = rng.range(0, 6.28)
            let r = rng.range(1.5, 5.0)
            node.position = SCNVector3(
                center.x + Float(cos(a) * r),
                0.06,
                center.z + Float(sin(a) * r)
            )
            parent.addChildNode(node)
        }
    }

    private static func scatterBushes(into parent: SCNNode, around center: SCNVector3,
                                      count: Int, rng: inout WorldSeededRandom) {
        for _ in 0..<count {
            let bush = SCNNode()
            for _ in 0..<3 {
                let blob = SCNSphere(radius: CGFloat(rng.range(0.24, 0.42)))
                blob.segmentCount = 10
                blob.firstMaterial = WorldMaterials.flat(WorldPalette.bush)
                let blobNode = SCNNode(geometry: blob)
                blobNode.position = SCNVector3(
                    Float(rng.range(-0.25, 0.25)),
                    Float(rng.range(0.1, 0.3)),
                    Float(rng.range(-0.25, 0.25))
                )
                blobNode.scale = SCNVector3(1, 0.78, 1)
                bush.addChildNode(blobNode)
            }
            let a = rng.range(0, 6.28)
            let r = rng.range(1.8, 4.5)
            bush.position = SCNVector3(
                center.x + Float(cos(a) * r),
                0,
                center.z + Float(sin(a) * r)
            )
            parent.addChildNode(bush)
        }
    }

    /// Pure-white rounded cloud cluster (4 unlit spheres, no shadows).
    private static func makeCloud(rng: inout WorldSeededRandom) -> SCNNode {
        let cloud = SCNNode()
        let material = WorldMaterials.unlit(WorldPalette.cloud)
        let blobs: [(Float, Float, CGFloat)] = [
            (0, 0, 0.9), (-0.9, -0.1, 0.65), (0.9, -0.1, 0.7), (0.2, 0.4, 0.6)
        ]
        for blob in blobs {
            let geo = SCNSphere(radius: blob.2)
            geo.segmentCount = 10
            geo.firstMaterial = material
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(blob.0 + Float(rng.range(-0.1, 0.1)),
                                       blob.1, 0)
            node.castsShadow = false
            cloud.addChildNode(node)
        }
        cloud.castsShadow = false
        return cloud
    }

    // MARK: - Life

    private static func makeBirdOrbit(height: Float, radius: Float,
                                      duration: TimeInterval, phase: Float) -> SCNNode {
        let orbit = SCNNode()
        orbit.position = SCNVector3(0, height, -2)
        orbit.eulerAngles.y = phase

        let bird = SCNNode()
        bird.position = SCNVector3(radius, 0, 0)
        bird.eulerAngles.y = .pi / 2

        let bodyGeo = SCNCapsule(capRadius: 0.06, height: 0.28)
        bodyGeo.firstMaterial = WorldMaterials.flat(UIColor(white: 0.25, alpha: 1))
        let body = SCNNode(geometry: bodyGeo)
        body.eulerAngles.x = .pi / 2
        bird.addChildNode(body)

        for side in [Float(-1), Float(1)] {
            let wingGeo = SCNPlane(width: 0.34, height: 0.16)
            wingGeo.firstMaterial = WorldMaterials.flat(UIColor(white: 0.3, alpha: 1))
            let wing = SCNNode(geometry: wingGeo)
            wing.pivot = SCNMatrix4MakeTranslation(side * -0.17, 0, 0)
            wing.position = SCNVector3(side * 0.05, 0.02, 0)
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

    /// Butterfly: two bright flat wing planes on a wandering figure-8-ish
    /// path (nested counter-rotations) with a scaleY wing flap.
    private static func makeButterfly(around center: SCNVector3, wingColor: UIColor) -> SCNNode {
        let outer = SCNNode()
        outer.position = center

        let inner = SCNNode()
        inner.position = SCNVector3(0.9, 0, 0)
        outer.addChildNode(inner)

        let butterfly = SCNNode()
        inner.addChildNode(butterfly)

        let bodyGeo = SCNCapsule(capRadius: 0.018, height: 0.12)
        bodyGeo.firstMaterial = WorldMaterials.flat(UIColor(white: 0.25, alpha: 1))
        let body = SCNNode(geometry: bodyGeo)
        butterfly.addChildNode(body)

        for side in [Float(-1), Float(1)] {
            let wingGeo = SCNPlane(width: 0.14, height: 0.11)
            wingGeo.cornerRadius = 0.05
            wingGeo.firstMaterial = WorldMaterials.unlit(wingColor)
            let wing = SCNNode(geometry: wingGeo)
            wing.pivot = SCNMatrix4MakeTranslation(side * -0.07, 0, 0)
            wing.position = SCNVector3(side * 0.02, 0.02, 0)
            wing.eulerAngles.x = -.pi / 2.4
            butterfly.addChildNode(wing)

            let flap = SCNAction.customAction(duration: 0.45) { node, elapsed in
                let f = 0.3 + 0.7 * abs(sin(Float(elapsed) * 2 * .pi / 0.45))
                node.scale = SCNVector3(1, f, 1)
            }
            wing.runAction(.repeatForever(flap))
        }

        // Nested counter-rotations trace a slow wandering loop (figure-8 feel).
        outer.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 14)))
        inner.runAction(.repeatForever(.rotateBy(x: 0, y: -4 * .pi, z: 0, duration: 14)))
        let bob = SCNAction.sequence([
            .moveBy(x: 0, y: 0.25, z: 0, duration: 1.3),
            .moveBy(x: 0, y: -0.25, z: 0, duration: 1.3)
        ])
        bob.timingMode = .easeInEaseOut
        butterfly.runAction(.repeatForever(bob))

        return outer
    }
}
