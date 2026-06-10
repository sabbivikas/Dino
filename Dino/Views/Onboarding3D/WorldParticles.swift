//
//  WorldParticles.swift
//  Dino
//
//  Playful illustrated ambience: bright pollen, glowing fireflies, falling
//  petals, gentle pond rain, flower sparkles, dragonflies, grove motes.
//  All skipped under reduce-motion.
//

import SceneKit
import UIKit

enum WorldParticles {

    /// Bright warm fireflies for the overlook night. ≈11 alive (< 12).
    static func fireflies() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.4
        p.particleLifeSpan = 8
        p.particleSize = 0.07
        p.particleColor = WorldPalette.flowerYellow
        p.particleVelocity = 0.22
        p.blendMode = .additive
        p.emitterShape = SCNBox(width: 10, height: 4, length: 8, chamferRadius: 0)
        return p
    }

    /// Light motes in the grove. ≈7 alive (< 8).
    static func motes() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.1
        p.particleLifeSpan = 6
        p.particleSize = 0.05
        p.particleColor = UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 0.7)
        p.particleVelocity = 0.15
        p.blendMode = .additive
        p.emitterShape = SCNBox(width: 6, height: 4, length: 6, chamferRadius: 0)
        return p
    }

    /// Bigger, more visible pollen in the meadow. ≈7 alive.
    static func pollen() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.2
        p.particleLifeSpan = 6
        p.particleSize = 0.08
        p.particleColor = UIColor(red: 1.0, green: 0.95, blue: 0.65, alpha: 0.8)
        p.particleVelocity = 0.16
        p.blendMode = .alpha
        p.emitterShape = SCNBox(width: 9, height: 3.5, length: 7, chamferRadius: 0)
        return p
    }

    /// Falling flower petals — pink/peach, slow tumble. ≈6 alive.
    static func petals() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 0.8
        p.particleLifeSpan = 7
        p.particleSize = 0.09
        p.particleColor = WorldPalette.flowerPeach
        p.particleColorVariation = SCNVector4(0.06, 0.04, 0.04, 0.0)
        p.particleVelocity = 0.3
        p.particleVelocityVariation = 0.15
        p.emittingDirection = SCNVector3(0, -1, 0)
        p.acceleration = SCNVector3(0.05, -0.08, 0)
        p.particleAngularVelocity = 60
        p.blendMode = .alpha
        p.emitterShape = SCNBox(width: 9, height: 0.5, length: 7, chamferRadius: 0)
        return p
    }

    /// Fine gentle rain over the pond. ≈30 alive, tiny and soft.
    static func rain() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 24
        p.particleLifeSpan = 1.2
        p.particleLifeSpanVariation = 0.2
        p.particleSize = 0.02
        p.particleColor = UIColor(white: 1.0, alpha: 0.45)
        p.particleVelocity = 2.4
        p.particleVelocityVariation = 0.4
        p.emittingDirection = SCNVector3(0, -1, 0)
        p.spreadingAngle = 4
        p.blendMode = .alpha
        p.emitterShape = SCNBox(width: 7, height: 0.3, length: 7, chamferRadius: 0)
        return p
    }

    /// Tiny star sparkles near the meadow flowers. ≈4 alive.
    static func sparkles() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.6
        p.particleLifeSpan = 2.2
        p.particleSize = 0.05
        p.particleColor = UIColor(red: 1.0, green: 0.98, blue: 0.85, alpha: 0.95)
        p.particleVelocity = 0.06
        p.blendMode = .additive
        p.emitterShape = SCNBox(width: 8, height: 0.8, length: 6, chamferRadius: 0)
        return p
    }

    /// A few dragonflies skimming the pond. ≈3 alive.
    static func dragonflies() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 0.5
        p.particleLifeSpan = 6
        p.particleSize = 0.07
        p.particleColor = WorldPalette.pond
        p.particleVelocity = 0.5
        p.particleVelocityVariation = 0.25
        p.blendMode = .alpha
        p.emitterShape = SCNBox(width: 4, height: 1.2, length: 4, chamferRadius: 0)
        return p
    }

    private static func base() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleLifeSpanVariation = 1.2
        p.particleSizeVariation = 0.02
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 180
        p.acceleration = SCNVector3(0, 0.015, 0)
        p.isAffectedByGravity = false
        p.birthLocation = .volume
        return p
    }
}
