//
//  GardenSceneBuilder.swift
//  Dino
//
//  Builds the full low-poly garden scene graph: rolling terrain, trees,
//  rocks, bushes, pond, sunflower, camera, lights. All randomness is
//  seeded with a fixed constant so the garden is identical every launch.
//  Total triangle budget: well under 15k.
//

import SceneKit
import UIKit

/// Deterministic xorshift RNG — fixed seed gives the same garden every build.
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
    let builtForReduceMotion: Bool

    init(scene: SCNScene, sunflower: SunflowerNode, rig: GardenLighting.Rig,
         cameraPivot: SCNNode, particleAnchor: SCNNode, builtForReduceMotion: Bool) {
        self.scene = scene
        self.sunflower = sunflower
        self.rig = rig
        self.cameraPivot = cameraPivot
        self.particleAnchor = particleAnchor
        self.builtForReduceMotion = builtForReduceMotion
    }
}

enum GardenSceneBuilder {

    private static let seed: UInt64 = 20_260_610

    static func build(reduceMotion: Bool) -> GardenSceneHandle {
        let scene = SCNScene()
        var rng = GardenSeededRandom(seed: seed)

        // Terrain
        let terrain = makeTerrain()
        scene.rootNode.addChildNode(terrain)

        // Trees (4, seeded positions around the rim)
        let treeAngles: [Double] = [0.7, 2.3, 3.7, 5.3]
        for angle in treeAngles {
            let radius = rng.range(5.4, 8.0)
            let tree = makeTree(rng: &rng)
            tree.position = SCNVector3(
                Float(cos(angle) * radius),
                0,
                Float(sin(angle) * radius) - 1.5
            )
            scene.rootNode.addChildNode(tree)
        }

        // Rocks (5)
        for _ in 0..<5 {
            let rock = makeRock(rng: &rng)
            let angle = rng.range(0, 2 * .pi)
            let radius = rng.range(2.2, 6.5)
            rock.position = SCNVector3(
                Float(cos(angle) * radius),
                0.04,
                Float(sin(angle) * radius) - 1.0
            )
            scene.rootNode.addChildNode(rock)
        }

        // Bushes (4)
        for _ in 0..<4 {
            let bush = makeBush(rng: &rng)
            let angle = rng.range(0, 2 * .pi)
            let radius = rng.range(3.0, 7.0)
            bush.position = SCNVector3(
                Float(cos(angle) * radius),
                0,
                Float(sin(angle) * radius) - 1.2
            )
            scene.rootNode.addChildNode(bush)
        }

        // Pond (front-right, flat disc with shimmer)
        let pondGeo = SCNCylinder(radius: 1.7, height: 0.04)
        pondGeo.radialSegmentCount = 18
        pondGeo.firstMaterial = GardenMaterials.pond(shimmer: !reduceMotion)
        let pond = SCNNode(geometry: pondGeo)
        pond.position = SCNVector3(2.6, 0.05, 1.4)
        scene.rootNode.addChildNode(pond)

        // Sunflower at center
        let sunflower = SunflowerNode()
        sunflower.position = SCNVector3(0, 0.05, 0)
        scene.rootNode.addChildNode(sunflower)

        // Lighting rig
        let rig = GardenLighting.makeRig()
        scene.rootNode.addChildNode(rig.sunNode)
        scene.rootNode.addChildNode(rig.ambientNode)
        scene.rootNode.addChildNode(rig.moonNode)

        // Camera: pivot at garden center; camera looks at the sunflower.
        let cameraPivot = SCNNode()
        cameraPivot.position = SCNVector3(0, 1.0, 0)

        let camera = SCNCamera()
        camera.fieldOfView = 48
        camera.zNear = 0.1
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.5, 6.4)

        let lookTarget = SCNNode()
        lookTarget.position = SCNVector3(0, 0.9, 0)
        scene.rootNode.addChildNode(lookTarget)

        let look = SCNLookAtConstraint(target: lookTarget)
        look.isGimbalLockEnabled = true
        cameraNode.constraints = [look]

        cameraPivot.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraPivot)

        // Particle anchor (systems attached/removed by GardenSceneView)
        let particleAnchor = SCNNode()
        particleAnchor.position = SCNVector3(0, 1.2, 0)
        scene.rootNode.addChildNode(particleAnchor)

        return GardenSceneHandle(
            scene: scene,
            sunflower: sunflower,
            rig: rig,
            cameraPivot: cameraPivot,
            particleAnchor: particleAnchor,
            builtForReduceMotion: reduceMotion
        )
    }

    // MARK: - Terrain (flat-shaded displaced grid, ~1.1k triangles)

    private static func makeTerrain() -> SCNNode {
        let gridCount = 24            // 24x24 quads = 1152 triangles
        let extent: Float = 22        // world size
        let half = extent / 2
        let step = extent / Float(gridCount)

        var heightRng = GardenSeededRandom(seed: seed &+ 99)
        let p1 = Float(heightRng.range(0, 6.28))
        let p2 = Float(heightRng.range(0, 6.28))
        let p3 = Float(heightRng.range(0, 6.28))

        func height(_ x: Float, _ z: Float) -> Float {
            // Rolling hills from layered sines; flattened near the center
            // so the sunflower and pond sit on level ground.
            let rolling = 0.38 * sin(x * 0.45 + p1) * cos(z * 0.40 + p2)
                        + 0.16 * sin(x * 1.1 + p3) * sin(z * 0.9 + p1)
            let dist = sqrt(x * x + z * z)
            let flatten = min(1.0, max(0.0, (dist - 2.2) / 3.5))
            return rolling * flatten * flatten
        }

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []
        vertices.reserveCapacity(gridCount * gridCount * 6)

        func emitTriangle(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3) {
            // Per-face normal → flat-shaded low-poly look.
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

        for gx in 0..<gridCount {
            for gz in 0..<gridCount {
                let x0 = -half + Float(gx) * step
                let z0 = -half + Float(gz) * step
                let x1 = x0 + step
                let z1 = z0 + step

                let v00 = SCNVector3(x0, height(x0, z0), z0)
                let v10 = SCNVector3(x1, height(x1, z0), z0)
                let v01 = SCNVector3(x0, height(x0, z1), z1)
                let v11 = SCNVector3(x1, height(x1, z1), z1)

                emitTriangle(v00, v01, v10)
                emitTriangle(v10, v01, v11)
            }
        }

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        geometry.firstMaterial = GardenMaterials.flat(GardenPalette.grass)

        return SCNNode(geometry: geometry)
    }

    // MARK: - Props

    private static func makeTree(rng: inout GardenSeededRandom) -> SCNNode {
        let root = SCNNode()
        let scale = Float(rng.range(0.85, 1.25))

        let trunkHeight = CGFloat(1.0 * scale)
        let trunk = SCNCylinder(radius: 0.12, height: trunkHeight)
        trunk.radialSegmentCount = 7
        trunk.firstMaterial = GardenMaterials.flat(GardenPalette.bark)
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, Float(trunkHeight) / 2, 0)
        root.addChildNode(trunkNode)

        // 2-3 foliage blobs, slightly offset for irregularity.
        let blobCount = 2 + Int(rng.range(0, 1.99))
        for i in 0..<blobCount {
            let radius = CGFloat(rng.range(0.45, 0.75)) * CGFloat(scale)
            let blob = SCNSphere(radius: radius)
            blob.segmentCount = 8
            let color = (i % 2 == 0) ? GardenPalette.foliage : GardenPalette.foliageDeep
            blob.firstMaterial = GardenMaterials.flat(color)
            let blobNode = SCNNode(geometry: blob)
            blobNode.position = SCNVector3(
                Float(rng.range(-0.3, 0.3)),
                Float(trunkHeight) + Float(rng.range(0.0, 0.5)) * scale,
                Float(rng.range(-0.3, 0.3))
            )
            root.addChildNode(blobNode)
        }

        return root
    }

    private static func makeRock(rng: inout GardenSeededRandom) -> SCNNode {
        let geo = SCNSphere(radius: CGFloat(rng.range(0.14, 0.30)))
        geo.segmentCount = 6
        geo.firstMaterial = GardenMaterials.flat(
            rng.next() > 0.5 ? GardenPalette.rock : GardenPalette.rockDark
        )
        let node = SCNNode(geometry: geo)
        node.scale = SCNVector3(1.3, 0.55, 1.0)
        node.eulerAngles.y = Float(rng.range(0, 6.28))
        return node
    }

    private static func makeBush(rng: inout GardenSeededRandom) -> SCNNode {
        let root = SCNNode()
        for _ in 0..<3 {
            let geo = SCNSphere(radius: CGFloat(rng.range(0.22, 0.38)))
            geo.segmentCount = 7
            geo.firstMaterial = GardenMaterials.flat(GardenPalette.sage)
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(
                Float(rng.range(-0.25, 0.25)),
                Float(rng.range(0.10, 0.25)),
                Float(rng.range(-0.25, 0.25))
            )
            node.scale = SCNVector3(1.0, 0.75, 1.0)
            root.addChildNode(node)
        }
        return root
    }
}
