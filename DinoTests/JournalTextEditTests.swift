//
//  JournalTextEditTests.swift
//  DinoTests
//
//  Pure semantics of journal text editing: in-place by id, everything but
//  summary/updatedAt preserved, empty text is a no-op (never a silent blank),
//  and display order is unaffected by edits.
//

import XCTest
@testable import Dino

final class JournalTextEditTests: XCTestCase {

    private func makeEntry(_ text: String, date: Date, id: UUID = UUID()) -> JournalEntry {
        JournalEntry(id: id, date: date, audioFileName: "", title: "t",
                     summary: text, createdAt: date)
    }

    func testEditsInPlaceByIdAndPreservesEverythingElse() {
        let d1 = Date(timeIntervalSince1970: 1_000_000)
        let d2 = Date(timeIntervalSince1970: 2_000_000)
        let target = JournalEntry(id: UUID(), date: d1, audioFileName: "a.m4a",
                                  title: "t", summary: "unfinished thou",
                                  moodTag: "reflective", isFavorite: true,
                                  durationSeconds: 12, photoFileName: "p.jpg",
                                  createdAt: d1)
        let other = makeEntry("other", date: d2)
        let now = Date(timeIntervalSince1970: 3_000_000)

        let result = JournalEntry.applyingTextEdit(
            to: [other, target], id: target.id, newText: "unfinished thought, now finished", now: now)

        XCTAssertNotNil(result)
        let edited = result!.first { $0.id == target.id }!
        XCTAssertEqual(result!.count, 2, "in place — never a new entry")
        XCTAssertEqual(edited.summary, "unfinished thought, now finished")
        XCTAssertEqual(edited.updatedAt, now, "updatedAt stamped")
        XCTAssertEqual(edited.date, d1, "entry date preserved")
        XCTAssertEqual(edited.createdAt, d1, "createdAt preserved")
        XCTAssertEqual(edited.audioFileName, "a.m4a", "audio untouched")
        XCTAssertEqual(edited.photoFileName, "p.jpg")
        XCTAssertTrue(edited.isFavorite)
        // the other entry is byte-for-byte untouched
        let untouched = result!.first { $0.id == other.id }!
        XCTAssertEqual(untouched.summary, "other")
        XCTAssertNil(untouched.updatedAt)
    }

    func testTrimsWhitespace() {
        let e = makeEntry("old", date: Date())
        let result = JournalEntry.applyingTextEdit(to: [e], id: e.id, newText: "  new words \n")
        XCTAssertEqual(result?.first?.summary, "new words")
    }

    func testEmptyAndWhitespaceTextIsNoOpNeverASilentBlank() {
        let e = makeEntry("precious words", date: Date())
        XCTAssertNil(JournalEntry.applyingTextEdit(to: [e], id: e.id, newText: ""))
        XCTAssertNil(JournalEntry.applyingTextEdit(to: [e], id: e.id, newText: "   \n  "))
    }

    func testUnknownIdIsNoOp() {
        let e = makeEntry("words", date: Date())
        XCTAssertNil(JournalEntry.applyingTextEdit(to: [e], id: UUID(), newText: "new"))
    }

    func testUnchangedTextIsNoOp() {
        let e = makeEntry("same words", date: Date())
        XCTAssertNil(JournalEntry.applyingTextEdit(to: [e], id: e.id, newText: "same words"))
        XCTAssertNil(JournalEntry.applyingTextEdit(to: [e], id: e.id, newText: "  same words  "),
                     "trimmed-equal counts as unchanged")
    }

    func testDisplayOrderUnaffectedByEdit() {
        let base = Date(timeIntervalSince1970: 5_000_000)
        let entries = (0..<5).map { i in
            makeEntry("entry \(i)", date: base.addingTimeInterval(Double(i) * 86_400))
        }
        let orderBefore = JournalEntry.sortedForDisplay(entries).map(\.id)
        let edited = JournalEntry.applyingTextEdit(
            to: entries, id: entries[2].id, newText: "edited middle entry",
            now: base.addingTimeInterval(999_999_999))!
        let orderAfter = JournalEntry.sortedForDisplay(edited).map(\.id)
        XCTAssertEqual(orderBefore, orderAfter, "updatedAt never reorders the strip")
    }
}
