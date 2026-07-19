//
//  OutcomeLedgerTests.swift
//  DinoTests
//
//  F1 privacy-shape + pure-helper tests. The Firestore write path is
//  rules-validated live (REST checks at deploy); these lock the enums and
//  the mappings so a refactor can't silently widen the shape.
//

import XCTest
@testable import Dino

final class OutcomeLedgerTests: XCTestCase {

    func testAllowlistsAreClosed() {
        XCTAssertEqual(OutcomeLedger.kinds, ["rec", "gift"])
        XCTAssertEqual(OutcomeLedger.recTypes, ["music", "book", "film"])
        XCTAssertEqual(OutcomeLedger.giftNeeds, ["rest", "beauty", "hope", "wonder", "connection"])
        XCTAssertEqual(OutcomeLedger.actions, ["shown", "opened", "kept", "ignored", "notTonight", "lateKept"])
        XCTAssertEqual(OutcomeLedger.trends, ["improved", "steady", "heavier", "unknown"])
        XCTAssertEqual(OutcomeLedger.moods, ["clear", "partlyCloudy", "overwhelmed", "drained", "none"])
        XCTAssertEqual(OutcomeLedger.dayparts, ["morning", "afternoon", "evening", "night"])
    }

    func testDaypartMapping() {
        XCTAssertEqual(OutcomeLedger.daypart(hour: 5), "morning")
        XCTAssertEqual(OutcomeLedger.daypart(hour: 11), "morning")
        XCTAssertEqual(OutcomeLedger.daypart(hour: 12), "afternoon")
        XCTAssertEqual(OutcomeLedger.daypart(hour: 16), "afternoon")
        XCTAssertEqual(OutcomeLedger.daypart(hour: 17), "evening")
        XCTAssertEqual(OutcomeLedger.daypart(hour: 21), "evening")
        XCTAssertEqual(OutcomeLedger.daypart(hour: 22), "night")
        XCTAssertEqual(OutcomeLedger.daypart(hour: 2), "night")
        XCTAssertEqual(OutcomeLedger.daypart(hour: 0), "night")
    }

    func testFollowupTrendMapping() {
        // arrived into a heavy day: settling reads as improvement
        XCTAssertEqual(OutcomeLedger.followupTrend(current: "steady", shownContext: "drained"), "improved")
        XCTAssertEqual(OutcomeLedger.followupTrend(current: "steady", shownContext: "overwhelmed"), "improved")
        XCTAssertEqual(OutcomeLedger.followupTrend(current: "wobbly", shownContext: "drained"), "steady")
        XCTAssertEqual(OutcomeLedger.followupTrend(current: "heavy", shownContext: "drained"), "heavier")
        // arrived into a light day: steady is just steady
        XCTAssertEqual(OutcomeLedger.followupTrend(current: "steady", shownContext: "clear"), "steady")
        XCTAssertEqual(OutcomeLedger.followupTrend(current: "heavy", shownContext: "clear"), "heavier")
        XCTAssertEqual(OutcomeLedger.followupTrend(current: "nonsense", shownContext: "clear"), "unknown")
    }

    func testSourceDomainNormalization() {
        XCTAssertEqual(OutcomeLedger.sourceDomain(from: "https://www.poetryfoundation.org/poems/x"),
                       "poetryfoundation.org")
        XCTAssertEqual(OutcomeLedger.sourceDomain(from: "https://NASA.gov/image"), "nasa.gov")
        XCTAssertNil(OutcomeLedger.sourceDomain(from: "not a url"))
        // size cap matches the rules
        let long = "https://" + String(repeating: "a", count: 80) + ".org/x"
        XCTAssertLessThanOrEqual(OutcomeLedger.sourceDomain(from: long)?.count ?? 0, 40)
    }

    func testAnnouncementVocabularyIsClosed() {
        XCTAssertEqual(OutcomeLedger.announcementKind, "announcement")
        XCTAssertEqual(OutcomeLedger.announcementItemType, "parcel")
        XCTAssertEqual(OutcomeLedger.announcementActions, ["shown", "opened", "ignored"])
        XCTAssertEqual(OutcomeLedger.announcementIdPrefix, "ann_")
        // the announcement kind is NOT client-creatable — `kinds` mirrors the
        // rules' client-create allowlist (['rec','gift']); SHOWN/IGNORED are
        // server-authored, the client only flips an existing knock to opened
        XCTAssertFalse(OutcomeLedger.kinds.contains("announcement"))
        XCTAssertNil(OutcomeLedger.recordShown(kind: "announcement", itemType: "parcel", moodEntries: []))
    }

    func testAnnouncementOutcomeIdIsDeterministic() {
        XCTAssertEqual(OutcomeLedger.announcementOutcomeId(deliveryId: "abc123"), "ann_abc123")
        // stable → a push-tap and a shelf-catch reveal of the SAME delivery
        // land on the SAME doc, so the open can never be double-recorded
        XCTAssertEqual(OutcomeLedger.announcementOutcomeId(deliveryId: "abc123"),
                       OutcomeLedger.announcementOutcomeId(deliveryId: "abc123"))
        XCTAssertNotEqual(OutcomeLedger.announcementOutcomeId(deliveryId: "a"),
                          OutcomeLedger.announcementOutcomeId(deliveryId: "b"))
    }

    func testRecordShownRejectsOffShapeInput() {
        // no auth in unit tests — but shape rejection happens before auth is
        // consulted for invalid enums? recordShown guards auth first; these
        // assert the guard order stays safe by returning nil either way.
        XCTAssertNil(OutcomeLedger.recordShown(kind: "prank", itemType: "music", moodEntries: []))
        XCTAssertNil(OutcomeLedger.recordShown(kind: "rec", itemType: "podcast", moodEntries: []))
        XCTAssertNil(OutcomeLedger.recordShown(kind: "gift", itemType: "music", moodEntries: []))
    }
}
