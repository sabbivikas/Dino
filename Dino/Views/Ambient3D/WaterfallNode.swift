//
//  WaterfallNode.swift
//  Dino
//
//  The hero 3D element: a cascading waterfall over dark wet rock, with
//  continuously scrolling water (UV-scroll shader over a generated streak
//  texture), base mist and impact splash. Sits center-back between the
//  painted forest and the pool.
//

import SceneKit
import UIKit

final class WaterfallNode: SCNNode {

    private var mistSystem: SCNParticleSystem?

    init(reduceMotion: Bool) {
        super.init()
        buildRockFace()
        buildCascade(animate: !reduceMotion)
        buildPool(animate: !reduceMotion)
        if !reduceMotion {
            attachMistAndSplash()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { return nil }

    /// Waterfall mist is always on; night makes it more mysterious.
    func setNight(_ isNight: Bool) {
        mistSystem?.particleColor = UIColor(white: 1.0, alpha: isNight ? 0.4 : 0.6)
    }

    // MARK: - Rock face

    private func buildRockFace() {
        let rocks: [(w: CGFloat, h: CGFloat, d: CGFloat, x: Float, y: Float, z: Float, tilt: Float, hex: UInt32)] = [
            (2.5, 1.2, 0.9, 0, 0.6, -3.0, 0.04, 0x1A2A1A),
            (2.2, 1.1, 0.8, 0.15, 1.6, -3.05, -0.05, 0x2A3A2A),
            (1.9, 1.0, 0.7, -0.1, 2.5, -3.1, 0.06, 0x223222),
            (1.6, 0.8, 0.6, 0.1, 3.2, -3.15, -0.03, 0x2A3A2A)
        ]
        for rock in rocks {
            let geo = SCNBox(width: rock.w, height: rock.h, length: rock.d,
                             chamferRadius: 0.12)
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(hexRGB: rock.hex)
            m.lightingModel = .lambert
            m.specular.contents = UIColor(white: 0.25, alpha: 1)   // wet sheen
            geo.firstMaterial = m
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(rock.x, rock.y, rock.z)
            node.eulerAngles.z = rock.tilt
            addChildNode(node)
        }
    }

    // MARK: - Water cascade

    private func buildCascade(animate: Bool) {
        let texture = WaterfallNode.streakTexture()
        let segments: [(w: CGFloat, h: CGFloat, x: Float, y: Float, z: Float, tilt: Float)] = [
            (0.8, 1.0, 0, 3.5, -2.8, -0.06),
            (1.2, 1.2, 0, 2.2, -2.7, 0.04),
            (1.8, 0.8, 0, 1.0, -2.6, -0.03)
        ]
        for seg in segments {
            let plane = SCNPlane(width: seg.w, height: seg.h)
            plane.widthSegmentCount = 6
            plane.heightSegmentCount = 12
            let m = SCNMaterial()
            m.diffuse.contents = texture
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.transparency = 0.8
            m.writesToDepthBuffer = false
            if animate {
                // Continuous downward flow + gentle horizontal wave.
                m.shaderModifiers = [
                    .geometry: """
                    _geometry.texcoords[0].y -= u_time * 0.8;
                    _geometry.texcoords[0].x += sin(_geometry.texcoords[0].y * 8.0 + u_time * 2.0) * 0.03;
                    """
                ]
            }
            plane.firstMaterial = m
            let node = SCNNode(geometry: plane)
            node.position = SCNVector3(seg.x, seg.y, seg.z)
            node.eulerAngles.z = seg.tilt
            node.castsShadow = false
            addChildNode(node)
        }
    }

    /// Vertical white streak texture the cascade scrolls through.
    private static func streakTexture() -> UIImage {
        let size = CGSize(width: 64, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        var rng = GardenSeededRandom(seed: 64)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            // Soft white sheet base.
            cg.setFillColor(UIColor(white: 1.0, alpha: 0.3).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            // Bright falling streaks.
            for _ in 0..<16 {
                let x = CGFloat(rng.range(0, 64))
                let y = CGFloat(rng.range(-40, 256))
                let length = CGFloat(rng.range(40, 130))
                let width = CGFloat(rng.range(1.5, 4))
                let alpha = CGFloat(rng.range(0.25, 0.7))
                cg.setFillColor(UIColor(white: 1.0, alpha: alpha).cgColor)
                let path = UIBezierPath(
                    roundedRect: CGRect(x: x, y: y, width: width, height: length),
                    cornerRadius: width / 2
                )
                cg.addPath(path.cgPath)
                cg.fillPath()
            }
        }
    }

    // MARK: - Pool

    private func buildPool(animate: Bool) {
        let poolGeo = SCNPlane(width: 4, height: 4)
        poolGeo.widthSegmentCount = 8
        poolGeo.heightSegmentCount = 8
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(hexRGB: 0x1A6B5A)
        m.lightingModel = .lambert
        m.specular.contents = UIColor.black
        m.transparency = 0.94
        m.isDoubleSided = true
        if animate {
            // Gentle ripple — much softer than the falls.
            m.shaderModifiers = [
                .surface: """
                float t = u_time;
                vec2 uv = _surface.diffuseTexcoord;
                float ripple = sin(uv.x * 18.0 + t * 0.7) * sin(uv.y * 14.0 - t * 0.5);
                _surface.diffuse.rgb += vec3(smoothstep(0.7, 1.0, ripple) * 0.18);
                """
            ]
        }
        poolGeo.firstMaterial = m
        let pool = SCNNode(geometry: poolGeo)
        pool.eulerAngles.x = -Float.pi / 2
        pool.position = SCNVector3(0, 0.02, -1.2)
        pool.castsShadow = false
        addChildNode(pool)
    }

    // MARK: - Mist + splash

    private func attachMistAndSplash() {
        let mist = AmbientParticles.waterfallMist()
        let mistAnchor = SCNNode()
        mistAnchor.position = SCNVector3(0, 0.5, -2.5)
        mistAnchor.addParticleSystem(mist)
        addChildNode(mistAnchor)
        mistSystem = mist

        let splash = AmbientParticles.splash()
        let splashAnchor = SCNNode()
        splashAnchor.position = SCNVector3(0, 0.3, -2.4)
        splashAnchor.addParticleSystem(splash)
        addChildNode(splashAnchor)
    }
}
