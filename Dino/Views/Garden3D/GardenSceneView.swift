//
//  GardenSceneView.swift
//  Dino
//
//  SwiftUI wrapper for the illustrated 3D garden. Reads growth stage and
//  care state as plain values (the scene never writes back). The nine
//  GrowthStage cases map exhaustively to five visual stages; care look
//  uses the OLD GardenPanel's exact CareParams numbers. Watering recovery
//  animates over 1.5s with a golden sparkle burst. Scene built once and
//  cached; renderer + gyro pause on disappear.
//

import SwiftUI
import SceneKit

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

// MARK: - Public SwiftUI view

struct GardenSceneView: View {
    let stage: GrowthStage
    let careState: CareState
    let reduceMotion: Bool

    @State private var isActive: Bool = false

    var body: some View {
        GardenSceneRepresentable(
            stage: stage,
            careState: careState,
            reduceMotion: reduceMotion,
            isActive: isActive
        )
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

/// Care → (droop°, saturation, soil dryness). The droop and saturation
/// columns are the OLD GardenPanel CareParams numbers exactly — the
/// functional reference. Thresholds (daysSince → CareState) live in
/// GrowthViewModel and are inherited by construction.
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

/// Care ranking used to detect recovery (watering after neglect).
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

// MARK: - UIViewRepresentable

private struct GardenSceneRepresentable: UIViewRepresentable {
    let stage: GrowthStage
    let careState: CareState
    let reduceMotion: Bool
    let isActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let handle = GardenSceneCache.handle(reduceMotion: reduceMotion)

        view.scene = handle.scene
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = false
        view.allowsCameraControl = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        context.coordinator.handle = handle

        // Appear pop — parity with the old GardenPanel's spring scale-in.
        if reduceMotion {
            handle.sunflower.scale = SCNVector3(1, 1, 1)
        } else {
            handle.sunflower.scale = SCNVector3(0.01, 0.01, 0.01)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.8
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(
                controlPoints: 0.34, 1.45, 0.64, 1.0   // soft overshoot ≈ spring
            )
            handle.sunflower.scale = SCNVector3(1, 1, 1)
            SCNTransaction.commit()
        }

        applyState(view: view, coordinator: context.coordinator, animatedCare: false)
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
        coordinator.parallax.stop()
        view.isPlaying = false
    }

    private func applyState(view: SCNView, coordinator: Coordinator, animatedCare: Bool) {
        guard let handle = coordinator.handle else { return }

        let look = careLook(for: careState)
        let period = GardenLighting.Period.current(
            hour: Calendar.current.component(.hour, from: Date())
        )
        let sway = !reduceMotion && (careState == .healthy || careState == .tired)
        let isBloom = (stage == .bloomed || stage == .thriving)
        let showBees = isBloom && (period == .day || period == .morning) && !reduceMotion

        // Recovery detection: care improved since last application → animate
        // upright + re-saturate over 1.5s and fire the golden sparkle burst.
        var recovering = false
        if let last = coordinator.lastCareState,
           careRank(careState) < careRank(last) {
            recovering = true
        }
        let animateThisApply = animatedCare && !reduceMotion &&
            (recovering || coordinator.lastCareState != careState)

        handle.sunflower.apply(
            stage: sunflowerStage(for: stage),
            droopDegrees: look.droop,
            saturation: look.saturation,
            soilDryness: look.dryness,
            sway: sway,
            showBees: showBees,
            animated: animateThisApply
        )
        handle.sunflower.setBeesAnimating(showBees)

        if recovering && !reduceMotion {
            let burst = GardenParticles.recoveryBurst()
            handle.sunflower.addParticleSystem(burst)
            handle.sunflower.runAction(.sequence([
                .wait(duration: 2.5),
                .run { node in node.removeParticleSystem(burst) }
            ]))
        }
        coordinator.lastCareState = careState

        // Time-of-day lighting + celestial/cloud/bird visibility.
        GardenLighting.apply(
            period: period, rig: handle.rig, scene: handle.scene,
            animated: animatedCare && !reduceMotion && coordinator.lastPeriod != period
        )
        coordinator.lastPeriod = period

        // Butterfly keeps the bloom company (day periods, motion allowed).
        handle.butterfly.isHidden = !(isBloom && !reduceMotion &&
                                      (period == .day || period == .morning))

        // Period particles (none under reduce-motion; day life is node-based).
        handle.particleAnchor.removeAllParticleSystems()
        if !reduceMotion && isActive {
            switch period {
            case .morning:
                handle.particleAnchor.addParticleSystem(GardenParticles.pollen())
            case .day:
                break   // butterflies + bees are nodes, not particles
            case .evening:
                handle.particleAnchor.addParticleSystem(GardenParticles.petals())
            case .night:
                handle.particleAnchor.addParticleSystem(GardenParticles.fireflies())
            }
        }

        // Renderer + parallax lifecycle.
        view.isPlaying = isActive && !reduceMotion
        if isActive && !reduceMotion {
            coordinator.parallax.start(pivot: handle.cameraPivot)
        } else {
            coordinator.parallax.stop()
        }
    }

    final class Coordinator {
        var handle: GardenSceneHandle?
        var lastCareState: CareState?
        var lastPeriod: GardenLighting.Period?
        let parallax = GardenParallaxController()

        deinit {
            parallax.stop()
        }
    }
}
