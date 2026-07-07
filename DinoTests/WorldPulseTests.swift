//
//  WorldPulseTests.swift
//  DinoTests
//
//  Pulse parsing, expiry filtering, and the listener detach contract.
//

import XCTest
import FirebaseFirestore
@testable import Dino

final class WorldPulseTests: XCTestCase {

    // MARK: - Parse

    func testParseValidPulse() {
        let pulse = WorldPulse.parse([
            "countryCode": "US",
            "mood": "drained",
            "createdAt": Timestamp(date: Date()),
        ])
        XCTAssertEqual(pulse?.countryCode, "US")
        XCTAssertEqual(pulse?.mood, .drained)
    }

    func testParseDropsMalformedDocs() {
        XCTAssertNil(WorldPulse.parse(["mood": "angry", "createdAt": Timestamp(date: Date())]))
        XCTAssertNil(WorldPulse.parse(["mood": "clear"]))                      // no timestamp
        XCTAssertNil(WorldPulse.parse([:]))
    }

    func testParseMissingCountryFoldsToElsewhere() {
        let pulse = WorldPulse.parse(["mood": "clear", "createdAt": Timestamp(date: Date())])
        XCTAssertEqual(pulse?.countryCode, "elsewhere")
        let empty = WorldPulse.parse(["countryCode": "", "mood": "clear", "createdAt": Timestamp(date: Date())])
        XCTAssertEqual(empty?.countryCode, "elsewhere")
    }

    // MARK: - Expiry

    func testFreshFiltersExpiredAndFuturePulses() {
        let now = Date()
        func pulse(age: TimeInterval) -> WorldPulse {
            WorldPulse(countryCode: "US", mood: .clear, createdAt: now.addingTimeInterval(-age))
        }
        let pulses = [
            pulse(age: 10),                       // fresh
            pulse(age: WorldPulse.maxAge - 1),    // just inside
            pulse(age: WorldPulse.maxAge + 1),    // expired
            pulse(age: -120),                     // "future" beyond clock skew
        ]
        let fresh = WorldPulse.fresh(pulses, now: now)
        XCTAssertEqual(fresh.count, 2)
        XCTAssertTrue(fresh.allSatisfy { now.timeIntervalSince($0.createdAt) < WorldPulse.maxAge })
    }

    // MARK: - Listener detach (no leaks)

    private final class SpyRegistration: NSObject, ListenerRegistration {
        var removed = false
        func remove() { removed = true }
    }

    @MainActor
    func testStopRemovesAndReleasesRegistration() {
        let listener = WorldPulseListener()
        let spy = SpyRegistration()
        listener.attachForTesting(spy)
        XCTAssertTrue(listener.isActive)
        listener.stop()
        XCTAssertTrue(spy.removed)
        XCTAssertFalse(listener.isActive)
        // stop is idempotent
        listener.stop()
        XCTAssertFalse(listener.isActive)
    }
}
