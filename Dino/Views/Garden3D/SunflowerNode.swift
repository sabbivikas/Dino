//
//  SunflowerNode.swift
//  Dino
//
//  The centerpiece sunflower. Five discrete stage nodes (seed mound, sprout,
//  stem with leaves, bud, full bloom) with visibility toggled — no geometry
//  morphing. Care state drives droop rotation + material desaturation,
//  read-only from GrowthViewModel-provided values.
//

import SceneKit
import UIKit

final class SunflowerNode: SCNNode {

    /// Discrete geometry stages. GrowthViewModel's nine GrowthStage cases
    /// collapse onto these five (mapping lives in GardenSceneView).
    enum Stage: Int, CaseIterable {
        case seedMound = 0, sprout, stemWithLeaves, bud, fullBloom
    }

    private var stageNodes: [Stage: SCNNode] = [:]
    /// Materials whose diffuse should desaturate with poor care, with their base colors.
    private var tintables: [(material: SCNMaterial, base: UIColor)] = []
    /// The sub-node that pitches forward when the plant droops.
    private var headNodes: [Stage: SCNNode] = [:]

    private let swayKey = "garden.sway"

    override init() {
        super.init()
        buildAllStages()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { return nil }

    // MARK: - Public API

    /// Show exactly one stage and apply care-driven droop + desaturation.
    func apply(stage: Stage, droopDegrees: Double, saturation: CGFloat, sway: Bool) {
        for (s, node) in stageNodes {
            node.isHidden = (s != stage)
        }

        // Whole-plant lean (subtle) + head pitch (stronger).
        let lean = Float(droopDegrees * 0.35 * .pi / 180.0)
        let pitch = Float(droopDegrees * .pi / 180.0)
        for (_, node) in stageNodes {
            node.eulerAngles.z = -lean
        }
        for (_, head) in headNodes {
            head.eulerAngles.x = pitch
        }

        // Desaturate every tintable material toward the care level.
        for entry in tintables {
            entry.material.diffuse.contents = entry.base.gardenDesaturated(to: saturation)
        }

        // Gentle wind sway on the visible stage only.
        removeAction(forKey: swayKey)
        if sway {
            let tiltA = SCNAction.rotateBy(x: 0, y: 0, z: 0.03, duration: 2.4)
            tiltA.timingMode = .easeInEaseOut
            let tiltB = SCNAction.rotateBy(x: 0, y: 0, z: -0.03, duration: 2.4)
            tiltB.timingMode = .easeInEaseOut
            runAction(.repeatForever(.sequence([tiltA, tiltB])), forKey: swayKey)
        } else {
            eulerAngles.z = 0
        }
    }

    // MARK: - Stage construction

    private func buildAllStages() {
        stageNodes[.seedMound] = makeSeedMound()
        stageNodes[.sprout] = makeSprout()
        stageNodes[.stemWithLeaves] = makeStem(withBud: false, bloom: false)
        stageNodes[.bud] = makeStem(withBud: true, bloom: false)
        stageNodes[.fullBloom] = makeStem(withBud: false, bloom: true)
        for (_, node) in stageNodes {
            node.isHidden = true
            addChildNode(node)
        }
    }

    private func tintable(_ color: UIColor) -> SCNMaterial {
        let m = GardenMaterials.flat(color)
        tintables.append((m, color))
        return m
    }

    private func makeSeedMound() -> SCNNode {
        let root = SCNNode()

        let mound = SCNSphere(radius: 0.32)
        mound.segmentCount = 10
        mound.firstMaterial = tintable(GardenPalette.earth)
        let moundNode = SCNNode(geometry: mound)
        moundNode.scale = SCNVector3(1.0, 0.45, 1.0)
        moundNode.position = SCNVector3(0, 0.10, 0)
        root.addChildNode(moundNode)

        let seed = SCNSphere(radius: 0.07)
        seed.segmentCount = 8
        seed.firstMaterial = tintable(GardenPalette.seedShell)
        let seedNode = SCNNode(geometry: seed)
        seedNode.scale = SCNVector3(0.8, 1.2, 0.8)
        seedNode.position = SCNVector3(0, 0.30, 0)
        root.addChildNode(seedNode)

        return root
    }

    private func makeSprout() -> SCNNode {
        let root = SCNNode()

        let stem = SCNCylinder(radius: 0.035, height: 0.45)
        stem.radialSegmentCount = 8
        stem.firstMaterial = tintable(GardenPalette.sageDeep)
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, 0.225, 0)
        root.addChildNode(stemNode)

        for (i, side) in [Float(-1), Float(1)].enumerated() {
            let leaf = SCNSphere(radius: 0.12)
            leaf.segmentCount = 8
            leaf.firstMaterial = tintable(GardenPalette.leaf)
            let leafNode = SCNNode(geometry: leaf)
            leafNode.scale = SCNVector3(1.4, 0.35, 0.7)
            leafNode.position = SCNVector3(side * 0.16, 0.42 + Float(i) * 0.04, 0)
            leafNode.eulerAngles.z = side * 0.5
            root.addChildNode(leafNode)
        }

        return root
    }

    /// Shared builder for the three tall stages. `withBud` adds a closed green
    /// bud; `bloom` adds the full flower head. Both false = stem with leaves.
    private func makeStem(withBud: Bool, bloom: Bool) -> SCNNode {
        let root = SCNNode()
        let stemHeight: Float = bloom ? 1.5 : (withBud ? 1.3 : 1.0)

        let stem = SCNCylinder(radius: 0.05, height: CGFloat(stemHeight))
        stem.radialSegmentCount = 8
        stem.firstMaterial = tintable(GardenPalette.sageDeep)
        let stemNode = SCNNode(geometry: stem)
        stemNode.position = SCNVector3(0, stemHeight / 2, 0)
        root.addChildNode(stemNode)

        // Four alternating leaves up the stem.
        let leafHeights: [Float] = [0.30, 0.52, 0.74, 0.96].map { $0 * stemHeight }
        for (i, h) in leafHeights.enumerated() {
            let side: Float = (i % 2 == 0) ? -1 : 1
            let leaf = SCNSphere(radius: 0.16)
            leaf.segmentCount = 8
            leaf.firstMaterial = tintable(GardenPalette.leaf)
            let leafNode = SCNNode(geometry: leaf)
            leafNode.scale = SCNVector3(1.6, 0.30, 0.8)
            leafNode.position = SCNVector3(side * 0.22, h, 0)
            leafNode.eulerAngles.z = side * 0.45
            root.addChildNode(leafNode)
        }

        // Head pivot at the stem tip — droop pitches this node.
        let headPivot = SCNNode()
        headPivot.position = SCNVector3(0, stemHeight, 0)
        root.addChildNode(headPivot)

        if withBud {
            let budGeo = SCNSphere(radius: 0.16)
            budGeo.segmentCount = 10
            budGeo.firstMaterial = tintable(GardenPalette.bud)
            let budNode = SCNNode(geometry: budGeo)
            budNode.scale = SCNVector3(0.9, 1.25, 0.9)
            budNode.position = SCNVector3(0, 0.10, 0)
            headPivot.addChildNode(budNode)
        }

        if bloom {
            // Center disc.
            let center = SCNSphere(radius: 0.17)
            center.segmentCount = 10
            center.firstMaterial = tintable(GardenPalette.seedHead)
            let centerNode = SCNNode(geometry: center)
            centerNode.scale = SCNVector3(1.0, 1.0, 0.55)
            centerNode.position = SCNVector3(0, 0.14, 0.02)
            headPivot.addChildNode(centerNode)

            // 12 petals in a ring, flattened spheres.
            let petalCount = 12
            for i in 0..<petalCount {
                let angle = Float(i) / Float(petalCount) * 2 * .pi
                let petal = SCNSphere(radius: 0.11)
                petal.segmentCount = 6
                petal.firstMaterial = tintable(GardenPalette.petal)
                let petalNode = SCNNode(geometry: petal)
                petalNode.scale = SCNVector3(0.55, 1.5, 0.25)
                let ringRadius: Float = 0.26
                petalNode.position = SCNVector3(
                    cos(angle) * ringRadius,
                    0.14 + sin(angle) * ringRadius,
                    0
                )
                petalNode.eulerAngles.z = angle - .pi / 2
                headPivot.addChildNode(petalNode)
            }
        }

        headNodes[bloom ? .fullBloom : (withBud ? .bud : .stemWithLeaves)] = headPivot
        return root
    }
}
