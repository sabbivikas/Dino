//
//  GardenParallax.swift
//  Dino
//
//  CoreMotion-driven camera parallax. Device tilt nudges the camera pivot
//  by at most ±3°, smoothed with a 0.1 lerp. The motion manager is stopped
//  on disappear; the handler captures self weakly — no retain cycle.
//

import CoreMotion
import SceneKit

final class GardenParallaxController {

    private let motion = CMMotionManager()
    private weak var pivot: SCNNode?
    private var baseEuler = SCNVector3(0, 0, 0)
    private var smoothedYaw: Float = 0
    private var smoothedPitch: Float = 0
    private(set) var isRunning = false

    private let maxOffsetRadians: Float = 2.5 * .pi / 180.0   // ±2.5° clamp
    private let lerpFactor: Float = 0.1

    func start(pivot: SCNNode) {
        guard !isRunning, motion.isDeviceMotionAvailable else { return }
        self.pivot = pivot
        baseEuler = pivot.eulerAngles
        smoothedYaw = 0
        smoothedPitch = 0
        isRunning = true

        motion.deviceMotionUpdateInterval = 1.0 / 30.0   // 30hz max per spec
        motion.startDeviceMotionUpdates(to: .main) { [weak self] deviceMotion, _ in
            guard let self, let dm = deviceMotion, let pivot = self.pivot else { return }

            // Roll tilts the camera laterally, pitch vertically — both clamped.
            let targetYaw = max(-self.maxOffsetRadians,
                                min(self.maxOffsetRadians, Float(dm.attitude.roll) * 0.15))
            let targetPitch = max(-self.maxOffsetRadians,
                                  min(self.maxOffsetRadians, Float(dm.attitude.pitch - 0.7) * 0.10))

            self.smoothedYaw += (targetYaw - self.smoothedYaw) * self.lerpFactor
            self.smoothedPitch += (targetPitch - self.smoothedPitch) * self.lerpFactor

            pivot.eulerAngles = SCNVector3(
                self.baseEuler.x + self.smoothedPitch,
                self.baseEuler.y + self.smoothedYaw,
                self.baseEuler.z
            )
        }
    }

    func stop() {
        guard isRunning else { return }
        motion.stopDeviceMotionUpdates()
        isRunning = false
        if let pivot {
            pivot.eulerAngles = baseEuler
        }
    }

    deinit {
        motion.stopDeviceMotionUpdates()
    }
}
