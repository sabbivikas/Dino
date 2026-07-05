//
//  DinoThemeScaleTests.swift
//  DinoTests
//
//  Tests for the combined text scale: in-app setting × Dynamic Type, 1.75×
//  cap, then the ×1.15 baseline readability boost (effective ceiling ~2.01).
//

import XCTest
import UIKit
@testable import Dino

final class DinoThemeScaleTests: XCTestCase {
    private let tol: CGFloat = 1e-6
    private let boost = DinoTheme.baselineBoost

    // 1) Defaults: no user setting (0 → 1.0) at the iOS default category
    //    resolves to exactly the baseline boost — the whole point of it.
    func testDefaultIsTheBaselineBoost() {
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 0, category: .large), boost, accuracy: tol)
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 1.0, category: .large), boost, accuracy: tol)
        XCTAssertEqual(boost, 1.15, accuracy: tol, "approved baseline lift")
    }

    // 2) The combined cap: max user scale × accessibility sizes never exceeds
    //    1.75 × boost (≈2.01) — the boost rides on top of the capped scale.
    func testCombinedCap() {
        for category: UIContentSizeCategory in [.accessibilityLarge, .accessibilityExtraLarge,
                                                .accessibilityExtraExtraExtraLarge] {
            let s = DinoTheme.combinedScale(userScale: 1.4, category: category)
            XCTAssertLessThanOrEqual(s, 1.75 * boost + tol)
        }
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 1.4, category: .accessibilityExtraExtraExtraLarge),
                       1.75 * boost, accuracy: tol)
    }

    // 3) Floor: tiny user scale at the smallest category never drops below
    //    0.8 × boost — shrink-preference users still get the readability lift.
    func testFloor() {
        let s = DinoTheme.combinedScale(userScale: 0.8, category: .extraSmall)
        XCTAssertGreaterThanOrEqual(s, 0.8 * boost - tol)
    }

    // 4) Monotonic in the Dynamic Type category at a fixed user scale.
    func testMonotonicAcrossCategories() {
        let ordered: [UIContentSizeCategory] = [.extraSmall, .small, .medium, .large,
                                                .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
                                                .accessibilityMedium, .accessibilityLarge]
        var last: CGFloat = 0
        for c in ordered {
            let s = DinoTheme.combinedScale(userScale: 1.0, category: c)
            XCTAssertGreaterThanOrEqual(s + tol, last)
            last = s
        }
    }

    // 5) User scale is clamped to its documented 0.8...1.4 range (× boost).
    func testUserScaleClamped() {
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 3.0, category: .large), 1.4 * boost, accuracy: tol)
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 0.1, category: .large), 0.8 * boost, accuracy: tol)
    }
}
