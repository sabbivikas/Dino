//
//  FindingsStarHostView.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo. A small SCNView host for the FindingsStar,
//  following the app's SceneKit patterns (OnboardingWorldView: 30fps,
//  rendersContinuously false, transparent background, no camera control). The
//  star is centered and hovering; the four states drive it:
//    • idle    — star hovering, sway/blink (the copied class's idle life)
//    • sending — glide off-frame up-right + fade out
//    • away    — no star (it is out looking); the caller shows the caption
//    • back    — star returns via glide-in when a result lands
//  Reduce Motion follows the copied class's reduceMotion param; state
//  transitions fall back to opacity (no glide) when motion is reduced.
//
//  English-only demo (owner decision): plain string literals only.
//

import SwiftUI
import SceneKit

enum FindingsStarState: Equatable { case idle, sending, away, back }

struct FindingsStarHostView: View {
    let state: FindingsStarState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FindingsStarRepresentable(state: state, reduceMotion: reduceMotion)
            .allowsHitTesting(false)
    }
}

private struct FindingsStarRepresentable: UIViewRepresentable {
    let state: FindingsStarState
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = false
        view.allowsCameraControl = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        let scene = SCNScene()
        view.scene = scene

        // Camera: straight-on perspective, star at origin.
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 40
        cameraNode.position = SCNVector3(0, 0, 6)
        scene.rootNode.addChildNode(cameraNode)

        // A soft ambient so the star's own omni light isn't the only source.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 300
        scene.rootNode.addChildNode(ambient)

        let star = FindingsStar(reduceMotion: reduceMotion)
        star.position = Self.center
        star.scale = SCNVector3(2.0, 2.0, 2.0)   // fill the small host nicely
        scene.rootNode.addChildNode(star)

        context.coordinator.star = star
        context.coordinator.appliedState = .idle
        context.coordinator.builtForReduceMotion = reduceMotion
        applyState(state, coordinator: context.coordinator, animated: false)
        view.isPlaying = !reduceMotion
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coord = context.coordinator
        // Rebuild the star only if reduce-motion flipped (rare).
        if coord.builtForReduceMotion != reduceMotion, let old = coord.star {
            old.removeFromParentNode()
            let fresh = FindingsStar(reduceMotion: reduceMotion)
            fresh.position = Self.center
            fresh.scale = SCNVector3(2.0, 2.0, 2.0)
            view.scene?.rootNode.addChildNode(fresh)
            coord.star = fresh
            coord.builtForReduceMotion = reduceMotion
            coord.appliedState = nil
        }
        if coord.appliedState != state {
            applyState(state, coordinator: coord, animated: !reduceMotion)
            coord.appliedState = state
        }
        view.isPlaying = !reduceMotion && (state == .idle || state == .back)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        view.scene = nil
        coordinator.star = nil
    }

    private static let center = SCNVector3(0, 0, 0)
    private static let offFrame = SCNVector3(3.2, 3.0, -1.0)   // up-right, out of view

    private func applyState(_ state: FindingsStarState, coordinator: Coordinator, animated: Bool) {
        guard let star = coordinator.star else { return }
        switch state {
        case .idle, .back:
            if state == .back {
                // return via glide-in: start off-frame + faded, then glide home.
                star.position = Self.offFrame
                star.opacity = reduceMotion ? 1 : 0
                if reduceMotion {
                    star.position = Self.center
                    fade(star, to: 1)
                } else {
                    fade(star, to: 1)
                    star.glide(to: Self.center, duration: 0.9)
                }
            } else {
                star.position = Self.center
                star.opacity = 1
            }
        case .sending:
            // glide off-frame up-right + fade out.
            if reduceMotion {
                fade(star, to: 0)
            } else {
                star.glide(to: Self.offFrame, duration: 0.8)
                fade(star, to: 0)
            }
        case .away:
            // the star is out looking — hidden entirely.
            star.opacity = 0
            star.position = Self.offFrame
        }
    }

    private func fade(_ node: SCNNode, to opacity: CGFloat) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0.3 : 0.7
        node.opacity = opacity
        SCNTransaction.commit()
    }

    final class Coordinator {
        var star: FindingsStar?
        var appliedState: FindingsStarState?
        var builtForReduceMotion: Bool = false
    }
}
