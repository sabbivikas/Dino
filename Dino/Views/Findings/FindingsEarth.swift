//
//  FindingsEarth.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo — the small, distant, quiet Earth that sits
//  LOW behind the free-floating star in the shared full-bleed SceneKit scene.
//  Not focal: it feels far away, a little cool, turning slowly.
//
//  All procedural + deterministic (owner richness bar):
//    • an equirectangular texture drawn with UIGraphicsImageRenderer — soft
//      blue oceans, blobby muted-green continents, a few white cloud wisps, all
//      seeded so it is identical on every launch;
//    • a directional light from one side gives the terminator (a lit day side
//      easing into a near-black night side);
//    • an additive billboard halo behind the globe is the atmospheric rim glow;
//    • a slow continuous Y rotation, STOPPED under Reduce Motion.
//
//  English-only demo (owner decision): plain string literals only.
//

import SceneKit
import UIKit

enum FindingsEarth {

    /// Build the Earth rig: a globe + its own key light + an atmosphere halo,
    /// parented to one node the caller positions LOW and deep in the scene.
    static func makeNode(radius: CGFloat, reduceMotion: Bool) -> SCNNode {
        let rig = SCNNode()

        // ── the globe ────────────────────────────────────────────────────────
        let globe = SCNSphere(radius: radius)
        globe.segmentCount = 48
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = surfaceTexture()
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .clamp
        m.specular.contents = UIColor(white: 0.25, alpha: 1)   // faint ocean sheen
        m.shininess = 0.06
        // Night side must fall to near-black for a real terminator, so the
        // material's own ambient response is kept very low.
        m.ambient.contents = UIColor(white: 0.05, alpha: 1)
        globe.firstMaterial = m

        let globeNode = SCNNode(geometry: globe)
        globeNode.castsShadow = false

        // Slow, quiet spin (stopped under Reduce Motion).
        if !reduceMotion {
            let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 120)
            globeNode.runAction(.repeatForever(spin))
        }
        // A gentle axial tilt so it reads as a world, not a ball.
        globeNode.eulerAngles = SCNVector3(0, 0, 23.4 * .pi / 180)
        rig.addChildNode(globeNode)

        // ── the terminator key light (lit from one side) ─────────────────────
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 700
        key.light?.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
        key.light?.categoryBitMask = earthLightMask
        // from the upper-left, so the night side is on the lower-right.
        key.eulerAngles = SCNVector3(-0.25, 0.9, 0)
        rig.addChildNode(key)
        // Confine this light to the Earth so it never re-lights the flat star.
        globeNode.categoryBitMask = earthLightMask

        // A whisper of fill so the night side is dark, not pure void.
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 90
        fill.light?.color = UIColor(red: 0.30, green: 0.36, blue: 0.52, alpha: 1)
        fill.light?.categoryBitMask = earthLightMask
        rig.addChildNode(fill)

        // ── atmospheric rim glow (additive back-sphere shell) ────────────────
        // A slightly larger sphere rendered with the front faces culled, so only
        // its BACK hemisphere shows as a soft blue ring around the globe's
        // silhouette. Additive + no depth writes — the SAME proven recipe as the
        // star's glow shells (a plane-based halo rendered as an opaque box).
        let atmo = SCNSphere(radius: radius * 1.14)
        atmo.segmentCount = 48
        let am = SCNMaterial()
        am.lightingModel = .constant
        am.diffuse.contents = UIColor.clear
        am.emission.contents = UIColor(red: 0.42, green: 0.62, blue: 0.86, alpha: 0.5)
        am.blendMode = .add
        am.writesToDepthBuffer = false
        am.cullMode = .front            // show only the far shell → a rim, not a ball
        atmo.firstMaterial = am
        let atmoNode = SCNNode(geometry: atmo)
        atmoNode.categoryBitMask = ~earthLightMask   // unlit constant, ambient-safe
        atmoNode.castsShadow = false
        rig.addChildNode(atmoNode)

        return rig
    }

    /// A dedicated light category so the Earth's key/fill lights touch ONLY the
    /// Earth — the flat gold star must stay exactly #FFD04D (the no-olive rule).
    static let earthLightMask: Int = 1 << 4

    // MARK: - procedural textures (seeded, deterministic)

    private struct LCG {
        var s: UInt64
        init(_ seed: UInt64) { s = seed | 1 }
        mutating func next() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double(s >> 33) / Double(UInt32.max)
        }
    }

    /// Equirectangular 2:1 surface: ocean base, blobby continents, cloud wisps.
    private static func surfaceTexture() -> UIImage {
        let size = CGSize(width: 512, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            var rng = LCG(GradientSeed.hash("findings.earth"))

            // Ocean base — a soft cool blue vertical grade.
            let ocean = [
                UIColor(red: 0.13, green: 0.32, blue: 0.45, alpha: 1).cgColor,
                UIColor(red: 0.10, green: 0.25, blue: 0.38, alpha: 1).cgColor,
            ] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: ocean, locations: [0, 1]) {
                cg.drawLinearGradient(grad, start: .zero,
                                      end: CGPoint(x: 0, y: size.height), options: [])
            }

            // Continents — clusters of overlapping muted-green blobs.
            let green = UIColor(red: 0.36, green: 0.48, blue: 0.35, alpha: 1)
            let greenDim = UIColor(red: 0.30, green: 0.41, blue: 0.30, alpha: 1)
            let landmasses = 7
            for _ in 0..<landmasses {
                let cx = rng.next() * size.width
                let cy = 0.18 * size.height + rng.next() * 0.64 * size.height
                let blobs = 8 + Int(rng.next() * 10)
                for _ in 0..<blobs {
                    let bx = cx + (rng.next() - 0.5) * 90
                    let by = cy + (rng.next() - 0.5) * 60
                    let r = 10 + rng.next() * 34
                    (rng.next() > 0.5 ? green : greenDim).setFill()
                    cg.fillEllipse(in: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2))
                }
            }

            // Cloud wisps — a few soft white streaks, low alpha.
            for _ in 0..<10 {
                let cx = rng.next() * size.width
                let cy = rng.next() * size.height
                let w = 40 + rng.next() * 120
                let h = 8 + rng.next() * 16
                UIColor(white: 1.0, alpha: 0.10 + rng.next() * 0.10).setFill()
                cg.fillEllipse(in: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
            }
        }
    }

}
