//
//  BreathingPatternTests.swift
//  DinoTests
//
//  Pure pattern math for the breathing library — cycle lengths, whole-breath
//  session rounding, and structural invariants every pattern must hold.
//

import XCTest
@testable import Dino

final class BreathingPatternTests: XCTestCase {

    func testLibraryHasFourUniquePatterns() {
        XCTAssertEqual(BreathingPattern.library.count, 4)
        XCTAssertEqual(Set(BreathingPattern.library.map(\.id)).count, 4)
    }

    func testCycleLengths() {
        XCTAssertEqual(BreathingPattern.bigSigh.cycleLength, 12)      // 4 + 2 + 6
        XCTAssertEqual(BreathingPattern.sleepyCloud.cycleLength, 19)  // 4 + 7 + 8
        XCTAssertEqual(BreathingPattern.steadySquare.cycleLength, 16) // 4 + 4 + 4 + 4
        XCTAssertEqual(BreathingPattern.calmCurrent.cycleLength, 10)  // 5 + 5
    }

    func testTotalCyclesRoundsToNearestWholeBreath() {
        XCTAssertEqual(BreathingPattern.bigSigh.totalCycles(for: 120), 10)      // exact
        XCTAssertEqual(BreathingPattern.sleepyCloud.totalCycles(for: 120), 6)   // 6.3 rounds down
        XCTAssertEqual(BreathingPattern.steadySquare.totalCycles(for: 120), 8)  // 7.5 rounds up
        XCTAssertEqual(BreathingPattern.calmCurrent.totalCycles(for: 600), 60)  // exact
    }

    func testTotalCyclesNeverZero() {
        for pattern in BreathingPattern.library {
            XCTAssertEqual(pattern.totalCycles(for: 5), 1, "\(pattern.id) must plan at least one breath")
            XCTAssertEqual(pattern.totalCycles(for: 0), 1)
        }
    }

    func testPlannedDurationIsWholeCyclesNearRequested() {
        for pattern in BreathingPattern.library {
            for requested in [120, 300, 600] {
                let planned = pattern.plannedDuration(for: requested)
                XCTAssertEqual(planned % pattern.cycleLength, 0,
                               "\(pattern.id) planned duration must be whole cycles")
                XCTAssertLessThanOrEqual(abs(planned - requested), pattern.cycleLength,
                                         "\(pattern.id) planned duration should stay within one cycle of the request")
            }
        }
    }

    func testEveryPatternStartsOnAnInhaleAndEndsAtRest() {
        for pattern in BreathingPattern.library {
            XCTAssertEqual(pattern.steps.first?.kind, .inhale, "\(pattern.id) must open with an inhale")
            XCTAssertEqual(pattern.steps.last?.targetScale, 0.6,
                           "\(pattern.id) must end at rest scale so cycles chain seamlessly")
        }
    }

    func testScaleTargetsStayInCircleRange() {
        for pattern in BreathingPattern.library {
            for step in pattern.steps {
                XCTAssertGreaterThanOrEqual(step.targetScale, 0.6)
                XCTAssertLessThanOrEqual(step.targetScale, 1.15)
            }
        }
    }

    func testBigSighHasARisingDoubleInhale() {
        let steps = BreathingPattern.bigSigh.steps
        XCTAssertEqual(steps[0].kind, .inhale)
        XCTAssertEqual(steps[1].kind, .inhale)
        XCTAssertGreaterThan(steps[1].targetScale, steps[0].targetScale,
                             "the top up must push past the first inhale")
        XCTAssertEqual(steps[2].kind, .exhale)
    }

    func testTimingSummaries() {
        XCTAssertEqual(BreathingPattern.bigSigh.timingSummary, "4 · 2 · 6")
        XCTAssertEqual(BreathingPattern.sleepyCloud.timingSummary, "4 · 7 · 8")
        XCTAssertEqual(BreathingPattern.steadySquare.timingSummary, "4 · 4 · 4 · 4")
        XCTAssertEqual(BreathingPattern.calmCurrent.timingSummary, "5 · 5")
    }

    func testShortNamesDropTheArticle() {
        XCTAssertEqual(BreathingPattern.bigSigh.shortName, "big sigh")
        XCTAssertEqual(BreathingPattern.steadySquare.shortName, "steady square")
    }
}
