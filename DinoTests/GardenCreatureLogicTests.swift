//
//  GardenCreatureLogicTests.swift
//  DinoTests
//
//  Pure-logic coverage for the garden ecosystem: clock bands, letter gate,
//  easing/bezier math, and the hummingbird / bee / firefly state machines —
//  including the facing-locked-per-flight rule (the prototype's double-image
//  bug) and reduce-motion slowdown.
//

import XCTest
import simd
@testable import Dino

final class GardenCreatureLogicTests: XCTestCase {

    // MARK: Clock

    func testRegimeBands() {
        XCTAssertEqual(GardenCreatureRegime.from(hour: 6), .day)
        XCTAssertEqual(GardenCreatureRegime.from(hour: 12), .day)
        XCTAssertEqual(GardenCreatureRegime.from(hour: 17), .day)
        XCTAssertEqual(GardenCreatureRegime.from(hour: 18), .evening)
        XCTAssertEqual(GardenCreatureRegime.from(hour: 20), .evening)
        XCTAssertEqual(GardenCreatureRegime.from(hour: 21), .night)
        XCTAssertEqual(GardenCreatureRegime.from(hour: 23), .night)
        XCTAssertEqual(GardenCreatureRegime.from(hour: 0), .night)
        XCTAssertEqual(GardenCreatureRegime.from(hour: 5), .night)
    }

    // MARK: Letter gate

    func testLetterUnreadRules() {
        XCTAssertTrue(GardenLetterGate.isUnread(readDayKey: nil, todayKey: "2026-07-04"))
        XCTAssertTrue(GardenLetterGate.isUnread(readDayKey: "2026-07-03", todayKey: "2026-07-04"))
        XCTAssertFalse(GardenLetterGate.isUnread(readDayKey: "2026-07-04", todayKey: "2026-07-04"))
    }

    func testDayKeyFormat() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let date = DateComponents(calendar: cal, year: 2026, month: 7, day: 4, hour: 23).date!
        XCTAssertEqual(GardenLetterGate.dayKey(for: date, calendar: cal), "2026-07-04")
    }

    // MARK: Math

    func testArrivalEaseEndpointsAndMonotonicity() {
        XCTAssertEqual(GardenCreatureMath.arrivalEase(0), 0, accuracy: 1e-6)
        XCTAssertEqual(GardenCreatureMath.arrivalEase(1), 1, accuracy: 1e-6)
        var last: Float = -1
        for i in 0...100 {
            let v = GardenCreatureMath.arrivalEase(Float(i) / 100)
            XCTAssertGreaterThanOrEqual(v, last)
            last = v
        }
        // fast accel: the first half covers well over half the distance
        XCTAssertGreaterThan(GardenCreatureMath.arrivalEase(0.5), 0.7)
    }

    func testQuadBezierEndpointsAndRaisedMidpoint() {
        let a = SIMD3<Float>(0, 0, 0), b = SIMD3<Float>(2, 4, 0), c = SIMD3<Float>(4, 0, 0)
        XCTAssertEqual(GardenCreatureMath.quadBezier(a, b, c, 0), a)
        XCTAssertEqual(GardenCreatureMath.quadBezier(a, b, c, 1), c)
        let mid = GardenCreatureMath.quadBezier(a, b, c, 0.5)
        XCTAssertGreaterThan(mid.y, 0)   // raised midpoint arcs upward
    }

    // MARK: Hummingbird

    private func makeBird(seed: UInt64 = 7) -> HummingbirdBrain {
        HummingbirdBrain(rng: GardenSeededRandom(seed: seed))
    }

    func testArrivalReachesPresentingAfterDuration() {
        var bird = makeBird()
        bird.beginArrival(now: 100)
        let early = bird.tick(now: 101)
        XCTAssertEqual(early.view, .front)
        XCTAssertTrue(early.visible)
        XCTAssertLessThan(early.scale, 1)
        _ = bird.tick(now: 100 + 2.5)
        guard case .presenting = bird.mode else {
            return XCTFail("expected presenting after 2.4s, got \(bird.mode)")
        }
        XCTAssertTrue(bird.consumePresentingEvent())
        XCTAssertFalse(bird.consumePresentingEvent(), "presenting event fires exactly once")
    }

    func testPresentingHoldsUntilDelivery() {
        var bird = makeBird()
        bird.beginArrival(now: 0)
        _ = bird.tick(now: 3)
        _ = bird.tick(now: 60)
        guard case .presenting = bird.mode else {
            return XCTFail("she waits with the letter until tapped")
        }
    }

    func testFacingLockedForWholeDart() {
        var bird = makeBird()
        bird.beginVisiting(now: 0)
        guard case .darting(_, let duration, let from, let to, _, let facing) = bird.mode else {
            return XCTFail("expected darting")
        }
        XCTAssertEqual(facing, to.x - from.x > 0 ? 1 : -1)
        XCTAssertTrue((0.45...0.65).contains(duration))
        // facing never changes mid-flight, whatever the bob does
        for step in 1...9 {
            let pose = bird.tick(now: Double(step) * duration / 10)
            if case .darting = bird.mode {
                XCTAssertEqual(pose.facing, facing, "facing is set once per flight")
                XCTAssertEqual(pose.view, .profile)
            }
        }
    }

    func testDartLandsInHoverWithSpecRange() {
        var bird = makeBird()
        bird.beginVisiting(now: 0)
        _ = bird.tick(now: 1.0)   // any dart is over well before 1s at slowFactor 1? max 0.65 → yes
        guard case .hovering(_, let duration, let at) = bird.mode else {
            return XCTFail("expected hovering after the dart")
        }
        XCTAssertTrue((2.0...4.5).contains(duration))
        XCTAssertTrue((0..<HummingbirdWaypoints.garden.hoverPoints.count).contains(at))
    }

    func testHoverEventuallySipsAcrossSeeds() {
        // ~30% sip chance — across seeds, both outcomes must occur
        var sipped = false, darted = false
        for seed in 1...40 {
            var bird = makeBird(seed: UInt64(seed))
            bird.beginVisiting(now: 0)
            _ = bird.tick(now: 1.0)               // land in hover
            guard case .hovering(let start, let duration, _) = bird.mode else { continue }
            _ = bird.tick(now: start + duration + 0.01)
            switch bird.mode {
            case .sipping: sipped = true
            case .darting: darted = true
            default: break
            }
        }
        XCTAssertTrue(sipped, "some hovers end in a sip")
        XCTAssertTrue(darted, "most hovers end in a dart")
    }

    func testSipLeansAndReturnsToHover() {
        var bird = makeBird()
        bird.mode = .sipping(start: 0, at: 0)
        let mid = bird.tick(now: 0.6)
        XCTAssertGreaterThan(mid.lean, 0.2, "she leans into the bloom mid-sip")
        _ = bird.tick(now: 1.3)
        guard case .hovering = bird.mode else {
            return XCTFail("sip returns to hover")
        }
    }

    func testFlyHomeEndsGone() {
        var bird = makeBird()
        bird.beginVisiting(now: 0)
        let pose = bird.tick(now: 0.2)
        bird.flyHome(now: 0.3, from: pose.position)
        _ = bird.tick(now: 0.3 + 1.2)
        guard case .gone = bird.mode else { return XCTFail("expected gone after departing") }
        XCTAssertFalse(bird.tick(now: 2).visible)
    }

    func testDeliverCompleteYoungGardenDeparts() {
        var bird = makeBird()
        bird.beginArrival(now: 0)
        _ = bird.tick(now: 3)
        bird.deliverComplete(now: 3, stayForFlowers: false)
        guard case .departing = bird.mode else { return XCTFail("young garden → she leaves") }
        bird.deliverComplete(now: 3, stayForFlowers: true)
        guard case .darting = bird.mode else { return XCTFail("bloomed garden → she visits") }
    }

    func testReduceMotionSlowsArrival() {
        var bird = makeBird()
        bird.slowFactor = 2
        bird.banking = false
        bird.beginArrival(now: 0)
        _ = bird.tick(now: 3)
        if case .presenting = bird.mode {
            XCTFail("at slowFactor 2 the 2.4s arrival takes 4.8s")
        }
        _ = bird.tick(now: 5)
        guard case .presenting = bird.mode else { return XCTFail("arrives by 4.8s") }
    }

    // MARK: Bee

    private func makeBee(seed: UInt64 = 11) -> BeeBrain {
        BeeBrain(rng: GardenSeededRandom(seed: seed),
                 bloom: SIMD3<Float>(0, 2.5, 0.3),
                 restPoints: [SIMD3<Float>(-0.85, 1.75, 0.35), SIMD3<Float>(0.8, 1.6, 0.3)])
    }

    func testBeeLifecycleOrbitLandCollectTravel() {
        var bee = makeBee()
        guard case .orbiting(_, let duration, let radius, let speed, _) = bee.mode else {
            return XCTFail("bees start orbiting")
        }
        XCTAssertTrue((0.22...0.3).contains(radius))
        XCTAssertTrue((0.9...1.4).contains(speed))
        XCTAssertTrue((3.0...5.0).contains(duration))

        _ = bee.tick(now: duration + 0.01)
        guard case .landing = bee.mode else { return XCTFail("orbit → landing") }

        _ = bee.tick(now: duration + BeeBrain.landDuration + 0.01)
        guard case .collecting(_, let collectDuration) = bee.mode else {
            return XCTFail("landing → collecting")
        }
        XCTAssertTrue((1.6...2.6).contains(collectDuration))

        _ = bee.tick(now: duration + BeeBrain.landDuration + collectDuration + 0.05)
        guard case .traveling(_, let travelDuration, _, _) = bee.mode else {
            return XCTFail("collecting → traveling")
        }
        XCTAssertGreaterThanOrEqual(travelDuration, 2.5, "bees amble, they never dart")
    }

    func testBeeWingsPauseAndPollenEmitsOnceDuringCollect() {
        var bee = makeBee()
        guard case .orbiting(_, let duration, _, _, _) = bee.mode else { return XCTFail() }
        // the machine transitions lazily on tick — walk it: orbit end → landing,
        // then landing end → collecting
        _ = bee.tick(now: duration + 0.01)
        guard case .landing(let landStart, _) = bee.mode else { return XCTFail("expected landing") }
        let first = bee.tick(now: landStart + BeeBrain.landDuration + 0.01)
        XCTAssertFalse(first.wingsBeating, "wings pause while collecting")
        XCTAssertTrue(first.emitPollen, "pollen specks emit entering collect")
        let second = bee.tick(now: landStart + BeeBrain.landDuration + 0.07)
        let third = bee.tick(now: landStart + BeeBrain.landDuration + 0.13)
        XCTAssertFalse(second.emitPollen, "pollen emits exactly once per collect")
        XCTAssertFalse(third.emitPollen)
        XCTAssertTrue(abs(second.wiggle) > 0.001 || abs(third.wiggle) > 0.001,
                      "body wiggles while collecting")
    }

    func testBeeSleepAndWake() {
        var bee = makeBee()
        bee.sleep()
        let asleep = bee.tick(now: 100)
        XCTAssertFalse(asleep.wingsBeating)
        XCTAssertEqual(asleep.position, bee.sleepPosition)
        bee.wake(now: 200)
        guard case .orbiting = bee.mode else { return XCTFail("morning wakes the bee") }
    }

    // MARK: Fireflies

    func testFireflyBrightnessBreathesWithinBounds() {
        for t in stride(from: 0.0, to: 10.0, by: 0.05) {
            let b = FireflySpec.brightness(now: t, speed: 1.0, phase: 0.4)
            XCTAssertGreaterThanOrEqual(b, FireflySpec.opacityFloor, "floor keeps a shimmer")
            XCTAssertLessThanOrEqual(b, 1.0)
        }
    }

    func testFireflyFlockSpecsWithinRanges() {
        var rng = GardenSeededRandom(seed: 3)
        let flock = FireflySpec.flock(count: 12, rng: &rng)
        XCTAssertEqual(flock.count, 12)
        for f in flock {
            XCTAssertTrue((0.5...1.4).contains(f.blinkSpeed))
        }
        // rhythms differ — no synchronized strobing
        XCTAssertGreaterThan(Set(flock.map(\.blinkSpeed)).count, 6)
    }

    func testFireflyScaleSwellsWithBlink() {
        let spec = FireflySpec(home: .zero, blinkSpeed: 1, phase: 0, wanderSeed: 0)
        // peak of sin at t = 0.25s for speed 1Hz phase 0
        let bright = spec.scale(now: 0.25)
        let dim = spec.scale(now: 0.75)
        XCTAssertGreaterThan(bright, dim)
        XCTAssertEqual(bright, 1.25, accuracy: 0.01)
    }
}
