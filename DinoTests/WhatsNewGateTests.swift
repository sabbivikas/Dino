//
//  WhatsNewGateTests.swift
//  DinoTests
//
//  The once-per-version gate and the slide data contract (copy rules,
//  unique illustration slots).
//

import XCTest
@testable import Dino

final class WhatsNewGateTests: XCTestCase {

    func testShowsWhenVersionChanges() {
        XCTAssertTrue(WhatsNewGate.shouldShow(lastSeen: "1.8", current: "1.9"))
        XCTAssertTrue(WhatsNewGate.shouldShow(lastSeen: "1.9", current: "2.0"))
    }

    func testNeverShowsTwiceForSameVersion() {
        XCTAssertFalse(WhatsNewGate.shouldShow(lastSeen: "1.9", current: "1.9"))
    }

    func testLegacyUpdaterWithEmptyLastSeenShows() {
        // pre-seeding installs that update — they ARE updaters
        XCTAssertTrue(WhatsNewGate.shouldShow(lastSeen: "", current: "1.9"))
    }

    func testEmptyCurrentVersionNeverShows() {
        XCTAssertFalse(WhatsNewGate.shouldShow(lastSeen: "", current: ""))
        XCTAssertFalse(WhatsNewGate.shouldShow(lastSeen: "1.9", current: ""))
    }

    // Fresh-install behavior is the seed at onboarding completion:
    // lastSeen == current at first home open → gate returns false.
    func testSeededFreshInstallSkips() {
        XCTAssertFalse(WhatsNewGate.shouldShow(lastSeen: "1.9", current: "1.9"))
    }

    // MARK: Slide data contract

    func testSlidesAreFourToFive() {
        XCTAssertTrue((4...5).contains(WhatsNewSlide.current.count))
    }

    func testSlideIdsAreUniqueIllustrationSlots() {
        let ids = WhatsNewSlide.current.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ids.allSatisfy { !$0.isEmpty })
    }

    func testCopyIsLowercaseAndDashFree() {
        for slide in WhatsNewSlide.current {
            XCTAssertEqual(slide.title, slide.title.lowercased(), "\(slide.id) title lowercase")
            XCTAssertEqual(slide.body, slide.body.lowercased(), "\(slide.id) body lowercase")
            for dash in ["-", "\u{2013}", "\u{2014}"] {
                XCTAssertFalse(slide.title.contains(dash), "\(slide.id) title has a dash")
                XCTAssertFalse(slide.body.contains(dash), "\(slide.id) body has a dash")
            }
        }
    }
}
