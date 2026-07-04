//
//  GardenCreatureLogic.swift
//  Dino
//
//  Pure logic for the garden ecosystem — the hummingbird / bee state
//  machines, firefly blink math, the creature clock, and the daily-letter
//  gate. No SceneKit, no UIKit: every function is (state, time, seeded
//  random) → pose, so the whole layer is unit-testable.
//

import Foundation
import simd

// MARK: - Debug hooks (simulator verification only)

enum GardenDebug {
    private static var args: [String] { ProcessInfo.processInfo.arguments }

    /// -gardenHour <0-23> forces the creature clock + lighting period.
    static var forcedHour: Int? {
        #if DEBUG
        guard let i = args.firstIndex(of: "-gardenHour"), i + 1 < args.count,
              let h = Int(args[i + 1]), (0..<24).contains(h) else { return nil }
        return h
        #else
        return nil
        #endif
    }

    #if DEBUG
    static var forceBloomed: Bool { args.contains("-gardenBloomed") }
    static var forceLetter: Bool { args.contains("-gardenLetter") }
    static var showPerfHUD: Bool { args.contains("-gardenPerfHUD") }
    static var autoOpen: Bool { args.contains("-gardenAutoOpen") }
    #else
    static var forceBloomed: Bool { false }
    static var forceLetter: Bool { false }
    static var showPerfHUD: Bool { false }
    static var autoOpen: Bool { false }
    #endif
}

// MARK: - The creature clock

/// Locked bands: day 6–18 (bird + bees), evening 18–21 (fireflies emerging
/// as the light cools), night 21–6 (full fireflies, moon up).
enum GardenCreatureRegime: String, Equatable {
    case day, evening, night

    static func from(hour: Int) -> GardenCreatureRegime {
        switch hour {
        case 6..<18: return .day
        case 18..<21: return .evening
        default: return .night
        }
    }
}

// MARK: - Daily letter gate (one letter per local day)

enum GardenLetterGate {
    /// Unread whenever the stored read-day differs from today — covers nil
    /// (never read), yesterday's unread letter, and day rollover while open.
    static func isUnread(readDayKey: String?, todayKey: String) -> Bool {
        readDayKey != todayKey
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}

// MARK: - Shared math

enum GardenCreatureMath {
    static func smoothstep(_ t: Float) -> Float {
        let c = min(max(t, 0), 1)
        return c * c * (3 - 2 * c)
    }

    /// The prototype's arrival ease: fast acceleration, dead-stop deceleration.
    static func arrivalEase(_ t: Float) -> Float {
        1 - pow(1 - smoothstep(t), 3)
    }

    static func quadBezier(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>,
                           _ p2: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        let u = 1 - t
        return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
    }
}

// MARK: - Hummingbird

struct HummingbirdWaypoints {
    let far: SIMD3<Float>            // deep in the scene, where arrivals begin
    let present: SIMD3<Float>        // close to camera, where she offers the letter
    let exit: SIMD3<Float>           // offscreen home
    let hoverPoints: [SIMD3<Float>]  // bloom head first, then leaves + open air

    /// Tuned to the garden diorama: sunflower at origin, orthographic camera
    /// at (0,3,8) looking at (0,2,0).
    static let garden = HummingbirdWaypoints(
        far: SIMD3(-1.4, 3.4, -6.0),
        present: SIMD3(0.95, 2.2, 4.6),   // clear of the petals, easy to tap
        exit: SIMD3(3.6, 4.3, 1.0),
        hoverPoints: [
            SIMD3(0.0, 2.85, 0.5),     // above the bloom head
            SIMD3(-0.85, 1.75, 0.35),  // left leaf
            SIMD3(0.8, 1.6, 0.3),      // right leaf
            SIMD3(-1.5, 2.9, 1.4),     // open air left
            SIMD3(1.55, 3.15, 1.2),    // open air right
        ]
    )
}

enum HummingbirdSpriteView: Equatable { case front, profile }

struct HummingbirdPose: Equatable {
    var position: SIMD3<Float>
    var scale: Float
    var bank: Float
    var lean: Float
    var view: HummingbirdSpriteView
    var facing: Float        // +1 right / -1 left; locked per flight
    var visible: Bool
}

enum HummingbirdMode: Equatable {
    case gone
    case arriving(start: Double, from: SIMD3<Float>, fromScale: Float)
    case presenting(since: Double)
    case darting(start: Double, duration: Double,
                 from: SIMD3<Float>, to: SIMD3<Float>, toIndex: Int, facing: Float)
    case hovering(start: Double, duration: Double, at: Int)
    case sipping(start: Double, at: Int)
    case departing(start: Double, from: SIMD3<Float>)
}

struct HummingbirdBrain {
    var mode: HummingbirdMode = .gone
    var rng: GardenSeededRandom
    let points: HummingbirdWaypoints
    /// Reduce Motion: 2 → everything at half speed, no banking.
    var slowFactor: Double = 1
    var banking = true

    private var lastFacing: Float = 1
    private var reachedPresenting = false
    private var presentingTimedOut = false
    private var currentHoverIndex = 0

    static let arriveDuration = 2.4
    static let departDuration = 1.1
    static let sipDuration = 1.2
    /// Unacknowledged this long → she tucks the envelope and lives her day.
    static let presentTimeout = 45.0

    init(rng: GardenSeededRandom, points: HummingbirdWaypoints = .garden) {
        self.rng = rng
        self.points = points
    }

    /// True exactly once, the tick she settles into presenting — the
    /// controller turns it into the soft haptic + delivery analytics.
    mutating func consumePresentingEvent() -> Bool {
        defer { reachedPresenting = false }
        return reachedPresenting
    }

    /// True exactly once when presenting goes unacknowledged past the timeout.
    /// The controller tucks the envelope and sends her to the flowers — the
    /// letter itself stays unread and rides with her again next open.
    mutating func consumePresentingTimeout() -> Bool {
        defer { presentingTimedOut = false }
        return presentingTimedOut
    }

    // MARK: External events

    /// Letter delivery. From offscreen depth by default; when she's already
    /// mid-garden (the letter appeared while she was visiting), she swoops to
    /// the camera from where she is — never a teleport.
    mutating func beginArrival(now: Double, from: SIMD3<Float>? = nil, fromScale: Float = 0.35) {
        mode = .arriving(start: now, from: from ?? points.far, fromScale: from == nil ? 0.35 : fromScale)
    }

    /// Ordinary garden life (no letter): she darts in from home to a flower.
    mutating func beginVisiting(now: Double) {
        startDart(now: now, from: points.exit)
    }

    /// Letter opened. She either stays for the flowers or heads home.
    mutating func deliverComplete(now: Double, stayForFlowers: Bool) {
        if stayForFlowers {
            startDart(now: now, from: points.present)
        } else {
            mode = .departing(start: now, from: points.present)
        }
    }

    /// Evening/night (or the garden no longer earns visits): fly home.
    mutating func flyHome(now: Double, from position: SIMD3<Float>) {
        switch mode {
        case .gone, .departing: return
        default: mode = .departing(start: now, from: position)
        }
    }

    /// Tap while she isn't carrying a letter — she startles to another flower.
    mutating func scatter(now: Double, from position: SIMD3<Float>) {
        startDart(now: now, from: position)
    }

    private mutating func startDart(now: Double, from: SIMD3<Float>) {
        var index = Int(rng.range(0, Double(points.hoverPoints.count) - 0.001))
        index = min(max(index, 0), points.hoverPoints.count - 1)
        if index == currentHoverIndex {
            index = (index + 1) % points.hoverPoints.count
        }
        let to = points.hoverPoints[index]
        let dx = to.x - from.x
        // CRITICAL (prototype bug): facing is decided ONCE, here, from the
        // flight direction — never per-frame from the bobbing position.
        let facing: Float = dx == 0 ? lastFacing : (dx > 0 ? 1 : -1)
        lastFacing = facing
        currentHoverIndex = index
        mode = .darting(start: now, duration: rng.range(0.45, 0.65),
                        from: from, to: to, toIndex: index, facing: facing)
    }

    // MARK: Tick

    mutating func tick(now: Double) -> HummingbirdPose {
        switch mode {
        case .gone:
            return HummingbirdPose(position: points.exit, scale: 1, bank: 0, lean: 0,
                                   view: .profile, facing: lastFacing, visible: false)

        case .arriving(let start, let from, let fromScale):
            let t = Float((now - start) / (Self.arriveDuration * slowFactor))
            if t >= 1 {
                mode = .presenting(since: now)
                reachedPresenting = true
                return tick(now: now)
            }
            let e = GardenCreatureMath.arrivalEase(t)
            let mid = (from + points.present) * 0.5 + SIMD3<Float>(0, 1.1, 0)
            let pos = GardenCreatureMath.quadBezier(from, mid, points.present, e)
            return HummingbirdPose(position: pos, scale: fromScale + (1 - fromScale) * e,
                                   bank: 0, lean: 0, view: .front, facing: 1, visible: true)

        case .presenting(let since):
            if now - since >= Self.presentTimeout {
                presentingTimedOut = true   // controller decides stay vs depart
            }
            let bob = SIMD3<Float>(Float(sin(now * 1.7)) * 0.03,
                                   Float(sin(now * 2.2)) * 0.045,
                                   Float(sin(now * 3.2)) * 0.02)
            return HummingbirdPose(position: points.present + bob, scale: 1, bank: 0, lean: 0,
                                   view: .front, facing: 1, visible: true)

        case .darting(let start, let duration, let from, let to, let toIndex, let facing):
            let t = Float((now - start) / (duration * slowFactor))
            if t >= 1 {
                mode = .hovering(start: now, duration: rng.range(2.0, 4.5), at: toIndex)
                return tick(now: now)
            }
            let mid = (from + to) * 0.5 + SIMD3<Float>(0, 0.45, 0)
            let pos = GardenCreatureMath.quadBezier(from, mid, to, GardenCreatureMath.smoothstep(t))
            let bank = banking ? Float(sin(Double(t) * .pi)) * 0.35 * facing : 0
            return HummingbirdPose(position: pos, scale: 1, bank: bank, lean: 0,
                                   view: .profile, facing: facing, visible: true)

        case .hovering(let start, let duration, let at):
            if now - start >= duration * slowFactor {
                if rng.next() < 0.3 {
                    mode = .sipping(start: now, at: at)
                } else {
                    startDart(now: now, from: points.hoverPoints[at])
                }
                return tick(now: now)
            }
            let base = points.hoverPoints[at]
            let bob = SIMD3<Float>(Float(sin(now * 2.1)) * 0.025,
                                   Float(sin(now * 2.9)) * 0.035,
                                   Float(sin(now * 3.4)) * 0.015)
            return HummingbirdPose(position: base + bob, scale: 1, bank: 0, lean: 0,
                                   view: .profile, facing: lastFacing, visible: true)

        case .sipping(let start, let at):
            let t = (now - start) / (Self.sipDuration * slowFactor)
            if t >= 1 {
                mode = .hovering(start: now, duration: rng.range(2.0, 4.5), at: at)
                return tick(now: now)
            }
            let lean = Float(sin(t * .pi)) * 0.3
            let base = points.hoverPoints[at]
            return HummingbirdPose(position: base, scale: 1, bank: 0, lean: lean,
                                   view: .profile, facing: lastFacing, visible: true)

        case .departing(let start, let from):
            let t = Float((now - start) / (Self.departDuration * slowFactor))
            if t >= 1 {
                mode = .gone
                return tick(now: now)
            }
            let mid = (from + points.exit) * 0.5 + SIMD3<Float>(0, 0.6, 0)
            let pos = GardenCreatureMath.quadBezier(from, mid, points.exit,
                                                    GardenCreatureMath.smoothstep(t))
            let facing: Float = points.exit.x - from.x >= 0 ? 1 : -1
            return HummingbirdPose(position: pos, scale: 1,
                                   bank: banking ? Float(sin(Double(t) * .pi)) * 0.25 * facing : 0,
                                   lean: 0, view: .profile, facing: facing, visible: true)
        }
    }
}

// MARK: - Bee

struct BeePose: Equatable {
    var position: SIMD3<Float>
    var facing: Float
    var wingsBeating: Bool
    var wiggle: Float
    var emitPollen: Bool     // true on exactly one tick, entering collect
    var visible: Bool
}

enum BeeMode: Equatable {
    case orbiting(start: Double, duration: Double, radius: Float, speed: Float, phase: Float)
    case landing(start: Double, from: SIMD3<Float>)
    case collecting(start: Double, duration: Double)
    case traveling(start: Double, duration: Double, from: SIMD3<Float>, to: SIMD3<Float>)
    case sleeping
}

struct BeeBrain {
    var mode: BeeMode
    var rng: GardenSeededRandom
    let bloom: SIMD3<Float>
    let restPoints: [SIMD3<Float>]
    var slowFactor: Double = 1

    private var pollenEmitted = true
    private var lastFacing: Float = 1

    static let landDuration = 0.7
    static let travelBob: Float = 0.05

    init(rng: GardenSeededRandom, bloom: SIMD3<Float>, restPoints: [SIMD3<Float>]) {
        self.rng = rng
        self.bloom = bloom
        self.restPoints = restPoints
        var r = rng
        self.mode = .orbiting(start: 0, duration: r.range(3, 5),
                              radius: Float(r.range(0.22, 0.3)),
                              speed: Float(r.range(0.9, 1.4)),
                              phase: Float(r.range(0, .pi * 2)))
        self.rng = r
    }

    /// The bloom-top rest position where a sleeping bee settles.
    var sleepPosition: SIMD3<Float> { bloom + SIMD3<Float>(0, 0.05, 0.12) }

    mutating func wake(now: Double) {
        guard case .sleeping = mode else { return }
        beginOrbit(now: now)
    }

    mutating func sleep() { mode = .sleeping }

    /// Tap: she ambles away to a rest point, mid-whatever she was doing.
    mutating func scatter(now: Double, from position: SIMD3<Float>) {
        let to = restPoints[min(Int(rng.range(0, Double(restPoints.count) - 0.001)), restPoints.count - 1)]
        lastFacing = to.x - position.x >= 0 ? 1 : -1
        mode = .traveling(start: now, duration: rng.range(2.2, 3.6), from: position, to: to)
    }

    private mutating func beginOrbit(now: Double) {
        mode = .orbiting(start: now, duration: rng.range(3, 5),
                         radius: Float(rng.range(0.22, 0.3)),
                         speed: Float(rng.range(0.9, 1.4)),
                         phase: Float(rng.range(0, .pi * 2)))
    }

    mutating func tick(now: Double) -> BeePose {
        switch mode {
        case .sleeping:
            return BeePose(position: sleepPosition, facing: lastFacing,
                           wingsBeating: false, wiggle: 0, emitPollen: false, visible: true)

        case .orbiting(let start, let duration, let radius, let speed, let phase):
            if now - start >= duration * slowFactor {
                mode = .landing(start: now, from: orbitPosition(now: now, radius: radius,
                                                                speed: speed, phase: phase))
                return tick(now: now)
            }
            let pos = orbitPosition(now: now, radius: radius, speed: speed, phase: phase)
            let theta = Float(now) * speed / Float(slowFactor) + phase
            lastFacing = -sin(theta) >= 0 ? 1 : -1
            return BeePose(position: pos, facing: lastFacing,
                           wingsBeating: true, wiggle: 0, emitPollen: false, visible: true)

        case .landing(let start, let from):
            let t = Float((now - start) / (Self.landDuration * slowFactor))
            if t >= 1 {
                pollenEmitted = false
                mode = .collecting(start: now, duration: rng.range(1.6, 2.6))
                return tick(now: now)
            }
            // exponential settle onto the bloom
            let k = 1 - exp(-4 * t)
            let pos = from + (sleepPosition - from) * k
            return BeePose(position: pos, facing: lastFacing,
                           wingsBeating: true, wiggle: 0, emitPollen: false, visible: true)

        case .collecting(let start, let duration):
            if now - start >= duration * slowFactor {
                let to = restPoints[min(Int(rng.range(0, Double(restPoints.count) - 0.001)), restPoints.count - 1)]
                lastFacing = to.x - sleepPosition.x >= 0 ? 1 : -1
                mode = .traveling(start: now, duration: rng.range(2.5, 4.0),
                                  from: sleepPosition, to: to)
                return tick(now: now)
            }
            let emit = !pollenEmitted
            pollenEmitted = true
            // wings pause, body wiggles
            let wiggle = Float(sin(now * 14)) * 0.015
            return BeePose(position: sleepPosition, facing: lastFacing,
                           wingsBeating: false, wiggle: wiggle, emitPollen: emit, visible: true)

        case .traveling(let start, let duration, let from, let to):
            let t = Float((now - start) / (duration * slowFactor))
            if t >= 1 {
                beginOrbit(now: now)
                return tick(now: now)
            }
            // slow meandering amble — never a dart (contrast with the bird)
            let mid = (from + to) * 0.5 + SIMD3<Float>(0, 0.25, 0)
            var pos = GardenCreatureMath.quadBezier(from, mid, to, GardenCreatureMath.smoothstep(t))
            pos.x += Float(sin(now * 3.1)) * Self.travelBob
            pos.y += Float(sin(now * 2.3)) * Self.travelBob
            return BeePose(position: pos, facing: lastFacing,
                           wingsBeating: true, wiggle: 0, emitPollen: false, visible: true)
        }
    }

    private func orbitPosition(now: Double, radius: Float, speed: Float, phase: Float) -> SIMD3<Float> {
        let theta = Float(now) * speed / Float(slowFactor) + phase
        return bloom + SIMD3<Float>(cos(theta) * radius,
                                    sin(theta * 0.7) * 0.08,
                                    sin(theta) * radius * 0.6)
    }
}

// MARK: - Firefly

struct FireflySpec {
    let home: SIMD3<Float>
    let blinkSpeed: Float     // 0.5–1.4 Hz
    let phase: Float
    let wanderSeed: Float

    static let opacityFloor: Float = 0.18

    /// Squared-sine falloff over a floor — breathes, never strobes.
    static func brightness(now: Double, speed: Float, phase: Float,
                           floor: Float = opacityFloor) -> Float {
        let s = sin(Float(now) * speed * 2 * .pi + phase)
        let lit = max(0, s)
        return floor + (1 - floor) * lit * lit
    }

    var brightnessNow: (Double) -> Float { { Self.brightness(now: $0, speed: blinkSpeed, phase: phase) } }

    /// Lazy 3-axis wander around home.
    func position(now: Double) -> SIMD3<Float> {
        home + SIMD3<Float>(Float(sin(now * 0.21 + Double(wanderSeed))) * 0.35,
                            Float(sin(now * 0.16 + Double(wanderSeed) * 2)) * 0.25,
                            Float(sin(now * 0.13 + Double(wanderSeed) * 3)) * 0.30)
    }

    /// Scale swells with the blink.
    func scale(now: Double) -> Float {
        0.85 + 0.4 * Self.brightness(now: now, speed: blinkSpeed, phase: phase)
    }

    static func flock(count: Int, rng: inout GardenSeededRandom) -> [FireflySpec] {
        (0..<count).map { _ in
            FireflySpec(home: SIMD3<Float>(Float(rng.range(-2.2, 2.2)),
                                           Float(rng.range(0.8, 3.4)),
                                           Float(rng.range(-1.0, 2.0))),
                        blinkSpeed: Float(rng.range(0.5, 1.4)),
                        phase: Float(rng.range(0, .pi * 2)),
                        wanderSeed: Float(rng.range(0, 40)))
        }
    }
}
