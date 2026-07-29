//
//  FindingsStarHostView.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo — the FULL-BLEED SceneKit layer.
//
//  THE BOX-KILL (owner: "it STILL renders inside a visible box"): the star and
//  the Earth now share ONE transparent SCNView that covers the ENTIRE screen,
//  layered over the SwiftUI space backdrop. Because the view fills the screen
//  and is transparent on every axis (view.backgroundColor .clear, isOpaque
//  false, scene.background .clear, and — the one that actually rendered as the
//  black rectangle — the view's CALayer backgroundColor cleared too), there is
//  NO frame edge anywhere on screen for a box to show at. The glow shells
//  overflow into transparent pixels instead of being clipped, so the halo can
//  never be cropped either. Positioning is done in SCENE coordinates: the star
//  rides a "rig" node that sits HIGH and large when no card is up, and drops
//  LOWER and smaller (with a clear gap under the card) when a finding is shown.
//
//  Hit-testing stays off the SCNView entirely (isUserInteractionEnabled false);
//  the tab owns a SwiftUI tap region over the star.
//
//  The copied D-844 idle motion (drift, breath, lean/sway, blink, twinkles) is
//  untouched; only the branch-owned flight choreography is driven per state.
//  Reduce Motion follows the copied class + stops the Earth spin.
//
//  English-only demo (owner decision): plain string literals only.
//

import SwiftUI
import SceneKit

enum FindingsStarState: Equatable { case idle, sending, away, landing }

struct FindingsStarHostView: View {
    let state: FindingsStarState
    /// When a finding card is up, the star drops lower + smaller so the card can
    /// own the upper screen with a clear gap between them.
    var cardPresented: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FindingsSceneRepresentable(state: state, cardPresented: cardPresented,
                                   reduceMotion: reduceMotion)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

private struct FindingsSceneRepresentable: UIViewRepresentable {
    let state: FindingsStarState
    let cardPresented: Bool
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.preferredFramesPerSecond = 30
        // MSAA can hand back a blank drawable for a transparent SCNView on the
        // simulator; the star draws reliably with it off. rendersContinuously
        // guarantees a frame is produced AFTER Auto Layout gives the view its
        // real bounds (a one-shot render can fire at size zero and never repeat).
        view.antialiasingMode = .none
        view.rendersContinuously = true
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false

        // TRANSPARENT ON EVERY AXIS — the three SceneKit needs plus the view's
        // own CALayer, so no opaque rectangle can render behind the star.
        view.backgroundColor = .clear
        view.isOpaque = false
        view.layer.backgroundColor = UIColor.clear.cgColor

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        view.scene = scene

        // Camera straight-on; the whole screen is the canvas.
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 200
        cameraNode.position = SCNVector3(0, 0, 7)
        scene.rootNode.addChildNode(cameraNode)

        // Soft ambient for the whole scene, but NOT the Earth (its own key/fill
        // light carve the terminator; a flat ambient would wash it). The star is
        // .constant/unlit so ambient never touches its flat gold regardless.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 260
        ambient.light?.categoryBitMask = ~FindingsEarth.earthLightMask
        scene.rootNode.addChildNode(ambient)

        // ── the Earth: small (~1/3 screen wide), LOW and deep, quiet ─────────
        let earth = FindingsEarth.makeNode(radius: 0.62, reduceMotion: reduceMotion)
        earth.position = Self.earthPosition
        scene.rootNode.addChildNode(earth)
        context.coordinator.earth = earth

        // ── the star on its positioning rig ─────────────────────────────
        let rig = SCNNode()
        rig.position = Self.heroRigPosition
        rig.scale = Self.heroRigScale
        scene.rootNode.addChildNode(rig)

        let star = FindingsStar(reduceMotion: reduceMotion)
        star.position = Self.starCenter
        rig.addChildNode(star)

        context.coordinator.rig = rig
        context.coordinator.star = star
        context.coordinator.appliedState = .idle
        context.coordinator.appliedCard = cardPresented
        context.coordinator.builtForReduceMotion = reduceMotion
        applyRig(cardPresented, coordinator: context.coordinator, animated: false)
        applyState(state, coordinator: context.coordinator, animated: false)
        view.isPlaying = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coord = context.coordinator
        if coord.builtForReduceMotion != reduceMotion, let old = coord.star, let rig = coord.rig {
            old.removeFromParentNode()
            let fresh = FindingsStar(reduceMotion: reduceMotion)
            fresh.position = Self.starCenter
            rig.addChildNode(fresh)
            coord.star = fresh
            coord.builtForReduceMotion = reduceMotion
            coord.appliedState = nil
        }
        if coord.appliedCard != cardPresented {
            applyRig(cardPresented, coordinator: coord, animated: !reduceMotion)
            coord.appliedCard = cardPresented
        }
        if coord.appliedState != state {
            applyState(state, coordinator: coord, animated: !reduceMotion)
            coord.appliedState = state
        }
        // Keep the render loop alive (cheap for a near-static scene). Under
        // Reduce Motion the scene simply has no animations — still, but drawn.
        view.isPlaying = true
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        view.scene = nil
        coordinator.star = nil
        coordinator.rig = nil
        coordinator.earth = nil
    }

    // MARK: - scene geometry

    private static let starCenter = SCNVector3(0, 0, 0)
    /// Hero: high and large, the free-floating centerpiece — large enough to be
    /// the hero, small enough that its glow doesn't drown the deep-space sky.
    private static let heroRigPosition = SCNVector3(0, 1.05, 0)
    private static let heroRigScale = SCNVector3(1.28, 1.28, 1.28)
    /// Card up: lower and smaller, a clear gap under the card above it.
    private static let cardRigPosition = SCNVector3(0, -1.75, 0)
    private static let cardRigScale = SCNVector3(0.8, 0.8, 0.8)
    /// Earth low and deep — small (~a third of the width), distant, not focal;
    /// mostly below the caption so it only peeks at the very bottom.
    private static let earthPosition = SCNVector3(0.4, -4.7, -5.2)
    /// Off-screen exit for the fly-away (local to the rig): up and to the right.
    private static let offFrame = SCNVector3(2.6, 3.2, -1.0)
    /// Far, tiny, high start for the landing streak (local to the rig).
    private static let farStart = SCNVector3(-2.7, 3.4, -7.0)

    private func applyRig(_ card: Bool, coordinator: Coordinator, animated: Bool) {
        guard let rig = coordinator.rig else { return }
        let pos = card ? Self.cardRigPosition : Self.heroRigPosition
        let scl = card ? Self.cardRigScale : Self.heroRigScale
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.6
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            rig.position = pos
            rig.scale = scl
            SCNTransaction.commit()
        } else {
            rig.position = pos
            rig.scale = scl
        }
    }

    private func applyState(_ state: FindingsStarState, coordinator: Coordinator, animated: Bool) {
        guard let star = coordinator.star else { return }
        switch state {
        case .idle:
            star.removeAllActions()
            star.isHidden = false
            star.position = Self.starCenter
            star.scale = SCNVector3(1, 1, 1)
            star.opacity = 1
        case .landing:
            // LANDING: streak in tiny from a far corner and decelerate the WHOLE
            // way down (~3.4s incl. the settle), a small overshoot at the end.
            star.streakIn(from: Self.farStart, to: Self.starCenter,
                          reduceMotion: reduceMotion, arcDuration: 3.0)
        case .sending:
            star.flyAway(to: Self.offFrame, reduceMotion: reduceMotion) { }
        case .away:
            star.isHidden = true
            star.opacity = 0
            star.position = Self.offFrame
        }
    }

    final class Coordinator {
        var rig: SCNNode?
        var star: FindingsStar?
        var earth: SCNNode?
        var appliedState: FindingsStarState?
        var appliedCard: Bool = false
        var builtForReduceMotion: Bool = false
    }
}
