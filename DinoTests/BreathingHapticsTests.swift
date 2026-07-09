//
//  BreathingHapticsTests.swift
//  DinoTests
//
//  Pure phase→curve mapping (the tide shapes) + toggle persistence.
//

import XCTest
@testable import Dino

final class BreathingHapticsTests: XCTestCase {

    // MARK: - Curve shapes

    func testInhaleIsASoftRisingSwell() {
        let pts = BreathingHapticCurves.points(for: .inhale, duration: 4)
        XCTAssertEqual(pts.first?.intensity, 0.20)
        XCTAssertEqual(pts.last?.intensity, 0.60)
        XCTAssertEqual(pts.last?.time, 4)
        // monotonic rise — a swell, never a spike
        for (a, b) in zip(pts, pts.dropFirst()) {
            XCTAssertLessThanOrEqual(a.intensity, b.intensity)
            XCTAssertLessThan(a.time, b.time)
        }
        XCTAssertTrue(pts.allSatisfy { $0.sharpness <= 0.3 }, "inhale must stay round, never clicky")
    }

    func testHoldIsBarelyThereAndSteady(){
        let pts = BreathingHapticCurves.points(for: .hold, duration: 7)
        XCTAssertTrue(pts.allSatisfy { $0.intensity == 0.15 }, "hold shimmer must be flat")
        XCTAssertEqual(pts.last?.time, 7)
    }

    func testExhaleIsALongFadeToTrueZero() {
        let pts = BreathingHapticCurves.points(for: .exhale, duration: 8)
        XCTAssertEqual(pts.last?.intensity, 0.0, "exhale must land at true zero")
        for (a, b) in zip(pts, pts.dropFirst()) {
            XCTAssertGreaterThanOrEqual(a.intensity, b.intensity)   // monotonic fade
        }
        // softening as it goes — sharpness never rises through the exhale
        for (a, b) in zip(pts, pts.dropFirst()) {
            XCTAssertGreaterThanOrEqual(a.sharpness, b.sharpness)
        }
    }

    func testRestPhasesAreTrueSilence() {
        XCTAssertTrue(BreathingHapticCurves.points(for: .idle, duration: 4).isEmpty)
        XCTAssertTrue(BreathingHapticCurves.points(for: .done, duration: 4).isEmpty)
        XCTAssertTrue(BreathingHapticCurves.points(for: .inhale, duration: 0).isEmpty)
    }

    func testCurvesScaleWithAnyPatternDuration() {
        // works across ALL patterns: durations come from the pattern steps
        for duration in [2.0, 4.0, 7.0, 11.0] {
            let inhale = BreathingHapticCurves.points(for: .inhale, duration: duration)
            XCTAssertEqual(inhale.last?.time, duration)
            let exhale = BreathingHapticCurves.points(for: .exhale, duration: duration)
            XCTAssertEqual(exhale.last?.time, duration)
        }
    }

    func testTideNeverExceedsGentleCeilings() {
        // never taps or notifications: intensity ≤ 0.6, sharpness ≤ 0.3
        for phase in [BreathingPhase.inhale, .hold, .exhale] {
            for p in BreathingHapticCurves.points(for: phase, duration: 5) {
                XCTAssertLessThanOrEqual(p.intensity, 0.6)
                XCTAssertLessThanOrEqual(p.sharpness, 0.3)
            }
        }
    }

    // MARK: - Toggle persistence (on by default)

    @MainActor
    func testTogglePersistsAndDefaultsOn() {
        let old = UserDefaults.standard.object(forKey: BreathingHaptics.enabledKey)
        defer { UserDefaults.standard.set(old, forKey: BreathingHaptics.enabledKey) }

        UserDefaults.standard.removeObject(forKey: BreathingHaptics.enabledKey)
        XCTAssertTrue(BreathingHaptics.isEnabled, "absent key must read as on")

        BreathingHaptics.isEnabled = false
        XCTAssertFalse(BreathingHaptics.isEnabled)
        BreathingHaptics.isEnabled = true
        XCTAssertTrue(BreathingHaptics.isEnabled)
    }
}
