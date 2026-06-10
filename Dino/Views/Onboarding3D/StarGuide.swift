//
//  StarGuide.swift
//  Dino
//
//  The glowing star guide — the world's character presence. A warm emissive
//  orb with three nested glow shells and a real omni light so nearby trees
//  and ground catch its warmth. It travels ahead of the camera between
//  onboarding steps, leaving a soft golden trail, and bursts with sparkles
//  when the user advances.
//

import SceneKit
import UIKit

final class StarGuide: SCNNode {

    private let floatNode = SCNNode()      // idle bob lives here, separate from journey moves
    private var glowLayers: [SCNNode] = []
    private let lightNode = SCNNode()
    private let reduceMotion: Bool

    private let journeyKey = "star.journey"
    private let baseLightIntensity: CGFloat = 800

    init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        super.init()
        castsShadow = false
        buildStar()
        if !reduceMotion {
            startIdleAnimations()
            attachTrail()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { return nil }

    // MARK: - Construction

    private func buildStar() {
        addChildNode(floatNode)

        // Core — pure warm-white emissive.
        let coreGeo = SCNSphere(radius: 0.18)
        coreGeo.segmentCount = 12
        coreGeo.firstMaterial = WorldMaterials.glow(UIColor(red: 1.0, green: 0.973, blue: 0.906, alpha: 1)) // #FFF8E7
        let core = SCNNode(geometry: coreGeo)
        core.castsShadow = false
        floatNode.addChildNode(core)

        // Three nested glow shells.
        let shells: [(radius: CGFloat, color: UIColor, alpha: CGFloat)] = [
            (0.24, UIColor(red: 1.0, green: 0.894, blue: 0.627, alpha: 1), 0.35),  // #FFE4A0
            (0.35, UIColor(red: 1.0, green: 0.843, blue: 0.0, alpha: 1), 0.15),    // #FFD700
            (0.55, UIColor(red: 1.0, green: 0.980, blue: 0.941, alpha: 1), 0.08)   // #FFFAF0
        ]
        for shell in shells {
            let geo = SCNSphere(radius: shell.radius)
            geo.segmentCount = 10
            let m = SCNMaterial()
            m.diffuse.contents = shell.color.withAlphaComponent(shell.alpha)
            m.emission.contents = shell.color.withAlphaComponent(shell.alpha)
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

        // The star genuinely lights the world around it.
        let light = SCNLight()
        light.type = .omni
        light.color = UIColor(red: 1.0, green: 0.973, blue: 0.906, alpha: 1)
        light.intensity = baseLightIntensity
        light.attenuationStartDistance = 2.0
        light.attenuationEndDistance = 8.0
        light.castsShadow = false
        lightNode.light = light
        floatNode.addChildNode(lightNode)
    }

    private func startIdleAnimations() {
        // Gentle float: ±0.15 over a 3s round trip.
        let up = SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 1.5)
        up.timingMode = .easeInEaseOut
        let down = SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 1.5)
        down.timingMode = .easeInEaseOut
        floatNode.runAction(.repeatForever(.sequence([up, down])))

        // Glow pulse: shells breathe 1.0→1.15→1.0 over 2.5s.
        for layer in glowLayers {
            let grow = SCNAction.scale(to: 1.15, duration: 1.25)
            grow.timingMode = .easeInEaseOut
            let shrink = SCNAction.scale(to: 1.0, duration: 1.25)
            shrink.timingMode = .easeInEaseOut
            layer.runAction(.repeatForever(.sequence([grow, shrink])))
        }

        // Slow spin — one revolution every 20s.
        floatNode.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 20)))
    }

    private func attachTrail() {
        let trail = SCNParticleSystem()
        trail.birthRate = 15
        trail.particleLifeSpan = 0.8
        trail.particleSize = 0.04
        trail.particleColor = UIColor(red: 1.0, green: 0.843, blue: 0.0, alpha: 0.8)  // #FFD700
        trail.particleColorVariation = SCNVector4(0.02, 0.04, 0.0, 0.1)
        trail.particleVelocity = 0.05
        trail.speedFactor = 0.3
        trail.spreadingAngle = 180
        trail.isAffectedByGravity = false
        trail.blendMode = .additive
        trail.birthLocation = .surface
        trail.emitterShape = SCNSphere(radius: 0.1)
        floatNode.addParticleSystem(trail)
    }

    // MARK: - Journey

    /// Glide to the next step's perch. The star leads the camera — callers
    /// pass a duration ~0.3s shorter than the camera dolly.
    func glide(to position: SCNVector3, duration: TimeInterval) {
        removeAction(forKey: journeyKey)
        if reduceMotion || duration <= 0.05 {
            self.position = position
            return
        }
        let move = SCNAction.move(to: position, duration: duration)
        move.timingMode = .easeInEaseOut
        runAction(move, forKey: journeyKey)
    }

    // MARK: - Reactions

    /// Step advance: bright burst — scale pop, light spike, 8 sparkles.
    func onStepAdvance() {
        guard !reduceMotion else { return }
        reactionBurst(peakScale: 1.4, sparkles: 8, lightPeak: 2000)
    }

    /// Selection: a gentler acknowledgment — 4 sparkles.
    func onSelection() {
        guard !reduceMotion else { return }
        reactionBurst(peakScale: 1.2, sparkles: 4, lightPeak: 1300)
    }

    private func reactionBurst(peakScale: CGFloat, sparkles: Int, lightPeak: CGFloat) {
        // Scale pop with a springy settle (overshoot timing curve).
        let popKey = "star.pop"
        floatNode.removeAction(forKey: popKey)
        let up = SCNAction.scale(to: peakScale, duration: 0.15)
        up.timingMode = .easeOut
        let settle = SCNAction.scale(to: 1.0, duration: 0.25)
        settle.timingFunction = { t in
            // Soft overshoot ≈ spring(response 0.3, damping 0.5)
            let p = t - 1.0
            return 1.0 + p * p * p * (1.0 + 1.6 * t)
        }
        floatNode.runAction(.sequence([up, settle]), forKey: popKey)

        // Light spike 800 → peak → 800.
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.15
        lightNode.light?.intensity = lightPeak
        SCNTransaction.completionBlock = { [weak self] in
            guard let self else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.25
            self.lightNode.light?.intensity = self.baseLightIntensity
            SCNTransaction.commit()
        }
        SCNTransaction.commit()

        // One-shot sparkle burst, removed after it dies.
        let burst = SCNParticleSystem()
        burst.birthRate = CGFloat(sparkles) / 0.15
        burst.emissionDuration = 0.15
        burst.loops = false
        burst.particleLifeSpan = 1.2
        burst.particleSize = 0.05
        burst.particleColor = UIColor(red: 1.0, green: 0.894, blue: 0.627, alpha: 1)
        burst.particleVelocity = 1.0
        burst.particleVelocityVariation = 0.4
        burst.spreadingAngle = 180
        burst.isAffectedByGravity = false
        burst.blendMode = .additive
        burst.birthLocation = .surface
        burst.emitterShape = SCNSphere(radius: 0.18)
        floatNode.addParticleSystem(burst)
        floatNode.runAction(.sequence([
            .wait(duration: 1.6),
            .run { node in node.removeParticleSystem(burst) }
        ]))
    }
}
