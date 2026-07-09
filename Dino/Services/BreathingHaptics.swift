//
//  BreathingHaptics.swift
//  Dino
//
//  The breath you can feel — a continuous CoreHaptics tide that mirrors the
//  breath phases, driven by the SAME phase transitions as the circle
//  animation (runStep in BreathingViewModel), so they can never drift.
//
//  Tone contract: a slow tide or a sleeping animal's breath. Long continuous
//  events shaped by parameter curves — never transient taps, never anything
//  resembling a notification buzz. Haptics are garnish: every failure path
//  degrades to silence, never to a broken session.
//

import Foundation
import CoreHaptics

// MARK: - Pure curve shapes (testable without an engine)

struct HapticCurvePoint: Equatable {
    let time: Double        // seconds from phase start
    let intensity: Double   // 0...1
    let sharpness: Double   // 0...1 — low = round and soft, high = clicky
}

enum BreathingHapticCurves {

    /// The tide per phase. Inhale swells, hold shimmers barely-there, exhale
    /// is one long fade to nothing, rest/idle/done are true silence.
    static func points(for phase: BreathingPhase, duration: Double) -> [HapticCurvePoint] {
        guard duration > 0 else { return [] }
        switch phase {
        case .inhale:
            // soft rising swell: most of the rise early, a gentle crest at the top
            return [
                HapticCurvePoint(time: 0, intensity: 0.20, sharpness: 0.30),
                HapticCurvePoint(time: duration * 0.7, intensity: 0.50, sharpness: 0.30),
                HapticCurvePoint(time: duration, intensity: 0.60, sharpness: 0.30),
            ]
        case .hold:
            // barely-there steady shimmer — presence, not attention
            return [
                HapticCurvePoint(time: 0, intensity: 0.15, sharpness: 0.20),
                HapticCurvePoint(time: duration, intensity: 0.15, sharpness: 0.20),
            ]
        case .exhale:
            // long fade to zero, softening as it goes
            return [
                HapticCurvePoint(time: 0, intensity: 0.50, sharpness: 0.25),
                HapticCurvePoint(time: duration * 0.6, intensity: 0.20, sharpness: 0.20),
                HapticCurvePoint(time: duration, intensity: 0.0, sharpness: 0.15),
            ]
        case .idle, .done:
            return []   // true silence
        }
    }
}

// MARK: - Engine wrapper (lazy; silent absence on unsupported devices)

@MainActor
final class BreathingHaptics {
    static let shared = BreathingHaptics()
    private init() {}

    static let enabledKey = "dino.breathing.hapticsEnabled"

    /// On by default — absent key reads true.
    static var isEnabled: Bool {
        get { (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// No CoreHaptics hardware → the feature silently doesn't exist (no dead
    /// toggle, no crash). Also false when the system disables haptics.
    static var deviceSupported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    /// Called at every phase transition with the phase's full duration — the
    /// same call site that drives the circle, so haptics can never drift.
    func play(phase: BreathingPhase, duration: Double) {
        guard Self.isEnabled, Self.deviceSupported, duration > 0 else { return }
        let points = BreathingHapticCurves.points(for: phase, duration: duration)
        guard !points.isEmpty else {
            stopCurrent()   // rest phases are true silence
            return
        }
        do {
            try ensureEngine()
            stopCurrent()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(points[0].sharpness)),
                ],
                relativeTime: 0,
                duration: duration
            )
            let intensityCurve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: points.map { .init(relativeTime: $0.time, value: Float($0.intensity)) },
                relativeTime: 0
            )
            let sharpnessCurve = CHHapticParameterCurve(
                parameterID: .hapticSharpnessControl,
                controlPoints: points.map { .init(relativeTime: $0.time, value: Float($0.sharpness)) },
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameterCurves: [intensityCurve, sharpnessCurve])
            let newPlayer = try engine?.makePlayer(with: pattern)
            try newPlayer?.start(atTime: CHHapticTimeImmediate)
            player = newPlayer
        } catch {
            stop()   // garnish, never a broken breath
        }
    }

    /// Ends the current phase's tide without tearing the engine down.
    func stopCurrent() {
        try? player?.cancel()
        player = nil
    }

    /// Session over — full teardown; the engine is rebuilt lazily next time.
    func stop() {
        stopCurrent()
        engine?.stop(completionHandler: nil)
        engine = nil
    }

    private func ensureEngine() throws {
        if engine != nil { return }
        let newEngine = try CHHapticEngine()
        newEngine.playsHapticsOnly = true
        // Interruptions (calls, siri, route changes): clean stop — the next
        // phase transition lazily rebuilds and restarts.
        newEngine.resetHandler = { [weak self] in
            Task { @MainActor in
                self?.player = nil
                self?.engine = nil
            }
        }
        newEngine.stoppedHandler = { [weak self] _ in
            Task { @MainActor in
                self?.player = nil
                self?.engine = nil
            }
        }
        try newEngine.start()
        engine = newEngine
    }
}
