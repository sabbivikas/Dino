//
//  FindingsStar.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo. VERBATIM copy of Onboarding3D/StarGuide.swift
//  (git bf7e3a1), renamed FindingsStar, so the findings tab can host the same
//  hand-drawn star WITHOUT touching main's onboarding orb. Zero new deps
//  (SceneKit + UIKit only). Do not edit the original.
//
//  The star guide — dino's hand-drawn wobbly star (owner reference D-844).
//  A plump five-point star with uneven arms, rounded tips, and gently
//  curved edges; flat warm gold with two dot eyes and a thin smile. The
//  flat body is the only sanctioned flat surface — richness lives in the
//  three additive glow shells, the omni light that warms the world, and
//  the golden trail. It travels ahead of the camera between onboarding
//  steps and bursts with sparkles when the user advances.
//

import SceneKit
import UIKit

final class FindingsStar: SCNNode {

    // MARK: - Hand-wobble constants (D-844 — tweak here only, no runtime randomness)

    private enum StarSpec {
        static let outerRadius: CGFloat = 0.42
        static let innerRadius: CGFloat = 0.195
        // Index 0 = top point (tallest); clockwise from the top.
        // Amplitudes pushed past the pre-gate values: ±10% arm lengths and
        // up to 7° angle skew so the unevenness reads at frame scale.
        static let outerRadiusMul: [CGFloat]      = [1.10, 0.97, 0.90, 1.04, 0.93]
        static let outerAngleOffsetDeg: [CGFloat] = [4, -6, 5, -4, 7]
        static let innerRadiusMul: [CGFloat]      = [1.10, 0.86, 1.12, 0.90, 1.05]
        static let innerAngleOffsetDeg: [CGFloat] = [-5, 7, -6, 4, -6]
        /// Per-segment edge bows (outward +, inward −) applied to the
        /// quad-curve control point, perpendicular to the segment.
        static let bows: [CGFloat] = [0.022, -0.014, 0.026, -0.012, 0.019,
                                      -0.018, 0.024, -0.013, 0.017, -0.020]
        static let tipTrim: CGFloat = 0.07     // rounding trim at outer points
        static let notchTrim: CGFloat = 0.05   // rounding trim at inner notches
        static let extrusion: CGFloat = 0.14
        static let chamfer: CGFloat = 0.015
    }

    private static let bodyGold = UIColor(red: 1.0, green: 208.0 / 255.0, blue: 77.0 / 255.0, alpha: 1)   // #FFD04D
    private static let faceInk  = UIColor(red: 23.0 / 255.0, green: 23.0 / 255.0, blue: 28.0 / 255.0, alpha: 1) // #17171C

    // MARK: - Nodes

    private let floatNode = SCNNode()      // idle bob + reaction pop live here
    private let billboardNode = SCNNode()  // keeps the face toward the camera (Y-axis only)
    private let bodyNode = SCNNode()       // star silhouette + face; carries the lazy sway
    private var eyeNodes: [SCNNode] = []
    private var glowLayers: [SCNNode] = []
    private let lightNode = SCNNode()
    private var trailSystem: SCNParticleSystem?
    private let reduceMotion: Bool

    private let journeyKey = "star.journey"
    private let arrivalTiltKey = "star.arriveTilt"
    private let baseLightIntensity: CGFloat = 1000
    private let baseTrailBirthRate: CGFloat = 9

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

        // The star has a face now, so it must never rotate away from the
        // viewer: minimum Y-axis billboard, with animations on child nodes
        // so they compose. (The old 20s spin is retired.)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        billboardNode.constraints = [billboard]
        floatNode.addChildNode(billboardNode)

        buildBody()
        buildFace()
        buildGlowShells()
        buildLight()
    }

    /// The plump hand-drawn star body — flat, unlit gold that no lighting
    /// or tone-mapping can shift (the no-olive lesson).
    private func buildBody() {
        let path = Self.wobblyStarPath()
        let geo = SCNShape(path: path, extrusionDepth: StarSpec.extrusion)
        geo.chamferRadius = StarSpec.chamfer
        geo.chamferMode = .both

        // Emission-only flat fill: with .constant the diffuse term is still
        // multiplied by the region ambient (white 0.6 in the meadow, orange
        // in the grove), which shifted and washed the gold at the pre-gate.
        // Black diffuse + full-intensity gold emission renders exactly
        // #FFD04D under every region grade.
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor.black
        m.emission.contents = Self.bodyGold
        geo.firstMaterial = m

        bodyNode.geometry = geo
        bodyNode.castsShadow = false
        billboardNode.addChildNode(bodyNode)
    }

    /// Deterministic wobbly 5-point star: fixed per-arm radius/angle tweaks,
    /// rounded tips and notches (quad arcs through the true vertices), and
    /// gently bowed edges for the hand-drawn line quality.
    private static func wobblyStarPath() -> UIBezierPath {
        // 10 alternating outer/inner vertices, clockwise from the top point.
        var verts: [CGPoint] = []
        for i in 0..<10 {
            let k = i / 2
            let outer = i % 2 == 0
            let baseDeg: CGFloat = 90 - CGFloat(i) * 36
            let deg = baseDeg + (outer ? StarSpec.outerAngleOffsetDeg[k]
                                       : StarSpec.innerAngleOffsetDeg[k])
            let r = outer ? StarSpec.outerRadius * StarSpec.outerRadiusMul[k]
                          : StarSpec.innerRadius * StarSpec.innerRadiusMul[k]
            let a = deg * .pi / 180
            verts.append(CGPoint(x: r * cos(a), y: r * sin(a)))
        }

        func trimmed(from a: CGPoint, toward b: CGPoint, by d: CGFloat) -> CGPoint {
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(0.0001, sqrt(dx * dx + dy * dy))
            return CGPoint(x: a.x + dx / len * d, y: a.y + dy / len * d)
        }

        // Per-edge endpoints, trimmed back from each vertex so the corner
        // arcs produce genuinely round silhouette tips.
        var starts: [CGPoint] = []
        var ends: [CGPoint] = []
        for i in 0..<10 {
            let v0 = verts[i], v1 = verts[(i + 1) % 10]
            let trim0 = i % 2 == 0 ? StarSpec.tipTrim : StarSpec.notchTrim
            let trim1 = (i + 1) % 2 == 0 ? StarSpec.tipTrim : StarSpec.notchTrim
            starts.append(trimmed(from: v0, toward: v1, by: trim0))
            ends.append(trimmed(from: v1, toward: v0, by: trim1))
        }

        let path = UIBezierPath()
        path.move(to: starts[0])
        for i in 0..<10 {
            // Bowed edge: control point = midpoint pushed perpendicular,
            // positive bows push away from center (plumpness).
            let a = starts[i], b = ends[i]
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            var px = -(b.y - a.y), py = b.x - a.x
            let plen = max(0.0001, sqrt(px * px + py * py))
            px /= plen; py /= plen
            if px * mid.x + py * mid.y < 0 { px = -px; py = -py }
            let control = CGPoint(x: mid.x + px * StarSpec.bows[i],
                                  y: mid.y + py * StarSpec.bows[i])
            path.addQuadCurve(to: b, controlPoint: control)
            // Rounded tip/notch: arc through the true vertex to the next edge.
            path.addQuadCurve(to: starts[(i + 1) % 10],
                              controlPoint: verts[(i + 1) % 10])
        }
        path.close()
        path.flatness = 0.001   // default 0.6 would polygonize at this tiny scale
        return path
    }

    /// Two dot eyes and one thin round-capped smile, near center. Nothing else.
    private func buildFace() {
        let faceZ = Float(StarSpec.extrusion / 2 + 0.001)

        // Emission-only ink for the same reason as the body: the face must
        // stay a true dark #17171C, never a region-ambient-tinted gray.
        let ink = SCNMaterial()
        ink.lightingModel = .constant
        ink.diffuse.contents = UIColor.black
        ink.emission.contents = Self.faceInk

        for side: Float in [-1, 1] {
            let eyeGeo = SCNSphere(radius: 0.045)
            eyeGeo.segmentCount = 12
            eyeGeo.firstMaterial = ink
            let eye = SCNNode(geometry: eyeGeo)
            eye.position = SCNVector3(0.115 * side, 0.045, faceZ)
            eye.scale = SCNVector3(1, 1, 0.35)
            eye.castsShadow = false
            bodyNode.addChildNode(eye)
            eyeNodes.append(eye)
        }

        // Smile: one explicitly OPEN 130° arc — the dedicated arc
        // initializer, a single moveTo + two cubic segments, never
        // close()d — stroked with round caps and extruded flat.
        //
        // D-844 "third nose dot" audit (verified empirically on the
        // shipping simulator runtime): walking the stroked CGPath's
        // elements yields exactly 8 elements with 1 moveTo and 1
        // closeSubpath — a single closed crescent outline, no stray
        // subpath, no blob at the arc center — and an offscreen SCNShape
        // render of eyes + smile produces exactly three ink regions.
        // The "dot" in the pre-gate frames was not geometry at all: it
        // sampled as text ink (RGB 61/61/66), not face ink #17171C
        // (23/23/28) — the tittle of the letter "i" in the step quote's
        // "with", overlapping the face at the old perch. Fixed at the
        // root by CameraJourney.perchOverride moving the settle point
        // out of the text block. The debug assert below keeps the
        // outline honest against future stroker surprises.
        let arc = UIBezierPath(
            arcCenter: CGPoint(x: 0, y: -0.045), radius: 0.115,
            startAngle: 205 * .pi / 180, endAngle: 335 * .pi / 180,
            clockwise: true)
        let stroked = arc.cgPath.copy(strokingWithWidth: 0.028, lineCap: .round,
                                      lineJoin: .round, miterLimit: 10)
        assert(Self.subpathCount(of: stroked) == 1,
               "smile outline must be exactly one closed subpath")
        let smilePath = UIBezierPath(cgPath: stroked)
        smilePath.flatness = 0.001
        let smileGeo = SCNShape(path: smilePath, extrusionDepth: 0.012)
        smileGeo.firstMaterial = ink
        let smile = SCNNode(geometry: smileGeo)
        smile.position = SCNVector3(0, 0, faceZ)
        smile.castsShadow = false
        bodyNode.addChildNode(smile)
    }

    /// Counts moveTo-delimited subpaths. The face contract is exactly two
    /// dot eyes + one thin round-capped smile — the smile band must stay a
    /// single closed outline whatever the CG stroker emits.
    private static func subpathCount(of path: CGPath) -> Int {
        var count = 0
        path.applyWithBlock { element in
            if element.pointee.type == .moveToPoint { count += 1 }
        }
        return count
    }

    /// Three layered bloom shells — soft radial-falloff planes stacked
    /// BEHIND the body on the billboard. The pre-gate spheres enclosed the
    /// body and additively washed it (and the face) to cream; these read
    /// the depth buffer, so the opaque gold body carves its silhouette out
    /// of the glow. The fringe wraps the star, the flat #FFD04D fill and
    /// the dark face stay untouched.
    private func buildGlowShells() {
        let shells: [(side: CGFloat, z: Float, color: UIColor, alpha: CGFloat)] = [
            (1.15, -0.22, UIColor(red: 1.0, green: 0.878, blue: 0.541, alpha: 1), 0.55),  // #FFE08A
            (1.70, -0.26, FindingsStar.bodyGold, 0.30),                                       // #FFD04D
            (2.40, -0.30, UIColor(red: 1.0, green: 0.953, blue: 0.839, alpha: 1), 0.16)   // #FFF3D6
        ]
        for shell in shells {
            let geo = SCNPlane(width: shell.side, height: shell.side)
            let m = SCNMaterial()
            m.lightingModel = .constant
            // CLEAR, not black: over a TRANSPARENT SCNView an additive plane with
            // a black diffuse composites its transparent rim as OPAQUE black —
            // that black square is the "box" the star kept rendering inside. A
            // clear diffuse lets the glow's transparent falloff stay transparent,
            // so the deep-space backdrop shows through instead of a black edge.
            m.diffuse.contents = UIColor.clear
            m.emission.contents = Self.glowTexture(color: shell.color, alpha: shell.alpha)
            m.isDoubleSided = true
            m.blendMode = .add
            m.writesToDepthBuffer = false
            geo.firstMaterial = m
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(0, 0, shell.z)
            node.castsShadow = false
            glowLayers.append(node)
            billboardNode.addChildNode(node)
        }
    }

    /// Radial falloff sprite for the bloom shells: tinted core easing to
    /// clear at the rim (premultiplied, so the additive add fades to zero).
    private static func glowTexture(color: UIColor, alpha: CGFloat) -> UIImage {
        let side: CGFloat = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let colors = [color.withAlphaComponent(alpha).cgColor,
                          color.withAlphaComponent(alpha * 0.45).cgColor,
                          color.withAlphaComponent(0).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors, locations: [0, 0.55, 1]) else { return }
            let c = CGPoint(x: side / 2, y: side / 2)
            ctx.cgContext.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                             endCenter: c, endRadius: side / 2, options: [])
        }
    }

    /// Soft sparkle sprite shared by every particle system. SceneKit's
    /// default nil particleImage renders each particle as a hard-edged
    /// untextured quad — the pre-gate frames showed the wake as 15–25px
    /// axis-aligned squares. A white radial-falloff core (tinted by
    /// particleColor, additive) makes each mote read as a point of light
    /// with soft alpha falloff instead of a billboard rectangle.
    private static let sparkleSprite: UIImage = {
        let side: CGFloat = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let colors = [UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0.5).cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors, locations: [0, 0.35, 1]) else { return }
            let c = CGPoint(x: side / 2, y: side / 2)
            ctx.cgContext.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                             endCenter: c, endRadius: side / 2, options: [])
        }
    }()

    /// The star genuinely lights the world around it.
    private func buildLight() {
        let light = SCNLight()
        light.type = .omni
        light.color = UIColor(red: 1.0, green: 0.882, blue: 0.639, alpha: 1)  // #FFE1A3 — a genuinely warm cast
        light.intensity = baseLightIntensity
        light.attenuationStartDistance = 2.0
        light.attenuationEndDistance = 10.0
        light.castsShadow = false
        lightNode.light = light
        floatNode.addChildNode(lightNode)
    }

    // MARK: - Idle life

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

        // Lazy sway: rotation.z ±6° sine over 4.8s, on the body child so it
        // composes with the billboard facing. (Replaces the retired spin.)
        let six = 6.0 * Double.pi / 180
        let sway = CAKeyframeAnimation(keyPath: "eulerAngles.z")
        sway.values = [0.0, six, 0.0, -six, 0.0]
        sway.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        sway.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
        sway.duration = 4.8
        sway.repeatCount = .infinity
        bodyNode.addAnimation(sway, forKey: "star.sway")

        // Blink: both eyes together — quick squash, pop back, long wait.
        let waitT = 5.9, downT = 0.09, upT = 0.12
        let total = waitT + downT + upT
        let blink = CAKeyframeAnimation(keyPath: "scale.y")
        blink.values = [1.0, 1.0, 0.12, 1.0]
        blink.keyTimes = [0,
                          NSNumber(value: waitT / total),
                          NSNumber(value: (waitT + downT) / total),
                          1]
        blink.duration = total
        blink.repeatCount = .infinity
        for eye in eyeNodes {
            eye.addAnimation(blink, forKey: "star.blink")
        }
    }

    private func attachTrail() {
        // A subtle drifting sparkle wake that actually reads at frame
        // scale: the old 0.04-size, 0.8s motes vanished into the bloom.
        // The emitter trails slightly behind and below the body so motes
        // peek out around the silhouette instead of drowning in the glow
        // core; birth on a sphere surface gives them varied depth. Sparse
        // and slow by design — ~9/s over ~2.6s keeps a couple dozen warm
        // motes breathing near the star, never confetti. (Reduce Motion
        // never attaches a trail — see init.)
        let emitter = SCNNode()
        emitter.position = SCNVector3(0.08, -0.14, -0.42)
        floatNode.addChildNode(emitter)

        let trail = SCNParticleSystem()
        trail.birthRate = baseTrailBirthRate
        trail.particleLifeSpan = 2.6
        trail.particleLifeSpanVariation = 0.9
        trail.particleSize = 0.085
        trail.particleSizeVariation = 0.035
        trail.particleImage = Self.sparkleSprite
        trail.particleColor = UIColor(red: 1.0, green: 208.0 / 255.0, blue: 77.0 / 255.0, alpha: 0.9)  // #FFD04D
        // Wider alpha variation than the pre-gate 0.12: with the soft
        // sprite, per-mote brightness variance is what sells "sparkle".
        trail.particleColorVariation = SCNVector4(0.02, 0.05, 0.0, 0.3)
        trail.particleVelocity = 0.06
        trail.particleVelocityVariation = 0.04
        trail.speedFactor = 0.3
        trail.spreadingAngle = 180
        trail.isAffectedByGravity = false
        trail.blendMode = .additive
        trail.birthLocation = .surface
        trail.emitterShape = SCNSphere(radius: 0.3)
        // Soft fade in/out so motes melt away instead of popping.
        let fade = CAKeyframeAnimation()
        fade.values = [0.0, 1.0, 1.0, 0.0]
        fade.keyTimes = [0, 0.15, 0.6, 1]
        fade.duration = 2.6
        trail.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        emitter.addParticleSystem(trail)
        trailSystem = trail
    }

    // MARK: - Journey

    /// Glide to the next step's perch. The star leads the camera — callers
    /// pass a duration ~0.3s shorter than the camera dolly.
    func glide(to position: SCNVector3, duration: TimeInterval) {
        removeAction(forKey: journeyKey)
        // If an arrival was still in flight, land its end state instantly.
        floatNode.removeAction(forKey: arrivalTiltKey)
        scale = SCNVector3(1, 1, 1)
        opacity = 1
        trailSystem?.birthRate = baseTrailBirthRate

        if reduceMotion || duration <= 0.05 {
            self.position = position
            return
        }
        let move = SCNAction.move(to: position, duration: duration)
        move.timingMode = .easeInEaseOut
        runAction(move, forKey: journeyKey)
    }

    /// One-time entrance at the first onboarding mount: the star sweeps in
    /// from high off-perch (right +2.4, up +6.5, deep −9), small and bright,
    /// overshoots the perch and settles with a tiny tilt. Callers set
    /// `position` to the perch first; the arrival flies to it. Scene-side
    /// only and non-blocking — never gates or delays step UI.
    func performArrival(reduceMotion: Bool) {
        removeAction(forKey: journeyKey)
        let perch = position

        if reduceMotion {
            // Still arrival: appear at the perch, no motion, no spike.
            // Model value lands at 1 immediately; presentation fades when
            // the renderer draws (safe even with the render loop paused).
            opacity = 0
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.8
            opacity = 1
            SCNTransaction.commit()
            return
        }

        let start = SCNVector3(perch.x + 2.4, perch.y + 6.5, perch.z - 9.0)
        // Overshoot slightly past the perch along the travel direction.
        let overshoot = SCNVector3(perch.x - 2.4 * 0.06,
                                   perch.y - 6.5 * 0.06,
                                   perch.z + 9.0 * 0.06)

        position = start
        scale = SCNVector3(0.25, 0.25, 0.25)
        // Arrival wake: brighter stream along the sweep, but the longer
        // mote lifespan means 120/s would read as confetti — 60 keeps a
        // clear golden path without the spam.
        trailSystem?.birthRate = 60

        let sweep = SCNAction.move(to: overshoot, duration: 1.7)
        sweep.timingMode = .easeOut
        let settle = SCNAction.move(to: perch, duration: 0.5)
        settle.timingMode = .easeInEaseOut
        let finish = SCNAction.run { [weak self] _ in
            guard let self else { return }
            self.trailSystem?.birthRate = self.baseTrailBirthRate
        }
        let grow = SCNAction.scale(to: 1.0, duration: 2.2)
        grow.timingMode = .easeOut
        runAction(.group([.sequence([sweep, settle, finish]), grow]), forKey: journeyKey)

        // Tiny 4° tilt overshoot on touch-down.
        let tilt: CGFloat = 4 * .pi / 180
        let tiltIn = SCNAction.rotateTo(x: 0, y: 0, z: tilt, duration: 0.25, usesShortestUnitArc: true)
        tiltIn.timingMode = .easeOut
        let tiltBack = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.25, usesShortestUnitArc: true)
        tiltBack.timingMode = .easeInEaseOut
        floatNode.runAction(.sequence([.wait(duration: 1.7), tiltIn, tiltBack]),
                            forKey: arrivalTiltKey)
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
        burst.particleImage = Self.sparkleSprite
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

    // MARK: - Findings flight choreography (branch-owned additions)
    //
    // These extend the copied D-844 star for the findings tab's send-out /
    // return story, reusing the SAME motion vocabulary already in this file —
    // the golden trail birthRate spike from performArrival(), the overshoot
    // settle curve and sparkle burst from reactionBurst(). No new motion
    // systems; the originals above are untouched.

    /// A quadratic-bezier arc between two points, easing baked into the block
    /// (SCNAction.customAction ignores timingMode). The control point is lifted
    /// above the higher endpoint so the star travels in a real arc, not a line.
    private func arcAction(from start: SCNVector3, to end: SCNVector3,
                           lift: Float, duration: TimeInterval,
                           ease: @escaping (Float) -> Float) -> SCNAction {
        let ctrl = SCNVector3((start.x + end.x) / 2,
                              max(start.y, end.y) + lift,
                              (start.z + end.z) / 2)
        return SCNAction.customAction(duration: duration) { node, elapsed in
            let raw = duration > 0 ? Float(elapsed) / Float(duration) : 1
            let t = ease(min(1, max(0, raw)))
            let mt = 1 - t
            node.position = SCNVector3(
                mt * mt * start.x + 2 * mt * t * ctrl.x + t * t * end.x,
                mt * mt * start.y + 2 * mt * t * ctrl.y + t * t * end.y,
                mt * mt * start.z + 2 * mt * t * ctrl.z + t * t * end.z)
        }
    }

    private static let easeIn: (Float) -> Float = { $0 * $0 }
    private static let easeOut: (Float) -> Float = { 1 - (1 - $0) * (1 - $0) }

    /// Send the star out: it GATHERS (a brief inhale — scale-down + the glow
    /// tightening with the body — ~0.4s), then arcs away off-screen with the
    /// trail spiked, receding to a point. ~1.35s total. `completion` fires when
    /// the star is off-screen so the caller can flip to the empty AWAY state.
    /// Reduce Motion: a simple fade-out, no flight.
    func flyAway(to exit: SCNVector3, reduceMotion: Bool, completion: @escaping () -> Void) {
        removeAction(forKey: journeyKey)
        floatNode.removeAction(forKey: arrivalTiltKey)
        isHidden = false

        if reduceMotion {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35
            SCNTransaction.completionBlock = completion
            opacity = 0
            SCNTransaction.commit()
            return
        }

        let start = position
        // 1) GATHER — inhale: the whole node scales down, so the three glow
        //    shells tighten in with the body (the "glow tighten").
        let inhale = SCNAction.scale(to: 0.72, duration: 0.4)
        inhale.timingMode = .easeInEaseOut
        // 2) ARC AWAY — spike the golden trail (like performArrival's stream),
        //    arc off-screen while receding to a bright point.
        let spike = SCNAction.run { [weak self] _ in self?.trailSystem?.birthRate = 90 }
        let arc = arcAction(from: start, to: exit, lift: 2.4, duration: 0.95, ease: Self.easeIn)
        let recede = SCNAction.scale(to: 0.16, duration: 0.95)
        recede.timingMode = .easeIn
        let away = SCNAction.group([arc, recede])
        let done = SCNAction.run { [weak self] _ in
            guard let self else { return }
            self.trailSystem?.birthRate = self.baseTrailBirthRate
            self.isHidden = true
            completion()
        }
        runAction(.sequence([inhale, spike, away, done]), forKey: journeyKey)
    }

    /// The star returns: it streaks in from far (tiny + distant, trail spiked),
    /// grows along an arc down to the hover point, settles with a small
    /// overshoot bounce and a sparkle burst, then resumes idle sway/blink.
    /// ~1.3s. Reduce Motion: a simple fade-in at the hover point, no streak.
    ///
    /// `arcDuration` lets the caller slow the descent: the LANDING state passes
    /// a long value (~3.4s total with the settle) so the star decelerates the
    /// whole way in, per the redesign; the default keeps the quick return.
    func streakIn(from start: SCNVector3, to hover: SCNVector3, reduceMotion: Bool,
                  arcDuration: TimeInterval = 1.0) {
        removeAction(forKey: journeyKey)
        floatNode.removeAction(forKey: arrivalTiltKey)
        isHidden = false

        if reduceMotion {
            position = hover
            scale = SCNVector3(1, 1, 1)
            trailSystem?.birthRate = baseTrailBirthRate
            opacity = 0
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.6
            opacity = 1
            SCNTransaction.commit()
            return
        }

        position = start
        scale = SCNVector3(0.12, 0.12, 0.12)
        opacity = 1
        trailSystem?.birthRate = 90   // bright streak, like the arrival stream

        let arc = arcAction(from: start, to: hover, lift: 1.6, duration: arcDuration, ease: Self.easeOut)
        let grow = SCNAction.scale(to: 1.08, duration: arcDuration)   // slight size overshoot
        grow.timingMode = .easeOut
        let streak = SCNAction.group([arc, grow])
        // Overshoot bounce — the same soft spring curve as reactionBurst's settle.
        let settle = SCNAction.scale(to: 1.0, duration: 0.28)
        settle.timingFunction = { t in
            let p = t - 1.0
            return 1.0 + p * p * p * (1.0 + 1.6 * t)
        }
        let land = SCNAction.run { [weak self] _ in
            guard let self else { return }
            self.trailSystem?.birthRate = self.baseTrailBirthRate
            self.onSelection()   // sparkle burst on settle (reused pop/burst helper)
        }
        runAction(.sequence([streak, settle, land]), forKey: journeyKey)
    }
}
