//
//  WorldParallax.swift
//  Dino
//
//  CoreMotion tilt parallax for the onboarding world camera. Clamped to
//  ±2.5°, lerp 0.1, 30hz. Stops on disappear; handler holds self weakly.
//

import CoreMotion
import SceneKit

final class WorldParallaxController {

    private let motion = CMMotionManager()
    private weak var pivot: SCNNode?
    private var smoothedYaw: Float = 0
    private var smoothedPitch: Float = 0
    private(set) var isRunning = false

    private let maxOffset: Float = 2.5 * .pi / 180.0   // ±2.5°
    private let lerp: Float = 0.1

    func start(pivot: SCNNode) {
        guard !isRunning, motion.isDeviceMotionAvailable else { return }
        self.pivot = pivot
        smoothedYaw = 0
        smoothedPitch = 0
        isRunning = true

        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] dm, _ in
            guard let self, let dm, let pivot = self.pivot else { return }
            let targetYaw = max(-self.maxOffset, min(self.maxOffset, Float(dm.attitude.roll) * 0.12))
            let targetPitch = max(-self.maxOffset, min(self.maxOffset, Float(dm.attitude.pitch - 0.7) * 0.08))
            self.smoothedYaw += (targetYaw - self.smoothedYaw) * self.lerp
            self.smoothedPitch += (targetPitch - self.smoothedPitch) * self.lerp
            pivot.eulerAngles = SCNVector3(self.smoothedPitch, self.smoothedYaw, 0)
        }
    }

    func stop() {
        guard isRunning else { return }
        motion.stopDeviceMotionUpdates()
        isRunning = false
        pivot?.eulerAngles = SCNVector3(0, 0, 0)
    }

    deinit {
        motion.stopDeviceMotionUpdates()
    }
}
