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
        context.coordinator.startAutoRotate()

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
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
        coordinator.globe?.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        var globe: WorldGlobeScene?
        var appliedBucket: WorldDayBucket?
        var appliedEchoMood: EmotionalWeather?
        var appliedEchoCountry: String = ""
        var lastFindTrigger = 0
        private var resumeWorkItem: DispatchWorkItem?

        func startAutoRotate() {
            let spin = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 90)
            globe?.globeNode.runAction(.repeatForever(spin), forKey: "autorotate")
        }

        private func pauseAutoRotate() {
            globe?.globeNode.removeAction(forKey: "autorotate")
            resumeWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.startAutoRotate() }
            resumeWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: item)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let node = globe?.globeNode else { return }
            pauseAutoRotate()
            let translation = gesture.translation(in: gesture.view)
            gesture.setTranslation(.zero, in: gesture.view)
            node.eulerAngles.y += Float(translation.x) * 0.008
            node.eulerAngles.x = max(-0.6, min(0.6, node.eulerAngles.x + Float(translation.y) * 0.004))
            if gesture.state == .ended {
                let vx = gesture.velocity(in: gesture.view).x
                let momentum = SCNAction.rotateBy(x: 0, y: CGFloat(vx) * 0.0009, z: 0, duration: 0.9)
                momentum.timingMode = .easeOut
                node.runAction(momentum)
            }
        }

        func findMyLight(onFound: ((Bool) -> Void)?) {
            guard let globe else { onFound?(false); return }
            globe.globeNode.removeAction(forKey: "autorotate")
            resumeWorkItem?.cancel()
            let code = WorldMoodService.countryCode(from: Locale.current.region?.identifier)
            guard code != "elsewhere", let firefly = globe.focus(on: code) else {
                onFound?(false)
                startAutoRotateLater()
                return
            }
            // Pulse ×3 — behavior distinguishes "you", not a special color.
            let pulseUp = SCNAction.scale(to: 2.2, duration: 0.4)
            pulseUp.timingMode = .easeInEaseOut
            let pulseDown = SCNAction.scale(to: 1.0, duration: 0.4)
            pulseDown.timingMode = .easeInEaseOut
            firefly.runAction(.sequence([.wait(duration: 1.4), .repeat(.sequence([pulseUp, pulseDown]), count: 3)]))
            onFound?(true)
            startAutoRotateLater(delay: 6)
        }

        private func startAutoRotateLater(delay: TimeInterval = 3.5) {
            let item = DispatchWorkItem { [weak self] in self?.startAutoRotate() }
            resumeWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }
}
