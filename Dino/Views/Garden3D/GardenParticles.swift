//
//  GardenParticles.swift
//  Dino
//
//  Intimate garden-scale ambience per period: morning pollen, evening
//  petals, night fireflies — plus a one-shot golden sparkle burst for the
//  watering-recovery moment. (Day butterflies and bees are nodes, not
//  particles — see GardenSceneBuilder / SunflowerNode.)
//

import SceneKit
import UIKit

enum GardenParticles {

    /// Morning: ~6 golden pollen motes.
    static func pollen() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.0
        p.particleLifeSpan = 6
        p.particleSize = 0.05
        p.particleImage = circleParticle()
        p.particleColor = UIColor(red: 1.0, green: 0.93, blue: 0.6, alpha: 0.8)
        p.particleVelocity = 0.14
        p.blendMode = .alpha
        p.emitterShape = SCNBox(width: 6, height: 2.5, length: 5, chamferRadius: 0)
        return p
    }

    /// Evening: ~8 pink/peach petals drifting down.
    static func petals() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.1
        p.particleLifeSpan = 7
        p.particleSize = 0.07
        p.particleImage = circleParticle()
        p.particleColor = GardenPalette.flowerPeach
        p.particleColorVariation = SCNVector4(0.06, 0.04, 0.05, 0.0)
        p.particleVelocity = 0.28
        p.emittingDirection = SCNVector3(0, -1, 0)
        p.acceleration = SCNVector3(0.04, -0.06, 0)
        p.particleAngularVelocity = 55
        p.blendMode = .alpha
        p.emitterShape = SCNBox(width: 6, height: 0.5, length: 5, chamferRadius: 0)
        return p
    }

    /// Night: ~10 warm yellow fireflies pulsing — round, additive glow.
    static func fireflies() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 1.3
        p.particleLifeSpan = 7.5
        p.particleSize = 0.06
        p.particleImage = circleParticle()
        p.particleColor = GardenPalette.firefly
        p.particleVelocity = 0.2
        p.blendMode = .additive
        p.emitterShape = SCNBox(width: 6.5, height: 3, length: 5.5, chamferRadius: 0)
        return p
    }

    /// Soft round white dot — a radial-gradient sprite so motes read as
    /// circles, not squares. Cached.
    private static var cachedCircle: UIImage?
    private static func circleParticle() -> UIImage {
        if let cachedCircle { return cachedCircle }
        let size = CGSize(width: 32, height: 32)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 1]) else { return }
            let c = CGPoint(x: 16, y: 16)
            cg.drawRadialGradient(g, startCenter: c, startRadius: 0,
                                  endCenter: c, endRadius: 16, options: [])
        }
        cachedCircle = image
        return image
    }

    /// One-shot water-droplet sparkle for the watering-recovery moment —
    /// cool blue-white drops arcing off the plant.
    static func waterDroplets() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 50
        p.emissionDuration = 0.6
        p.loops = false
        p.particleLifeSpan = 1.1
        p.particleLifeSpanVariation = 0.3
        p.particleSize = 0.045
        p.particleColor = UIColor(red: 0.78, green: 0.92, blue: 1.0, alpha: 0.95)
        p.particleVelocity = 1.0
        p.particleVelocityVariation = 0.5
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 60
        p.acceleration = SCNVector3(0, -2.2, 0)
        p.isAffectedByGravity = false
        p.blendMode = .additive
        p.birthLocation = .surface
        p.emitterShape = SCNSphere(radius: 0.5)
        return p
    }

    /// One-shot golden sparkle burst for the watering-recovery moment.
    /// Emits for ~0.6s then dies; caller removes the system after ~2.5s.
    static func recoveryBurst() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 60
        p.emissionDuration = 0.5
        p.loops = false
        p.particleLifeSpan = 1.4
        p.particleLifeSpanVariation = 0.4
        p.particleSize = 0.06
        p.particleSizeVariation = 0.02
        p.particleColor = GardenPalette.petal
        p.particleVelocity = 1.2
        p.particleVelocityVariation = 0.5
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 70
        p.acceleration = SCNVector3(0, -0.8, 0)
        p.isAffectedByGravity = false
        p.blendMode = .additive
        p.birthLocation = .surface
        p.emitterShape = SCNSphere(radius: 0.3)
        return p
    }

    private static func base() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleLifeSpanVariation = 1.2
        p.particleSizeVariation = 0.02
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 180
        p.acceleration = SCNVector3(0, 0.012, 0)
        p.isAffectedByGravity = false
        p.birthLocation = .volume
        return p
    }
}
