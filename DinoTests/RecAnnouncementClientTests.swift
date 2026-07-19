//
//  RecAnnouncementClientTests.swift
//  DinoTests
//
//  Rec delivery F3 — client side: the parcel-raise decision, the push-token
//  prefs gate, the reveal deep link, and the locked announcement strings
//  (both catalogs, all four languages, dino's voice rules).
//

import XCTest
@testable import Dino

final class RecAnnouncementClientTests: XCTestCase {

    // MARK: - The parcel-raise decision (never spammy)

    func testParcelRaisesOnlyForAFreshAnnouncement() {
        let now = Date()
        XCTAssertTrue(RecAnnouncementObserver.shouldRaiseParcel(
            announcedAt: now.addingTimeInterval(-60), now: now, masterEnabled: true))
        XCTAssertTrue(RecAnnouncementObserver.shouldRaiseParcel(
            announcedAt: now.addingTimeInterval(-6 * 3600 + 1), now: now, masterEnabled: true))
        XCTAssertFalse(RecAnnouncementObserver.shouldRaiseParcel(
            announcedAt: now.addingTimeInterval(-6 * 3600), now: now, masterEnabled: true),
            "6h is the parcel's whole life — at the boundary it stays down")
        XCTAssertFalse(RecAnnouncementObserver.shouldRaiseParcel(
            announcedAt: now.addingTimeInterval(-7 * 3600), now: now, masterEnabled: true))
    }

    func testParcelNeverRaisesWithNotificationsMasterOff() {
        let now = Date()
        XCTAssertFalse(RecAnnouncementObserver.shouldRaiseParcel(
            announcedAt: now.addingTimeInterval(-60), now: now, masterEnabled: false),
            "master toggle off = dino stays quiet on every channel")
    }

    func testParcelHandlesMissingOrFutureAnnouncement() {
        let now = Date()
        XCTAssertFalse(RecAnnouncementObserver.shouldRaiseParcel(
            announcedAt: nil, now: now, masterEnabled: true))
        // a clock-skewed future stamp still counts as fresh? no — age < 0 skips
        XCTAssertFalse(RecAnnouncementObserver.shouldRaiseParcel(
            announcedAt: now.addingTimeInterval(120), now: now, masterEnabled: true))
    }

    func testParcelLifetimeIsSixHours() {
        XCTAssertEqual(RecParcelActivityAttributes.lifetime, 6 * 3600)
    }

    // MARK: - The push-token prefs gate

    func testTokenStoresOnlyWhenEveryConsentHolds() {
        XCTAssertTrue(RecPushTokenStore.shouldStoreToken(
            signedIn: true, hasPermission: true, masterEnabled: true))
        XCTAssertFalse(RecPushTokenStore.shouldStoreToken(
            signedIn: false, hasPermission: true, masterEnabled: true))
        XCTAssertFalse(RecPushTokenStore.shouldStoreToken(
            signedIn: true, hasPermission: false, masterEnabled: true))
        XCTAssertFalse(RecPushTokenStore.shouldStoreToken(
            signedIn: true, hasPermission: true, masterEnabled: false))
    }

    // MARK: - The reveal deep link (F4 inherits this route)

    func testRecRevealLinkParsesTheRoute() {
        let link = RecRevealLink.from(url: URL(string: "dino://rec-reveal/abc123")!)
        XCTAssertEqual(link?.deliveryId, "abc123")
        XCTAssertEqual(link?.id, "abc123")
    }

    func testRecRevealLinkRejectsMalformedUrls() {
        XCTAssertNil(RecRevealLink.from(url: URL(string: "dino://rec-reveal")!))
        XCTAssertNil(RecRevealLink.from(url: URL(string: "dino://rec-reveal/")!))
        XCTAssertNil(RecRevealLink.from(url: URL(string: "dino://mood")!))
        XCTAssertNil(RecRevealLink.from(url: URL(string: "https://rec-reveal/abc")!))
    }

    // MARK: - The locked strings (both catalogs, ×4 + english)

    private func catalogStrings(_ relativePath: String) throws -> [String: Any] {
        // DinoTests/…/this file → repo root → the catalog
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["strings"] as? [String: Any]) ?? [:]
    }

    private func assertKey(_ key: String, in strings: [String: Any],
                           expectedEnglish: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let entry = strings[key] as? [String: Any],
              let locs = entry["localizations"] as? [String: Any] else {
            XCTFail("missing catalog entry: \(key)", file: file, line: line); return
        }
        for lang in ["en", "es", "ja", "ko", "vi"] {
            guard let l = locs[lang] as? [String: Any],
                  let unit = l["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String, !value.isEmpty else {
                XCTFail("\(key) missing \(lang)", file: file, line: line); continue
            }
            XCTAssertFalse(value.contains("\u{2014}") || value.contains("\u{2013}") || value.contains(" - "),
                           "dash in \(lang) of \(key): \(value)", file: file, line: line)
            if lang == "en" {
                XCTAssertEqual(value, expectedEnglish, "english drifted for \(key)", file: file, line: line)
            }
            if lang == "es" || lang == "vi" {
                XCTAssertEqual(value, value.lowercased(), "case in \(lang) of \(key)", file: file, line: line)
            }
        }
    }

    func testPushLocKeysCarryTheLockedCopyInAllLanguages() throws {
        let strings = try catalogStrings("Dino/Localizable.xcstrings")
        // the LOCKED spec strings — lowercase, no dashes, dino's voice
        assertKey("rec_announcement_title", in: strings,
                  expectedEnglish: "dino found something for you")
        assertKey("rec_announcement_body", in: strings,
                  expectedEnglish: "what is it? \u{1F381}")
    }

    func testLiveActivityLinesCarryAllLanguagesInTheWidgetCatalog() throws {
        let strings = try catalogStrings("DinoLiveActivity/Localizable.xcstrings")
        assertKey("dino has something for you", in: strings,
                  expectedEnglish: "dino has something for you")
        assertKey("what is it? \u{1F381}", in: strings,
                  expectedEnglish: "what is it? \u{1F381}")
    }
}
