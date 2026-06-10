//
//  GardenParticles.swift
//  Dino
//
//  Ambient particle systems built in code: night fireflies (max ~12) and
//  daytime pollen motes (max ~8). Deliberately low birth rates — ambience,
//  not a fireworks show. Skipped entirely under reduce-motion.
//

import SceneKit
import UIKit

enum GardenParticles {

    /// Slow-drifting glowing fireflies for the night period.
    /// birthRate 1.4 × lifeSpan 8s ≈ 11 alive — within the 12 budget.
    static func fireflies() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 1.4
        p.particleLifeSpan = 8
        p.particleLifeSpanVariation = 2
        p.particleSize = 0.055
        p.particleSizeVariation = 0.02
        p.particleColor = UIColor(hexRGB: 0xF5E9C4)
        p.particleColorVariation = SCNVector4(0.02, 0.02, 0.0, 0.0)
        p.particleVelocity = 0.25
        p.particleVelocityVariation = 0.15
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 180
        p.acceleration = SCNVector3(0, 0.02, 0)
        p.isAffectedByGravity = false
        p.blendMode = .additive
        p.emitterShape = {
            let box = SCNBox(width: 9, height: 2.5, length: 7, chamferRadius: 0)
            return box
        }()
        p.birthLocation = .volume
        return p
    }

    /// Faint pollen motes drifting through daylight.
    /// birthRate 1.1 × lifeSpan 6s ≈ 7 alive — within the 8 budget.
    static func pollen() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 1.1
        p.particleLifeSpan = 6
        p.particleLifeSpanVariation = 1.5
        p.particleSize = 0.035
        p.particleSizeVariation = 0.015
        p.particleColor = UIColor(white: 1.0, alpha: 0.55)
        p.particleVelocity = 0.18
        p.particleVelocityVariation = 0.1
        p.emittingDirection = SCNVector3(0.3, 0.5, 0)
        p.spreadingAngle = 160
        p.acceleration = SCNVector3(0.01, -0.005, 0)
        p.isAffectedByGravity = false
        p.blendMode = .alpha
        p.emitterShape = {
            let box = SCNBox(width: 8, height: 3, length: 6, chamferRadius: 0)
            return box
        }()
        p.birthLocation = .volume
        return p
    }
}
