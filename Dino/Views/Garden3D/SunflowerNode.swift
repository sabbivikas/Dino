//
//  SunflowerNode.swift
//  Dino
//
//  The illustrated centerpiece sunflower. Five discrete stage nodes,
//  visibility-toggled (no morphing). Care state — read from
//  GrowthViewModel via GardenSceneView, using the OLD GardenPanel's exact
//  CareParams numbers — drives droop + desaturation + dry soil. Watering
//  recovery animates upright + re-saturates over 1.5s.
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
    private var tintables: [(material: SCNMaterial, base: UIColor)] = []

    // Soil patch under the plant — cream when healthy, dry cracked when not.
    private let soilMaterial = GardenMaterials.flat(GardenPalette.soilCream)
    private var crackGroup = SCNNode()

    // Bees orbit the open bloom (day + bloom stage only).
    private var beeOrbit = SCNNode()

    private let swayKey = "garden.sway"

    override init() {
        super.init()
        buildSoil()
        buildAllStages()
        buildBees()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { return nil }

    // MARK: - Public API

    /// Show one stage with care-driven droop/desaturation. When `animated`,
    /// changes ease over 1.5s — the watering-recovery moment.
    func apply(stage: Stage, droopDegrees: Double, saturation: CGFloat,
               soilDryness: CGFloat, sway: Bool, showBees: Bool, animated: Bool) {
        let work = { [self] in
            for (s, node) in stageNodes {
                node.isHidden = (s != stage)
            }

            let lean = Float(droopDegrees * 0.35 * .pi / 180.0)
            let pitch = Float(droopDegrees * .pi / 180.0)
            for (_, node) in stageNodes {
                node.eulerAngles.z = -lean
            }
            for (_, head) in headNodes {
                head.eulerAngles.x = pitch
            }

            for entry in tintables {
                entry.material.diffuse.contents = entry.base.gardenDesaturated(to: saturation)
            }

            // Soil: cream → dry cracked brown as care worsens.
            let dry = max(0, min(1, soilDryness))
            self.soilMaterial.diffuse.contents = self.blend(
                GardenPalette.soilCream, GardenPalette.soilBrown, t: dry
            )
            self.crackGroup.opacity = dry

            self.beeOrbit.isHidden = !(showBees && stage == .fullBloom)
        }

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.5
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            work()
            SCNTransaction.commit()
        } else {
            work()
        }

        // Gentle idle sway on the whole plant when healthy and motion allowed.
        removeAction(forKey: swayKey)
        if sway {
            let amp: CGFloat = 0.017   // ≈1° — visible but calm, 3s round trip
            let a = SCNAction.rotateBy(x: 0, y: 0, z: amp, duration: 1.5)
            a.timingMode = .easeInEaseOut
            let b = SCNAction.rotateBy(x: 0, y: 0, z: -amp, duration: 1.5)
            b.timingMode = .easeInEaseOut
            runAction(.repeatForever(.sequence([a, b])), forKey: swayKey)
        } else {
            eulerAngles.z = 0
        }
    }

    private func blend(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t,
                       blue: ab + (bb - ab) * t, alpha: 1)
    }

    private func tintable(_ color: UIColor) -> SCNMaterial {
        let m = GardenMaterials.flat(color)
        tintables.append((m, color))
        return m
    }

    // MARK: - Soil patch + cracks

    private func buildSoil() {
        let patch = SCNCylinder(radius: 0.65, height: 0.04)
        patch.radialSegmentCount = 18
        patch.firstMaterial = soilMaterial
        let patchNode = SCNNode(geometry: patch)
        patchNode.position = SCNVector3(0, 0.02, 0)
        patchNode.castsShadow = false
        addChildNode(patchNode)

        // A few brown patches for the healthy look.
        var rng = GardenSeededRandom(seed: 41)
        for _ in 0..<3 {
            let spot = SCNCylinder(radius: CGFloat(rng.range(0.08, 0.14)), height: 0.045)
            spot.radialSegmentCount = 10
            spot.firstMaterial = GardenMaterials.flat(GardenPalette.soilBrown)
            let node = SCNNode(geometry: spot)
            let a = rng.range(0, 6.28)
            let r = rng.range(0.2, 0.45)
            node.position = SCNVector3(Float(cos(a) * r), 0.022, Float(sin(a) * r))
            node.castsShadow = false
            addChildNode(node)
        }

        // Dry cracks — thin dark slats, faded in with dryness.
        crackGroup = SCNNode()
        crackGroup.opacity = 0
        for i in 0..<5 {
            let crack = SCNBox(width: CGFloat(rng.range(0.25, 0.5)),
                               height: 0.005, length: 0.02, chamferRadius: 0)
            crack.firstMaterial = GardenMaterials.unlit(GardenPalette.soilCrack)
            let node = SCNNode(geometry: crack)
            node.position = SCNVector3(
                Float(rng.range(-0.3, 0.3)), 0.045, Float(rng.range(-0.3, 0.3))
            )
            node.eulerAngles.y = Float(i) * 1.25
            node.castsShadow = false
            crackGroup.addChildNode(node)
        }
        addChildNode(crackGroup)
    }

    // MARK: - Stage construction

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

    /// Stage 1 — SEED: warm brown mound with a hopeful crack of light.
    private func makeSeedMound() -> SCNNode {
        let root = SCNNode()

        let mound = SCNSphere(radius: 0.3)
        mound.segmentCount = 14
        mound.firstMaterial = tintable(GardenPalette.seedSoil)
        let moundNode = SCNNode(geometry: mound)
        moundNode.scale = SCNVector3(1.0, 0.5, 1.0)
        moundNode.position = SCNVector3(0, 0.1, 0)
        root.addChildNode(moundNode)

        // The crack — a sliver of pale gold light where the seed will break through.
        let crack = SCNBox(width: 0.16, height: 0.012, length: 0.025, chamferRadius: 0.005)
        crack.firstMaterial = GardenMaterials.glow(GardenPalette.budPale)
        let crackNode = SCNNode(geometry: crack)
        crackNode.position = SCNVector3(0, 0.245, 0.02)
        crackNode.eulerAngles.y = 0.4
        root.addChildNode(crackNode)

        return root
    }

    /// Stage 2 — SPROUT: short stem, two bright rounded leaves reaching up.
    private func makeSprout() -> SCNNode {
        let root = SCNNode()

        let stem = SCNCylinder(radius: 0.035, height: 0.42)
        stem.radialSegmentCount = 10
        stem.firstMaterial = tintable(GardenPalette.stem)
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, 0.21, 0)
        root.addChildNode(stemNode)

        for (i, side) in [Float(-1), Float(1)].enumerated() {
            let leaf = SCNSphere(radius: 0.12)
            leaf.segmentCount = 12
            leaf.firstMaterial = tintable(GardenPalette.leaf)
            let leafNode = SCNNode(geometry: leaf)
            leafNode.scale = SCNVector3(1.4, 0.4, 0.7)
            leafNode.position = SCNVector3(side * 0.15, 0.38 + Float(i) * 0.05, 0)
            leafNode.eulerAngles.z = side * 0.55   // reaching upward
            root.addChildNode(leafNode)
        }

        return root
    }

    /// Stage 3 — GROWING: taller stem, 4 leaves, pale bud forming.
    private func makeGrowing() -> SCNNode {
        let root = makeStemAndLeaves(height: 1.0, leafCount: 4)
        let headPivot = SCNNode()
        headPivot.position = SCNVector3(0, 1.0, 0)
        root.addChildNode(headPivot)

        let bud = SCNSphere(radius: 0.11)
        bud.segmentCount = 12
        bud.firstMaterial = tintable(GardenPalette.budPale)
        let budNode = SCNNode(geometry: bud)
        budNode.scale = SCNVector3(0.9, 1.15, 0.9)
        budNode.position = SCNVector3(0, 0.08, 0)
        headPivot.addChildNode(budNode)

        headNodes[.stemWithLeaves] = headPivot
        return root
    }

    /// Stage 4 — BUDDING: full height, bright yellow bud, green sepals.
    private func makeBudding() -> SCNNode {
        let root = makeStemAndLeaves(height: 1.3, leafCount: 4)
        let headPivot = SCNNode()
        headPivot.position = SCNVector3(0, 1.3, 0)
        root.addChildNode(headPivot)

        let bud = SCNSphere(radius: 0.15)
        bud.segmentCount = 12
        bud.firstMaterial = tintable(GardenPalette.budBright)
        let budNode = SCNNode(geometry: bud)
        budNode.scale = SCNVector3(0.95, 1.25, 0.95)
        budNode.position = SCNVector3(0, 0.12, 0)
        headPivot.addChildNode(budNode)

        // Four green sepals cupping the bud — about to open.
        for i in 0..<4 {
            let sepal = SCNSphere(radius: 0.07)
            sepal.segmentCount = 10
            sepal.firstMaterial = tintable(GardenPalette.stem)
            let sepalNode = SCNNode(geometry: sepal)
            sepalNode.scale = SCNVector3(0.5, 1.4, 0.3)
            let angle = Float(i) * .pi / 2
            sepalNode.position = SCNVector3(cos(angle) * 0.11, 0.02, sin(angle) * 0.11)
            sepalNode.eulerAngles = SCNVector3(0.35 * sin(angle), 0, -0.35 * cos(angle))
            headPivot.addChildNode(sepalNode)
        }

        headNodes[.bud] = headPivot
        return root
    }

    /// Stage 5 — FULL BLOOM: 16 golden petals, rich brown seed disc with a
    /// dotted seed-spiral, proud and center frame. The most beautiful moment
    /// in the app.
    private func makeFullBloom() -> SCNNode {
        let root = makeStemAndLeaves(height: 1.55, leafCount: 4)
        let headPivot = SCNNode()
        headPivot.position = SCNVector3(0, 1.55, 0)
        // Face the head slightly toward the camera so the disc reads.
        headPivot.eulerAngles.x = 0.18
        root.addChildNode(headPivot)

        // Center disc — rich brown.
        let center = SCNSphere(radius: 0.19)
        center.segmentCount = 14
        center.firstMaterial = tintable(GardenPalette.bloomCenter)
        let centerNode = SCNNode(geometry: center)
        centerNode.scale = SCNVector3(1.0, 1.0, 0.5)
        centerNode.position = SCNVector3(0, 0.16, 0.02)
        headPivot.addChildNode(centerNode)

        // Seed pattern: an outer ring of 10 dots + inner ring of 5.
        let dotMaterial = GardenMaterials.unlit(GardenPalette.seedDot)
        for (count, ringRadius) in [(10, Float(0.115)), (5, Float(0.055))] {
            for i in 0..<count {
                let angle = Float(i) / Float(count) * 2 * .pi
                let dot = SCNSphere(radius: 0.014)
                dot.segmentCount = 6
                dot.firstMaterial = dotMaterial
                let dotNode = SCNNode(geometry: dot)
                dotNode.position = SCNVector3(
                    cos(angle) * ringRadius,
                    0.16 + sin(angle) * ringRadius,
                    0.115
                )
                headPivot.addChildNode(dotNode)
            }
        }

        // 16 bright golden petals — two subtle length variants for life.
        let petalCount = 16
        for i in 0..<petalCount {
            let angle = Float(i) / Float(petalCount) * 2 * .pi
            let long = (i % 2 == 0)
            let petal = SCNSphere(radius: long ? 0.115 : 0.10)
            petal.segmentCount = 8
            petal.firstMaterial = tintable(GardenPalette.petal)
            let petalNode = SCNNode(geometry: petal)
            petalNode.scale = SCNVector3(0.5, 1.6, 0.22)
            let ringRadius: Float = long ? 0.30 : 0.27
            petalNode.position = SCNVector3(
                cos(angle) * ringRadius,
                0.16 + sin(angle) * ringRadius,
                0
            )
            petalNode.eulerAngles.z = angle - .pi / 2
            headPivot.addChildNode(petalNode)
        }

        headNodes[.fullBloom] = headPivot
        return root
    }

    /// Shared tall-stage builder: stem + alternating bright leaves.
    private func makeStemAndLeaves(height: Float, leafCount: Int) -> SCNNode {
        let root = SCNNode()

        let stem = SCNCylinder(radius: 0.05, height: CGFloat(height))
        stem.radialSegmentCount = 10
        stem.firstMaterial = tintable(GardenPalette.stem)
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, height / 2, 0)
        root.addChildNode(stemNode)

        for i in 0..<leafCount {
            let f = Float(i + 1) / Float(leafCount + 1)
            let side: Float = (i % 2 == 0) ? -1 : 1
            let leaf = SCNSphere(radius: 0.15)
            leaf.segmentCount = 12
            leaf.firstMaterial = tintable(GardenPalette.leaf)
            let leafNode = SCNNode(geometry: leaf)
            leafNode.scale = SCNVector3(1.6, 0.32, 0.8)
            leafNode.position = SCNVector3(side * 0.2, height * f, 0)
            leafNode.eulerAngles.z = side * 0.45
            root.addChildNode(leafNode)
        }

        return root
    }

    // MARK: - Bees (orbit the open bloom, day only)

    private func buildBees() {
        beeOrbit = SCNNode()
        beeOrbit.position = SCNVector3(0, 1.7, 0)
        beeOrbit.isHidden = true

        for k in 0..<2 {
            let bee = SCNNode()
            let bodyGeo = SCNSphere(radius: 0.035)
            bodyGeo.segmentCount = 8
            bodyGeo.firstMaterial = GardenMaterials.unlit(GardenPalette.flowerYellow)
            let body = SCNNode(geometry: bodyGeo)
            bee.addChildNode(body)

            let stripeGeo = SCNSphere(radius: 0.02)
            stripeGeo.segmentCount = 6
            stripeGeo.firstMaterial = GardenMaterials.unlit(UIColor(white: 0.15, alpha: 1))
            let stripe = SCNNode(geometry: stripeGeo)
            stripe.position = SCNVector3(0.02, 0, 0)
            bee.addChildNode(stripe)

            let radius: Float = 0.45 + Float(k) * 0.12
            bee.position = SCNVector3(radius, Float(k) * 0.1 - 0.05, 0)
            beeOrbit.addChildNode(bee)
        }
        addChildNode(beeOrbit)
    }

    /// Start/stop the bee orbit action (kept separate so reduce-motion can
    /// show static bees — in practice bees are hidden under reduce-motion).
    func setBeesAnimating(_ animating: Bool) {
        let key = "garden.bees"
        beeOrbit.removeAction(forKey: key)
        if animating {
            beeOrbit.runAction(
                .repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 7)),
                forKey: key
            )
        }
    }
}
