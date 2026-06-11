//
//  AmbientWorldView.swift
//  Dino
//
//  SwiftUI window into the ambient waterfall world. Renders the cached
//  SceneKit diorama, applies day/night, runs period particles, and reports
//  the lily pad's projected screen position so the SwiftUI tap zone can
//  sit exactly over the 3D pad.
//

import SwiftUI
import SceneKit

enum AmbientSceneCache {
    private static var cached: AmbientSceneHandle?

    @MainActor
    static func handle(reduceMotion: Bool) -> AmbientSceneHandle {
        if let cached, cached.builtForReduceMotion == reduceMotion {
            return cached
        }
        let fresh = AmbientSceneBuilder.build(reduceMotion: reduceMotion)
        cached = fresh
        return fresh
    }
}

struct AmbientWorldView: View {
    let isNight: Bool
    var onLilyPadPosition: ((CGPoint) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isActive: Bool = false

    var body: some View {
        AmbientWorldRepresentable(
            isNight: isNight,
            reduceMotion: reduceMotion,
            isActive: isActive,
            onLilyPadPosition: onLilyPadPosition
        )
        .onAppear { isActive = true }
        .onDisappear { isActive = false }
    }
}

private struct AmbientWorldRepresentable: UIViewRepresentable {
    let isNight: Bool
    let reduceMotion: Bool
    let isActive: Bool
    let onLilyPadPosition: ((CGPoint) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let handle = AmbientSceneCache.handle(reduceMotion: reduceMotion)

        view.scene = handle.scene
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = false
        view.allowsCameraControl = false
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false   // taps handled by SwiftUI overlays

        context.coordinator.handle = handle
        apply(view: view, coordinator: context.coordinator, animated: false)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        apply(view: view, coordinator: context.coordinator, animated: true)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
    }

    private func apply(view: SCNView, coordinator: Coordinator, animated: Bool) {
        guard let handle = coordinator.handle else { return }

        if coordinator.lastIsNight != isNight {
            AmbientLighting.apply(
                isNight: isNight, rig: handle.rig, scene: handle.scene,
                treeMaterials: handle.treeMaterials,
                animated: animated && !reduceMotion && coordinator.lastIsNight != nil
            )
            handle.waterfall.setNight(isNight)

            // Period particles in the 3D layer.
            handle.particleAnchor.removeAllParticleSystems()
            if !reduceMotion {
                if isNight {
                    handle.particleAnchor.addParticleSystem(AmbientParticles.fireflies())
                    handle.particleAnchor.addParticleSystem(AmbientParticles.mist())
                } else {
                    handle.particleAnchor.addParticleSystem(AmbientParticles.pollen())
                }
            }
            coordinator.lastIsNight = isNight
        }

        // Renderer runs while visible; waterfall flow is the point of this
        // screen. reduceMotion builds a static scene (no shaders/particles),
        // so pausing play there keeps it a still, lit frame.
        view.isPlaying = isActive && !reduceMotion

        // Report the lily pad's screen position once the view has real bounds.
        let size = view.bounds.size
        if size.width > 1, size.height > 1, coordinator.lastProjectedSize != size {
            coordinator.lastProjectedSize = size
            let worldPos = handle.lilyPad.worldPosition
            let callback = onLilyPadPosition
            DispatchQueue.main.async { [weak view] in
                guard let view, view.bounds.size == size else { return }
                let projected = view.projectPoint(worldPos)
                callback?(CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y)))
            }
        }
    }

    final class Coordinator {
        var handle: AmbientSceneHandle?
        var lastIsNight: Bool?
        var lastProjectedSize: CGSize = .zero
    }
}
