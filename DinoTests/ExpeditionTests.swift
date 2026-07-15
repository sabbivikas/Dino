//
//  ExpeditionTests.swift
//  DinoTests
//
//  F1's pure parts: the bucketizers (raw numbers stop at the device edge),
//  on device eligibility (crisis first and absolute), and the two ignore
//  cooloff.
//

import XCTest
@testable import Dino

final class ExpeditionTests: XCTestCase {

    private let suite = "expedition-tests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - Bucketizers (enum out, never a number)

    func testHeavyDayBuckets() {
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(0), "0")
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(1), "1")
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(2), "2to3")
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(3), "2to3")
        XCTAssertEqual(ExpeditionSignals.heavyDaysBucket(7), "4plus")
    }

    func testSleepBuckets() {
        XCTAssertEqual(ExpeditionSignals.sleepBucket(hours: nil), "unknown",
                       "no health data is unknown, never a real looking bucket")
        XCTAssertEqual(ExpeditionSignals.sleepBucket(hours: 4.5), "short")
        XCTAssertEqual(ExpeditionSignals.sleepBucket(hours: 7.5), "ok")
        XCTAssertEqual(ExpeditionSignals.sleepBucket(hours: 10.0), "long")
    }

    func testStepsBuckets() {
        XCTAssertEqual(ExpeditionSignals.stepsBucket(steps: nil), "unknown",
                       "no health data is unknown, never a real looking bucket")
        XCTAssertEqual(ExpeditionSignals.stepsBucket(steps: 1200), "low")
        XCTAssertEqual(ExpeditionSignals.stepsBucket(steps: 5000), "mid")
        XCTAssertEqual(ExpeditionSignals.stepsBucket(steps: 12000), "high")
    }

    func testMoodOnlyUserEntersTheCohort() {
        // no watch, no permission, no health at all — mood signals alone
        // carry the full experience. eligibility takes no health inputs.
        XCTAssertTrue(ExpeditionSignals.isEligible(heavyDays: 2, crisisDate: nil,
                                                   defaults: defaults))
        XCTAssertEqual(ExpeditionSignals.sleepBucket(hours: nil), "unknown")
        XCTAssertEqual(ExpeditionSignals.stepsBucket(steps: nil), "unknown")
    }

    func testDaysSinceBuckets() {
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(nil), "14plus")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(0), "0to2")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(2), "0to2")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(5), "3to7")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(10), "8to13")
        XCTAssertEqual(ExpeditionSignals.daysSinceBucket(30), "14plus")
    }

    func testTrendMatchesTheRecBucketExactly() {
        for n in 0...7 {
            XCTAssertEqual(ExpeditionSignals.moodTrendBucket(heavyDays: n),
                           ComfortRecTrend.bucket(heavyDaysInLastWeek: n))
        }
    }

    // MARK: - Eligibility (crisis first and absolute)

    func testCrisisWindowBlocksEverything() {
        XCTAssertFalse(ExpeditionSignals.isEligible(heavyDays: 5, crisisDate: Date(),
                                                    defaults: defaults))
    }

    func testNoHeavySignalMeansNoCohort() {
        XCTAssertFalse(ExpeditionSignals.isEligible(heavyDays: 0, crisisDate: nil,
                                                    defaults: defaults))
        XCTAssertTrue(ExpeditionSignals.isEligible(heavyDays: 1, crisisDate: nil,
                                                   defaults: defaults))
    }

    func testToggleOffMeansQuiet() {
        defaults.set(false, forKey: ExpeditionSignals.enabledKey)
        XCTAssertFalse(ExpeditionSignals.isEligible(heavyDays: 5, crisisDate: nil,
                                                    defaults: defaults))
    }

    // MARK: - F3: voice contract (lowercase, zero dashes)

    func testVoiceObeysTheContract() {
        for s in ExpeditionVoice.allFixedStrings {
            XCTAssertEqual(s, s.lowercased(), "'\(s)' breaks lowercase")
            for dash in ["-", "\u{2013}", "\u{2014}"] {
                XCTAssertFalse(s.contains(dash), "'\(s)' contains a dash")
            }
        }
    }

    // MARK: - F3: parser (belt and suspenders at the door)

    private func serverDoc() -> [String: Any] {
        ["needKind": "hope",
         "gift": ["title": "Hope Is The Thing — With Feathers",
                  "source": "Poetry Foundation",
                  "excerpt": "hope is the thing with feathers that perches in the soul",
                  "url": "https://www.poetryfoundation.org/poems/42889",
                  "dinoLine": "dino went looking and this one sang back"] as [String: Any]]
    }

    func testParserCleansAndKeeps() {
        let gift = ExpeditionParser.gift(from: serverDoc())
        XCTAssertEqual(gift?.title, "hope is the thing with feathers")
        XCTAssertEqual(gift?.source, "poetry foundation")
        XCTAssertEqual(gift?.needKind, "hope")
    }

    func testParserRejectsBrokenGifts() {
        var d = serverDoc(); d["needKind"] = "revenge"
        XCTAssertNil(ExpeditionParser.gift(from: d))
        d = serverDoc()
        var g = d["gift"] as! [String: Any]; g["url"] = "http://x.org"; d["gift"] = g
        XCTAssertNil(ExpeditionParser.gift(from: d))
        d = serverDoc()
        g = d["gift"] as! [String: Any]; g["title"] = ""; d["gift"] = g
        XCTAssertNil(ExpeditionParser.gift(from: d))
    }

    // MARK: - F3: shown once, kept forever

    private var sampleGift: ExpeditionGift {
        ExpeditionGift(needKind: "hope", title: "t", source: "s", excerpt: "e",
                       url: "https://example.org/x", dinoLine: "l", foundAt: Date())
    }

    func testGiftPresentsOnceThenRests() {
        let gift = sampleGift
        XCTAssertTrue(ExpeditionStore.shouldPresent(gift, defaults: defaults))
        ExpeditionStore.markPresented(gift, defaults: defaults)
        XCTAssertFalse(ExpeditionStore.shouldPresent(gift, defaults: defaults),
                       "the dove never nags")
    }

    func testToggleOffSilencesDelivery() {
        defaults.set(false, forKey: ExpeditionSignals.enabledKey)
        XCTAssertFalse(ExpeditionStore.shouldPresent(sampleGift, defaults: defaults))
    }

    func testKeepsakeMappingCarriesTheDoor() {
        let rec = sampleGift.asKeepsakeRec
        XCTAssertEqual(rec.type, "gift")
        XCTAssertEqual(rec.watchLink, "https://example.org/x")
        XCTAssertEqual(rec.searchLinks.first?.label, ExpeditionVoice.openLink)
        XCTAssertEqual(rec.searchLinks.first?.url.host, "example.org")
        XCTAssertEqual(ComfortRecVoice.icon(type: "gift"), "\u{1F54A}")
    }

    func testTwoIgnoresEarnAThirtyDayCooloff() {
        XCTAssertTrue(ExpeditionSignals.isEligible(heavyDays: 3, crisisDate: nil, defaults: defaults))
        ExpeditionSignals.recordIgnore(defaults: defaults)
        XCTAssertTrue(ExpeditionSignals.isEligible(heavyDays: 3, crisisDate: nil, defaults: defaults),
                      "one ignore is not a signal yet")
        ExpeditionSignals.recordIgnore(defaults: defaults)
        XCTAssertFalse(ExpeditionSignals.isEligible(heavyDays: 3, crisisDate: nil, defaults: defaults),
                       "two ignores → 30 day quiet")
        // and the counter reset so a return is possible after the cooloff
        XCTAssertEqual(defaults.integer(forKey: ExpeditionSignals.ignoreCountKey), 0)
    }
}
