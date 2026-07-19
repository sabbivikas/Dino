//
//  RecDeliveryClientTests.swift
//  DinoTests
//
//  Rec delivery F2 — client side: the presence heartbeat throttle and the
//  tz field the server trusts for quiet hours.
//

import XCTest
@testable import Dino

final class RecDeliveryClientTests: XCTestCase {

    // MARK: - Presence heartbeat throttle

    func testFirstBeatAlwaysWrites() {
        XCTAssertTrue(PresenceHeartbeat.shouldBeat(lastWriteAt: nil, now: Date()))
    }

    func testBeatThrottledInsideTheMinuteGap() {
        let now = Date()
        XCTAssertFalse(PresenceHeartbeat.shouldBeat(lastWriteAt: now.addingTimeInterval(-30), now: now))
        XCTAssertFalse(PresenceHeartbeat.shouldBeat(lastWriteAt: now.addingTimeInterval(-59), now: now))
        XCTAssertTrue(PresenceHeartbeat.shouldBeat(lastWriteAt: now.addingTimeInterval(-60), now: now))
        XCTAssertTrue(PresenceHeartbeat.shouldBeat(lastWriteAt: now.addingTimeInterval(-3600), now: now))
    }

    // MARK: - The timezone the server computes quiet hours in

    func testHeartbeatZoneIsARealIanaIdWithinTheRulesCap() {
        let id = TimeZone.current.identifier
        XCTAssertNotNil(TimeZone(identifier: id))
        XCTAssertFalse(id.isEmpty)
        XCTAssertLessThanOrEqual(id.count, 64)   // firestore.rules size cap
    }
}
