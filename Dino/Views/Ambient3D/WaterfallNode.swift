//
//  WaterfallNode.swift
//  Dino
//
//  The single waterfall ribbon — two overlapping UV-scroll planes centered
//  over the painted falls gap, bright cyan-white and glowing, with round
//  foam particles boiling up at the plunge. NO box geometry, no 3D rock,
//  no 3D pool — the cliff, boulders and pool are painted in the background.
//

import SceneKit
import UIKit

final class WaterfallNode: SCNNode {

    private var ribbonMaterials: [SCNMaterial] = []
    private var foamSystem: SCNParticleSystem?

    // Ribbon geometry centered on the painted falls (camera ortho ½-height 8,
    // looking down -Z): ledge ≈ y 3.2, waterline ≈ y -1.9.
    private let ribbonTop: Float = 3.2
    private let ribbonBottom: Float = -1.9

    init(reduceMotion: Bool) {
        super.init()
        buildRibbon(animate: !reduceMotion)
        if !reduceMotion { attachFoam() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { return nil }

    /// Tint the ribbon + foam for day (bright cyan-white) vs night (pale blue).
    func setPeriod(isNight: Bool) {
        let tint = isNight ? UIColor(hexRGB: 0xD2E2F0) : UIColor(hexRGB: 0xF4FBFC)
        for m in ribbonMaterials { m.multiply.contents = tint }
        foamSystem?.particleColor = isNight
            ? UIColor(hexRGB: 0xCFDBE8).withAlphaComponent(0.7)
            : UIColor.white.withAlphaComponent(0.8)
    }

    // MARK: - Ribbon

    private func buildRibbon(animate: Bool) {
        let texture = WaterfallNode.streakTexture()
        let height = CGFloat(ribbonTop - ribbonBottom)
        let centerY = (ribbonTop + ribbonBottom) / 2

        // back glow (wide, faint) + front ribbon (narrow, bright).
        let specs: [(w: CGFloat, alpha: CGFloat, speed: Float, z: Float)] = [
            (1.7, 0.45, 0.5, -0.02),
            (1.05, 0.9, 0.85, 0.0)
        ]
        for spec in specs {
            let plane = SCNPlane(width: spec.w, height: height)
            plane.heightSegmentCount = 12
            let m = SCNMaterial()
            m.diffuse.contents = texture
            m.diffuse.wrapT = .repeat
            m.diffuse.wrapS = .clamp
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.transparency = spec.alpha
            m.writesToDepthBuffer = false
            m.multiply.contents = UIColor(hexRGB: 0xF4FBFC)
            if animate {
                let speed = spec.speed
                m.shaderModifiers = [
                    .geometry: """
                    _geometry.texcoords[0].y -= u_time * \(speed);
                    _geometry.texcoords[0].x += sin(_geometry.texcoords[0].y * 7.0 + u_time * 2.0) * 0.02;
                    """
                ]
            }
            plane.firstMaterial = m
            ribbonMaterials.append(m)
            let node = SCNNode(geometry: plane)
            node.position = SCNVector3(0, centerY, spec.z)
            node.castsShadow = false
            addChildNode(node)
        }
    }

    /// Vertical white streaks on a faint base — scrolled by the shader.
    private static func streakTexture() -> UIImage {
        let size = CGSize(width: 64, height: 256)
        var rng = GardenSeededRandom(seed: 64)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(white: 1.0, alpha: 0.22).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<18 {
                let x = CGFloat(rng.range(4, 60))
                let y = CGFloat(rng.range(-40, 256))
                let length = CGFloat(rng.range(50, 150))
                let width = CGFloat(rng.range(1.5, 4))
                cg.setFillColor(UIColor(white: 1.0, alpha: CGFloat(rng.range(0.3, 0.8))).cgColor)
                cg.addPath(UIBezierPath(
                    roundedRect: CGRect(x: x, y: y, width: width, height: length),
                    cornerRadius: width / 2).cgPath)
                cg.fillPath()
            }
        }
    }

    // MARK: - Foam at the plunge

    private func attachFoam() {
        let foam = AmbientParticles.foam()
        let anchor = SCNNode()
        anchor.position = SCNVector3(0, ribbonBottom + 0.1, 0)
        anchor.addParticleSystem(foam)
        addChildNode(anchor)
        foamSystem = foam
    }
}
