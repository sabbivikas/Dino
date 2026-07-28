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
        view.isUserInteractionEnabled = false

        // TRANSPARENT COMPOSITING (owner fix #1): the SCNView must sit directly
        // on the space backdrop with zero visible container edge — no opaque
        // black rectangle. SceneKit needs all three: a clear view background, a
        // non-opaque layer, and a clear SCENE background (the scene background
        // is what was rendering as the black box).
        view.backgroundColor = .clear
        view.isOpaque = false

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        view.scene = scene

        // Camera: straight-on perspective, star at origin. Pulled in close so
        // the star at its natural scale (1.0) reads as the large centerpiece of
        // the top area (owner fix #3) — the glow shells overflow into the now
        // transparent bounds instead of being clipped by a small host.
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 40
        cameraNode.position = SCNVector3(0, 0, 2.2)
        scene.rootNode.addChildNode(cameraNode)

        // A soft ambient so the star's own omni light isn't the only source.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 300
        scene.rootNode.addChildNode(ambient)

        let star = FindingsStar(reduceMotion: reduceMotion)
        star.position = Self.center
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
            view.scene?.rootNode.addChildNode(fresh)
            coord.star = fresh
            coord.builtForReduceMotion = reduceMotion
            coord.appliedState = nil
        }
        if coord.appliedState != state {
            applyState(state, coordinator: coord, animated: !reduceMotion)
            coord.appliedState = state
        }
        // Keep the render loop alive for every state that animates the star
        // (idle sway, the fly-away, the return streak); pause only when the
        // star is genuinely gone from the AWAY sky.
        view.isPlaying = !reduceMotion && state != .away
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        view.scene = nil
        coordinator.star = nil
    }

    private static let center = SCNVector3(0, 0, 0)
    // Off-screen exit for the fly-away: up and to the right, out of view.
    private static let offFrame = SCNVector3(2.8, 3.4, -1.0)
    // Far, tiny, high start for the return streak: distant and deep so it
    // reads as coming back from a long way off.
    private static let farStart = SCNVector3(-2.8, 3.6, -7.0)

    private func applyState(_ state: FindingsStarState, coordinator: Coordinator, animated: Bool) {
        guard let star = coordinator.star else { return }
        switch state {
        case .idle:
            // Resume the calm hover — reset any flight transform.
            star.removeAllActions()
            star.isHidden = false
            star.position = Self.center
            star.scale = SCNVector3(1, 1, 1)
            star.opacity = 1
        case .back:
            // RETURN (owner fix #7): streak in from far, grow along an arc,
            // settle with an overshoot bounce + sparkle burst. Reduce Motion
            // handled inside streakIn (a simple fade-in, no streak).
            star.streakIn(from: Self.farStart, to: Self.center, reduceMotion: reduceMotion)
        case .sending:
            // LAUNCH (owner fix #5): gather (inhale + glow tighten), then arc
            // away off-screen with the trail spiked. Reduce Motion → fade.
            star.flyAway(to: Self.offFrame, reduceMotion: reduceMotion) { }
        case .away:
            // AWAY (owner fix #6): the star is fully gone from the scene, not
            // dimmed. The caller keeps the sky alive with the lonely mote.
            star.isHidden = true
            star.opacity = 0
            star.position = Self.offFrame
        }
    }

    final class Coordinator {
        var star: FindingsStar?
        var appliedState: FindingsStarState?
        var builtForReduceMotion: Bool = false
    }
}
