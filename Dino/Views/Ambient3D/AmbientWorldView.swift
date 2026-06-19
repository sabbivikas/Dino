//
//  AmbientWorldView.swift
//  Dino
//
//  SwiftUI window into the ambient waterfall world. Self-drives the time-of-
//  day period from the device clock (re-checked every 60s, timer invalidated
//  on disappear, 4s crossfade), runs night fireflies/mist, and reports the
//  lily-pad screen position so the SwiftUI tap zone sits over the painted pad.
//  `forcedPeriod` pins the period (used by the forest-letter backdrop).
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
    var forcedPeriod: AmbientPeriod? = nil
    var onLilyPadPosition: ((CGPoint) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isActive = false
    @State private var period: AmbientPeriod = AmbientPeriod.current(
        hour: Calendar.current.component(.hour, from: Date()))
    @State private var clock: Timer?

    private var activePeriod: AmbientPeriod { forcedPeriod ?? period }

    var body: some View {
        AmbientWorldRepresentable(
            period: activePeriod,
            reduceMotion: reduceMotion,
            isActive: isActive,
            onLilyPadPosition: onLilyPadPosition
        )
        .onAppear {
            isActive = true
            if forcedPeriod == nil {
                period = AmbientPeriod.current(hour: Calendar.current.component(.hour, from: Date()))
                let t = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    period = AmbientPeriod.current(hour: Calendar.current.component(.hour, from: Date()))
                }
                clock = t
            }
        }
        .onDisappear {
            isActive = false
            clock?.invalidate()
            clock = nil
        }
    }
}

private struct AmbientWorldRepresentable: UIViewRepresentable {
    let period: AmbientPeriod
    let reduceMotion: Bool
    let isActive: Bool
    let onLilyPadPosition: ((CGPoint) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

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

        if coordinator.lastPeriod != period {
            AmbientLighting.apply(
                period: period, scene: handle.scene,
                animated: animated && !reduceMotion && coordinator.lastPeriod != nil
            )
            handle.waterfall.setPeriod(isNight: period.isNight)
            for f in handle.fish { f.setPeriod(isNight: period.isNight) }

            // Night life: round fireflies + mist over the pool.
            handle.particleAnchor.removeAllParticleSystems()
            if !reduceMotion && period.isNight {
                handle.particleAnchor.addParticleSystem(AmbientParticles.fireflies())
                handle.particleAnchor.addParticleSystem(AmbientParticles.mist())
            }
            coordinator.lastPeriod = period
        }

        view.isPlaying = isActive && !reduceMotion

        // Report the lily marker's screen position once bounds are real.
        let size = view.bounds.size
        if size.width > 1, size.height > 1, coordinator.lastProjectedSize != size {
            coordinator.lastProjectedSize = size
            let worldPos = handle.lilyMarker.worldPosition
            let callback = onLilyPadPosition
            DispatchQueue.main.async { [weak view] in
                guard let view, view.bounds.size == size else { return }
                let p = view.projectPoint(worldPos)
                callback?(CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
            }
        }
    }

    final class Coordinator {
        var handle: AmbientSceneHandle?
        var lastPeriod: AmbientPeriod?
        var lastProjectedSize: CGSize = .zero
    }
}
