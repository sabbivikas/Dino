//
//  FindingsDomainTests.swift
//  DinoTests
//
//  EXPERIMENTAL star-findings demo — NEW test file (no existing test modified).
//  Covers the pure domain helper that fills the redesigned card's source pill.
//

import XCTest
@testable import Dino

final class FindingsDomainTests: XCTestCase {

    func testStripsSchemeWwwAndPath() {
        XCTAssertEqual(FindingsDomain.source(from: "https://www.sppl.org/events/hatha"), "sppl.org")
        XCTAssertEqual(FindingsDomain.source(from: "http://www.eventbrite.com/e/12345"), "eventbrite.com")
        XCTAssertEqual(FindingsDomain.source(from: "https://stpaul.gov/como/quiet-hours?x=1"), "stpaul.gov")
    }

    func testLowercasesHostAndKeepsSubdomains() {
        XCTAssertEqual(FindingsDomain.source(from: "https://Calendar.Library.ORG/x"), "calendar.library.org")
        // a non-www subdomain is kept (it is part of the real source)
        XCTAssertEqual(FindingsDomain.source(from: "https://lu.ma/events/abc"), "lu.ma")
    }

    func testSchemeIsOptional() {
        XCTAssertEqual(FindingsDomain.source(from: "sppl.org/events"), "sppl.org")
        XCTAssertEqual(FindingsDomain.source(from: "www.como.org"), "como.org")
    }

    // MARK: - honest copy for the non-finding outcomes

    func testStepCapGetsItsOwnHonestLineNotTheWarmEmptyOne() {
        let line = FindingsCopy.failedLine(outcome: "failed:step_cap")
        XCTAssertEqual(line, "the star searched as long as it could tonight and ran out of time")
        // never the empty-handed copy: nothing was "not found", the trip was cut short
        XCTAssertFalse(line.contains("open paws"))
        XCTAssertFalse(line.contains("empty pawed"))
        // dino's voice, and no nudge to spend another billed run right now
        XCTAssertEqual(line, line.lowercased())
        XCTAssertFalse(line.contains("-"))
        XCTAssertFalse(line.contains("try again"))
    }

    func testOtherFailureReasonsAreHonestAndDistinct() {
        let timeout = FindingsCopy.failedLine(outcome: "failed:timeout")
        let other = FindingsCopy.failedLine(outcome: "failed:error")
        XCTAssertNotEqual(timeout, other)
        for line in [timeout, other, FindingsCopy.failedLine(outcome: "")] {
            XCTAssertFalse(line.isEmpty)
            XCTAssertEqual(line, line.lowercased())
            XCTAssertFalse(line.contains("-"))
            XCTAssertFalse(line.contains("try again"))
            XCTAssertFalse(line.contains("open paws"))
        }
        // an unknown reason still says something honest rather than nothing
        XCTAssertEqual(FindingsCopy.failedLine(outcome: "weird"),
                       FindingsCopy.failedLine(outcome: ""))
    }

    func testAlreadyRunningReadsAsAwayNotAsAnError() {
        let line = FindingsCopy.alreadyRunningLine
        XCTAssertEqual(line, "the star is already out looking")
        XCTAssertEqual(line, line.lowercased())
        XCTAssertFalse(line.contains("try again"))
        XCTAssertFalse(line.contains("lost its way"))
    }

    func testReturnsNilForUnusableInput() {
        XCTAssertNil(FindingsDomain.source(from: ""))
        XCTAssertNil(FindingsDomain.source(from: "   "))
        XCTAssertNil(FindingsDomain.source(from: "not a real url"))   // space → invalid
        XCTAssertNil(FindingsDomain.source(from: "https://"))
    }
}
