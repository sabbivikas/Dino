//
//  GardenSceneView.swift
//  Dino
//
//  SwiftUI wrapper around SCNView for the living 3D garden. Reads growth
//  stage and care state (passed in as plain values — the scene never
//  writes back). Scene is built once and cached; renderer and the motion
//  manager pause on disappear and resume on appear.
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

private func sunflowerStage(for stage: GrowthStage) -> SunflowerNode.Stage {
    switch stage {
    case .seed, .cracking:      return .seedMound
    case .sprout, .seedling:    return .sprout
    case .growing:              return .stemWithLeaves
    case .budding, .opening:    return .bud
    case .bloomed, .thriving:   return .fullBloom
    }
}

/// Care → (droop degrees, saturation). Mirrors the intent of GrowthView's
/// CareParams table without touching it.
private func careLook(for state: CareState) -> (droop: Double, saturation: CGFloat) {
    switch state {
    case .healthy:    return (0, 1.0)
    case .tired:      return (4, 0.9)
    case .struggling: return (12, 0.8)
    case .wilting:    return (22, 0.7)
    case .dying:      return (38, 0.55)
    case .dead:       return (70, 0.4)
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
        applyState(view: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        // Rebuild only if the reduce-motion mode changed since the cache was built.
        let handle = GardenSceneCache.handle(reduceMotion: reduceMotion)
        if view.scene !== handle.scene {
            view.scene = handle.scene
            context.coordinator.handle = handle
        }
        applyState(view: view, coordinator: context.coordinator)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.parallax.stop()
        view.isPlaying = false
    }

    private func applyState(view: SCNView, coordinator: Coordinator) {
        guard let handle = coordinator.handle else { return }

        // Sunflower stage + care look.
        let look = careLook(for: careState)
        let sway = !reduceMotion && (careState == .healthy || careState == .tired)
        handle.sunflower.apply(
            stage: sunflowerStage(for: stage),
            droopDegrees: look.droop,
            saturation: look.saturation,
            sway: sway
        )

        // Time-of-day lighting from the device clock.
        let hour = Calendar.current.component(.hour, from: Date())
        let period = GardenLighting.Period.current(hour: hour)
        GardenLighting.apply(period: period, rig: handle.rig, scene: handle.scene)

        // Particles: night fireflies / day pollen; none under reduce-motion.
        handle.particleAnchor.removeAllParticleSystems()
        if !reduceMotion && isActive {
            switch period {
            case .night:
                handle.particleAnchor.addParticleSystem(GardenParticles.fireflies())
            case .morning, .midday, .evening:
                handle.particleAnchor.addParticleSystem(GardenParticles.pollen())
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
        let parallax = GardenParallaxController()

        deinit {
            parallax.stop()
        }
    }
}
