//
//  AmbientStarGuide.swift
//  Dino
//
//  The star companion from onboarding, simplified for the ambient scene:
//  the same warm core + three glow shells + real omni light, with idle
//  float, pulse and slow spin only — no bursts, no trail, no reactions.
//  A peaceful presence beside the waterfall.
//

import SceneKit
import UIKit

final class AmbientStarGuide: SCNNode {

    private let floatNode = SCNNode()

    init(reduceMotion: Bool) {
        super.init()
        castsShadow = false
        addChildNode(floatNode)

        let coreGeo = SCNSphere(radius: 0.15)
        coreGeo.segmentCount = 12
        let cm = SCNMaterial()
        cm.diffuse.contents = UIColor(hexRGB: 0xFFF8E7)
        cm.emission.contents = UIColor(hexRGB: 0xFFF8E7)
        cm.lightingModel = .constant
        coreGeo.firstMaterial = cm
        let core = SCNNode(geometry: coreGeo)
        core.castsShadow = false
        floatNode.addChildNode(core)

        var glowLayers: [SCNNode] = []
        let shells: [(radius: CGFloat, hex: UInt32, alpha: CGFloat)] = [
            (0.2, 0xFFE4A0, 0.35), (0.3, 0xFFD700, 0.15), (0.46, 0xFFFAF0, 0.08)
        ]
        for shell in shells {
            let geo = SCNSphere(radius: shell.radius)
            geo.segmentCount = 10
            let m = SCNMaterial()
            let color = UIColor(hexRGB: shell.hex).withAlphaComponent(shell.alpha)
            m.diffuse.contents = color
            m.emission.contents = color
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.blendMode = .add
            m.writesToDepthBuffer = false
            geo.firstMaterial = m
            let node = SCNNode(geometry: geo)
            node.castsShadow = false
            glowLayers.append(node)
            floatNode.addChildNode(node)
        }

        // The star genuinely lights its corner of the world.
        let light = SCNLight()
        light.type = .omni
        light.color = UIColor(hexRGB: 0xFFF8E7)
        light.intensity = 600
        light.attenuationStartDistance = 1.5
        light.attenuationEndDistance = 6
        light.castsShadow = false
        let lightNode = SCNNode()
        lightNode.light = light
        floatNode.addChildNode(lightNode)

        guard !reduceMotion else { return }

        // Idle float ±0.12 over 3s.
        let up = SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 1.5)
        up.timingMode = .easeInEaseOut
        let down = SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 1.5)
        down.timingMode = .easeInEaseOut
        floatNode.runAction(.repeatForever(.sequence([up, down])))

        // Glow pulse 1.0 → 1.15 → 1.0 over 2.5s.
        for layer in glowLayers {
            let grow = SCNAction.scale(to: 1.15, duration: 1.25)
            grow.timingMode = .easeInEaseOut
            let shrink = SCNAction.scale(to: 1.0, duration: 1.25)
            shrink.timingMode = .easeInEaseOut
            layer.runAction(.repeatForever(.sequence([grow, shrink])))
        }

        // Slow spin.
        floatNode.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 20)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { return nil }
}
