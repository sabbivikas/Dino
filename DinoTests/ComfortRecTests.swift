//
//  ComfortRecTests.swift
//  DinoTests
//
//  Feature 1's pure parts: the voice contract, the daypart header, the
//  sanitizer (never trust the server), trend buckets, plain search links,
//  and the local cache + keepsakes store.
//

import XCTest
@testable import Dino

final class ComfortRecTests: XCTestCase {

    private let suite = "comfort-rec-tests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - Voice contract (lowercase, zero dashes)

    func testVoiceObeysTheContract() {
        for s in ComfortRecVoice.allFixedStrings {
            XCTAssertEqual(s, s.lowercased(), "'\(s)' breaks lowercase")
            for dash in ["-", "\u{2013}", "\u{2014}"] {
                XCTAssertFalse(s.contains(dash), "'\(s)' contains a dash")
            }
        }
    }

    func testHeaderFollowsTheHour() {
        // owner tweak: no forced moon at midday
        XCTAssertNotEqual(ComfortRecVoice.header(hour: 13), ComfortRecVoice.header(hour: 21))
        XCTAssertFalse(ComfortRecVoice.header(hour: 13).contains("🌙"))
        XCTAssertTrue(ComfortRecVoice.header(hour: 21).contains("🌙"))
    }

    // MARK: - Sanitizer (never trust the server)

    private func sampleDict() -> [String: Any] {
        ["type": "Music", "title": "Music for Airports", "creator": "Brian Eno",
         "year": 1978, "why": "A Soft — Landing", "flags": ["not graphic", "chainsaws"],
         "feel": "QUIET", "length": "about 48 minutes"]
    }

    func testSanitizerCleansAndLowercases() {
        let rec = ComfortRecSanitizer.rec(from: sampleDict())
        XCTAssertEqual(rec?.title, "music for airports")
        XCTAssertEqual(rec?.creator, "brian eno")
        XCTAssertEqual(rec?.why, "a soft landing")     // dash gone, spaces collapsed
        XCTAssertEqual(rec?.feel, "quiet")
        XCTAssertEqual(rec?.flags, ["not graphic"])    // allowlist only
    }

    func testSanitizerRejectsBrokenRecs() {
        var d = sampleDict(); d["type"] = "podcast"
        XCTAssertNil(ComfortRecSanitizer.rec(from: d))
        d = sampleDict(); d["title"] = ""
        XCTAssertNil(ComfortRecSanitizer.rec(from: d))
        d = sampleDict(); d["year"] = 1850
        XCTAssertNil(ComfortRecSanitizer.rec(from: d))
    }

    func testEmptyWhyGetsTheFallbackNeverBlank() {
        var d = sampleDict(); d["why"] = ""
        XCTAssertEqual(ComfortRecSanitizer.rec(from: d)?.why, ComfortRecVoice.fallbackWhy)
    }

    func testEmptyFlagsGetTheSoftDefault() {
        var d = sampleDict(); d["flags"] = ["gore"]
        XCTAssertEqual(ComfortRecSanitizer.rec(from: d)?.flags, ["a soft one"])
    }

    // MARK: - Trend buckets (privacy: the word travels, never the count)

    func testTrendBuckets() {
        XCTAssertEqual(ComfortRecTrend.bucket(heavyDaysInLastWeek: 0), "steady")
        XCTAssertEqual(ComfortRecTrend.bucket(heavyDaysInLastWeek: 1), "steady")
        XCTAssertEqual(ComfortRecTrend.bucket(heavyDaysInLastWeek: 2), "wobbly")
        XCTAssertEqual(ComfortRecTrend.bucket(heavyDaysInLastWeek: 3), "wobbly")
        XCTAssertEqual(ComfortRecTrend.bucket(heavyDaysInLastWeek: 4), "heavy")
        XCTAssertEqual(ComfortRecTrend.bucket(heavyDaysInLastWeek: 7), "heavy")
    }

    // MARK: - Search links (plain URLs, no APIs)

    private func rec(type: String, title: String = "music for airports") -> RichRec {
        RichRec(type: type, title: title, creator: "brian eno", year: 1978,
                why: "w", flags: ["a soft one"], feel: "quiet", length: "about 48 minutes")
    }

    func testMusicGetsBothStores() {
        let links = rec(type: "music").searchLinks
        XCTAssertEqual(links.map(\.label),
                       [ComfortRecVoice.openAppleMusic, ComfortRecVoice.openSpotify])
        XCTAssertEqual(links[0].url.host, "music.apple.com")
        XCTAssertEqual(links[1].url.host, "open.spotify.com")
    }

    func testBookAndFilmLinks() {
        XCTAssertEqual(rec(type: "book").searchLinks.map(\.label), [ComfortRecVoice.openBooks])
        XCTAssertEqual(rec(type: "book").searchLinks.first?.url.host, "books.apple.com")
        XCTAssertEqual(rec(type: "film").searchLinks.map(\.label), [ComfortRecVoice.openTV])
        XCTAssertEqual(rec(type: "film").searchLinks.first?.url.host, "tv.apple.com")
    }

    func testSearchTermIsPercentEncoded() {
        let url = rec(type: "music").searchLinks[0].url.absoluteString
        XCTAssertFalse(url.contains(" "), "spaces must be encoded")
        XCTAssertTrue(url.contains("music%20for%20airports"))
    }

    // MARK: - Cache (show one, keep two, never keep stale)

    func testCacheConsumesInOrder() {
        let now = Date()
        RichRecStore.save(RichRecBatch(recs: [rec(type: "music"), rec(type: "book")],
                                       fetchedAt: now), defaults: defaults)
        XCTAssertEqual(RichRecStore.consumeOne(defaults: defaults, now: now)?.type, "music")
        XCTAssertEqual(RichRecStore.loadCache(defaults: defaults, now: now)?.recs.count, 1)
        XCTAssertEqual(RichRecStore.consumeOne(defaults: defaults, now: now)?.type, "book")
        XCTAssertNil(RichRecStore.consumeOne(defaults: defaults, now: now))
    }

    func testStaleCacheIsDiscarded() {
        let old = Calendar.current.date(byAdding: .day, value: -46, to: Date())!
        RichRecStore.save(RichRecBatch(recs: [rec(type: "music")], fetchedAt: old),
                          defaults: defaults)
        XCTAssertNil(RichRecStore.consumeOne(defaults: defaults))
    }

    // MARK: - Keepsakes (feature 3's shelf starts honest)

    func testKeepsakesNewestFirstAndCapped() {
        for i in 0..<30 {
            RichRecStore.recordKeepsake(rec(type: "music", title: "t\(i)"), defaults: defaults)
        }
        let kept = RichRecStore.keepsakes(defaults: defaults)
        XCTAssertEqual(kept.count, RichRecStore.keepsakeCap)
        XCTAssertEqual(kept.first?.rec.title, "t29")
    }

    func testExcludeTitlesCapsAtTen() {
        for i in 0..<12 {
            RichRecStore.recordKeepsake(rec(type: "music", title: "t\(i)"), defaults: defaults)
        }
        XCTAssertEqual(RichRecStore.excludeTitles(defaults: defaults).count, 10)
    }
}
