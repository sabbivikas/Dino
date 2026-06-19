//
//  SunflowerNode.swift
//  Dino
//
//  The photorealistic centerpiece sunflower. Custom-mesh petals and leaves
//  (curved, seeded per-petal variation), a domed seed disc with Fibonacci
//  seed rings that catch light individually, a naturally curved stem, and
//  green sepals. Care state — read from GrowthViewModel via GardenSceneView
//  — drives droop, petal curl, browning, desaturation and dry soil.
//  Watering recovery straightens, unfurls and re-colors over 2s.
//

import SceneKit
import UIKit

final class SunflowerNode: SCNNode {

    /// Five visual stages. GrowthViewModel's nine GrowthStage cases collapse
    /// onto these (exhaustive mapping in GardenSceneView).
    enum Stage: Int, CaseIterable {
        case seedMound = 0, sprout, stemWithLeaves, bud, fullBloom
    }

    private var stageNodes: [Stage: SCNNode] = [:]
    private var headNodes: [Stage: SCNNode] = [:]
    private var leafNodes: [SCNNode] = []                  // droop with neglect
    private var petalNodes: [(node: SCNNode, baseEuler: SCNVector3)] = []
    private var petalMaterials: [(material: SCNMaterial, base: UIColor)] = []
    private var tintables: [(material: SCNMaterial, base: UIColor)] = []

    /// World-space height of the bloom head — creatures orbit here.
    private(set) var bloomHeadHeight: Float = 2.6

    private let soilMaterial = GardenMaterials.flat(GardenPalette.soilCream)
    private var crackGroup = SCNNode()
    private let swayKey = "garden.sway"
    private let animateMotion: Bool

    init(reduceMotion: Bool) {
        self.animateMotion = !reduceMotion
        super.init()
        buildSoil()
        buildAllStages()
        if animateMotion {
            startPetalFlutter()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { return nil }

    // MARK: - Public API

    /// Show one stage with care-driven look. `heliotropism` is -1 (morning,
    /// head east) … 0 (noon, up) … +1 (evening, head west). When `animated`,
    /// changes ease over 2s — the watering-recovery moment.
    func apply(stage: Stage, droopDegrees: Double, saturation: CGFloat,
               soilDryness: CGFloat, heliotropism: Float,
               sway: Bool, animated: Bool) {
        let dry = max(0, min(1, soilDryness))
        let browning = max(0, (dry - 0.55) / 0.45)   // brown creeps in from wilting onward

        let work = { [self] in
            for (s, node) in stageNodes {
                node.isHidden = (s != stage)
            }

            // Stem lean + head droop.
            let lean = Float(droopDegrees * 0.35 * .pi / 180.0)
            let pitch = Float(droopDegrees * .pi / 180.0)
            for (_, node) in stageNodes {
                node.eulerAngles.z = -lean
            }
            for (s, head) in headNodes {
                head.eulerAngles.x = pitch + (s == .fullBloom ? 0.25 : 0)
                if s == .fullBloom {
                    head.eulerAngles.z = heliotropism * 0.14
                }
            }

            // Leaves droop more severely than the stem.
            for (i, leaf) in leafNodes.enumerated() {
                let side: Float = (i % 2 == 0) ? -1 : 1
                leaf.eulerAngles.z = side * 0.45 + side * Float(droopDegrees) * 0.012
            }

            // Petal curl inward + brown-from-tips (approximated as a blend).
            let curl = Float(dry) * 0.5
            for petal in self.petalNodes {
                petal.node.eulerAngles = SCNVector3(
                    petal.baseEuler.x + curl * 0.6,
                    petal.baseEuler.y,
                    petal.baseEuler.z
                )
            }
            for entry in self.petalMaterials {
                let desat = entry.base.gardenDesaturated(to: saturation)
                entry.material.diffuse.contents = self.blend(
                    desat, GardenPalette.witherBrown, t: CGFloat(browning) * 0.6
                )
            }
            for entry in self.tintables {
                entry.material.diffuse.contents = entry.base.gardenDesaturated(to: saturation)
            }

            self.soilMaterial.diffuse.contents = self.blend(
                GardenPalette.soilCream, GardenPalette.soilBrown, t: dry
            )
            self.crackGroup.opacity = dry
        }

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 2.0
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            work()
            SCNTransaction.commit()
        } else {
            work()
        }

        removeAction(forKey: swayKey)
        if sway && animateMotion {
            let amp: CGFloat = 0.035   // ±2°, 4s round trip
            let a = SCNAction.rotateBy(x: 0, y: 0, z: amp, duration: 2.0)
            a.timingMode = .easeInEaseOut
            let b = SCNAction.rotateBy(x: 0, y: 0, z: -amp, duration: 2.0)
            b.timingMode = .easeInEaseOut
            runAction(.repeatForever(.sequence([a, b])), forKey: swayKey)
        }
    }

    // MARK: - Custom geometry

    /// Curved teardrop petal strip: wide base → narrow tip, concave bow.
    private func petalGeometry(length: CGFloat, baseWidth: CGFloat,
                               tipWidth: CGFloat, bow: CGFloat) -> SCNGeometry {
        let segments = 7
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []

        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let y = Float(length * t)
            // Teardrop profile: bulge near base third, taper to tip.
            let half = Float((baseWidth / 2) * (1 - t) + (tipWidth / 2) * t
                             + 0.05 * sin(t * .pi))
            let z = Float(bow * sin(t * .pi))
            vertices.append(SCNVector3(-half, y, z))
            vertices.append(SCNVector3(half, y, z))
            normals.append(SCNVector3(0, 0, 1))
            normals.append(SCNVector3(0, 0, 1))
            if i < segments {
                let base = Int32(i * 2)
                indices.append(contentsOf: [base, base + 1, base + 2,
                                            base + 1, base + 3, base + 2])
            }
        }

        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices),
                      SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        return geometry
    }

    /// Heart/teardrop leaf with a gentle lengthwise bend (≈15°).
    private func leafGeometry(length: CGFloat, width: CGFloat) -> SCNGeometry {
        let segments = 6
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []

        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let y = Float(length * t)
            // Heart profile: widest a third of the way up.
            let half = Float(width / 2 * sin(min(t * 1.45, 1.0) * .pi))
            let z = Float(-0.26 * length * sin(t * .pi / 2))   // ≈15° bend
            vertices.append(SCNVector3(-half, y, z))
            vertices.append(SCNVector3(half, y, z))
            normals.append(SCNVector3(0, 0.3, 1))
            normals.append(SCNVector3(0, 0.3, 1))
            if i < segments {
                let base = Int32(i * 2)
                indices.append(contentsOf: [base, base + 1, base + 2,
                                            base + 1, base + 3, base + 2])
            }
        }

        return SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices),
                      SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }

    private func petalMaterial(_ color: UIColor) -> SCNMaterial {
        let m = GardenMaterials.flat(color)
        petalMaterials.append((m, color))
        return m
    }

    private func tintable(_ color: UIColor) -> SCNMaterial {
        let m = GardenMaterials.flat(color)
        tintables.append((m, color))
        return m
    }

    private func blend(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t,
                       blue: ab + (bb - ab) * t, alpha: 1)
    }

    // MARK: - Soil

    private func buildSoil() {
        let patch = SCNCylinder(radius: 0.8, height: 0.04)
        patch.radialSegmentCount = 20
        patch.firstMaterial = soilMaterial
        let patchNode = SCNNode(geometry: patch)
        patchNode.position = SCNVector3(0, 0.02, 0)
        patchNode.castsShadow = false
        addChildNode(patchNode)

        var rng = GardenSeededRandom(seed: 41)
        crackGroup = SCNNode()
        crackGroup.opacity = 0
        for i in 0..<5 {
            let crack = SCNBox(width: CGFloat(rng.range(0.3, 0.6)),
                               height: 0.005, length: 0.025, chamferRadius: 0)
            crack.firstMaterial = GardenMaterials.unlit(GardenPalette.soilCrack)
            let node = SCNNode(geometry: crack)
            node.position = SCNVector3(
                Float(rng.range(-0.4, 0.4)), 0.045, Float(rng.range(-0.4, 0.4))
            )
            node.eulerAngles.y = Float(i) * 1.25
            node.castsShadow = false
            crackGroup.addChildNode(node)
        }
        addChildNode(crackGroup)
    }

    // MARK: - Stages

    private func buildAllStages() {
        stageNodes[.seedMound] = makeSeedMound()
        stageNodes[.sprout] = makeSprout()
        stageNodes[.stemWithLeaves] = makeGrowing()
        stageNodes[.bud] = makeBudding()
        stageNodes[.fullBloom] = makeFullBloom()
        for (_, node) in stageNodes {
            node.isHidden = true
            addChildNode(node)
        }
    }

    private func makeSeedMound() -> SCNNode {
        let root = SCNNode()
        let mound = SCNSphere(radius: 0.32)
        mound.segmentCount = 16
        mound.firstMaterial = tintable(GardenPalette.seedSoil)
        let moundNode = SCNNode(geometry: mound)
        moundNode.scale = SCNVector3(1.0, 0.5, 1.0)
        moundNode.position = SCNVector3(0, 0.1, 0)
        root.addChildNode(moundNode)

        let crack = SCNBox(width: 0.18, height: 0.012, length: 0.028, chamferRadius: 0.005)
        crack.firstMaterial = GardenMaterials.glow(GardenPalette.budPale)
        let crackNode = SCNNode(geometry: crack)
        crackNode.position = SCNVector3(0, 0.26, 0.02)
        crackNode.eulerAngles.y = 0.4
        root.addChildNode(crackNode)
        return root
    }

    private func makeSprout() -> SCNNode {
        let root = SCNNode()
        let stem = makeCurvedStem(height: 0.45, radius: 0.03)
        root.addChildNode(stem.node)

        for (i, side) in [Float(-1), Float(1)].enumerated() {
            let leaf = SCNNode(geometry: leafGeometry(length: 0.3, width: 0.18))
            leaf.geometry?.firstMaterial = tintable(GardenPalette.leafTop)
            leaf.position = SCNVector3(side * 0.03, 0.32 + Float(i) * 0.06, 0)
            leaf.eulerAngles = SCNVector3(-0.5, side * .pi / 2, 0)
            leafNodes.append(leaf)
            root.addChildNode(leaf)
        }
        return root
    }

    private func makeGrowing() -> SCNNode {
        let root = SCNNode()
        let stem = makeCurvedStem(height: 1.2, radius: 0.045)
        root.addChildNode(stem.node)
        addLeaves(to: root, stemHeight: 1.2, count: 4, leafLength: 0.45)

        let headPivot = SCNNode()
        headPivot.position = SCNVector3(stem.topOffset, 1.2, 0)
        let bud = SCNSphere(radius: 0.12)
        bud.segmentCount = 14
        bud.firstMaterial = tintable(GardenPalette.budPale)
        let budNode = SCNNode(geometry: bud)
        budNode.scale = SCNVector3(0.9, 1.2, 0.9)
        budNode.position = SCNVector3(0, 0.09, 0)
        headPivot.addChildNode(budNode)
        root.addChildNode(headPivot)
        headNodes[.stemWithLeaves] = headPivot
        return root
    }

    private func makeBudding() -> SCNNode {
        let root = SCNNode()
        let stem = makeCurvedStem(height: 1.9, radius: 0.055)
        root.addChildNode(stem.node)
        addLeaves(to: root, stemHeight: 1.9, count: 5, leafLength: 0.55)

        let headPivot = SCNNode()
        headPivot.position = SCNVector3(stem.topOffset, 1.9, 0)

        let bud = SCNSphere(radius: 0.17)
        bud.segmentCount = 14
        bud.firstMaterial = tintable(GardenPalette.budBright)
        let budNode = SCNNode(geometry: bud)
        budNode.scale = SCNVector3(0.95, 1.3, 0.95)
        budNode.position = SCNVector3(0, 0.13, 0)
        headPivot.addChildNode(budNode)

        addSepals(to: headPivot, count: 6, radius: 0.13, scale: 0.7)
        root.addChildNode(headPivot)
        headNodes[.bud] = headPivot
        return root
    }

    /// FULL BLOOM — the star of the garden. 8 deep-gold back petals, 16
    /// bright-gold front petals (seeded ±5% size, ±3° variation), domed seed
    /// disc with Fibonacci rings (21 + 13 lit seeds), 8 sepals behind.
    private func makeFullBloom() -> SCNNode {
        let root = SCNNode()
        let height: Float = 2.6
        bloomHeadHeight = height
        let stem = makeCurvedStem(height: CGFloat(height), radius: 0.06)
        root.addChildNode(stem.node)
        addLeaves(to: root, stemHeight: height, count: 6, leafLength: 0.65)

        let headPivot = SCNNode()
        headPivot.position = SCNVector3(stem.topOffset, height, 0)
        headPivot.eulerAngles.x = 0.25   // face slightly toward the viewer
        root.addChildNode(headPivot)

        var rng = GardenSeededRandom(seed: 7_2026)

        // Sepals — 8 pointed green shapes behind everything.
        addSepals(to: headPivot, count: 8, radius: 0.3, scale: 1.0, z: -0.06)

        // Back petals — 8 deep golden, slightly larger.
        for i in 0..<8 {
            let angle = Float(i) / 8 * 2 * .pi + .pi / 16
            addPetal(to: headPivot, angle: angle, ringRadius: 0.34,
                     length: 0.88, color: GardenPalette.petalBack,
                     z: -0.03, rng: &rng)
        }
        // Front petals — 16 bright golden, angled slightly toward the viewer.
        for i in 0..<16 {
            let angle = Float(i) / 16 * 2 * .pi
            addPetal(to: headPivot, angle: angle, ringRadius: 0.36,
                     length: 0.8, color: GardenPalette.petalFront,
                     z: 0.02, rng: &rng)
        }

        // Center disc: shallow cylinder + raised dome, rich dark brown.
        let disc = SCNCylinder(radius: 0.4, height: 0.05)
        disc.radialSegmentCount = 24
        disc.firstMaterial = tintable(GardenPalette.discBrown)
        let discNode = SCNNode(geometry: disc)
        discNode.eulerAngles.x = .pi / 2
        discNode.position = SCNVector3(0, 0, 0.04)
        headPivot.addChildNode(discNode)

        let dome = SCNSphere(radius: 0.4)
        dome.segmentCount = 20
        dome.firstMaterial = tintable(GardenPalette.discBrown)
        let domeNode = SCNNode(geometry: dome)
        domeNode.scale = SCNVector3(1.0, 1.0, 0.35)
        domeNode.position = SCNVector3(0, 0, 0.05)
        headPivot.addChildNode(domeNode)

        // Fibonacci seed rings — 21 outer + 13 inner, each a lit sphere.
        let golden: Float = 2.39996
        for (count, baseRadius) in [(21, Float(0.30)), (13, Float(0.17))] {
            for i in 0..<count {
                let angle = Float(i) * golden
                let r = baseRadius + Float(rng.range(-0.012, 0.012))
                let seed = SCNSphere(radius: 0.022)
                seed.segmentCount = 6
                seed.firstMaterial = GardenMaterials.flat(GardenPalette.seedDark)
                let seedNode = SCNNode(geometry: seed)
                let lift = 0.16 * sqrt(max(0, 1 - (r / 0.42) * (r / 0.42)))
                seedNode.position = SCNVector3(cos(angle) * r, sin(angle) * r, 0.05 + lift)
                headPivot.addChildNode(seedNode)
            }
        }

        headNodes[.fullBloom] = headPivot
        return root
    }

    private func addPetal(to head: SCNNode, angle: Float, ringRadius: Float,
                          length: CGFloat, color: UIColor, z: Float,
                          rng: inout GardenSeededRandom) {
        let sizeVar = CGFloat(rng.range(0.95, 1.05))          // ±5%
        let angleVar = Float(rng.range(-0.052, 0.052))        // ±3°
        let geo = petalGeometry(length: length * sizeVar, baseWidth: 0.25,
                                tipWidth: 0.05, bow: 0.06)
        geo.firstMaterial = petalMaterial(color)
        let petal = SCNNode(geometry: geo)
        petal.position = SCNVector3(cos(angle) * ringRadius,
                                    sin(angle) * ringRadius, z)
        // Point outward, tipped slightly up toward the viewer.
        let euler = SCNVector3(-0.18, 0, angle - .pi / 2 + angleVar)
        petal.eulerAngles = euler
        petalNodes.append((petal, euler))
        head.addChildNode(petal)
    }

    private func addSepals(to head: SCNNode, count: Int, radius: Float,
                           scale: CGFloat, z: Float = -0.04) {
        for i in 0..<count {
            let angle = Float(i) / Float(count) * 2 * .pi + .pi / Float(count)
            let geo = petalGeometry(length: 0.4 * scale, baseWidth: 0.16,
                                    tipWidth: 0.02, bow: 0.04)
            geo.firstMaterial = tintable(GardenPalette.sepalGreen)
            let sepal = SCNNode(geometry: geo)
            sepal.position = SCNVector3(cos(angle) * radius, sin(angle) * radius, z)
            sepal.eulerAngles = SCNVector3(-0.1, 0, angle - .pi / 2)
            head.addChildNode(sepal)
        }
    }

    /// Naturally curved stem: three stacked segments, top offset ~0.1 east.
    private func makeCurvedStem(height: CGFloat, radius: CGFloat)
        -> (node: SCNNode, topOffset: Float) {
        let root = SCNNode()
        let segs = 3
        let topOffset: Float = 0.1 * Float(min(height / 2.6, 1.0))
        var prevX: Float = 0
        for i in 0..<segs {
            let t0 = Float(i) / Float(segs)
            let t1 = Float(i + 1) / Float(segs)
            let x0 = topOffset * t0 * t0
            let x1 = topOffset * t1 * t1
            let segHeight = height / CGFloat(segs)
            let cyl = SCNCylinder(radius: radius * CGFloat(1.0 - 0.25 * Double(t0)),
                                  height: segHeight * 1.06)
            cyl.radialSegmentCount = 10
            cyl.firstMaterial = tintable(GardenPalette.stemDeep)
            let seg = SCNNode(geometry: cyl)
            seg.position = SCNVector3((x0 + x1) / 2,
                                      Float(height) * (t0 + t1) / 2, 0)
            seg.eulerAngles.z = -atan2(x1 - x0, Float(height) / Float(segs))
            root.addChildNode(seg)
            prevX = x1
        }
        _ = prevX
        return (root, topOffset)
    }

    private func addLeaves(to root: SCNNode, stemHeight: Float,
                           count: Int, leafLength: CGFloat) {
        for i in 0..<count {
            let f = Float(i + 1) / Float(count + 1)
            let side: Float = (i % 2 == 0) ? -1 : 1
            let leaf = SCNNode(geometry: leafGeometry(length: leafLength, width: leafLength * 0.62))
            leaf.geometry?.firstMaterial = tintable(
                i % 2 == 0 ? GardenPalette.leafTop : GardenPalette.leafUnder
            )
            leaf.position = SCNVector3(side * 0.05, stemHeight * f * 0.92, 0)
            // Out from the stem, slight natural droop.
            leaf.eulerAngles = SCNVector3(-0.35, side * .pi / 2, side * 0.45)
            leafNodes.append(leaf)
            root.addChildNode(leaf)
        }
    }

    /// Subtle individual petal flutter — ±0.5°, distinct phase per petal.
    private func startPetalFlutter() {
        var rng = GardenSeededRandom(seed: 99)
        for petal in petalNodes {
            let amp = CGFloat(0.0087)   // 0.5°
            let period = rng.range(1.6, 2.6)
            let delay = rng.range(0, 1.2)
            let a = SCNAction.rotateBy(x: amp, y: 0, z: 0, duration: period / 2)
            a.timingMode = .easeInEaseOut
            let b = SCNAction.rotateBy(x: -amp, y: 0, z: 0, duration: period / 2)
            b.timingMode = .easeInEaseOut
            petal.node.runAction(.sequence([.wait(duration: delay),
                                            .repeatForever(.sequence([a, b]))]))
        }
    }
}
