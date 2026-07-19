//
//  RecShelfTests.swift
//  DinoTests
//
//  Rec delivery F5 — the shelf catch: the merge/sort/dedupe rule (wrapped
//  parcels first, opened keepsakes newest-first, a just-opened delivery
//  deduped by identity), the everything · kept filter over the mixed shelf,
//  the on-device opened-id tracking, and the one new catalog string.
//

import XCTest
@testable import Dino

final class RecShelfTests: XCTestCase {

    // MARK: - helpers

    private func rec(_ title: String, type: String = "music") -> RichRec {
        RichRec(type: type, title: title, creator: "someone kind", year: 2000,
                why: "w", flags: ["a soft one"], feel: "quiet", length: "no rush at all")
    }

    private func keepsake(_ title: String, shownAt: Date, kept: Bool = false) -> RichRecStore.Keepsake {
        RichRecStore.Keepsake(rec: rec(title), shownAt: shownAt, kept: kept)
    }

    private func wrapped(_ id: String, _ announcedAt: Date) -> WrappedDelivery {
        WrappedDelivery(deliveryId: id, announcedAt: announcedAt)
    }

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - merge / sort

    func testWrappedParcelsLeadAndSortNewestFirst() {
        let entries = RecShelf.merge(
            wrapped: [wrapped("d-old", t0), wrapped("d-new", t0.addingTimeInterval(3600))],
            keepsakes: [keepsake("a pick", shownAt: t0.addingTimeInterval(7200))],
            openedIds: [])
        // wrapped-and-waiting first, newest announcement first, then the archive
        XCTAssertEqual(entries.map(\.id),
                       ["wrapped-d-new", "wrapped-d-old",
                        "opened-a pick-\(t0.addingTimeInterval(7200).timeIntervalSince1970)"])
    }

    func testOpenedKeepsakesSortNewestFirstAfterAnyParcels() {
        let entries = RecShelf.merge(
            wrapped: [],
            keepsakes: [keepsake("older", shownAt: t0),
                        keepsake("newer", shownAt: t0.addingTimeInterval(60))],
            openedIds: [])
        XCTAssertEqual(entries.map { e -> String in
            if case .opened(let k) = e { return k.rec.title } else { return "?" }
        }, ["newer", "older"])
    }

    // MARK: - dedupe (a just-opened delivery is one entry, never two)

    func testAnOpenedDeliveryIsDedupedOutOfTheWrappedParcels() {
        // the delivery was opened on this device (its keepsake now exists AND
        // its id is remembered) — it must NOT also show as a wrapped parcel,
        // even while the server still reports it 'announced' for a beat.
        let entries = RecShelf.merge(
            wrapped: [wrapped("d1", t0), wrapped("d2", t0)],
            keepsakes: [keepsake("the opened one", shownAt: t0)],
            openedIds: ["d1"])
        let ids = entries.map(\.id)
        XCTAssertFalse(ids.contains("wrapped-d1"), "the opened parcel must not linger")
        XCTAssertTrue(ids.contains("wrapped-d2"), "a still-wrapped sibling stays")
        XCTAssertEqual(ids.filter { $0.hasPrefix("wrapped-") }.count, 1)
    }

    // MARK: - the everything · kept filter over the mixed shelf

    func testKeptFilterHidesWrappedParcelsAndUnkeptKeepsakes() {
        let entries = RecShelf.merge(
            wrapped: [wrapped("d1", t0)],
            keepsakes: [keepsake("kept one", shownAt: t0.addingTimeInterval(2), kept: true),
                        keepsake("unkept one", shownAt: t0.addingTimeInterval(1), kept: false)],
            openedIds: [])
        // everything: the parcel + both keepsakes
        XCTAssertEqual(RecShelf.visible(entries, keptOnly: false).count, 3)
        // kept: only the kept opened keepsake (no parcel, no unkept)
        let kept = RecShelf.visible(entries, keptOnly: true)
        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(kept.first?.id, "opened-kept one-\(t0.addingTimeInterval(2).timeIntervalSince1970)")
        XCTAssertFalse(kept.contains { $0.isWrapped })
    }

    func testEmptyShelfIsEmptyEntries() {
        XCTAssertTrue(RecShelf.merge(wrapped: [], keepsakes: [], openedIds: []).isEmpty)
    }

    // MARK: - on-device opened-id tracking (persistent, capped, idempotent)

    func testMarkDeliveryOpenedPersistsAndIsIdempotent() {
        let d = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        XCTAssertTrue(RichRecStore.openedDeliveryIds(defaults: d).isEmpty)
        RichRecStore.markDeliveryOpened("abc", defaults: d)
        RichRecStore.markDeliveryOpened("abc", defaults: d)   // idempotent
        RichRecStore.markDeliveryOpened("def", defaults: d)
        XCTAssertEqual(RichRecStore.openedDeliveryIds(defaults: d), ["abc", "def"])
        RichRecStore.markDeliveryOpened("", defaults: d)      // empty is a no-op
        XCTAssertEqual(RichRecStore.openedDeliveryIds(defaults: d).count, 2)
    }

    // MARK: - the wrapped-delivery fixture only answers the QA flag

    @MainActor
    func testWrappedQAFixturesOnlyUnderTheFlag() {
        XCTAssertNil(RecRevealService.qaWrappedDeliveries(arguments: []))
        let fixtures = RecRevealService.qaWrappedDeliveries(arguments: ["-recShelfWrappedQA"])
        XCTAssertEqual(fixtures?.count, 2)
        // both ids are qa- prefixed so a tap routes through the reveal fixtures
        XCTAssertTrue(fixtures?.allSatisfy { $0.deliveryId.hasPrefix("qa-") } ?? false)
    }

    // MARK: - the one new string (×4 with the shipped voice)

    func testStillWrappedCarriesAllFourTranslationsInTheCatalog() throws {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Dino/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = (json?["strings"] as? [String: Any]) ?? [:]
        guard let entry = strings["still wrapped · tap to open"] as? [String: Any],
              let locs = entry["localizations"] as? [String: Any] else {
            return XCTFail("missing catalog entry: still wrapped · tap to open")
        }
        for lang in ["en", "es", "ja", "ko", "vi"] {
            guard let l = locs[lang] as? [String: Any],
                  let unit = l["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String, !value.isEmpty else {
                XCTFail("still wrapped missing \(lang)"); continue
            }
            // no dashes anywhere (the middot is intentional, dashes are not)
            XCTAssertFalse(value.contains("\u{2014}") || value.contains("\u{2013}") || value.contains(" - "),
                           "dash in \(lang): \(value)")
            XCTAssertTrue(value.contains("\u{00B7}"), "middot preserved in \(lang): \(value)")
        }
        // english byte-exact, lowercase
        let en = (locs["en"] as? [String: Any])
            .flatMap { $0["stringUnit"] as? [String: Any] }?["value"] as? String
        XCTAssertEqual(en, "still wrapped \u{00B7} tap to open")
        XCTAssertEqual(en, en?.lowercased())
    }
}
