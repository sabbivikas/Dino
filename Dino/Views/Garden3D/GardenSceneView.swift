//
//  GardenSceneView.swift
//  Dino
//
//  SwiftUI window into the explorable garden world. Reads growth stage and
//  care state as plain values (never writes back). Pan to explore (with
//  momentum and soft world boundaries), double-tap or the compass button
//  to spring home to the sunflower. Regions populate lazily as the camera
//  approaches — and only once the plant has grown enough to earn them.
//

import SwiftUI
import SceneKit
import Combine

// MARK: - Scene cache (build once per process / reduce-motion mode)

enum GardenSceneCache {
    private static var cached: GardenSceneHandle?

    @MainActor
    static func handle(reduceMotion: Bool) -> GardenSceneHandle {
        if let cached, cached.builtForReduceMotion == reduceMotion {
            return cached
        }
        let fresh = GardenSceneBuilder.build(reduceMotion: reduceMotion)
        cached = fresh
        return fresh
    }
}

// MARK: - Camera bridge (SwiftUI button → coordinator)

final class GardenCameraBridge: ObservableObject {
    var recenter: (() -> Void)?
}

// MARK: - Public SwiftUI view

struct GardenSceneView: View {
    let stage: GrowthStage
    let careState: CareState
    let reduceMotion: Bool

    @State private var isActive: Bool = false
    @StateObject private var bridge = GardenCameraBridge()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GardenSceneRepresentable(
                stage: stage,
                careState: careState,
                reduceMotion: reduceMotion,
                isActive: isActive,
                bridge: bridge
            )

            Button {
                bridge.recenter?()
            } label: {
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.85), .black.opacity(0.25))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .accessibilityLabel("return to sunflower")
            .padding(12)
        }
        .onAppear { isActive = true }
        .onDisappear { isActive = false }
    }
}

// MARK: - Growth / care mapping (read-only translation of VM state)

/// All NINE GrowthViewModel stages map here — exhaustively, so a future
/// tenth case is a compile error, never a silent fallback.
private func sunflowerStage(for stage: GrowthStage) -> SunflowerNode.Stage {
    switch stage {
    case .seed, .cracking:      return .seedMound
    case .sprout, .seedling:    return .sprout
    case .growing:              return .stemWithLeaves
    case .budding, .opening:    return .bud
    case .bloomed, .thriving:   return .fullBloom
    }
}

/// Which world regions exist at each visual stage — the world grows with
/// the plant. Seed: empty horizons. Full bloom: everything.
private func allowedRegions(for stage: SunflowerNode.Stage) -> Set<GardenRegion> {
    switch stage {
    case .seedMound:      return []
    case .sprout:         return [.pond]
    case .stemWithLeaves: return [.pond, .meadow]
    case .bud:            return [.pond, .meadow, .orchard]
    case .fullBloom:      return [.pond, .meadow, .orchard, .forest]
    }
}

/// Care → (droop°, saturation, soil dryness). The droop and saturation
/// columns are the OLD GardenPanel CareParams numbers exactly. Thresholds
/// (daysSince → CareState) live in GrowthViewModel, inherited by construction.
private func careLook(for state: CareState) -> (droop: Double, saturation: CGFloat, dryness: CGFloat) {
    switch state {
    case .healthy:    return (0,  1.0,  0.0)
    case .tired:      return (4,  0.9,  0.15)
    case .struggling: return (15, 0.8,  0.4)
    case .wilting:    return (30, 0.7,  0.7)
    case .dying:      return (50, 0.55, 0.9)
    case .dead:       return (85, 0.4,  1.0)
    }
}

private func careRank(_ state: CareState) -> Int {
    switch state {
    case .healthy: return 0
    case .tired: return 1
    case .struggling: return 2
    case .wilting: return 3
    case .dying: return 4
    case .dead: return 5
    }
}

/// Heliotropism: -1 morning (head east) … 0 noon … +1 evening (head west).
private func heliotropism(for period: GardenLighting.Period) -> Float {
    switch period {
    case .dawn, .morning: return -1
    case .midday: return 0
    case .lateAfternoon: return 0.6
    case .sunset, .dusk: return 1
    case .night: return 0
    }
}

// MARK: - UIViewRepresentable

private struct GardenSceneRepresentable: UIViewRepresentable {
    let stage: GrowthStage
    let careState: CareState
    let reduceMotion: Bool
    let isActive: Bool
    let bridge: GardenCameraBridge

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let handle = GardenSceneCache.handle(reduceMotion: reduceMotion)

        view.scene = handle.scene
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling2X
        view.isJitteringEnabled = false
        view.rendersContinuously = false
        view.allowsCameraControl = false
        view.backgroundColor = .clear

        let coordinator = context.coordinator
        coordinator.handle = handle
        coordinator.reduceMotion = reduceMotion

        // Pan to explore. Double-tap to come home.
        let pan = UIPanGestureRecognizer(target: coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        coordinator.panGesture = pan

        let doubleTap = UITapGestureRecognizer(target: coordinator,
                                               action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        bridge.recenter = { [weak coordinator] in
            coordinator?.springHome()
        }

        applyState(view: view, coordinator: coordinator, animatedCare: false)
        coordinator.refreshWorld()
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let handle = GardenSceneCache.handle(reduceMotion: reduceMotion)
        if view.scene !== handle.scene {
            view.scene = handle.scene
            context.coordinator.handle = handle
            context.coordinator.lastCareState = nil
        }
        applyState(view: view, coordinator: context.coordinator, animatedCare: true)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.stopMomentum()
        coordinator.panGesture?.isEnabled = false
        view.isPlaying = false
    }

    private func applyState(view: SCNView, coordinator: Coordinator, animatedCare: Bool) {
        guard let handle = coordinator.handle else { return }

        let visualStage = sunflowerStage(for: stage)
        let look = careLook(for: careState)
        // reduceMotion → static well-lit noon scene (health still visible).
        let period: GardenLighting.Period = reduceMotion
            ? .midday
            : GardenLighting.Period.current(
                hour: Calendar.current.component(.hour, from: Date())
              )
        let sway = !reduceMotion && (careState == .healthy || careState == .tired)
        let isBloom = (visualStage == .fullBloom)

        var recovering = false
        if let last = coordinator.lastCareState, careRank(careState) < careRank(last) {
            recovering = true
        }
        let animateThisApply = animatedCare && !reduceMotion &&
            (recovering || coordinator.lastCareState != careState)

        handle.sunflower.apply(
            stage: visualStage,
            droopDegrees: look.droop,
            saturation: look.saturation,
            soilDryness: look.dryness,
            heliotropism: heliotropism(for: period),
            sway: sway,
            animated: animateThisApply
        )

        if recovering && !reduceMotion {
            let droplets = GardenParticles.waterDroplets()
            let sparkle = GardenParticles.recoveryBurst()
            handle.sunflower.addParticleSystem(droplets)
            handle.sunflower.addParticleSystem(sparkle)
            handle.sunflower.runAction(.sequence([
                .wait(duration: 2.5),
                .run { node in
                    node.removeParticleSystem(droplets)
                    node.removeParticleSystem(sparkle)
                }
            ]))
        }
        coordinator.lastCareState = careState

        GardenLighting.apply(
            period: period, rig: handle.rig, scene: handle.scene,
            animated: animatedCare && !reduceMotion && coordinator.lastPeriod != period
        )
        coordinator.lastPeriod = period

        // Creature visibility: bees + butterflies need the bloom and daylight;
        // fireflies own the night; birds vary through the day. All hidden
        // under reduce-motion (static scene), per spec.
        let daylight: Set<GardenLighting.Period> = [.dawn, .morning, .midday, .lateAfternoon]
        handle.beeGroup.isHidden = !(isBloom && daylight.contains(period) && !reduceMotion)
        handle.butterflyGroup.isHidden = !(isBloom && daylight.contains(period) && !reduceMotion)
        handle.fireflyGroup.isHidden = !((period == .night || period == .dusk) && !reduceMotion)
        handle.morningBirds.isHidden = !((period == .dawn || period == .morning) && !reduceMotion)
        handle.middayBird.isHidden = !((period == .midday || period == .lateAfternoon) && !reduceMotion)
        handle.sunsetFormation.isHidden = !(period == .sunset && !reduceMotion)

        // World gating by growth + camera proximity.
        coordinator.allowed = allowedRegions(for: visualStage)
        coordinator.refreshWorld()

        // Renderer + gestures lifecycle. Pan stays enabled under reduce-motion
        // (exploration must remain accessible) — the scene still re-renders
        // on camera change even with isPlaying false.
        view.isPlaying = isActive && !reduceMotion
        coordinator.panGesture?.isEnabled = isActive
        if !isActive {
            coordinator.stopMomentum()
        }
    }

    // MARK: - Coordinator: pan, momentum, boundaries, home, lazy world

    final class Coordinator: NSObject {
        var handle: GardenSceneHandle?
        var lastCareState: CareState?
        var lastPeriod: GardenLighting.Period?
        var reduceMotion = false
        var allowed: Set<GardenRegion> = []
        weak var panGesture: UIPanGestureRecognizer?

        private var displayLink: CADisplayLink?
        private var velocity = SIMD2<Float>(0, 0)   // world units per frame
        private let sensitivity: Float = 0.015
        private let homeKey = "garden.home"

        deinit {
            displayLink?.invalidate()
        }

        // MARK: Pan

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let handle else { return }
            switch gesture.state {
            case .began:
                stopMomentum()
                handle.cameraRig.removeAction(forKey: homeKey)
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                gesture.setTranslation(.zero, in: gesture.view)
                move(dx: Float(-translation.x) * sensitivity,
                     dz: Float(-translation.y) * sensitivity)
            case .ended, .cancelled:
                let v = gesture.velocity(in: gesture.view)
                velocity = SIMD2(Float(-v.x) * sensitivity / 30.0,
                                 Float(-v.y) * sensitivity / 30.0)
                startMomentum()
            default:
                break
            }
        }

        private func move(dx: Float, dz: Float) {
            guard let handle else { return }
            var p = handle.cameraRig.position
            p.x = softClamp(p.x + dx)
            p.z = softClamp(p.z + dz)
            handle.cameraRig.position = p
            refreshWorld()
        }

        /// Soft boundary: resistance grows over the last 3 units; hard clamp ±18.
        private func softClamp(_ value: Float) -> Float {
            let hard = GardenSceneBuilder.worldHalf
            let soft = hard - GardenSceneBuilder.softEdge
            let magnitude = abs(value)
            guard magnitude > soft else { return value }
            let over = min(magnitude - soft, GardenSceneBuilder.softEdge * 2)
            let resisted = soft + over * (1 - over / (4 * GardenSceneBuilder.softEdge))
            let clamped = min(resisted, hard)
            return value > 0 ? clamped : -clamped
        }

        // MARK: Momentum

        private func startMomentum() {
            guard simd_length(velocity) > 0.001 else { return }
            displayLink?.invalidate()
            let link = CADisplayLink(target: self, selector: #selector(momentumTick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func momentumTick() {
            move(dx: velocity.x, dz: velocity.y)
            velocity *= 0.92
            if simd_length(velocity) < 0.001 {
                stopMomentum()
            }
        }

        func stopMomentum() {
            displayLink?.invalidate()
            displayLink = nil
            velocity = .zero
        }

        // MARK: Home

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            springHome()
        }

        func springHome() {
            guard let handle else { return }
            stopMomentum()
            handle.cameraRig.removeAction(forKey: homeKey)
            if reduceMotion {
                handle.cameraRig.position = SCNVector3Zero
                refreshWorld()
                return
            }
            let home = SCNAction.move(to: SCNVector3Zero, duration: 0.8)
            home.timingMode = .easeInEaseOut
            handle.cameraRig.runAction(.sequence([
                home,
                .run { [weak self] _ in
                    DispatchQueue.main.async { self?.refreshWorld() }
                }
            ]), forKey: homeKey)
        }

        // MARK: Lazy world population + creature activity gating

        func refreshWorld() {
            guard let handle else { return }
            let cam = handle.cameraRig.position

            for region in GardenRegion.allCases {
                guard let anchor = handle.regionAnchors[region] else { continue }
                let isAllowed = allowed.contains(region)
                anchor.isHidden = !isAllowed && handle.populatedRegions.contains(region)

                let dx = cam.x - region.center.x
                let dz = cam.z - region.center.z
                let distance = sqrt(dx * dx + dz * dz)

                // Populate once when allowed and the camera comes within 15.
                if isAllowed && !handle.populatedRegions.contains(region) && distance < 15 {
                    GardenSceneBuilder.populate(region: region, into: anchor,
                                                reduceMotion: reduceMotion)
                    handle.populatedRegions.insert(region)
                    anchor.isHidden = false
                }

                // Activity gating: pause creature/idle actions beyond 12 units.
                if handle.populatedRegions.contains(region) {
                    anchor.isPaused = distance > 12
                }
            }
        }
    }
}
