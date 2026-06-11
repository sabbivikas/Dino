//
//  GardenSceneBuilder.swift
//  Dino
//
//  The explorable 40×40 garden world. The sunflower lives at the center;
//  four discovery regions surround it — orchard (north), pond (east),
//  meadow (west), forest edge (south) — populated lazily as the camera
//  approaches AND as the plant grows (growth stage gates which regions
//  exist at all). Orthographic camera on a pannable rig. Fixed seeds:
//  the same world every launch. Tree crowns carry distance LODs.
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

/// The discoverable regions of the world.
enum GardenRegion: CaseIterable {
    case orchard   // north (-z)
    case pond      // east  (+x)
    case meadow    // west  (-x)
    case forest    // south (+z)

    var center: SCNVector3 {
        switch self {
        case .orchard: return SCNVector3(0, 0, -12)
        case .pond:    return SCNVector3(12, 0, 0)
        case .meadow:  return SCNVector3(-12, 0, 0)
        case .forest:  return SCNVector3(0, 0, 12)
        }
    }
}

/// Everything GardenSceneView needs to drive the cached scene.
final class GardenSceneHandle {
    let scene: SCNScene
    let sunflower: SunflowerNode
    let rig: GardenLighting.Rig
    let cameraRig: SCNNode
    let regionAnchors: [GardenRegion: SCNNode]
    var populatedRegions: Set<GardenRegion> = []
    let beeGroup: SCNNode          // bloom + daytime only
    let butterflyGroup: SCNNode    // near the bloom
    let fireflyGroup: SCNNode      // night only
    let morningBirds: SCNNode
    let middayBird: SCNNode
    let sunsetFormation: SCNNode
    let builtForReduceMotion: Bool

    init(scene: SCNScene, sunflower: SunflowerNode, rig: GardenLighting.Rig,
         cameraRig: SCNNode, regionAnchors: [GardenRegion: SCNNode],
         beeGroup: SCNNode, butterflyGroup: SCNNode, fireflyGroup: SCNNode,
         morningBirds: SCNNode, middayBird: SCNNode, sunsetFormation: SCNNode,
         builtForReduceMotion: Bool) {
        self.scene = scene
        self.sunflower = sunflower
        self.rig = rig
        self.cameraRig = cameraRig
        self.regionAnchors = regionAnchors
        self.beeGroup = beeGroup
        self.butterflyGroup = butterflyGroup
        self.fireflyGroup = fireflyGroup
        self.morningBirds = morningBirds
        self.middayBird = middayBird
        self.sunsetFormation = sunsetFormation
        self.builtForReduceMotion = builtForReduceMotion
    }
}

enum GardenSceneBuilder {

    static let worldHalf: Float = 18      // hard camera bound
    static let softEdge: Float = 3        // resistance starts here

    static func build(reduceMotion: Bool) -> GardenSceneHandle {
        let scene = SCNScene()
        var rng = GardenSeededRandom(seed: 20_260_610)
        let animate = !reduceMotion

        // ── Ground: 500 wide, 70 deep (z -30…+40), just under Y 0.
        //    The depth is deliberate: with the shallow camera tilt, the far
        //    edge at z -30 projects to ≈55% frame height — that edge IS the
        //    horizon line, with the gradient background (sky) above it. A
        //    500×500 plane would cover the entire frame and no sky could
        //    ever show — the root cause of the previous all-green screens.
        let groundGeo = SCNPlane(width: 500, height: 70)
        groundGeo.firstMaterial = GardenMaterials.flat(GardenPalette.ground)
        let ground = SCNNode(geometry: groundGeo)
        ground.eulerAngles.x = -Float.pi / 2
        ground.position = SCNVector3(0, -0.01, 5)
        ground.castsShadow = false
        scene.rootNode.addChildNode(ground)

        // ── Center: the sunflower exactly ON the ground (stem base at Y 0,
        //    growing upward only — the ground plane is at Y 0).
        let sunflower = SunflowerNode(reduceMotion: reduceMotion)
        sunflower.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(sunflower)

        // Soft soil-to-grass transition: a vertex-colored ring (≈0.3 wide)
        // blending the soil patch into the lawn — no hard circle edge.
        scene.rootNode.addChildNode(makeSoilBlendRing(
            innerRadius: 0.78, outerRadius: 1.1
        ))

        scatterGrass(into: scene.rootNode, center: SCNVector3Zero, count: 30,
                     spread: 4.5, sway: animate, rng: &rng)
        // Near-field grass: the ground in the lower half of the frame
        // (toward the camera) gets its own tuft cover + green patches.
        scatterGrass(into: scene.rootNode, center: SCNVector3(0, 0, 6), count: 40,
                     spread: 5.5, sway: animate, rng: &rng)
        scatterPebbles(into: scene.rootNode, center: SCNVector3Zero,
                       count: 10, spread: 4.0, rng: &rng)
        scatterFlowerDots(into: scene.rootNode, center: SCNVector3Zero,
                          count: 8, spread: 4.0, rng: &rng)

        // ── Background trees: always present so the horizon is never empty.
        //    Behind the flower (z -5 … -20), in front of the sky, scaled up
        //    so their crowns ride above the horizon line in the 3/4 view.
        let backTreeSpecs: [(x: Float, z: Float, boost: Float)] = [
            (-14, -18, 1.7), (-8, -12, 1.45), (-3.5, -7, 1.2),
            (3.5, -6, 1.25), (8, -11, 1.5), (14, -17, 1.75),
            (-11, -6, 1.1), (11, -5.5, 1.05)
        ]
        for spec in backTreeSpecs {
            let tree = makeTree(rng: &rng, crown: GardenPalette.crown1,
                                sway: animate, scaleBoost: spec.boost)
            tree.position = SCNVector3(spec.x, 0, spec.z)
            scene.rootNode.addChildNode(tree)
        }

        // ── Center creatures (visibility toggled by SceneView).
        let beeGroup = SCNNode()
        beeGroup.isHidden = true
        let headHeight = sunflower.bloomHeadHeight
        for (i, spec) in [(Float(0.5), 5.5, 2.5), (0.85, 7.0, 3.5), (1.2, 8.5, 2.0)].enumerated() {
            beeGroup.addChildNode(GardenCreatures.beeOrbit(
                headHeight: headHeight, radius: spec.0,
                lapSeconds: spec.1, pauseSeconds: spec.2,
                phase: Float(i) * 2.1, animate: animate
            ))
        }
        scene.rootNode.addChildNode(beeGroup)

        let butterflyGroup = SCNNode()
        butterflyGroup.isHidden = true
        butterflyGroup.addChildNode(GardenCreatures.butterflyFlight(
            color: GardenPalette.monarch, orbitRadius: 1.6,
            height: headHeight + 0.4, period: 12, animate: animate))
        butterflyGroup.addChildNode(GardenCreatures.butterflyFlight(
            color: GardenPalette.violetWing, orbitRadius: 2.2,
            height: headHeight - 0.4, period: 16, animate: animate))
        scene.rootNode.addChildNode(butterflyGroup)

        // ── Fireflies: 16 around center and toward the forest, night only.
        let fireflyGroup = SCNNode()
        fireflyGroup.isHidden = true
        var fireflyRng = GardenSeededRandom(seed: 4242)
        for i in 0..<16 {
            let fly = GardenCreatures.firefly(rng: &fireflyRng, animate: animate)
            let towardForest = i >= 9
            let a = fireflyRng.range(0, 6.28)
            let r = fireflyRng.range(1.5, towardForest ? 5.0 : 4.0)
            fly.position = SCNVector3(
                Float(cos(a) * r),
                Float(fireflyRng.range(0.3, 2.5)),
                Float(sin(a) * r) + (towardForest ? 8 : 0)
            )
            fireflyGroup.addChildNode(fly)
        }
        scene.rootNode.addChildNode(fireflyGroup)

        // ── Birds per period.
        let morningBirds = SCNNode()
        morningBirds.isHidden = true
        morningBirds.addChildNode(GardenCreatures.birdOrbit(
            height: 8, radius: 9, duration: 40, phase: 0, animate: animate))
        morningBirds.addChildNode(GardenCreatures.birdOrbit(
            height: 9.5, radius: 12, duration: 55, phase: .pi, animate: animate))
        morningBirds.addChildNode(GardenCreatures.birdOrbit(
            height: 7, radius: 7, duration: 33, phase: 2, animate: animate))
        scene.rootNode.addChildNode(morningBirds)

        let middayBird = GardenCreatures.birdOrbit(
            height: 13, radius: 14, duration: 70, phase: 1, animate: animate)
        middayBird.isHidden = true
        scene.rootNode.addChildNode(middayBird)

        let sunsetFormation = GardenCreatures.vFormation(animate: animate)
        sunsetFormation.isHidden = true
        scene.rootNode.addChildNode(sunsetFormation)

        // ── Clouds: volumetric, casting real ground shadows. None at night
        //    (lighting rig fades the group).
        let cloudGroup = SCNNode()
        // Cloud heights chosen for the sky band of the frame (v ≈ 6–9).
        let cloudSpecs: [(y: Float, z: Float, scale: Float, duration: TimeInterval)] = [
            (6.5, -10, 0.8, 80), (7.5, -13, 1.0, 105), (6, -8, 0.6, 65), (8, -14, 0.9, 120)
        ]
        for (i, spec) in cloudSpecs.enumerated() {
            let cloud = makeCloud(rng: &rng)
            cloud.scale = SCNVector3(spec.scale, spec.scale, spec.scale)
            cloud.position = SCNVector3(-16 + Float(i) * 8, spec.y, spec.z)
            if animate {
                let drift = SCNAction.sequence([
                    .moveBy(x: 32, y: 0, z: 0, duration: spec.duration),
                    .run { node in node.position.x = -16 }
                ])
                cloud.runAction(.repeatForever(drift))
            }
            cloudGroup.addChildNode(cloud)
        }
        scene.rootNode.addChildNode(cloudGroup)

        // ── Lighting rig.
        let rig = GardenLighting.makeRig(cloudGroup: cloudGroup)
        scene.rootNode.addChildNode(rig.sunNode)
        scene.rootNode.addChildNode(rig.ambientNode)
        scene.rootNode.addChildNode(rig.sunDisc)
        scene.rootNode.addChildNode(rig.moonGroup)
        scene.rootNode.addChildNode(rig.starGroup)

        // ── Region anchors — empty parents, populated lazily.
        var anchors: [GardenRegion: SCNNode] = [:]
        for region in GardenRegion.allCases {
            let anchor = SCNNode()
            anchor.position = region.center
            scene.rootNode.addChildNode(anchor)
            anchors[region] = anchor
        }

        // ── Camera: pannable rig; player-perspective 3/4 view — standing in
        //    the garden looking across it, not hovering above it. The camera
        //    sits behind and above (0, 8, 12) looking at the world center,
        //    so the frame shows sky above, horizon in the middle, and the
        //    sunflower on the ground below. Sun, moon and stars are visible.
        //    The rig pans in X/Z only — height stays fixed at 8, and the
        //    look-direction (toward the horizon) never changes.
        let cameraRig = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 10.0   // wide — sky fills the upper half
        camera.zNear = 0.1
        camera.zFar = 160
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        // Low and far back, aimed just above the ground — a shallow ≈12.5°
        // tilt that puts the horizon mid-frame and sky in the top half.
        cameraNode.position = SCNVector3(0, 5, 18)
        let target = SCNVector3(0, 1, 0)
        let dx = target.x - cameraNode.position.x
        let dy = target.y - cameraNode.position.y
        let dz = target.z - cameraNode.position.z
        let pitch = atan2(dy, sqrt(dx * dx + dz * dz))   // negative → looks down
        let yaw = atan2(dx, -dz)
        cameraNode.eulerAngles = SCNVector3(pitch, yaw, 0)
        cameraRig.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraRig)

        return GardenSceneHandle(
            scene: scene, sunflower: sunflower, rig: rig, cameraRig: cameraRig,
            regionAnchors: anchors, beeGroup: beeGroup,
            butterflyGroup: butterflyGroup, fireflyGroup: fireflyGroup,
            morningBirds: morningBirds, middayBird: middayBird,
            sunsetFormation: sunsetFormation,
            builtForReduceMotion: reduceMotion
        )
    }

    // MARK: - Lazy region population

    static func populate(region: GardenRegion, into anchor: SCNNode,
                         reduceMotion: Bool) {
        let animate = !reduceMotion
        switch region {
        case .orchard:  buildOrchard(into: anchor, animate: animate)
        case .pond:     buildPond(into: anchor, animate: animate)
        case .meadow:   buildMeadow(into: anchor, animate: animate)
        case .forest:   buildForest(into: anchor, animate: animate)
        }
    }

    /// NORTH — fruit trees, fallen apples, a beehive with worker bees.
    private static func buildOrchard(into anchor: SCNNode, animate: Bool) {
        var rng = GardenSeededRandom(seed: 111)
        for i in 0..<6 {
            let tree = makeTree(rng: &rng, crown: GardenPalette.crown1,
                                sway: animate)
            let a = Double(i) / 6.0 * 6.28 + rng.range(-0.3, 0.3)
            let r = rng.range(2.0, 4.8)
            tree.position = SCNVector3(Float(cos(a) * r), 0, Float(sin(a) * r))
            // Apples in the crown + fallen at the base.
            for _ in 0..<3 {
                let apple = SCNSphere(radius: 0.06)
                apple.segmentCount = 8
                apple.firstMaterial = GardenMaterials.flat(GardenPalette.appleRed)
                let node = SCNNode(geometry: apple)
                let aa = rng.range(0, 6.28)
                node.position = SCNVector3(
                    Float(cos(aa) * rng.range(0.2, 0.6)),
                    Float(rng.range(1.4, 2.0)),
                    Float(sin(aa) * rng.range(0.2, 0.6))
                )
                tree.addChildNode(node)
            }
            for _ in 0..<2 {
                let fallen = SCNSphere(radius: 0.055)
                fallen.segmentCount = 8
                fallen.firstMaterial = GardenMaterials.flat(GardenPalette.appleRed)
                let node = SCNNode(geometry: fallen)
                let aa = rng.range(0, 6.28)
                node.position = SCNVector3(
                    tree.position.x + Float(cos(aa) * rng.range(0.4, 0.9)),
                    0.05,
                    tree.position.z + Float(sin(aa) * rng.range(0.4, 0.9))
                )
                anchor.addChildNode(node)
            }
            anchor.addChildNode(tree)

            // Beehive in the first tree, with a small worker-bee orbit.
            if i == 0 {
                let hiveGeo = SCNSphere(radius: 0.18)
                hiveGeo.segmentCount = 10
                hiveGeo.firstMaterial = GardenMaterials.flat(GardenPalette.beehive)
                let hive = SCNNode(geometry: hiveGeo)
                hive.scale = SCNVector3(0.8, 1.15, 0.8)
                hive.position = SCNVector3(0.35, 1.35, 0.15)
                tree.addChildNode(hive)

                for k in 0..<2 {
                    let worker = GardenCreatures.beeOrbit(
                        headHeight: 1.35, radius: 0.5 + Float(k) * 0.3,
                        lapSeconds: 4.5 + Double(k), pauseSeconds: 1.5,
                        phase: Float(k) * 3, animate: animate
                    )
                    worker.position = tree.position
                    anchor.addChildNode(worker)
                }
            }
        }
    }

    /// EAST — big living pond: ducks, frogs on pads, dragonflies, willow.
    private static func buildPond(into anchor: SCNNode, animate: Bool) {
        var rng = GardenSeededRandom(seed: 222)

        let waterGeo = SCNCylinder(radius: 3.4, height: 0.05)
        waterGeo.radialSegmentCount = 30
        waterGeo.firstMaterial = GardenMaterials.water(shimmer: animate)
        let water = SCNNode(geometry: waterGeo)
        water.position = SCNVector3(0, 0.04, 0)
        water.castsShadow = false
        anchor.addChildNode(water)

        // Lily pads + frogs on two of them.
        var padPositions: [SCNVector3] = []
        for _ in 0..<6 {
            let pad = SCNCylinder(radius: CGFloat(rng.range(0.2, 0.36)), height: 0.03)
            pad.radialSegmentCount = 12
            pad.firstMaterial = GardenMaterials.flat(GardenPalette.leaf)
            let node = SCNNode(geometry: pad)
            let a = rng.range(0, 6.28)
            let r = rng.range(0.8, 2.6)
            node.position = SCNVector3(Float(cos(a) * r), 0.09, Float(sin(a) * r))
            node.castsShadow = false
            padPositions.append(node.position)
            anchor.addChildNode(node)
        }
        for k in 0..<2 where padPositions.count > k * 2 + 1 {
            let from = padPositions[k * 2]
            let to = padPositions[k * 2 + 1]
            let hop = SCNVector3(to.x - from.x, 0, to.z - from.z)
            let frog = GardenCreatures.frog(hopTo: hop, animate: animate, rng: &rng)
            frog.position = SCNVector3(from.x, 0.16, from.z)
            anchor.addChildNode(frog)
        }

        // Ducks drifting slow circles.
        for k in 0..<2 {
            let duck = GardenCreatures.duck(
                drift: 1.2 + Float(k) * 0.9, period: 40 + Double(k) * 14,
                phase: Float(k) * 2.4, animate: animate
            )
            anchor.addChildNode(duck)
        }

        // Dragonflies skimming.
        for k in 0..<2 {
            anchor.addChildNode(GardenCreatures.dragonfly(
                radius: 2.0 + Float(k) * 0.8, period: 7 + Double(k) * 3,
                phase: Float(k) * 2, animate: animate
            ))
        }

        // Weeping willow at the edge: tall trunk + drooping frond strips.
        let willow = SCNNode()
        let trunkGeo = SCNCone(topRadius: 0.08, bottomRadius: 0.14, height: 2.0)
        trunkGeo.radialSegmentCount = 10
        trunkGeo.firstMaterial = GardenMaterials.flat(GardenPalette.trunk)
        let trunk = SCNNode(geometry: trunkGeo)
        trunk.position = SCNVector3(0, 1.0, 0)
        willow.addChildNode(trunk)
        let crownGeo = SCNSphere(radius: 0.9)
        crownGeo.segmentCount = 12
        crownGeo.firstMaterial = GardenMaterials.swaying(GardenPalette.willowGreen, sway: animate)
        let crown = SCNNode(geometry: crownGeo)
        crown.scale = SCNVector3(1.2, 0.7, 1.2)
        crown.position = SCNVector3(0, 2.15, 0)
        willow.addChildNode(crown)
        for i in 0..<10 {
            let frondGeo = SCNBox(width: 0.05, height: CGFloat(rng.range(0.9, 1.5)),
                                  length: 0.02, chamferRadius: 0.01)
            frondGeo.firstMaterial = GardenMaterials.swaying(GardenPalette.willowGreen, sway: animate)
            let frond = SCNNode(geometry: frondGeo)
            let a = Float(i) / 10 * 2 * .pi
            let h = Float(frondGeo.height)
            frond.position = SCNVector3(cos(a) * 1.0, 2.1 - h / 2, sin(a) * 1.0)
            frond.castsShadow = false
            willow.addChildNode(frond)
        }
        willow.position = SCNVector3(-3.0, 0, -2.4)
        anchor.addChildNode(willow)

        // Low mist wisps at the water's edge.
        for i in 0..<5 {
            let mistGeo = SCNSphere(radius: CGFloat(rng.range(0.3, 0.5)))
            mistGeo.segmentCount = 8
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(white: 1.0, alpha: 0.15)
            m.lightingModel = .constant
            m.writesToDepthBuffer = false
            mistGeo.firstMaterial = m
            let mist = SCNNode(geometry: mistGeo)
            let a = Double(i) / 5.0 * 6.28
            mist.position = SCNVector3(Float(cos(a) * 3.6), 0.2, Float(sin(a) * 3.6))
            mist.castsShadow = false
            if animate {
                let drift = SCNAction.sequence([
                    .moveBy(x: 0.35, y: 0.06, z: 0, duration: 7),
                    .moveBy(x: -0.35, y: -0.06, z: 0, duration: 7)
                ])
                drift.timingMode = .easeInEaseOut
                mist.runAction(.repeatForever(drift))
            }
            anchor.addChildNode(mist)
        }
    }

    /// WEST — open wildflower field, drifting butterflies, a wooden bench.
    private static func buildMeadow(into anchor: SCNNode, animate: Bool) {
        var rng = GardenSeededRandom(seed: 333)
        scatterGrass(into: anchor, center: SCNVector3Zero, count: 40,
                     spread: 5.0, sway: animate, rng: &rng)
        scatterFlowerDots(into: anchor, center: SCNVector3Zero, count: 26,
                          spread: 5.0, rng: &rng)

        let colors = [GardenPalette.monarch, GardenPalette.morpho,
                      GardenPalette.violetWing, GardenPalette.monarch,
                      GardenPalette.morpho]
        for (k, color) in colors.enumerated() {
            let fly = GardenCreatures.butterflyFlight(
                color: color, orbitRadius: 1.2 + Float(k) * 0.5,
                height: 0.8 + Float(k % 3) * 0.4,
                period: 10 + Double(k) * 3, animate: animate
            )
            fly.position = SCNVector3(Float(rng.range(-2.5, 2.5)), 0,
                                      Float(rng.range(-2.5, 2.5)))
            anchor.addChildNode(fly)
        }

        // Wooden bench: two leg boxes + seat + backrest.
        let bench = SCNNode()
        let wood = GardenMaterials.flat(GardenPalette.benchWood)
        let seatGeo = SCNBox(width: 1.2, height: 0.06, length: 0.35, chamferRadius: 0.02)
        seatGeo.firstMaterial = wood
        let seat = SCNNode(geometry: seatGeo)
        seat.position = SCNVector3(0, 0.4, 0)
        bench.addChildNode(seat)
        let backGeo = SCNBox(width: 1.2, height: 0.32, length: 0.05, chamferRadius: 0.02)
        backGeo.firstMaterial = wood
        let back = SCNNode(geometry: backGeo)
        back.position = SCNVector3(0, 0.62, -0.16)
        back.eulerAngles.x = 0.12
        bench.addChildNode(back)
        for side in [Float(-1), Float(1)] {
            let legGeo = SCNBox(width: 0.07, height: 0.4, length: 0.3, chamferRadius: 0.01)
            legGeo.firstMaterial = wood
            let leg = SCNNode(geometry: legGeo)
            leg.position = SCNVector3(side * 0.5, 0.2, 0)
            bench.addChildNode(leg)
        }
        bench.position = SCNVector3(-1.8, 0, 1.6)
        bench.eulerAngles.y = 0.6
        anchor.addChildNode(bench)
    }

    /// SOUTH — darker forest edge: dense trees, mushrooms, a stream,
    /// dim daytime fireflies.
    private static func buildForest(into anchor: SCNNode, animate: Bool) {
        var rng = GardenSeededRandom(seed: 444)
        for i in 0..<5 {
            let tree = makeTree(rng: &rng, crown: GardenPalette.forestCrown,
                                sway: animate, trunkColor: GardenPalette.forestTrunk,
                                scaleBoost: 1.25)
            let a = Double(i) / 5.0 * 6.28 + rng.range(-0.25, 0.25)
            let r = rng.range(1.6, 4.4)
            tree.position = SCNVector3(Float(cos(a) * r), 0, Float(sin(a) * r) + 1.0)
            anchor.addChildNode(tree)
        }

        // Mushrooms: cream stems, red caps.
        for _ in 0..<7 {
            let mushroom = SCNNode()
            let stemGeo = SCNCylinder(radius: 0.03, height: 0.12)
            stemGeo.radialSegmentCount = 8
            stemGeo.firstMaterial = GardenMaterials.flat(GardenPalette.mushroomStem)
            let stem = SCNNode(geometry: stemGeo)
            stem.position = SCNVector3(0, 0.06, 0)
            mushroom.addChildNode(stem)
            let capGeo = SCNSphere(radius: 0.07)
            capGeo.segmentCount = 10
            capGeo.firstMaterial = GardenMaterials.flat(GardenPalette.mushroomCap)
            let cap = SCNNode(geometry: capGeo)
            cap.scale = SCNVector3(1, 0.6, 1)
            cap.position = SCNVector3(0, 0.13, 0)
            mushroom.addChildNode(cap)
            let a = rng.range(0, 6.28)
            let r = rng.range(0.8, 4.0)
            mushroom.position = SCNVector3(Float(cos(a) * r), 0, Float(sin(a) * r))
            anchor.addChildNode(mushroom)
        }

        // Small stream: long thin shimmer band.
        let streamGeo = SCNPlane(width: 1.0, height: 9.0)
        streamGeo.firstMaterial = GardenMaterials.water(shimmer: animate)
        let stream = SCNNode(geometry: streamGeo)
        stream.eulerAngles = SCNVector3(-.pi / 2, 0.4, 0)
        stream.position = SCNVector3(2.8, 0.03, 1.0)
        stream.castsShadow = false
        anchor.addChildNode(stream)

        // Dim daytime fireflies among the trunks.
        var fireflyRng = GardenSeededRandom(seed: 555)
        for _ in 0..<5 {
            let fly = GardenCreatures.firefly(rng: &fireflyRng, animate: animate)
            fly.opacity = 0.35
            let a = fireflyRng.range(0, 6.28)
            let r = fireflyRng.range(1.0, 3.5)
            fly.position = SCNVector3(
                Float(cos(a) * r),
                Float(fireflyRng.range(0.3, 1.4)),
                Float(sin(a) * r) + 1.0
            )
            anchor.addChildNode(fly)
        }
    }

    // MARK: - Shared props

    /// Organic tree with LOD: full multi-cluster crown nearby, a single
    /// cheap sphere beyond 16 units.
    private static func makeTree(rng: inout GardenSeededRandom, crown: UIColor,
                                 sway: Bool, trunkColor: UIColor = GardenPalette.trunk,
                                 scaleBoost: Float = 1.0) -> SCNNode {
        let root = SCNNode()
        let scale = Float(rng.range(0.85, 1.2)) * scaleBoost
        let trunkHeight = Float(rng.range(1.0, 1.5)) * scale

        let trunkGeo = SCNCone(topRadius: 0.08, bottomRadius: 0.13,
                               height: CGFloat(trunkHeight))
        trunkGeo.radialSegmentCount = 9
        trunkGeo.firstMaterial = GardenMaterials.flat(trunkColor)
        let trunk = SCNNode(geometry: trunkGeo)
        trunk.position = SCNVector3(0, trunkHeight / 2, 0)
        root.addChildNode(trunk)

        let crownMaterial = GardenMaterials.swaying(crown, sway: sway)
        let crownY = trunkHeight + 0.3 * scale

        // Main crown carries the LOD: full 12-seg sphere → 6-seg at 16 units.
        let mainGeo = SCNSphere(radius: CGFloat(rng.range(0.7, 0.95)) * CGFloat(scale))
        mainGeo.segmentCount = 12
        mainGeo.firstMaterial = crownMaterial
        let lowGeo = SCNSphere(radius: mainGeo.radius)
        lowGeo.segmentCount = 6
        lowGeo.firstMaterial = crownMaterial
        mainGeo.levelsOfDetail = [SCNLevelOfDetail(geometry: lowGeo, worldSpaceDistance: 16)]
        let main = SCNNode(geometry: mainGeo)
        main.position = SCNVector3(0, crownY, 0)
        root.addChildNode(main)

        for _ in 0..<3 {
            let subGeo = SCNSphere(radius: CGFloat(rng.range(0.35, 0.55)) * CGFloat(scale))
            subGeo.segmentCount = 8
            subGeo.firstMaterial = crownMaterial
            let subLow = SCNSphere(radius: subGeo.radius)
            subLow.segmentCount = 5
            subLow.firstMaterial = crownMaterial
            subGeo.levelsOfDetail = [SCNLevelOfDetail(geometry: subLow, worldSpaceDistance: 16)]
            let sub = SCNNode(geometry: subGeo)
            let a = rng.range(0, 6.28)
            let d = Float(rng.range(0.3, 0.6)) * scale
            sub.position = SCNVector3(cos(Float(a)) * d,
                                      crownY + Float(rng.range(-0.2, 0.35)) * scale,
                                      sin(Float(a)) * d)
            root.addChildNode(sub)
        }
        return root
    }

    /// Flat annulus with per-vertex colors blending soil cream (inner) into
    /// lawn green (outer) — the natural grass line around the plant.
    private static func makeSoilBlendRing(innerRadius: Float, outerRadius: Float) -> SCNNode {
        let segments = 40
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [Float] = []
        var indices: [Int32] = []

        // Warm brown #8B6914 inner → bright green #7EC86A outer. Vertex
        // colors render in linear space, so these are the linearized values
        // of those sRGB hexes (raw sRGB floats read grey-purple on screen).
        let inner: [Float] = [0.258, 0.140, 0.024, 1.0]   // #8B6914 linearized
        let outer: [Float] = [0.209, 0.578, 0.145, 1.0]   // #7EC86A linearized

        for i in 0...segments {
            let angle = Float(i) / Float(segments) * 2 * .pi
            let ca = cos(angle), sa = sin(angle)
            vertices.append(SCNVector3(ca * innerRadius, 0, sa * innerRadius))
            vertices.append(SCNVector3(ca * outerRadius, 0, sa * outerRadius))
            normals.append(SCNVector3(0, 1, 0))
            normals.append(SCNVector3(0, 1, 0))
            colors.append(contentsOf: inner)
            colors.append(contentsOf: outer)
            if i < segments {
                let base = Int32(i * 2)
                indices.append(contentsOf: [base, base + 2, base + 1,
                                            base + 1, base + 2, base + 3])
            }
        }

        let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSource = SCNGeometrySource(
            data: colorData, semantic: .color,
            vectorCount: vertices.count, usesFloatComponents: true,
            componentsPerVector: 4, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<Float>.size * 4
        )
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices),
                      SCNGeometrySource(normals: normals),
                      colorSource],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        let m = SCNMaterial()
        m.diffuse.contents = UIColor.white      // vertex colors carry the blend
        m.lightingModel = .lambert
        m.specular.contents = UIColor.black
        m.isDoubleSided = true
        geometry.firstMaterial = m

        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(0, 0.035, 0)   // just over the patch edge
        node.castsShadow = false
        return node
    }

    private static func makeCloud(rng: inout GardenSeededRandom) -> SCNNode {
        let cloud = SCNNode()
        let material = GardenMaterials.unlit(GardenPalette.cloud)
        let blobs: [(Float, Float, CGFloat)] = [
            (0, 0, 0.7), (-0.7, -0.08, 0.5), (0.7, -0.08, 0.55), (0.1, 0.3, 0.42)
        ]
        for blob in blobs {
            let geo = SCNSphere(radius: blob.2)
            geo.segmentCount = 8
            geo.firstMaterial = material
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(blob.0 + Float(rng.range(-0.1, 0.1)), blob.1, 0)
            node.castsShadow = true   // clouds shadow the ground
            cloud.addChildNode(node)
        }
        return cloud
    }

    private static func scatterGrass(into parent: SCNNode, center: SCNVector3,
                                     count: Int, spread: Double, sway: Bool,
                                     rng: inout GardenSeededRandom) {
        let materials = [
            GardenMaterials.swaying(GardenPalette.grassTip, sway: sway),
            GardenMaterials.swaying(GardenPalette.leaf, sway: sway)
        ]
        for i in 0..<count {
            let tuft = SCNNode()
            for k in 0..<2 {
                let blade = SCNPlane(width: 0.07, height: CGFloat(rng.range(0.15, 0.28)))
                blade.firstMaterial = materials[i % materials.count]
                let bladeNode = SCNNode(geometry: blade)
                bladeNode.position = SCNVector3(0, Float(blade.height) / 2, 0)
                bladeNode.eulerAngles.y = Float(k) * .pi / 2 + Float(rng.range(-0.3, 0.3))
                bladeNode.castsShadow = false
                tuft.addChildNode(bladeNode)
            }
            let a = rng.range(0, 6.28)
            let r = rng.range(0.9, spread)
            tuft.position = SCNVector3(center.x + Float(cos(a) * r), 0,
                                       center.z + Float(sin(a) * r))
            parent.addChildNode(tuft)
        }
    }

    private static func scatterPebbles(into parent: SCNNode, center: SCNVector3,
                                       count: Int, spread: Double,
                                       rng: inout GardenSeededRandom) {
        for _ in 0..<count {
            let pebble = SCNSphere(radius: CGFloat(rng.range(0.04, 0.09)))
            pebble.segmentCount = 6
            pebble.firstMaterial = GardenMaterials.flat(
                rng.next() > 0.5 ? GardenPalette.rock : GardenPalette.rockShade
            )
            let node = SCNNode(geometry: pebble)
            node.scale = SCNVector3(1.2, 0.7, 1.0)
            let a = rng.range(0, 6.28)
            let r = rng.range(1.0, spread)
            node.position = SCNVector3(center.x + Float(cos(a) * r), 0.03,
                                       center.z + Float(sin(a) * r))
            node.castsShadow = false
            parent.addChildNode(node)
        }
    }

    private static func scatterFlowerDots(into parent: SCNNode, center: SCNVector3,
                                          count: Int, spread: Double,
                                          rng: inout GardenSeededRandom) {
        let colors: [UIColor] = [
            GardenPalette.flowerPeach, GardenPalette.flowerLavender,
            GardenPalette.flowerYellow, GardenPalette.flowerWhite
        ]
        for i in 0..<count {
            let dot = SCNPlane(width: 0.11, height: 0.11)
            dot.cornerRadius = 0.055
            dot.firstMaterial = GardenMaterials.unlit(colors[i % colors.count])
            let node = SCNNode(geometry: dot)
            let a = rng.range(0, 6.28)
            let r = rng.range(1.0, spread)
            node.position = SCNVector3(center.x + Float(cos(a) * r),
                                       Float(rng.range(0.05, 0.12)),
                                       center.z + Float(sin(a) * r))
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            node.constraints = [billboard]
            node.castsShadow = false
            parent.addChildNode(node)
        }
    }
}
