//
//  OnboardingWorldView.swift
//  Dino
//
//  SwiftUI wrapper for the 3D onboarding world. Takes the current step
//  index; step changes dolly the camera along CameraJourney (2s ease) and
//  crossfade the region lighting. Scene is built once per onboarding
//  session and held by the Coordinator — no statics — so everything
//  releases when onboarding is dismissed. Renderer + gyro pause on
//  disappear; reduce-motion gets static cuts with no particles or sway.
//

import SwiftUI
import SceneKit

struct OnboardingWorldView: View {
    let currentStep: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isActive: Bool = false

    var body: some View {
        OnboardingWorldRepresentable(
            currentStep: currentStep,
            reduceMotion: reduceMotion,
            isActive: isActive
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { isActive = true }
        .onDisappear { isActive = false }
    }
}

private struct OnboardingWorldRepresentable: UIViewRepresentable {
    let currentStep: Int
    let reduceMotion: Bool
    let isActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = false
        view.allowsCameraControl = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        let handle = WorldBuilder.build(reduceMotion: reduceMotion)
        view.scene = handle.scene
        context.coordinator.handle = handle

        // Land on the initial pose + grade without animation.
        let pose = CameraJourney.pose(for: currentStep)
        handle.cameraRig.position = pose.position
        handle.cameraRig.eulerAngles = CameraJourney.eulerLooking(
            from: pose.position, at: pose.lookAt
        )
        WorldLighting.apply(region: pose.region, rig: handle.rig,
                            scene: handle.scene, animated: false)
        context.coordinator.appliedStep = currentStep

        applyLifecycle(view: view, coordinator: context.coordinator)
        applyParticles(for: pose.region, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator

        // Rebuild only if reduce-motion flipped mid-session (rare).
        if let handle = coordinator.handle, handle.builtForReduceMotion != reduceMotion {
            coordinator.parallax.stop()
            let fresh = WorldBuilder.build(reduceMotion: reduceMotion)
            view.scene = fresh.scene
            coordinator.handle = fresh
            coordinator.appliedStep = nil
        }

        guard let handle = coordinator.handle else { return }

        if coordinator.appliedStep != currentStep {
            moveCamera(to: currentStep, view: view, handle: handle, coordinator: coordinator)
            coordinator.appliedStep = currentStep
        }

        applyLifecycle(view: view, coordinator: coordinator)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.parallax.stop()
        view.isPlaying = false
        view.scene = nil   // release the world with the view
        coordinator.handle = nil
    }

    // MARK: - Camera journey

    private func moveCamera(to step: Int, view: SCNView,
                            handle: WorldHandle, coordinator: Coordinator) {
        let pose = CameraJourney.pose(for: step)
        let euler = CameraJourney.eulerLooking(from: pose.position, at: pose.lookAt)
        let rig = handle.cameraRig

        rig.removeAction(forKey: "journey")

        if reduceMotion {
            // Static cut, no dolly.
            rig.position = pose.position
            rig.eulerAngles = euler
            WorldLighting.apply(region: pose.region, rig: handle.rig,
                                scene: handle.scene, animated: false)
            applyParticles(for: pose.region, coordinator: coordinator)
            return
        }

        // Bump to 60fps for the 2s dolly, then settle back to 30.
        view.preferredFramesPerSecond = 60
        coordinator.transitionGeneration &+= 1
        let generation = coordinator.transitionGeneration

        let move = SCNAction.move(to: pose.position, duration: CameraJourney.transitionDuration)
        move.timingMode = .easeInEaseOut
        let rotate = SCNAction.rotateTo(
            x: CGFloat(euler.x), y: CGFloat(euler.y), z: CGFloat(euler.z),
            duration: CameraJourney.transitionDuration,
            usesShortestUnitArc: true
        )
        rotate.timingMode = .easeInEaseOut

        rig.runAction(.group([move, rotate]), forKey: "journey") { [weak view, weak coordinator] in
            DispatchQueue.main.async {
                guard let view, let coordinator,
                      coordinator.transitionGeneration == generation else { return }
                view.preferredFramesPerSecond = 30
            }
        }

        WorldLighting.apply(region: pose.region, rig: handle.rig,
                            scene: handle.scene, animated: true)
        applyParticles(for: pose.region, coordinator: coordinator)
    }

    // MARK: - Region particles

    private func applyParticles(for region: WorldRegion, coordinator: Coordinator) {
        guard let handle = coordinator.handle else { return }
        for (_, anchor) in handle.regionAnchors {
            anchor.removeAllParticleSystems()
        }
        guard !reduceMotion else { return }

        switch region {
        case .meadow:
            handle.regionAnchors[.meadow]?.addParticleSystem(WorldParticles.pollen())
        case .pond:
            handle.regionAnchors[.pond]?.addParticleSystem(WorldParticles.dragonflies())
        case .grove:
            handle.regionAnchors[.grove]?.addParticleSystem(WorldParticles.motes())
        case .overlook:
            handle.regionAnchors[.overlook]?.addParticleSystem(WorldParticles.fireflies())
        }
    }

    // MARK: - Lifecycle (pause renderer + gyro off-screen)

    private func applyLifecycle(view: SCNView, coordinator: Coordinator) {
        guard let handle = coordinator.handle else { return }
        let shouldRun = isActive && !reduceMotion
        view.isPlaying = shouldRun
        if shouldRun {
            coordinator.parallax.start(pivot: handle.parallaxPivot)
        } else {
            coordinator.parallax.stop()
        }
    }

    final class Coordinator {
        var handle: WorldHandle?
        var appliedStep: Int?
        var transitionGeneration: UInt64 = 0
        let parallax = WorldParallaxController()

        deinit {
            parallax.stop()
        }
    }
}
