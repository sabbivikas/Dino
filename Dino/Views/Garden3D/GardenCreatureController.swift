//
//  GardenCreatureController.swift
//  Dino
//
//  Owns the garden's living layer: the hummingbird courier, the bees, and
//  the night fireflies. Sprites are camera-facing SCNPlanes (the diorama
//  camera is fixed, so no billboard constraint is needed) with painted
//  textures from CreatureTextureProvider. All motion is evaluated per tick
//  from the pure brains in GardenCreatureLogic via one CADisplayLink — no
//  SCNActions drive creatures, so everything works identically under
//  Reduce Motion's paused scene (just slower, per spec).
//

import SceneKit
import UIKit

@MainActor
final class GardenCreatureController: NSObject {

    let root = SCNNode()

    private let textures: CreatureTextureProvider
    private let reduceMotion: Bool

    // sprites
    private let birdNode: SCNNode
    private let envelopeNode: SCNNode
    private var beeNodes: [SCNNode] = []
    private var fireflyNodes: [SCNNode] = []

    // brains
    private var bird: HummingbirdBrain
    private var bees: [BeeBrain] = []
    private var fireflySpecs: [FireflySpec] = []

    // config
    private var letterPending = false
    private var creaturesEarned = false
    private var configured = false
    private var regime: GardenCreatureRegime = .day
    private var onLetterTapped: (() -> Void)?
    private var onLetterTucked: (() -> Void)?
    /// She offers the letter once per garden open; after the presenting
    /// timeout she tucks it away until the next open (letter stays unread).
    private var tuckedAwayThisOpen = false

    // display link + fades
    private var displayLink: CADisplayLink?
    private var active = false
    private var lastTick: CFTimeInterval = 0
    private var beeOpacity: Float = 0
    private var beeTarget: Float = 0
    private var fireflyVisibleCount = 0
    private var fireflyFactors: [Float]

    // frame caching
    private var birdFrameKey = ""
    private var beeFrameKeys: [String]

    private let birdWingPeriod: Double
    private let beeWingPeriod: Double
    private static let fadeSeconds: Float = 1.5   // regime transitions ease, never snap
    private static let beeCount = 3
    private static let fireflyCountNight = 12     // parity with the old particle density
    private static let fireflyCountEvening = 6

    init(textures: CreatureTextureProvider, reduceMotion: Bool) {
        self.textures = textures
        self.reduceMotion = reduceMotion
        birdWingPeriod = reduceMotion ? 0.09 : 0.045   // wing swap halved under RM
        beeWingPeriod = reduceMotion ? 0.08 : 0.04

        var birdBrain = HummingbirdBrain(rng: GardenSeededRandom(seed: 0xB12D))
        birdBrain.slowFactor = reduceMotion ? 2 : 1
        birdBrain.banking = !reduceMotion
        bird = birdBrain

        birdNode = Self.spriteNode(size: 0.62, name: "creature-bird")
        envelopeNode = Self.spriteNode(size: 0.30, name: "creature-envelope")
        fireflyFactors = [Float](repeating: 0, count: Self.fireflyCountNight)
        beeFrameKeys = [String](repeating: "", count: Self.beeCount)

        super.init()

        // bird + trailing envelope (bird-local, so it shrinks/approaches with her)
        birdNode.isHidden = true
        envelopeNode.position = SCNVector3(0, -0.55, 0.05)
        envelopeNode.geometry?.firstMaterial?.diffuse.contents = textures.frame(named: "envelope")
        envelopeNode.isHidden = true
        birdNode.addChildNode(envelopeNode)
        birdNode.addChildNode(Self.tapTarget(radius: 0.5, name: "tap-bird"))
        root.addChildNode(birdNode)

        // bees — independent seeded rhythms around the one real bloom
        let bloom = SIMD3<Float>(0, 2.55, 0.35)
        let rests = Array(HummingbirdWaypoints.garden.hoverPoints[1...3])
        for i in 0..<Self.beeCount {
            var brain = BeeBrain(rng: GardenSeededRandom(seed: 0xBEE0 + UInt64(i * 7919)),
                                 bloom: bloom, restPoints: rests)
            brain.slowFactor = reduceMotion ? 2 : 1
            bees.append(brain)
            let node = Self.spriteNode(size: 0.24, name: "creature-bee-\(i)")
            node.opacity = 0
            node.addChildNode(Self.tapTarget(radius: 0.22, name: "tap-bee-\(i)"))
            beeNodes.append(node)
            root.addChildNode(node)
        }

        // fireflies — individual blink rhythms, never a shared strobe
        var rng = GardenSeededRandom(seed: 0xF17E)
        fireflySpecs = FireflySpec.flock(count: Self.fireflyCountNight, rng: &rng)
        for (i, _) in fireflySpecs.enumerated() {
            let node = Self.spriteNode(size: 0.16, name: "creature-firefly-\(i)", additive: true)
            node.geometry?.firstMaterial?.diffuse.contents = textures.frame(named: "firefly")
            node.opacity = 0
            node.addChildNode(Self.tapTarget(radius: 0.16, name: "tap-firefly-\(i)"))
            fireflyNodes.append(node)
            root.addChildNode(node)
        }
    }

    // MARK: - Configuration (called from GardenSceneView.applyState)

    func configure(earned: Bool, letterPending pending: Bool,
                   onLetterTapped: (() -> Void)?, onLetterTucked: (() -> Void)? = nil) {
        self.onLetterTapped = onLetterTapped
        self.onLetterTucked = onLetterTucked
        let changed = earned != creaturesEarned || pending != letterPending
        creaturesEarned = earned
        letterPending = pending
        if !configured || changed {
            configured = true
            applyRegime(currentRegime(), now: CACurrentMediaTime(), force: true)
        }
    }

    func setActive(_ isActive: Bool) {
        guard isActive != active else { return }
        active = isActive
        if isActive {
            tuckedAwayThisOpen = false   // each garden open, she offers again
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.preferredFramesPerSecond = reduceMotion ? 15 : 30
            link.add(to: .main, forMode: .common)
            displayLink = link
            lastTick = 0
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    private func currentRegime() -> GardenCreatureRegime {
        // RM shows the garden's static day frame — creatures match it
        if reduceMotion { return .day }
        let hour = GardenDebug.forcedHour ?? Calendar.current.component(.hour, from: Date())
        return GardenCreatureRegime.from(hour: hour)
    }

    // MARK: - Regime transitions

    private func applyRegime(_ new: GardenCreatureRegime, now: Double, force: Bool = false) {
        guard force || new != regime else { return }
        regime = new
        switch new {
        case .day:
            if letterPending && !tuckedAwayThisOpen {
                // the courier arrives even to a young garden — the letter is not gated
                switch bird.mode {
                case .arriving, .presenting:
                    break   // already delivering
                case .gone:
                    bird.beginArrival(now: now)
                default:
                    // the letter appeared while she was out visiting — swoop in
                    bird.beginArrival(now: now, from: SIMD3<Float>(birdNode.position), fromScale: 1)
                }
            } else if creaturesEarned {
                if case .gone = bird.mode { bird.beginVisiting(now: now) }
            } else {
                bird.flyHome(now: now, from: SIMD3<Float>(birdNode.position))
            }
            beeTarget = creaturesEarned ? 1 : 0
            if creaturesEarned {
                for i in bees.indices { bees[i].wake(now: now) }
            }
            fireflyVisibleCount = 0
        case .evening:
            bird.flyHome(now: now, from: SIMD3<Float>(birdNode.position))
            for i in bees.indices { bees[i].sleep() }
            beeTarget = 0
            fireflyVisibleCount = Self.fireflyCountEvening
        case .night:
            bird.flyHome(now: now, from: SIMD3<Float>(birdNode.position))
            for i in bees.indices { bees[i].sleep() }
            beeTarget = 0
            fireflyVisibleCount = Self.fireflyCountNight
        }
    }

    // MARK: - Tick

    @objc private func step(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = lastTick == 0 ? 1.0 / 30.0 : min(0.1, now - lastTick)
        lastTick = now

        applyRegime(currentRegime(), now: now)   // live dusk transition + foreground catch-up
        tickBird(now)
        tickBees(now, dt: Float(dt))
        tickFireflies(now, dt: Float(dt))
    }

    private func tickBird(_ now: Double) {
        var pose = bird.tick(now: now)
        if bird.consumePresentingEvent() {
            HapticManager.shared.light()   // soft tick: she's here with your letter
            AnalyticsManager.shared.trackLetterDeliveredByBird()
        }
        if bird.consumePresentingTimeout() {
            // unacknowledged — she tucks the envelope and lives her day;
            // the letter stays unread and she carries it again next open
            tuckedAwayThisOpen = true
            envelopeNode.isHidden = true
            bird.deliverComplete(now: now, stayForFlowers: creaturesEarned)
            let callback = onLetterTucked
            DispatchQueue.main.async { callback?() }
        }
        // a bird with nothing to do in an unearned garden stays gone
        if !letterPending && !creaturesEarned, case .gone = bird.mode {
            pose.visible = false
        }
        birdNode.isHidden = !pose.visible
        guard pose.visible else { return }

        birdNode.position = SCNVector3(pose.position)
        birdNode.scale = SCNVector3(pose.scale * pose.facing, pose.scale, pose.scale)
        birdNode.eulerAngles.z = pose.bank - pose.lean * 0.5 * pose.facing

        let wing = Int(now / birdWingPeriod) % 2 == 0 ? "up" : "down"
        let key = "hummingbird_\(pose.view == .front ? "front" : "profile")_\(wing)"
        if key != birdFrameKey {
            birdFrameKey = key
            birdNode.geometry?.firstMaterial?.diffuse.contents = textures.frame(named: key)
        }

        let carrying = letterPending && !tuckedAwayThisOpen
        envelopeNode.isHidden = !carrying
        if carrying {
            envelopeNode.eulerAngles.z = Float(sin(now * 1.3)) * 0.12   // gentle sway
        }
    }

    private func tickBees(_ now: Double, dt: Float) {
        beeOpacity += (beeTarget - beeOpacity) * min(1, dt / Self.fadeSeconds * 3)
        for i in bees.indices {
            let pose = bees[i].tick(now: now)
            let node = beeNodes[i]
            node.opacity = CGFloat(beeOpacity)
            node.isHidden = beeOpacity < 0.01
            guard !node.isHidden else { continue }
            var p = pose.position
            p.y += pose.wiggle
            node.position = SCNVector3(p)
            node.scale = SCNVector3(pose.facing, 1, 1)
            node.eulerAngles.z = pose.wiggle * 6
            let key = pose.wingsBeating
                ? "bee_\(Int(now / beeWingPeriod) % 2 == 0 ? "up" : "down")"
                : "bee_down"                       // wings pause while collecting
            if key != beeFrameKeys[i] {
                beeFrameKeys[i] = key
                node.geometry?.firstMaterial?.diffuse.contents = textures.frame(named: key)
            }
            if pose.emitPollen {
                spawnPollen(at: pose.position)
            }
        }
    }

    private func tickFireflies(_ now: Double, dt: Float) {
        for (i, spec) in fireflySpecs.enumerated() {
            let target: Float = i < fireflyVisibleCount ? 1 : 0
            fireflyFactors[i] += (target - fireflyFactors[i]) * min(1, dt / Self.fadeSeconds * 3)
            let node = fireflyNodes[i]
            let factor = fireflyFactors[i]
            node.isHidden = factor < 0.01
            guard !node.isHidden else { continue }
            node.position = SCNVector3(spec.position(now: now))
            let s = spec.scale(now: now)
            node.scale = SCNVector3(s, s, s)
            node.opacity = CGFloat(spec.brightnessNow(now) * factor)
        }
    }

    /// 3 golden pollen specks drifting up off the bloom, fading out.
    private func spawnPollen(at p: SIMD3<Float>) {
        guard !reduceMotion else { return }
        for _ in 0..<3 {
            let plane = SCNPlane(width: 0.09, height: 0.09)
            let m = SCNMaterial()
            m.lightingModel = .constant
            m.blendMode = .add
            m.writesToDepthBuffer = false
            m.diffuse.contents = textures.frame(named: "pollen")
            plane.firstMaterial = m
            let speck = SCNNode(geometry: plane)
            speck.castsShadow = false
            speck.position = SCNVector3(p.x + Float.random(in: -0.08...0.08),
                                        p.y + 0.05,
                                        p.z + Float.random(in: -0.05...0.05))
            speck.opacity = 0.9
            root.addChildNode(speck)
            let rise = SCNAction.moveBy(x: CGFloat(Float.random(in: -0.06...0.06)),
                                        y: 0.35, z: 0, duration: 1.5)
            rise.timingMode = .easeOut
            speck.runAction(.sequence([.group([rise, .fadeOut(duration: 1.5)]),
                                       .removeFromParentNode()]))
        }
    }

    // MARK: - Taps

    /// Resolves a hit-test result chain to a creature. Bird with a letter →
    /// open; anything else → tiny haptic + a startle, nothing more.
    func handleTap(_ hits: [SCNHitTestResult]) {
        for hit in hits {
            var current: SCNNode? = hit.node
            while let node = current {
                if let name = node.name, handleTapped(nodeName: name) {
                    return
                }
                current = node.parent
            }
        }
    }

    private func handleTapped(nodeName name: String) -> Bool {
        let now = CACurrentMediaTime()
        if name == "tap-bird" || name == "creature-bird" || name == "creature-envelope" {
            if letterPending, !tuckedAwayThisOpen, case .presenting = bird.mode {
                letterPending = false
                envelopeNode.isHidden = true
                HapticManager.shared.success()
                AnalyticsManager.shared.trackBirdLetterOpened()
                bird.deliverComplete(now: now, stayForFlowers: creaturesEarned)
                let callback = onLetterTapped
                DispatchQueue.main.async { callback?() }
            } else {
                HapticManager.shared.light()
                AnalyticsManager.shared.trackGardenCreatureTapped(creature: "hummingbird")
                if !birdNode.isHidden {
                    bird.scatter(now: now, from: SIMD3<Float>(birdNode.position))
                }
            }
            return true
        }
        if name.hasPrefix("tap-bee-") || name.hasPrefix("creature-bee-") {
            let index = Int(name.split(separator: "-").last.map(String.init) ?? "") ?? 0
            HapticManager.shared.light()
            AnalyticsManager.shared.trackGardenCreatureTapped(creature: "bee")
            if bees.indices.contains(index) {
                bees[index].scatter(now: now, from: SIMD3<Float>(beeNodes[index].position))
            }
            return true
        }
        if name.hasPrefix("tap-firefly-") || name.hasPrefix("creature-firefly-") {
            HapticManager.shared.light()
            AnalyticsManager.shared.trackGardenCreatureTapped(creature: "firefly")
            return true
        }
        return false
    }

    // MARK: - Node factories

    private static func spriteNode(size: CGFloat, name: String, additive: Bool = false) -> SCNNode {
        let plane = SCNPlane(width: size, height: size)
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.isDoubleSided = true                 // horizontal flips negate x scale
        m.writesToDepthBuffer = false
        if additive { m.blendMode = .add }     // fireflies glow against the night sky
        plane.firstMaterial = m
        let node = SCNNode(geometry: plane)
        node.name = name
        node.castsShadow = false
        return node
    }

    private static func tapTarget(radius: CGFloat, name: String) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        let m = SCNMaterial()
        m.colorBufferWriteMask = []            // invisible, still hit-testable
        m.writesToDepthBuffer = false
        sphere.firstMaterial = m
        let node = SCNNode(geometry: sphere)
        node.name = name
        node.castsShadow = false
        return node
    }
}

private extension SCNVector3 {
    init(_ v: SIMD3<Float>) { self.init(v.x, v.y, v.z) }
}

private extension SIMD3 where Scalar == Float {
    init(_ v: SCNVector3) { self.init(v.x, v.y, v.z) }
}
