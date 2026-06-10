//
//  WorldParticles.swift
//  Dino
//
//  Region ambience particles, deliberately sparse: meadow pollen, grove
//  light motes, pond dragonflies, overlook fireflies (max 12). All skipped
//  under reduce-motion.
//

import SceneKit
import UIKit

enum WorldParticles {

    /// Fireflies for the overlook. 1.4/s × 8s ≈ 11 alive (< 12 budget).
    static func fireflies() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.4
        p.particleLifeSpan = 8
        p.particleSize = 0.06
        p.particleColor = WorldPalette.moon
        p.particleVelocity = 0.22
        p.blendMode = .additive
        p.emitterShape = SCNBox(width: 10, height: 4, length: 8, chamferRadius: 0)
        return p
    }

    /// Light motes drifting in the grove god rays. ≈7 alive (< 8 budget).
    static func motes() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.1
        p.particleLifeSpan = 6
        p.particleSize = 0.04
        p.particleColor = UIColor(white: 1.0, alpha: 0.6)
        p.particleVelocity = 0.15
        p.blendMode = .additive
        p.emitterShape = SCNBox(width: 6, height: 4, length: 6, chamferRadius: 0)
        return p
    }

    /// Pollen in the meadow. ≈6 alive.
    static func pollen() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.0
        p.particleLifeSpan = 6
        p.particleSize = 0.035
        p.particleColor = UIColor(red: 1.0, green: 0.97, blue: 0.85, alpha: 0.55)
        p.particleVelocity = 0.16
        p.blendMode = .alpha
        p.emitterShape = SCNBox(width: 9, height: 3.5, length: 7, chamferRadius: 0)
        return p
    }

    /// A few dragonflies skimming the pond. ≈3 alive.
    static func dragonflies() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 0.5
        p.particleLifeSpan = 6
        p.particleSize = 0.07
        p.particleColor = WorldPalette.sage
        p.particleVelocity = 0.5
        p.particleVelocityVariation = 0.25
        p.blendMode = .alpha
        p.emitterShape = SCNBox(width: 4, height: 1.2, length: 4, chamferRadius: 0)
        return p
    }

    private static func base() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleLifeSpanVariation = 1.5
        p.particleSizeVariation = 0.015
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 180
        p.acceleration = SCNVector3(0, 0.015, 0)
        p.isAffectedByGravity = false
        p.birthLocation = .volume
        return p
    }
}
