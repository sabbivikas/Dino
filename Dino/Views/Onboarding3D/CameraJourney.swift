//
//  CameraJourney.swift
//  Dino
//
//  The step → camera choreography. One pose per onboarding step (0...11);
//  advancing or going back dollies the camera to the target pose over 2s
//  (easeInEaseOut). Retune positions here without touching geometry.
//
//  Path: meadow (0-2) → pond (3) → overlook/night (4) → grove (5-6)
//        → pond (7-8) → back to the warm meadow (9-11) — the loop home.
//

import SceneKit

struct CameraPose {
    let position: SCNVector3
    let lookAt: SCNVector3
    let region: WorldRegion
}

enum CameraJourney {

    static let transitionDuration: TimeInterval = 2.0

    /// One pose per onboarding step index.
    static let poses: [CameraPose] = [
        // 0 — welcome: wide meadow establishing shot
        CameraPose(position: SCNVector3(0, 1.6, 5.5),  lookAt: SCNVector3(0, 1.2, 0),      region: .meadow),
        // 1 — feeling pills: drift closer
        CameraPose(position: SCNVector3(0.8, 1.5, 4.2), lookAt: SCNVector3(0, 1.1, -0.5),  region: .meadow),
        // 2 — challenge picker: meadow edge
        CameraPose(position: SCNVector3(-1.2, 1.5, 3.4), lookAt: SCNVector3(-0.4, 1.1, -1.5), region: .meadow),
        // 3 — encouragement: approaching the pond
        CameraPose(position: SCNVector3(-3.4, 1.5, -4.5), lookAt: SCNVector3(-5, 0.8, -9), region: .pond),
        // 4 — navy quote: the overlook, tilted up so the night sky owns the frame
        CameraPose(position: SCNVector3(0, 2.8, -23.5), lookAt: SCNVector3(0, 5.5, -32),   region: .overlook),
        // 5 — referral: into the grove
        CameraPose(position: SCNVector3(3.2, 1.6, -14.5), lookAt: SCNVector3(4.5, 1.4, -18), region: .grove),
        // 6 — notifications: deeper grove
        CameraPose(position: SCNVector3(4.6, 1.5, -16.5), lookAt: SCNVector3(4.0, 1.6, -20), region: .grove),
        // 7 — name: returning past the pond
        CameraPose(position: SCNVector3(-2.0, 1.5, -6.5), lookAt: SCNVector3(-5, 0.9, -9.5), region: .pond),
        // 8 — anxiety/breathing: still water, calm
        CameraPose(position: SCNVector3(-4.4, 1.3, -7.5), lookAt: SCNVector3(-5.4, 0.8, -10), region: .pond),
        // 9 — rough day: back toward the meadow
        CameraPose(position: SCNVector3(-1.0, 1.6, 1.5), lookAt: SCNVector3(0.5, 1.1, -1), region: .meadow),
        // 10 — disclaimer + confetti: warm meadow light for the celebration
        CameraPose(position: SCNVector3(0, 1.7, 4.0),  lookAt: SCNVector3(0, 1.2, -0.6),   region: .meadow),
        // 11 — rating: gentle pull back, warm send-off
        CameraPose(position: SCNVector3(0.4, 1.8, 5.0), lookAt: SCNVector3(0, 1.3, -0.2),  region: .meadow)
    ]

    /// Clamped lookup — any out-of-range step lands on the nearest pose, so a
    /// future 13th step can never crash the camera.
    static func pose(for step: Int) -> CameraPose {
        let index = max(0, min(step, poses.count - 1))
        return poses[index]
    }

    /// Euler angles (pitch, yaw, 0) for a camera at `position` looking at
    /// `target`. SceneKit cameras look down -Z; euler order is ZYX.
    static func eulerLooking(from position: SCNVector3, at target: SCNVector3) -> SCNVector3 {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dz = target.z - position.z
        let horizontal = sqrt(dx * dx + dz * dz)
        let yaw = atan2(-dx, -dz)
        let pitch = atan2(dy, horizontal)
        return SCNVector3(pitch, yaw, 0)
    }
}
