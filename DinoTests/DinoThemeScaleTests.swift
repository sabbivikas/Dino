//
//  DinoThemeScaleTests.swift
//  DinoTests
//
//  Tests for the combined text scale: in-app setting × Dynamic Type, 1.75× cap.
//

import XCTest
import UIKit
@testable import Dino

final class DinoThemeScaleTests: XCTestCase {
    private let tol: CGFloat = 1e-6

    // 1) Defaults: no user setting (0 → 1.0) at the iOS default category = 1.0.
    func testDefaultIsIdentity() {
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 0, category: .large), 1.0, accuracy: tol)
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 1.0, category: .large), 1.0, accuracy: tol)
    }

    // 2) The combined cap: max user scale × accessibility sizes never exceeds 1.75.
    func testCombinedCap() {
        for category: UIContentSizeCategory in [.accessibilityLarge, .accessibilityExtraLarge,
                                                .accessibilityExtraExtraExtraLarge] {
            let s = DinoTheme.combinedScale(userScale: 1.4, category: category)
            XCTAssertLessThanOrEqual(s, 1.75 + tol)
        }
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 1.4, category: .accessibilityExtraExtraExtraLarge),
                       1.75, accuracy: tol)
    }

    // 3) Floor: tiny user scale at the smallest category never drops below 0.8.
    func testFloor() {
        let s = DinoTheme.combinedScale(userScale: 0.8, category: .extraSmall)
        XCTAssertGreaterThanOrEqual(s, 0.8 - tol)
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

    // 5) User scale is clamped to its documented 0.8...1.4 range.
    func testUserScaleClamped() {
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 3.0, category: .large), 1.4, accuracy: tol)
        XCTAssertEqual(DinoTheme.combinedScale(userScale: 0.1, category: .large), 0.8, accuracy: tol)
    }
}
