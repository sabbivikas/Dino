//
//  GardenCreatures.swift
//  Dino
//
//  The garden's living residents: striped bees with blurred wings, painted
//  butterflies with true rotation wing-flaps, hinged two-part-wing birds,
//  node-based fireflies with drift-pause-pulse behavior, frogs that hop
//  between lily pads, bobbing ducks, and skimming dragonflies. Factories
//  only — placement belongs to GardenSceneBuilder. All actions are baked
//  with seeded randomness so the world is stable across launches.
//

import SceneKit
import UIKit

enum GardenCreatures {

    // MARK: - Bees

    /// Striped bee with two pairs of translucent, blue-tinted wings that
    /// blur via rapid opacity flutter. Orbits its parent pivot.
    static func bee(animate: Bool) -> SCNNode {
        let bee = SCNNode()

        // Body: alternating yellow/black segments.
        let colors = [GardenPalette.beeYellow, GardenPalette.beeBlack,
                      GardenPalette.beeYellow, GardenPalette.beeBlack]
        for (i, color) in colors.enumerated() {
            let seg = SCNSphere(radius: i == 0 ? 0.035 : 0.03)
            seg.segmentCount = 8
            seg.firstMaterial = GardenMaterials.flat(color)
            let node = SCNNode(geometry: seg)
            node.position = SCNVector3(Float(i) * 0.028 - 0.04, 0, 0)
            bee.addChildNode(node)
        }

        // Two pairs of iridescent wings.
        for (dx, side) in [(Float(-0.015), Float(-1)), (-0.015, 1),
                           (0.015, -1), (0.015, 1)] {
            let wingGeo = SCNPlane(width: 0.07, height: 0.045)
            wingGeo.cornerRadius = 0.02
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(red: 0.82, green: 0.88, blue: 1.0, alpha: 0.6)
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.writesToDepthBuffer = false
            wingGeo.firstMaterial = m
            let wing = SCNNode(geometry: wingGeo)
            wing.position = SCNVector3(dx, 0.035, side * 0.03)
            wing.eulerAngles = SCNVector3(side * 0.6, 0, 0)
            if animate {
                // Wing blur: rapid opacity flutter.
                let dim = SCNAction.fadeOpacity(to: 0.3, duration: 1.0 / 15.0)
                let bright = SCNAction.fadeOpacity(to: 0.9, duration: 1.0 / 15.0)
                wing.runAction(.repeatForever(.sequence([dim, bright])))
            }
            bee.addChildNode(wing)
        }
        bee.castsShadow = false
        return bee
    }

    /// Orbit pivot for a bee around a flower head: varying radius/height,
    /// with a pause (landing beat) each lap.
    static func beeOrbit(headHeight: Float, radius: Float, lapSeconds: TimeInterval,
                         pauseSeconds: TimeInterval, phase: Float, animate: Bool) -> SCNNode {
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, headHeight + 0.25, 0)
        pivot.eulerAngles.y = phase

        let bee = bee(animate: animate)
        bee.position = SCNVector3(radius, 0, 0)
        bee.eulerAngles.y = .pi / 2
        pivot.addChildNode(bee)

        if animate {
            let lap = SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: lapSeconds)
            pivot.runAction(.repeatForever(.sequence([
                lap, .wait(duration: pauseSeconds)
            ])))
            // Drift in/out + up/down so the orbit isn't a perfect circle.
            let inOut = SCNAction.sequence([
                .moveBy(x: 0.25, y: 0.18, z: 0, duration: 2.6),
                .moveBy(x: -0.25, y: -0.18, z: 0, duration: 2.6)
            ])
            inOut.timingMode = .easeInEaseOut
            bee.runAction(.repeatForever(inOut))
        }
        return pivot
    }

    // MARK: - Butterflies

    /// Painted butterfly: 4 wing planes (fore + hind per side) hinged at the
    /// body, flapping by true rotation — wings meet above, sweep down/out.
    static func butterfly(color: UIColor, animate: Bool) -> SCNNode {
        let body = SCNNode()
        let bodyGeo = SCNCapsule(capRadius: 0.014, height: 0.1)
        bodyGeo.firstMaterial = GardenMaterials.flat(UIColor(white: 0.2, alpha: 1))
        body.addChildNode(SCNNode(geometry: bodyGeo))

        for side in [Float(-1), Float(1)] {
            for (fore, length, sweep) in [(true, CGFloat(0.11), Float(0.03)),
                                          (false, CGFloat(0.085), Float(-0.035))] {
                let wingGeo = SCNPlane(width: length, height: fore ? 0.09 : 0.075)
                wingGeo.cornerRadius = 0.035
                wingGeo.firstMaterial = GardenMaterials.unlit(color)
                let wing = SCNNode(geometry: wingGeo)
                // Hinge at the body edge.
                wing.pivot = SCNMatrix4MakeTranslation(side * -Float(length) / 2, 0, 0)
                wing.position = SCNVector3(side * 0.012, sweep, 0)
                wing.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)

                if animate {
                    // Wings meet at top (±75°), sweep down and out (±15°).
                    let up = SCNAction.rotateTo(
                        x: -.pi / 2, y: CGFloat(side) * 1.3, z: 0,
                        duration: 0.75, usesShortestUnitArc: true
                    )
                    up.timingMode = .easeOut
                    let down = SCNAction.rotateTo(
                        x: -.pi / 2, y: CGFloat(side) * 0.25, z: 0,
                        duration: 0.75, usesShortestUnitArc: true
                    )
                    down.timingMode = .easeInEaseOut
                    wing.runAction(.repeatForever(.sequence([up, down])))
                }
                body.addChildNode(wing)
            }
        }
        body.castsShadow = false
        return body
    }

    /// Wandering flight rig: outer orbit + counter-rotating inner gives a
    /// figure-8-ish path; vertical bob layered on the butterfly itself.
    static func butterflyFlight(color: UIColor, orbitRadius: Float,
                                height: Float, period: TimeInterval,
                                animate: Bool) -> SCNNode {
        let outer = SCNNode()
        outer.position = SCNVector3(0, height, 0)
        let inner = SCNNode()
        inner.position = SCNVector3(orbitRadius * 0.55, 0, 0)
        outer.addChildNode(inner)
        let fly = butterfly(color: color, animate: animate)
        fly.position = SCNVector3(orbitRadius * 0.45, 0, 0)
        inner.addChildNode(fly)

        if animate {
            outer.runAction(.repeatForever(
                .rotateBy(x: 0, y: 2 * .pi, z: 0, duration: period)))
            inner.runAction(.repeatForever(
                .rotateBy(x: 0, y: -4 * .pi, z: 0, duration: period)))
            let bob = SCNAction.sequence([
                .moveBy(x: 0, y: 0.25, z: 0, duration: 1.4),
                .moveBy(x: 0, y: -0.25, z: 0, duration: 1.4)
            ])
            bob.timingMode = .easeInEaseOut
            fly.runAction(.repeatForever(bob))
        }
        return outer
    }

    // MARK: - Birds

    /// Realistic bird: elongated body, cone beak, fan tail, two-part wings —
    /// the upper hinged at the shoulder, the lower following with a delay.
    static func bird(animate: Bool) -> SCNNode {
        let bird = SCNNode()

        let bodyGeo = SCNSphere(radius: 0.09)
        bodyGeo.segmentCount = 10
        bodyGeo.firstMaterial = GardenMaterials.flat(GardenPalette.birdInk)
        let body = SCNNode(geometry: bodyGeo)
        body.scale = SCNVector3(2.2, 0.5, 0.6)
        bird.addChildNode(body)

        let beakGeo = SCNCone(topRadius: 0, bottomRadius: 0.02, height: 0.07)
        beakGeo.radialSegmentCount = 6
        beakGeo.firstMaterial = GardenMaterials.flat(UIColor(hexRGB: 0xE8923A))
        let beak = SCNNode(geometry: beakGeo)
        beak.position = SCNVector3(0.22, 0.01, 0)
        beak.eulerAngles.z = -.pi / 2
        bird.addChildNode(beak)

        let tailGeo = SCNBox(width: 0.12, height: 0.008, length: 0.09, chamferRadius: 0.01)
        tailGeo.firstMaterial = GardenMaterials.flat(GardenPalette.birdInk)
        let tail = SCNNode(geometry: tailGeo)
        tail.position = SCNVector3(-0.2, 0.01, 0)
        tail.eulerAngles.z = 0.18
        bird.addChildNode(tail)

        for side in [Float(-1), Float(1)] {
            // Upper wing, hinged at the shoulder.
            let upperGeo = SCNBox(width: 0.04, height: 0.01, length: 0.18, chamferRadius: 0.004)
            upperGeo.firstMaterial = GardenMaterials.flat(GardenPalette.birdInk)
            let upper = SCNNode(geometry: upperGeo)
            upper.pivot = SCNMatrix4MakeTranslation(0, 0, side * -0.09)
            upper.position = SCNVector3(0.02, 0.03, side * 0.05)

            // Lower wing, hinged at the upper's tip, follows with delay.
            let lowerGeo = SCNBox(width: 0.035, height: 0.008, length: 0.16, chamferRadius: 0.004)
            lowerGeo.firstMaterial = GardenMaterials.flat(GardenPalette.birdInk)
            let lower = SCNNode(geometry: lowerGeo)
            lower.pivot = SCNMatrix4MakeTranslation(0, 0, side * -0.08)
            lower.position = SCNVector3(0, 0, side * 0.17)
            upper.addChildNode(lower)

            if animate {
                let upAngle = CGFloat(side) * 0.85
                let downAngle = CGFloat(side) * -0.5
                let upperUp = SCNAction.rotateTo(x: upAngle, y: 0, z: 0,
                                                 duration: 0.24, usesShortestUnitArc: true)
                upperUp.timingMode = .easeOut
                let upperDown = SCNAction.rotateTo(x: downAngle, y: 0, z: 0,
                                                   duration: 0.3, usesShortestUnitArc: true)
                upperDown.timingMode = .easeIn
                upper.runAction(.repeatForever(.sequence([upperUp, upperDown])))

                let lowerUp = SCNAction.rotateTo(x: upAngle * 0.7, y: 0, z: 0,
                                                 duration: 0.24, usesShortestUnitArc: true)
                let lowerDown = SCNAction.rotateTo(x: downAngle * 0.6, y: 0, z: 0,
                                                   duration: 0.3, usesShortestUnitArc: true)
                lower.runAction(.sequence([
                    .wait(duration: 0.08),
                    .repeatForever(.sequence([lowerUp, lowerDown]))
                ]))
            }
            bird.addChildNode(upper)
        }
        bird.castsShadow = false
        return bird
    }

    /// Circling bird at altitude.
    static func birdOrbit(height: Float, radius: Float, duration: TimeInterval,
                          phase: Float, animate: Bool) -> SCNNode {
        let orbit = SCNNode()
        orbit.position = SCNVector3(0, height, 0)
        orbit.eulerAngles.y = phase
        let flier = bird(animate: animate)
        flier.position = SCNVector3(radius, 0, 0)
        flier.eulerAngles.y = .pi / 2
        orbit.addChildNode(flier)
        if animate {
            orbit.runAction(.repeatForever(
                .rotateBy(x: 0, y: 2 * .pi, z: 0, duration: duration)))
        }
        return orbit
    }

    /// Sunset V formation — 5 birds flying home, wrapping across the sky.
    static func vFormation(animate: Bool) -> SCNNode {
        let group = SCNNode()
        group.position = SCNVector3(-22, 9, -6)
        let offsets: [(Float, Float)] = [(0, 0), (-0.9, 0.6), (-0.9, -0.6),
                                         (-1.8, 1.2), (-1.8, -1.2)]
        for (dx, dz) in offsets {
            let flier = bird(animate: animate)
            flier.position = SCNVector3(dx, Float.random(in: 0...0).rounded(), dz) // deterministic 0
            flier.eulerAngles.y = .pi / 2
            group.addChildNode(flier)
        }
        if animate {
            let cross = SCNAction.sequence([
                .moveBy(x: 44, y: 0, z: 0, duration: 30),
                .run { node in node.position.x = -22 }
            ])
            group.runAction(.repeatForever(cross))
        }
        return group
    }

    // MARK: - Fireflies (node-based: drift → pause+pulse → drift)

    static func firefly(rng: inout GardenSeededRandom, animate: Bool) -> SCNNode {
        let fly = SCNNode()
        let coreGeo = SCNSphere(radius: 0.025)
        coreGeo.segmentCount = 6
        coreGeo.firstMaterial = GardenMaterials.glow(GardenPalette.firefly)
        fly.addChildNode(SCNNode(geometry: coreGeo))

        let glowGeo = SCNSphere(radius: 0.06)
        glowGeo.segmentCount = 8
        let m = SCNMaterial()
        m.diffuse.contents = GardenPalette.firefly.withAlphaComponent(0.3)
        m.emission.contents = GardenPalette.firefly.withAlphaComponent(0.3)
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        glowGeo.firstMaterial = m
        fly.addChildNode(SCNNode(geometry: glowGeo))
        fly.castsShadow = false

        if animate {
            // Pre-baked seeded wander: 5 × (drift → pause) loop.
            var moves: [SCNAction] = []
            for _ in 0..<5 {
                let drift = SCNAction.moveBy(
                    x: CGFloat(rng.range(-0.8, 0.8)),
                    y: CGFloat(rng.range(-0.3, 0.4)),
                    z: CGFloat(rng.range(-0.8, 0.8)),
                    duration: rng.range(2.0, 3.0)
                )
                drift.timingMode = .easeInEaseOut
                moves.append(drift)
                moves.append(.wait(duration: rng.range(0.4, 1.0)))
            }
            // Return home so the loop is seamless.
            let home = SCNAction.move(to: SCNVector3Zero, duration: 2.4)
            home.timingMode = .easeInEaseOut
            // Wander is on a child so `fly`'s placed position is preserved.
            if let core = fly.childNodes.first {
                _ = core
            }
            let wanderer = SCNNode()
            for child in fly.childNodes { child.removeFromParentNode(); wanderer.addChildNode(child) }
            fly.addChildNode(wanderer)
            wanderer.runAction(.repeatForever(.sequence(moves + [home])))

            // Pulse on/off with individual timing.
            let period = rng.range(0.5, 1.5)
            let dim = SCNAction.fadeOpacity(to: 0.08, duration: period)
            dim.timingMode = .easeInEaseOut
            let bright = SCNAction.fadeOpacity(to: 1.0, duration: period)
            bright.timingMode = .easeInEaseOut
            wanderer.runAction(.sequence([
                .wait(duration: rng.range(0, 1.2)),
                .repeatForever(.sequence([dim, bright]))
            ]))
        }
        return fly
    }

    // MARK: - Pond life

    /// Frog on a lily pad — flattened green body, two eye spheres,
    /// occasional hop between its pad and a neighbor.
    static func frog(hopTo offset: SCNVector3, animate: Bool,
                     rng: inout GardenSeededRandom) -> SCNNode {
        let frog = SCNNode()
        let bodyGeo = SCNSphere(radius: 0.09)
        bodyGeo.segmentCount = 10
        bodyGeo.firstMaterial = GardenMaterials.flat(GardenPalette.frogGreen)
        let body = SCNNode(geometry: bodyGeo)
        body.scale = SCNVector3(1.2, 0.65, 1.0)
        frog.addChildNode(body)

        for side in [Float(-1), Float(1)] {
            let eyeGeo = SCNSphere(radius: 0.028)
            eyeGeo.segmentCount = 6
            eyeGeo.firstMaterial = GardenMaterials.flat(GardenPalette.frogGreen)
            let eye = SCNNode(geometry: eyeGeo)
            eye.position = SCNVector3(side * 0.045, 0.07, 0.05)
            frog.addChildNode(eye)
            let pupilGeo = SCNSphere(radius: 0.012)
            pupilGeo.segmentCount = 5
            pupilGeo.firstMaterial = GardenMaterials.unlit(UIColor(white: 0.1, alpha: 1))
            let pupil = SCNNode(geometry: pupilGeo)
            pupil.position = SCNVector3(side * 0.045, 0.075, 0.072)
            frog.addChildNode(pupil)
        }

        if animate {
            let jumpOut = SCNAction.group([
                .moveBy(x: CGFloat(offset.x), y: 0, z: CGFloat(offset.z), duration: 0.5),
                .sequence([.moveBy(x: 0, y: 0.35, z: 0, duration: 0.25),
                           .moveBy(x: 0, y: -0.35, z: 0, duration: 0.25)])
            ])
            let jumpBack = SCNAction.group([
                .moveBy(x: -CGFloat(offset.x), y: 0, z: -CGFloat(offset.z), duration: 0.5),
                .sequence([.moveBy(x: 0, y: 0.35, z: 0, duration: 0.25),
                           .moveBy(x: 0, y: -0.35, z: 0, duration: 0.25)])
            ])
            frog.runAction(.repeatForever(.sequence([
                .wait(duration: rng.range(5, 9)), jumpOut,
                .wait(duration: rng.range(5, 9)), jumpBack
            ])))
        }
        frog.castsShadow = false
        return frog
    }

    /// Floating duck — white body, green head (male), orange bill; bobs on
    /// the water, drifts a slow circle, dips its head to feed.
    static func duck(drift radius: Float, period: TimeInterval, phase: Float,
                     animate: Bool) -> SCNNode {
        let pivot = SCNNode()
        pivot.eulerAngles.y = phase

        let duck = SCNNode()
        duck.position = SCNVector3(radius, 0.06, 0)
        duck.eulerAngles.y = .pi / 2

        let bodyGeo = SCNSphere(radius: 0.13)
        bodyGeo.segmentCount = 12
        bodyGeo.firstMaterial = GardenMaterials.flat(GardenPalette.duckBody)
        let body = SCNNode(geometry: bodyGeo)
        body.scale = SCNVector3(1.5, 0.85, 1.0)
        duck.addChildNode(body)

        let headPivot = SCNNode()
        headPivot.position = SCNVector3(0.14, 0.1, 0)
        let headGeo = SCNSphere(radius: 0.07)
        headGeo.segmentCount = 10
        headGeo.firstMaterial = GardenMaterials.flat(GardenPalette.duckHead)
        let head = SCNNode(geometry: headGeo)
        head.position = SCNVector3(0.02, 0.05, 0)
        headPivot.addChildNode(head)

        let billGeo = SCNCone(topRadius: 0.008, bottomRadius: 0.028, height: 0.06)
        billGeo.radialSegmentCount = 8
        billGeo.firstMaterial = GardenMaterials.flat(GardenPalette.duckBill)
        let bill = SCNNode(geometry: billGeo)
        bill.position = SCNVector3(0.09, 0.04, 0)
        bill.eulerAngles.z = -.pi / 2
        bill.scale = SCNVector3(1, 1, 0.55)   // flattened
        headPivot.addChildNode(bill)
        duck.addChildNode(headPivot)
        pivot.addChildNode(duck)

        if animate {
            let bob = SCNAction.sequence([
                .moveBy(x: 0, y: 0.03, z: 0, duration: 1.3),
                .moveBy(x: 0, y: -0.03, z: 0, duration: 1.3)
            ])
            bob.timingMode = .easeInEaseOut
            duck.runAction(.repeatForever(bob))

            let dipDown = SCNAction.rotateBy(x: 0, y: 0, z: -0.9, duration: 0.5)
            dipDown.timingMode = .easeIn
            let dipUp = SCNAction.rotateBy(x: 0, y: 0, z: 0.9, duration: 0.6)
            dipUp.timingMode = .easeOut
            headPivot.runAction(.repeatForever(.sequence([
                .wait(duration: 7), dipDown, .wait(duration: 1.2), dipUp
            ])))

            pivot.runAction(.repeatForever(
                .rotateBy(x: 0, y: 2 * .pi, z: 0, duration: period)))
        }
        pivot.castsShadow = false
        return pivot
    }

    /// Dragonfly skimming the water — thin body, fast shallow orbit.
    static func dragonfly(radius: Float, period: TimeInterval, phase: Float,
                          animate: Bool) -> SCNNode {
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, 0.25, 0)
        pivot.eulerAngles.y = phase

        let fly = SCNNode()
        fly.position = SCNVector3(radius, 0, 0)
        fly.eulerAngles.y = .pi / 2

        let bodyGeo = SCNCapsule(capRadius: 0.01, height: 0.12)
        bodyGeo.firstMaterial = GardenMaterials.flat(UIColor(hexRGB: 0x3AA8C0))
        let body = SCNNode(geometry: bodyGeo)
        body.eulerAngles.x = .pi / 2
        fly.addChildNode(body)

        for side in [Float(-1), Float(1)] {
            let wingGeo = SCNPlane(width: 0.1, height: 0.025)
            wingGeo.cornerRadius = 0.012
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(white: 0.95, alpha: 0.5)
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.writesToDepthBuffer = false
            wingGeo.firstMaterial = m
            let wing = SCNNode(geometry: wingGeo)
            wing.position = SCNVector3(side * 0.05, 0.012, 0)
            wing.eulerAngles.x = -.pi / 2
            if animate {
                let dim = SCNAction.fadeOpacity(to: 0.25, duration: 0.06)
                let bright = SCNAction.fadeOpacity(to: 0.8, duration: 0.06)
                wing.runAction(.repeatForever(.sequence([dim, bright])))
            }
            fly.addChildNode(wing)
        }
        pivot.addChildNode(fly)

        if animate {
            pivot.runAction(.repeatForever(
                .rotateBy(x: 0, y: 2 * .pi, z: 0, duration: period)))
        }
        pivot.castsShadow = false
        return pivot
    }
}
