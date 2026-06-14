//
//  GardenSceneView.swift
//  Dino
//
//  Option 3 window: illustrated gradient sky behind the 3D hero sunflower.
//  Fixed camera — no pan, no gyro. Reads growth stage and care state from
//  GrowthViewModel as plain values (never writes back); all 5 stages, all
//  health states, and the watering-recovery animation are preserved.
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
    case .day: return 0
    case .lateAfternoon: return 0.6
    case .sunset, .dusk: return 1
    case .night: return 0
    }
}

/// Cloud tint per period: bright white by day, warm near the sun's edges,
/// dim blue-grey at dusk/night.
private func cloudTint(for period: GardenLighting.Period) -> UIColor {
    switch period {
    case .morning, .day:           return UIColor.white
    case .dawn, .lateAfternoon:    return UIColor(hexRGB: 0xFFE0C0)
    case .sunset:                  return UIColor(hexRGB: 0xFFC8A0)
    case .dusk, .night:            return UIColor(hexRGB: 0x9AA6C0)
    }
}

/// Birds fly in the brighter daytime periods only — hidden by dusk.
private func birdsVisible(for period: GardenLighting.Period) -> Bool {
    switch period {
    case .dawn, .morning, .day: return true
    case .lateAfternoon, .sunset, .dusk, .night: return false
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
        view.isJitteringEnabled = false
        view.rendersContinuously = false
        view.allowsCameraControl = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        context.coordinator.handle = handle
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
        view.isPlaying = false
    }

    private func applyState(view: SCNView, coordinator: Coordinator, animatedCare: Bool) {
        guard let handle = coordinator.handle else { return }

        let visualStage = sunflowerStage(for: stage)
        let look = careLook(for: careState)
        // reduceMotion → static, well-lit day frame (health still visible).
        let period: GardenLighting.Period = reduceMotion
            ? .day
            : GardenLighting.Period.current(
                hour: Calendar.current.component(.hour, from: Date())
              )
        let sway = !reduceMotion && (careState == .healthy || careState == .tired)

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

        let periodChanged = coordinator.lastPeriod != period
        GardenLighting.apply(
            period: period, rig: handle.rig, scene: handle.scene,
            animated: animatedCare && !reduceMotion && periodChanged
        )

        // Tint the cloud nodes + fade the birds for the time of day.
        let tint = cloudTint(for: period)
        let birdsOn = birdsVisible(for: period)
        let applyVisuals = {
            for m in handle.cloudMaterials { m.diffuse.contents = tint }
            handle.birdGroup.opacity = birdsOn ? 1 : 0
        }
        if animatedCare && !reduceMotion && periodChanged {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 3.0
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            applyVisuals()
            SCNTransaction.commit()
        } else {
            applyVisuals()
        }
        coordinator.lastPeriod = period

        // Period particles in the 3D layer (none under reduce-motion).
        if coordinator.lastParticlePeriod != period || reduceMotion {
            handle.particleAnchor.removeAllParticleSystems()
            if !reduceMotion {
                switch period {
                case .dawn, .morning, .day:
                    handle.particleAnchor.addParticleSystem(GardenParticles.pollen())
                case .sunset:
                    handle.particleAnchor.addParticleSystem(GardenParticles.petals())
                case .dusk, .night:
                    handle.particleAnchor.addParticleSystem(GardenParticles.fireflies())
                case .lateAfternoon:
                    break
                }
            }
            coordinator.lastParticlePeriod = period
        }

        view.isPlaying = isActive && !reduceMotion
    }

    final class Coordinator {
        var handle: GardenSceneHandle?
        var lastCareState: CareState?
        var lastPeriod: GardenLighting.Period?
        var lastParticlePeriod: GardenLighting.Period?
    }
}
