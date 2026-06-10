//
//  WorldBuilder.swift
//  Dino
//
//  Builds the single continuous low-poly onboarding world: meadow, pond,
//  grove, overlook hill — one scene graph, regions spaced along the camera
//  path. All randomness uses a fixed seed (same world every launch).
//  Triangle budget ≈ 10k (documented per region below), under the 25k cap.
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

/// Everything OnboardingWorldView needs to drive the scene.
/// Held by the representable's Coordinator — NOT a static — so the whole
/// scene releases when onboarding is dismissed.
final class WorldHandle {
    let scene: SCNScene
    let rig: WorldLighting.Rig
    let cameraRig: SCNNode          // moves along the journey
    let parallaxPivot: SCNNode      // gyro offsets, child of cameraRig
    let regionAnchors: [WorldRegion: SCNNode]
    let builtForReduceMotion: Bool

    init(scene: SCNScene, rig: WorldLighting.Rig, cameraRig: SCNNode,
         parallaxPivot: SCNNode, regionAnchors: [WorldRegion: SCNNode],
         builtForReduceMotion: Bool) {
        self.scene = scene
        self.rig = rig
        self.cameraRig = cameraRig
        self.parallaxPivot = parallaxPivot
        self.regionAnchors = regionAnchors
        self.builtForReduceMotion = builtForReduceMotion
    }
}

enum WorldBuilder {

    private static let seed: UInt64 = 11_2026

    // Region centers along the path (world coordinates).
    private static let meadowCenter = SCNVector3(0, 0, 0)
    private static let pondCenter = SCNVector3(-5, 0, -9.5)
    private static let groveCenter = SCNVector3(4.5, 0, -18.5)
    private static let overlookCenter = SCNVector3(0, 0, -29)

    static func build(reduceMotion: Bool) -> WorldHandle {
        let scene = SCNScene()
        var rng = WorldSeededRandom(seed: seed)
        let sway = !reduceMotion

        // Shared swaying materials — ONE material instance animates every
        // grass blade / tree crown via the geometry shader modifier.
        let grassMaterial = WorldMaterials.swaying(WorldPalette.sageDeep, sway: sway)
        let crownMaterial = WorldMaterials.swaying(WorldPalette.foliage, sway: sway)
        let crownDeepMaterial = WorldMaterials.swaying(WorldPalette.foliageDeep, sway: sway)

        // ── Terrain: one displaced flat-shaded grid spanning the whole path.
        //    32×24 quads = 1,536 triangles.
        scene.rootNode.addChildNode(makeTerrain())

        // ── THE MEADOW (≈ 2,700 tris: 4 trees, grass, wildflowers, rocks)
        let meadowAnchor = SCNNode()
        meadowAnchor.position = SCNVector3(meadowCenter.x, 1.2, meadowCenter.z)
        scene.rootNode.addChildNode(meadowAnchor)

        for angle in [0.8, 2.4, 4.0, 5.4] {
            let tree = makeTree(rng: &rng, crown: crownMaterial, crownDeep: crownDeepMaterial)
            let radius = rng.range(4.2, 6.5)
            tree.position = SCNVector3(
                Float(cos(angle) * radius) + meadowCenter.x,
                0,
                Float(sin(angle) * radius) + meadowCenter.z - 1.0
            )
            scene.rootNode.addChildNode(tree)
        }
        scatterGrass(into: scene.rootNode, around: meadowCenter, count: 18,
                     spread: 5.0, material: grassMaterial, rng: &rng)
        scatterFlowers(into: scene.rootNode, around: meadowCenter, count: 16, rng: &rng)
        scatterRocks(into: scene.rootNode, around: meadowCenter, count: 3, rng: &rng)

        // ── THE POND (≈ 700 tris: water disc, lilies, cattails)
        let pondAnchor = SCNNode()
        pondAnchor.position = SCNVector3(pondCenter.x, 0.8, pondCenter.z)
        scene.rootNode.addChildNode(pondAnchor)

        let waterGeo = SCNCylinder(radius: 2.6, height: 0.05)
        waterGeo.radialSegmentCount = 20
        waterGeo.firstMaterial = WorldMaterials.water(shimmer: sway)
        let water = SCNNode(geometry: waterGeo)
        water.position = SCNVector3(pondCenter.x, 0.05, pondCenter.z)
        scene.rootNode.addChildNode(water)

        for _ in 0..<5 {
            let pad = SCNCylinder(radius: CGFloat(rng.range(0.18, 0.32)), height: 0.03)
            pad.radialSegmentCount = 10
            pad.firstMaterial = WorldMaterials.flat(WorldPalette.lily)
            let padNode = SCNNode(geometry: pad)
            let a = rng.range(0, 6.28)
            let r = rng.range(0.6, 2.0)
            padNode.position = SCNVector3(
                pondCenter.x + Float(cos(a) * r),
                0.09,
                pondCenter.z + Float(sin(a) * r)
            )
            scene.rootNode.addChildNode(padNode)
        }

        for _ in 0..<7 {
            let stalk = SCNCylinder(radius: 0.02, height: CGFloat(rng.range(0.7, 1.1)))
            stalk.radialSegmentCount = 6
            stalk.firstMaterial = grassMaterial
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
            tip.firstMaterial = WorldMaterials.flat(WorldPalette.cattail)
            let tipNode = SCNNode(geometry: tip)
            tipNode.position = SCNVector3(0, h / 2 + 0.1, 0)
            stalkNode.addChildNode(tipNode)
            scene.rootNode.addChildNode(stalkNode)
        }

        // ── THE GROVE (≈ 2,400 tris: 7 trees, god rays, bushes)
        let groveAnchor = SCNNode()
        groveAnchor.position = SCNVector3(groveCenter.x, 1.5, groveCenter.z)
        scene.rootNode.addChildNode(groveAnchor)

        for i in 0..<7 {
            let tree = makeTree(rng: &rng, crown: crownMaterial, crownDeep: crownDeepMaterial)
            let a = Double(i) / 7.0 * 6.28 + rng.range(-0.3, 0.3)
            let r = rng.range(2.2, 5.0)
            tree.position = SCNVector3(
                groveCenter.x + Float(cos(a) * r),
                0,
                groveCenter.z + Float(sin(a) * r)
            )
            scene.rootNode.addChildNode(tree)
        }

        // God rays: translucent additive cones slanting through the canopy.
        for i in 0..<3 {
            let cone = SCNCone(topRadius: 0.25, bottomRadius: 1.1, height: 7)
            cone.radialSegmentCount = 10
            cone.firstMaterial = WorldMaterials.ray(WorldPalette.cream, alpha: 0.10)
            let rayNode = SCNNode(geometry: cone)
            rayNode.position = SCNVector3(
                groveCenter.x - 1.5 + Float(i) * 1.6,
                3.4,
                groveCenter.z + Float(i - 1) * 1.2
            )
            rayNode.eulerAngles = SCNVector3(0.18, 0, -0.22)
            scene.rootNode.addChildNode(rayNode)
        }
        scatterBushes(into: scene.rootNode, around: groveCenter, count: 3, rng: &rng)

        // ── THE OVERLOOK (≈ 250 tris on the ground; night sky lives in the rig)
        let overlookAnchor = SCNNode()
        overlookAnchor.position = SCNVector3(overlookCenter.x, 3.4, overlookCenter.z)
        scene.rootNode.addChildNode(overlookAnchor)
        scatterGrass(into: scene.rootNode, around: SCNVector3(0, 0, -26), count: 8,
                     spread: 3.0, material: grassMaterial, rng: &rng)
        scatterRocks(into: scene.rootNode, around: SCNVector3(0, 0, -27), count: 2, rng: &rng)

        // ── Birds: two slow circling birds over the meadow with wing flap.
        if !reduceMotion {
            scene.rootNode.addChildNode(makeBirdOrbit(height: 7.5, radius: 9, duration: 38, phase: 0))
            scene.rootNode.addChildNode(makeBirdOrbit(height: 6.2, radius: 11, duration: 47, phase: .pi))
        }

        // ── Lighting rig + sky domes + night group.
        let rig = WorldLighting.makeRig()
        scene.rootNode.addChildNode(rig.sunNode)
        scene.rootNode.addChildNode(rig.ambientNode)
        scene.rootNode.addChildNode(rig.dayDome)
        scene.rootNode.addChildNode(rig.nightDome)
        scene.rootNode.addChildNode(rig.nightGroup)

        // ── Camera: rig (journey pose) → parallax pivot (gyro) → camera.
        let cameraRig = SCNNode()
        let parallaxPivot = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 52
        camera.zNear = 0.1
        camera.zFar = 120
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        parallaxPivot.addChildNode(cameraNode)
        cameraRig.addChildNode(parallaxPivot)
        scene.rootNode.addChildNode(cameraRig)

        let start = CameraJourney.pose(for: 0)
        cameraRig.position = start.position
        cameraRig.eulerAngles = CameraJourney.eulerLooking(from: start.position, at: start.lookAt)

        let anchors: [WorldRegion: SCNNode] = [
            .meadow: meadowAnchor,
            .pond: pondAnchor,
            .grove: groveAnchor,
            .overlook: overlookAnchor
        ]

        return WorldHandle(
            scene: scene,
            rig: rig,
            cameraRig: cameraRig,
            parallaxPivot: parallaxPivot,
            regionAnchors: anchors,
            builtForReduceMotion: reduceMotion
        )
    }

    // MARK: - Terrain (≈ 1,536 tris, flat-shaded)

    private static func makeTerrain() -> SCNNode {
        let gridX = 32, gridZ = 24
        let sizeX: Float = 50, sizeZ: Float = 52
        let originX = -sizeX / 2, originZ: Float = 10   // path runs z 10 ... -42
        let stepX = sizeX / Float(gridX)
        let stepZ = sizeZ / Float(gridZ)

        var hrng = WorldSeededRandom(seed: seed &+ 7)
        let p1 = Float(hrng.range(0, 6.28))
        let p2 = Float(hrng.range(0, 6.28))

        func height(_ x: Float, _ z: Float) -> Float {
            var h = 0.45 * sin(x * 0.30 + p1) * cos(z * 0.22 + p2)
                  + 0.20 * sin(x * 0.85 + p2) * sin(z * 0.6 + p1)
            // Overlook hill crest rising toward the far end.
            let overlookDist = sqrt(pow(x - 0, 2) + pow(z - (-29), 2))
            h += 2.6 * exp(-pow(overlookDist / 7.5, 2))
            // Flatten the pond basin.
            let pondDist = sqrt(pow(x - (-5), 2) + pow(z - (-9.5), 2))
            h *= Float(min(1.0, max(0.15, (pondDist - 2.4) / 2.2 + 0.15)))
            // Keep the meadow start gentle.
            let meadowDist = sqrt(x * x + z * z)
            if meadowDist < 4 { h *= meadowDist / 4 }
            return h
        }

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []

        func emit(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3) {
            let u = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
            let v = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
            var n = SCNVector3(
                u.y * v.z - u.z * v.y,
                u.z * v.x - u.x * v.z,
                u.x * v.y - u.y * v.x
            )
            let len = max(0.0001, sqrt(n.x * n.x + n.y * n.y + n.z * n.z))
            n = SCNVector3(n.x / len, n.y / len, n.z / len)
            let base = Int32(vertices.count)
            vertices.append(contentsOf: [a, b, c])
            normals.append(contentsOf: [n, n, n])
            indices.append(contentsOf: [base, base + 1, base + 2])
        }

        for gx in 0..<gridX {
            for gz in 0..<gridZ {
                let x0 = originX + Float(gx) * stepX
                let z0 = originZ - Float(gz) * stepZ
                let x1 = x0 + stepX
                let z1 = z0 - stepZ
                let v00 = SCNVector3(x0, height(x0, z0), z0)
                let v10 = SCNVector3(x1, height(x1, z0), z0)
                let v01 = SCNVector3(x0, height(x0, z1), z1)
                let v11 = SCNVector3(x1, height(x1, z1), z1)
                emit(v00, v01, v10)
                emit(v10, v01, v11)
            }
        }

        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        geometry.firstMaterial = WorldMaterials.flat(WorldPalette.grass)
        return SCNNode(geometry: geometry)
    }

    // MARK: - Props

    private static func makeTree(rng: inout WorldSeededRandom,
                                 crown: SCNMaterial, crownDeep: SCNMaterial) -> SCNNode {
        let root = SCNNode()
        let scale = Float(rng.range(0.8, 1.3))

        let trunkHeight = CGFloat(1.1 * scale)
        let trunk = SCNCylinder(radius: 0.13, height: trunkHeight)
        trunk.radialSegmentCount = 7
        trunk.firstMaterial = WorldMaterials.flat(WorldPalette.bark)
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, Float(trunkHeight) / 2, 0)
        root.addChildNode(trunkNode)

        let blobCount = 2 + Int(rng.range(0, 1.99))
        for i in 0..<blobCount {
            let blob = SCNSphere(radius: CGFloat(rng.range(0.5, 0.85)) * CGFloat(scale))
            blob.segmentCount = 8
            blob.firstMaterial = (i % 2 == 0) ? crown : crownDeep
            let blobNode = SCNNode(geometry: blob)
            blobNode.position = SCNVector3(
                Float(rng.range(-0.35, 0.35)),
                Float(trunkHeight) + Float(rng.range(0.1, 0.6)) * scale,
                Float(rng.range(-0.35, 0.35))
            )
            root.addChildNode(blobNode)
        }
        return root
    }

    private static func scatterGrass(into parent: SCNNode, around center: SCNVector3,
                                     count: Int, spread: Double,
                                     material: SCNMaterial, rng: inout WorldSeededRandom) {
        for _ in 0..<count {
            let tuft = SCNNode()
            for _ in 0..<3 {
                let blade = SCNCone(topRadius: 0.0, bottomRadius: 0.035, height: CGFloat(rng.range(0.25, 0.45)))
                blade.radialSegmentCount = 4
                blade.firstMaterial = material
                let bladeNode = SCNNode(geometry: blade)
                bladeNode.position = SCNVector3(
                    Float(rng.range(-0.08, 0.08)),
                    Float(blade.height) / 2,
                    Float(rng.range(-0.08, 0.08))
                )
                bladeNode.eulerAngles.z = Float(rng.range(-0.2, 0.2))
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

    private static func scatterFlowers(into parent: SCNNode, around center: SCNVector3,
                                       count: Int, rng: inout WorldSeededRandom) {
        let colors: [UIColor] = [WorldPalette.peach, WorldPalette.lavender,
                                 WorldPalette.rose, WorldPalette.gold]
        for i in 0..<count {
            let stem = SCNCylinder(radius: 0.015, height: CGFloat(rng.range(0.18, 0.32)))
            stem.radialSegmentCount = 5
            stem.firstMaterial = WorldMaterials.flat(WorldPalette.sageDeep)
            let stemNode = SCNNode(geometry: stem)

            let head = SCNSphere(radius: 0.055)
            head.segmentCount = 6
            head.firstMaterial = WorldMaterials.flat(colors[i % colors.count])
            let headNode = SCNNode(geometry: head)
            headNode.position = SCNVector3(0, Float(stem.height) / 2 + 0.04, 0)
            stemNode.addChildNode(headNode)

            let a = rng.range(0, 6.28)
            let r = rng.range(1.0, 5.5)
            stemNode.position = SCNVector3(
                center.x + Float(cos(a) * r),
                Float(stem.height) / 2,
                center.z + Float(sin(a) * r)
            )
            parent.addChildNode(stemNode)
        }
    }

    private static func scatterRocks(into parent: SCNNode, around center: SCNVector3,
                                     count: Int, rng: inout WorldSeededRandom) {
        for _ in 0..<count {
            let rock = SCNSphere(radius: CGFloat(rng.range(0.16, 0.34)))
            rock.segmentCount = 6
            rock.firstMaterial = WorldMaterials.flat(
                rng.next() > 0.5 ? WorldPalette.rock : WorldPalette.rockDark
            )
            let node = SCNNode(geometry: rock)
            node.scale = SCNVector3(1.25, 0.55, 1.0)
            let a = rng.range(0, 6.28)
            let r = rng.range(1.5, 5.0)
            node.position = SCNVector3(
                center.x + Float(cos(a) * r),
                0.05,
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
                let blob = SCNSphere(radius: CGFloat(rng.range(0.22, 0.4)))
                blob.segmentCount = 7
                blob.firstMaterial = WorldMaterials.flat(WorldPalette.sage)
                let blobNode = SCNNode(geometry: blob)
                blobNode.position = SCNVector3(
                    Float(rng.range(-0.25, 0.25)),
                    Float(rng.range(0.1, 0.3)),
                    Float(rng.range(-0.25, 0.25))
                )
                blobNode.scale = SCNVector3(1, 0.75, 1)
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

    // MARK: - Birds (slow orbit + scaleY wing flap, meadow sky)

    private static func makeBirdOrbit(height: Float, radius: Float,
                                      duration: TimeInterval, phase: Float) -> SCNNode {
        let orbit = SCNNode()
        orbit.position = SCNVector3(0, height, -2)
        orbit.eulerAngles.y = phase

        let bird = SCNNode()
        bird.position = SCNVector3(radius, 0, 0)
        // Face along the direction of travel (tangent to the orbit).
        bird.eulerAngles.y = .pi / 2

        let bodyGeo = SCNCapsule(capRadius: 0.06, height: 0.28)
        bodyGeo.firstMaterial = WorldMaterials.flat(UIColor(white: 0.25, alpha: 1))
        let body = SCNNode(geometry: bodyGeo)
        body.eulerAngles.x = .pi / 2
        bird.addChildNode(body)

        for side in [Float(-1), Float(1)] {
            let wingGeo = SCNPlane(width: 0.34, height: 0.16)
            wingGeo.firstMaterial = {
                let m = WorldMaterials.flat(UIColor(white: 0.3, alpha: 1))
                m.isDoubleSided = true
                return m
            }()
            let wing = SCNNode(geometry: wingGeo)
            wing.pivot = SCNMatrix4MakeTranslation(side * -0.17, 0, 0)
            wing.position = SCNVector3(side * 0.05, 0.02, 0)
            wing.eulerAngles.x = -.pi / 2
            bird.addChildNode(wing)

            // Wing flap: scaleY oscillation per the design's bird-flap keyframe.
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
}
