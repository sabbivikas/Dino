//
//  GardenShareTests.swift
//  DinoTests
//
//  The postcard's pure heart: stamp determinism and uniqueness, the day
//  count that never resets, the voice contract, and the privacy sweep.
//

import XCTest
@testable import Dino

final class GardenShareTests: XCTestCase {

    // MARK: - Stamp determinism (same user → the same stamp, forever)

    func testStampIsDeterministicForAUser() {
        let a1 = GradientSeed.fingerprint(GardenShare.stampSeed(uid: "user-123"))
        let a2 = GradientSeed.fingerprint(GardenShare.stampSeed(uid: "user-123"))
        XCTAssertEqual(a1, a2, "same uid must yield an identical stamp every time")
    }

    func testStampsDifferBetweenUsers() {
        let a = GradientSeed.fingerprint(GardenShare.stampSeed(uid: "stamp-proof-a"))
        let b = GradientSeed.fingerprint(GardenShare.stampSeed(uid: "stamp-proof-b"))
        XCTAssertNotEqual(a, b, "two users must never share a stamp")
    }

    func testStampSeedIsNamespaced() {
        // the stamp must not collide with other GradientSeed uses of the raw uid
        XCTAssertNotEqual(GardenShare.stampSeed(uid: "u1"), "u1")
        XCTAssertNotEqual(GradientSeed.fingerprint(GardenShare.stampSeed(uid: "u1")),
                          GradientSeed.fingerprint("u1"))
    }

    // MARK: - Garden age (never resets, not the streak)

    func testGardenAgeCountsFromFirstPractice() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 20))!
        XCTAssertEqual(GardenShare.age(firstPractice: now, now: now), 1, "first day is day 1")
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        XCTAssertEqual(GardenShare.age(firstPractice: weekAgo, now: now), 8)
        let yearAgo = cal.date(byAdding: .day, value: -364, to: now)!
        XCTAssertEqual(GardenShare.age(firstPractice: yearAgo, now: now), 365)
    }

    func testUntendedGardenIsDayOne() {
        XCTAssertEqual(GardenShare.age(firstPractice: nil), 1)
    }

    func testAgeSurvivesClockSkew() {
        // first practice "in the future" (device clock changed) → still day 1, never negative
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        XCTAssertEqual(GardenShare.age(firstPractice: tomorrow, now: now), 1)
    }

    // MARK: - Voice contract (lowercase, zero dashes)

    func testVoiceObeysTheContract() {
        for s in GardenShare.allFixedStrings {
            XCTAssertEqual(s, s.lowercased(), "'\(s)' breaks lowercase")
            for dash in ["-", "\u{2013}", "\u{2014}"] {
                XCTAssertFalse(s.contains(dash), "'\(s)' contains a dash")
            }
        }
        XCTAssertEqual(GardenShare.caption(day: 8), "my little garden \u{00B7} day 8")
        XCTAssertEqual(GardenShare.postmarkDay(day: 8), "day 8")
    }

    // MARK: - Privacy sweep — the card carries the garden, a day, a stamp. nothing else.

    func testComposedCardStringInventoryIsExactAndClean() {
        let day = 12
        let inventory = GardenShare.cardStrings(day: day)
        // exact inventory — anything new on the card must be added here on purpose
        XCTAssertEqual(inventory, [
            "my little garden \u{00B7} day 12",
            "grown with dino \u{1F995}",
            "dino post",
            "day 12",
        ])
        // and none of it may leak inner weather, streaks, or progress mechanics
        let forbidden = ["clear", "partly cloudy", "overwhelmed", "drained",
                         "streak", "xp", "level", "%", "mood", "session"]
        for s in inventory {
            for f in forbidden {
                XCTAssertFalse(s.lowercased().contains(f), "'\(s)' leaks '\(f)' onto the card")
            }
        }
    }
}