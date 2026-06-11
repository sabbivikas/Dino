//
//  AmbientParticles.swift
//  Dino
//
//  Life for the ambient waterfall world: pollen by day, fireflies and
//  water-edge mist by night, plus the waterfall's own mist and splash.
//

import SceneKit
import UIKit

enum AmbientParticles {

    /// Day: 6 golden motes drifting upward.
    static func pollen() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 1.0
        p.particleLifeSpan = 6
        p.particleLifeSpanVariation = 1.2
        p.particleSize = 0.05
        p.particleColor = UIColor(red: 1.0, green: 0.93, blue: 0.6, alpha: 0.8)
        p.particleVelocity = 0.14
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 180
        p.acceleration = SCNVector3(0, 0.012, 0)
        p.isAffectedByGravity = false
        p.blendMode = .alpha
        p.birthLocation = .volume
        p.emitterShape = SCNBox(width: 7, height: 3, length: 5, chamferRadius: 0)
        return p
    }

    /// Night: ~15 warm fireflies — drift, pause, pulse.
    static func fireflies() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 3.0
        p.particleLifeSpan = 5
        p.particleLifeSpanVariation = 1.5
        p.particleSize = 0.06
        p.particleColor = UIColor(hexRGB: 0xFFE066)
        p.particleVelocity = 0.18
        p.spreadingAngle = 180
        p.isAffectedByGravity = false
        p.blendMode = .additive
        p.birthLocation = .volume
        // Low over the pool and toward the trees — their glow doubles as
        // reflections near the water surface.
        p.emitterShape = SCNBox(width: 8, height: 2.2, length: 5, chamferRadius: 0)
        return p
    }

    /// Night: large soft mist wisps at the water's edge.
    static func mist() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 0.8
        p.particleLifeSpan = 8
        p.particleSize = 0.3
        p.particleSizeVariation = 0.1
        p.particleColor = UIColor(white: 1.0, alpha: 0.3)
        p.particleVelocity = 0.06
        p.spreadingAngle = 180
        p.isAffectedByGravity = false
        p.blendMode = .alpha
        p.birthLocation = .volume
        p.emitterShape = SCNBox(width: 7, height: 0.6, length: 4, chamferRadius: 0)
        return p
    }

    /// Waterfall base mist — always on; opacity graded by day/night.
    static func waterfallMist() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 8
        p.particleLifeSpan = 2.5
        p.particleSize = 0.15
        p.particleSizeVariation = 0.06
        p.particleColor = UIColor(white: 1.0, alpha: 0.6)
        p.particleVelocity = 0.4
        p.particleVelocityVariation = 0.2
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 70
        p.isAffectedByGravity = false
        p.blendMode = .additive
        p.birthLocation = .volume
        p.emitterShape = SCNBox(width: 1.8, height: 0.3, length: 0.6, chamferRadius: 0)
        return p
    }

    /// Waterfall impact splash — tiny white dots scattering outward.
    static func splash() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 20
        p.particleLifeSpan = 0.5
        p.particleLifeSpanVariation = 0.15
        p.particleSize = 0.035
        p.particleColor = UIColor(white: 1.0, alpha: 0.8)
        p.particleVelocity = 0.8
        p.particleVelocityVariation = 0.4
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 80
        p.acceleration = SCNVector3(0, -1.6, 0)
        p.isAffectedByGravity = false
        p.blendMode = .additive
        p.birthLocation = .surface
        p.emitterShape = SCNSphere(radius: 0.25)
        return p
    }
}
