//
//  CameraJourney.swift
//  Dino
//
//  Step → camera choreography for the ORTHOGRAPHIC illustrated world.
//  The camera faces nearly straight ahead with an 8–12° downward tilt
//  (Tolan's angle) — except the overlook, which tilts UP so the night sky
//  owns the frame. Each pose also carries an orthographicScale so regions
//  breathe: wide meadow, intimate pond, sky-dominant overlook.
//

import SceneKit

struct CameraPose {
    let position: SCNVector3
    let lookAt: SCNVector3
    let region: WorldRegion
    let orthoScale: Double
}

enum CameraJourney {

    static let transitionDuration: TimeInterval = 2.5

    /// One pose per onboarding step index (0...11).
    /// Down-tilt ≈ 9–10° everywhere except the overlook's upward gaze.
    static let poses: [CameraPose] = [
        // 0 — welcome: wide warm meadow
        CameraPose(position: SCNVector3(0, 3.2, 9.0),   lookAt: SCNVector3(0, 1.7, 0),      region: .meadow,     orthoScale: 10.0),
        // 1 — feeling pills
        CameraPose(position: SCNVector3(0.8, 3.0, 8.0), lookAt: SCNVector3(0.2, 1.6, -0.5), region: .meadow,     orthoScale: 10.0),
        // 2 — challenge picker
        CameraPose(position: SCNVector3(-1.2, 3.0, 7.5), lookAt: SCNVector3(-0.5, 1.6, -1.5), region: .meadow,   orthoScale: 10.0),
        // 3 — encouragement: the lavender pond, closer and intimate
        CameraPose(position: SCNVector3(-4.5, 2.8, -3.0), lookAt: SCNVector3(-5, 1.5, -9.5), region: .pond,      orthoScale: 8.5),
        // 4 — navy quote: the overlook — tilt UP, night sky owns the frame
        CameraPose(position: SCNVector3(0, 4.5, -21.0), lookAt: SCNVector3(0, 7.5, -32),     region: .overlook,  orthoScale: 11.0),
        // 5 — referral: amber grove
        CameraPose(position: SCNVector3(3.0, 3.0, -12.5), lookAt: SCNVector3(4.5, 1.6, -18.5), region: .grove,   orthoScale: 9.0),
        // 6 — notifications: deeper grove
        CameraPose(position: SCNVector3(4.8, 3.0, -14.5), lookAt: SCNVector3(4.2, 1.7, -20), region: .grove,     orthoScale: 9.0),
        // 7 — health: a gentle step further into the grove
        CameraPose(position: SCNVector3(5.2, 2.9, -15.5), lookAt: SCNVector3(4.6, 1.7, -21), region: .grove,     orthoScale: 9.0),
        // 8 — name: back past the pond
        CameraPose(position: SCNVector3(-2.5, 3.0, -5.0), lookAt: SCNVector3(-5, 1.6, -9.5), region: .pond,      orthoScale: 8.5),
        // 9 — breathing: still water
        CameraPose(position: SCNVector3(-4.8, 2.6, -6.0), lookAt: SCNVector3(-5.4, 1.4, -10), region: .pond,     orthoScale: 8.5),
        // 10 — rough day: dawn light coming home
        CameraPose(position: SCNVector3(-1.0, 3.0, 7.0), lookAt: SCNVector3(0.3, 1.6, -0.5), region: .returnDawn, orthoScale: 10.0),
        // 11 — disclaimer + confetti: golden celebration
        CameraPose(position: SCNVector3(0, 3.2, 8.5),   lookAt: SCNVector3(0, 1.7, -0.5),    region: .returnDawn, orthoScale: 10.0),
        // 12 — rating: gentle pull back, warm send-off
        CameraPose(position: SCNVector3(0.4, 3.4, 9.5), lookAt: SCNVector3(0, 1.8, 0),       region: .returnDawn, orthoScale: 10.0)
    ]

    /// Clamped lookup — out-of-range steps land on the nearest pose.
    static func pose(for step: Int) -> CameraPose {
        let index = max(0, min(step, poses.count - 1))
        return poses[index]
    }

    /// Euler (pitch, yaw, 0) for a camera at `position` looking at `target`.
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
