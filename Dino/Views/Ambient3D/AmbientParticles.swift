//
//  AmbientParticles.swift
//  Dino
//
//  Round-sprite particle systems for the ambient waterfall: foam + mist at
//  the plunge, and warm fireflies at night. EVERY system uses a code-drawn
//  circular particleImage so nothing ever ships as a square.
//

import SceneKit
import UIKit

enum AmbientParticles {

    /// Soft round white dot (radial gradient) — the shared particle sprite.
    private static var cachedCircle: UIImage?
    static func circleSprite() -> UIImage {
        if let cachedCircle { return cachedCircle }
        let size = CGSize(width: 32, height: 32)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 1]) else { return }
            let c = CGPoint(x: 16, y: 16)
            cg.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: 16, options: [])
        }
        cachedCircle = img
        return img
    }

    /// Night: ~12 warm round fireflies drifting low over the pool.
    static func fireflies() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 2.4
        p.particleLifeSpan = 5
        p.particleLifeSpanVariation = 1.5
        p.particleSize = 0.07
        p.particleColor = UIColor(hexRGB: 0xFFE066)
        p.particleVelocity = 0.16
        p.spreadingAngle = 180
        p.blendMode = .additive
        p.emitterShape = SCNBox(width: 9, height: 3, length: 1, chamferRadius: 0)
        return p
    }

    /// Soft mist drifting above the pool surface.
    static func mist() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 0.8
        p.particleLifeSpan = 8
        p.particleSize = 0.34
        p.particleSizeVariation = 0.12
        p.particleColor = UIColor(white: 1.0, alpha: 0.22)
        p.particleVelocity = 0.06
        p.spreadingAngle = 180
        p.blendMode = .alpha
        p.emitterShape = SCNBox(width: 8, height: 0.6, length: 0.6, chamferRadius: 0)
        return p
    }

    /// Foam/mist boiling up where the falls hits the pool. Always on; the
    /// color is graded for day vs night by the caller.
    static func foam() -> SCNParticleSystem {
        let p = base()
        p.birthRate = 14
        p.particleLifeSpan = 2.2
        p.particleLifeSpanVariation = 0.6
        p.particleSize = 0.18
        p.particleSizeVariation = 0.07
        p.particleColor = UIColor(white: 1.0, alpha: 0.7)
        p.particleVelocity = 0.45
        p.particleVelocityVariation = 0.25
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 75
        p.blendMode = .additive
        p.emitterShape = SCNBox(width: 1.4, height: 0.3, length: 0.4, chamferRadius: 0)
        return p
    }

    private static func base() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = circleSprite()          // round — never square
        p.isAffectedByGravity = false
        p.birthLocation = .volume
        p.emittingDirection = SCNVector3(0, 1, 0)
        return p
    }
}
