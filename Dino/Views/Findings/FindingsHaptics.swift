//
//  FindingsHaptics.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo — branch-owned haptics for the redesigned
//  findings screen. CoreHaptics (CHHapticEngine) for the CONTINUOUS textures
//  (the gather ramp, the launch decay); UIImpactFeedbackGenerator for the
//  DISCRETE taps (tap, settle, burst, card-lock, empty).
//
//  SILENT NO-OP CONTRACT: if the hardware cannot do CoreHaptics (the simulator,
//  older devices) or the engine fails to start, every continuous call is a
//  silent no-op — never a crash, never a fallback buzz. Discrete impacts use
//  UIImpactFeedbackGenerator, which already respects the system haptic setting
//  and no-ops on the simulator. This screen NEVER uses
//  UINotificationFeedbackGenerator .error (owner rule) — nothing here is a
//  failure the body should flinch at.
//
//  English-only demo (owner decision): plain string literals only.
//

import UIKit
import CoreHaptics

final class FindingsHaptics {
    static let shared = FindingsHaptics()

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    // MARK: - engine lifecycle (lazy, failure ⇒ permanent silent no-op)

    private func ensureEngine() -> CHHapticEngine? {
        guard supportsHaptics else { return nil }
        if let engine { return engine }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            // A reset (audio-session interruption) must never leave us buzzing.
            e.stoppedHandler = { [weak self] _ in self?.continuousPlayer = nil }
            e.resetHandler = { [weak self] in
                guard let self, let e = self.engine else { return }
                try? e.start()
            }
            try e.start()
            engine = e
            return e
        } catch {
            // Give up for good — supportsHaptics stays true but engine is nil,
            // so continuous calls silently no-op rather than retry-thrashing.
            supportsHaptics = false
            return nil
        }
    }

    // MARK: - discrete impacts (system-haptic-aware, sim-safe)

    /// tap the star — immediate light.
    func tapStar() { impact(.light) }

    /// LANDING settle — one soft thud when the star lands.
    func landingSettle() { impact(.soft) }

    /// CARD LOCK — a light rigid click as the card locks in.
    func cardLock() { impact(.rigid, intensity: 0.7) }

    /// BURST — the strongest hit in the whole app, exactly on the ray burst.
    func rayBurst() { impact(.heavy, intensity: 1.0) }

    /// EMPTY-HANDED — exactly one soft note, nothing more.
    func emptyHanded() { impact(.soft) }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle,
                        intensity: CGFloat = 1.0) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred(intensity: intensity)
    }

    // MARK: - GATHER — continuous ramp 0.2 → 0.6 over ~0.4s

    func gather(duration: TimeInterval = 0.4) {
        playContinuousRamp(from: 0.2, to: 0.6, sharpness: 0.35, duration: duration)
    }

    // MARK: - LAUNCH — a medium hit, then a continuous decay to zero as the star shrinks away

    func launch(decay: TimeInterval = 0.9) {
        impact(.medium)
        playContinuousRamp(from: 0.55, to: 0.0, sharpness: 0.5, duration: decay)
    }

    /// Stop any continuous texture immediately (state changed out from under it).
    func stopContinuous() {
        guard let player = continuousPlayer else { return }
        try? player.stop(atTime: CHHapticTimeImmediate)
        continuousPlayer = nil
    }

    /// One continuous event with a linear intensity control curve. Silent no-op
    /// on any hardware / engine that can't do CoreHaptics.
    private func playContinuousRamp(from start: Float, to end: Float,
                                    sharpness: Float, duration: TimeInterval) {
        guard let engine = ensureEngine() else { return }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: start),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: duration)
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: start),
                .init(relativeTime: duration, value: end),
            ],
            relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameterCurves: [curve])
            stopContinuous()
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            continuousPlayer = player
        } catch {
            // silent — a failed texture is never a fallback buzz.
        }
    }
}
