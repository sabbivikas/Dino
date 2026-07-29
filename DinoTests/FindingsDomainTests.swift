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

    func testReturnsNilForUnusableInput() {
        XCTAssertNil(FindingsDomain.source(from: ""))
        XCTAssertNil(FindingsDomain.source(from: "   "))
        XCTAssertNil(FindingsDomain.source(from: "not a real url"))   // space → invalid
        XCTAssertNil(FindingsDomain.source(from: "https://"))
    }
}
