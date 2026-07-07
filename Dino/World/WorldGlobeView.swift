//
//  WorldGlobeView.swift
//  Dino
//
//  SwiftUI wrapper for the DINO WORLD globe: auto-rotation, drag-to-spin with
//  momentum, warm peach halo behind the sphere, and a find-my-light hook.
//

import SwiftUI
import SceneKit

struct WorldGlobeView: UIViewRepresentable {
    let bucket: WorldDayBucket?
    var localEchoMood: EmotionalWeather? = nil   // the user's own light (today's log)
    var localEchoCountry: String = "elsewhere"
    @Binding var findMyLightTrigger: Int      // increment to fire the animation
    var onFoundLight: ((Bool) -> Void)? = nil // true when the country was found
    var onGlowTap: ((WorldGlobeScene.WorldGlowHit?) -> Void)? = nil // nil = tapped empty space

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 30            // gentle on older devices
        view.rendersContinuously = false

        let globe = WorldGlobeScene()
        globe.build()
        view.scene = globe.scene
        context.coordinator.globe = globe
        context.coordinator.scnView = view
        context.coordinator.onGlowTap = onGlowTap
        context.coordinator.startAutoRotate()
        // Live pulses — listen only while the globe is on screen (removed in
        // dismantleUIView). Weak globe: the listener never keeps the scene alive.
        context.coordinator.pulseListener.start { [weak globe] pulse in
            globe?.pulse(countryCode: pulse.countryCode, mood: pulse.mood)
        }

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onGlowTap = onGlowTap
        if let mood = localEchoMood, coordinator.appliedEchoMood != mood || coordinator.appliedEchoCountry != localEchoCountry {
            coordinator.appliedEchoMood = mood
            coordinator.appliedEchoCountry = localEchoCountry
            coordinator.globe?.setLocalEcho(mood: mood, countryCode: localEchoCountry)
        }
        if coordinator.appliedBucket != bucket {
            coordinator.appliedBucket = bucket
            coordinator.globe?.apply(bucket: bucket)
        }
        if coordinator.lastFindTrigger != findMyLightTrigger {
            coordinator.lastFindTrigger = findMyLightTrigger
            coordinator.findMyLight(onFound: onFoundLight)
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.pulseListener.stop()
        coordinator.globe?.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        var globe: WorldGlobeScene?
        let pulseListener = WorldPulseListener()
        weak var scnView: SCNView?
        var onGlowTap: ((WorldGlobeScene.WorldGlowHit?) -> Void)?
        var appliedBucket: WorldDayBucket?
        var appliedEchoMood: EmotionalWeather?
        var appliedEchoCountry: String = ""
        var lastFindTrigger = 0
        private var resumeWorkItem: DispatchWorkItem?
        private var screenRadius: CGFloat = 160

        func startAutoRotate() {
            let spin = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 90)
            globe?.globeNode.runAction(.repeatForever(spin), forKey: "autorotate")
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let node = globe?.globeNode else { return }
            switch gesture.state {
            case .began:
                // the finger owns the ball — nothing else may rotate it
                node.removeAction(forKey: "autorotate")
                node.removeAction(forKey: "momentum")
                node.removeAction(forKey: "focus")
                resumeWorkItem?.cancel()
                screenRadius = projectedGlobeRadius()
            case .changed:
                let t = gesture.translation(in: gesture.view)
                gesture.setTranslation(.zero, in: gesture.view)
                // 1:1 — a point of drag moves the surface a point under the finger
                let s = Float(1.0 / max(screenRadius, 60))
                node.eulerAngles.y += Float(t.x) * s
                node.eulerAngles.x = max(-0.6, min(0.6, node.eulerAngles.x + Float(t.y) * s))
            case .ended, .cancelled:
                let s = CGFloat(1.0 / max(screenRadius, 60))
                let releaseSpeed = gesture.velocity(in: gesture.view).x * s   // rad/s
                let duration: TimeInterval = 1.4
                // easeOut's initial slope is 2×angle/duration — this angle makes
                // the momentum start at exactly the release speed, so letting go
                // feels like the same ball still spinning
                let angle = releaseSpeed * CGFloat(duration) / 2
                if abs(angle) > 0.015 {
                    let momentum = SCNAction.rotateBy(x: 0, y: angle, z: 0, duration: duration)
                    momentum.timingMode = .easeOut
                    node.runAction(momentum, forKey: "momentum")
                }
                startAutoRotateLater(delay: 3.0)
            default:
                break
            }
        }

        /// On-screen globe radius in points — makes drag sensitivity 1:1
        /// regardless of device or layout.
        private func projectedGlobeRadius() -> CGFloat {
            guard let view = scnView else { return 160 }
            let c = view.projectPoint(SCNVector3(0, 0, 0))
            let e = view.projectPoint(SCNVector3(WorldGlobeScene.globeRadius, 0, 0))
            let r = hypot(CGFloat(e.x - c.x), CGFloat(e.y - c.y))
            return r > 40 ? r : 160
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView else { return }
            let point = gesture.location(in: view)
            let options: [SCNHitTestOption: Any] = [
                .searchMode: NSNumber(value: SCNHitTestSearchMode.all.rawValue)
            ]
            let hit = view.hitTest(point, options: options)
                .compactMap { globe?.glowHit(for: $0.node) }
                .first
            if hit != nil { HapticManager.shared.light() }
            let callback = onGlowTap
            // defer out of the gesture callback — the handler may write @State
            DispatchQueue.main.async { callback?(hit) }
        }

        func findMyLight(onFound: ((Bool) -> Void)?) {
            // Defer every callback out of the current SwiftUI update — this is
            // reached from updateUIView, and a synchronous @State write here is
            // "Modifying state during view update" (undefined behavior).
            func report(_ found: Bool) {
                DispatchQueue.main.async { onFound?(found) }
            }
            guard let globe else { report(false); return }
            globe.globeNode.removeAction(forKey: "autorotate")
            globe.globeNode.removeAction(forKey: "momentum")
            resumeWorkItem?.cancel()
            let code = WorldMoodService.countryCode(from: Locale.current.region?.identifier)
            guard code != "elsewhere", let firefly = globe.focus(on: code) else {
                report(false)
                startAutoRotateLater()
                return
            }
            // Pulse ×3 — behavior distinguishes "you", not a special color.
            let pulseUp = SCNAction.scale(to: 2.2, duration: 0.4)
            pulseUp.timingMode = .easeInEaseOut
            let pulseDown = SCNAction.scale(to: 1.0, duration: 0.4)
            pulseDown.timingMode = .easeInEaseOut
            firefly.runAction(.sequence([.wait(duration: 1.4), .repeat(.sequence([pulseUp, pulseDown]), count: 3)]))
            report(true)
            startAutoRotateLater(delay: 6)
        }

        private func startAutoRotateLater(delay: TimeInterval = 3.5) {
            let item = DispatchWorkItem { [weak self] in self?.startAutoRotate() }
            resumeWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }
}
