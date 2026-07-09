//
//  SiriVoiceTests.swift
//  DinoTests
//
//  Synonym mapping, deterministic reply rotation, the night-window rule,
//  and the voice-rule invariants (short, lowercase, dash free, spoken lines
//  never lean on emoji).
//

import XCTest
@testable import Dino

final class SiriVoiceTests: XCTestCase {

    // MARK: - Synonym table

    func testEverySynonymMapsToItsFamily() {
        for row in MoodSynonyms.table {
            for synonym in row.synonyms {
                XCTAssertEqual(MoodSynonyms.match(synonym), row.weather,
                               "'\(synonym)' should map to \(row.weather)")
            }
        }
    }

    func testOwnerAdditionsAndFlags() {
        XCTAssertEqual(MoodSynonyms.match("sad"), .drained)          // owner addition
        XCTAssertEqual(MoodSynonyms.match("nervous"), .overwhelmed)  // shipped, flagged for revisit
    }

    func testPrefixStrippingAndNormalization() {
        XCTAssertEqual(MoodSynonyms.match("i'm feeling exhausted"), .drained)
        XCTAssertEqual(MoodSynonyms.match("I FEEL SO STRESSED"), .overwhelmed)
        XCTAssertEqual(MoodSynonyms.match("really really good"), .clear)
        XCTAssertEqual(MoodSynonyms.match("kinda meh."), .partlyCloudy)
        XCTAssertEqual(MoodSynonyms.match("burnt-out"), .drained)    // punctuation → space
    }

    func testUnknownMoodReturnsNilForDisambiguation() {
        XCTAssertNil(MoodSynonyms.match("purple"))
        XCTAssertNil(MoodSynonyms.match(""))
        XCTAssertNil(MoodSynonyms.match("hungry"))
    }

    // MARK: - Donated entity synonyms (inline phrase matching)

    func testDonatedSynonymsRoundTripToTheirFamily() {
        for weather in EmotionalWeather.allCases {
            let synonyms = MoodSynonyms.synonyms(for: weather)
            XCTAssertFalse(synonyms.isEmpty, "\(weather) donates no synonyms")
            // every donated synonym must resolve back to the same family
            for s in synonyms {
                XCTAssertEqual(MoodSynonyms.match(s), weather,
                               "donated '\(s)' resolves to the wrong family")
            }
            // the canonical label is the title, never duplicated as a synonym
            XCTAssertFalse(synonyms.contains(weather.label))
        }
    }

    // MARK: - Reply rotation (deterministic, never twice in a row)

    func testMoodLineRotationIsDeterministicAndVaries() {
        for weather in EmotionalWeather.allCases {
            let a = SiriReplies.moodLine(for: weather, rotation: 0)
            let b = SiriReplies.moodLine(for: weather, rotation: 1)
            XCTAssertNotEqual(a, b, "\(weather) rotation should vary")
            XCTAssertEqual(a, SiriReplies.moodLine(for: weather, rotation: 0))  // deterministic
        }
        XCTAssertNotEqual(SiriReplies.gratitudeLine(rotation: 0), SiriReplies.gratitudeLine(rotation: 1))
    }

    // MARK: - Night window (21:00 through 04:59)

    func testNightWindowBoundaries() {
        XCTAssertFalse(SiriReplies.isNight(hour: 20))   // 20:59 is day
        XCTAssertTrue(SiriReplies.isNight(hour: 21))
        XCTAssertTrue(SiriReplies.isNight(hour: 0))
        XCTAssertTrue(SiriReplies.isNight(hour: 4))     // 04:59 is night
        XCTAssertFalse(SiriReplies.isNight(hour: 5))    // 05:00 is day
    }

    func testJournalLineSelection() {
        XCTAssertEqual(SiriReplies.journalLine(hour: 2), "kept. sleep well.")
        XCTAssertEqual(SiriReplies.journalLine(hour: 14), "kept. it's safe here.")
    }

    // MARK: - Voice rules (short, lowercase, dash free, no spoken emoji)

    func testEverySpokenLineObeysTheVoiceRules() {
        let spoken = SiriReplies.drainedLines + SiriReplies.overwhelmedLines
            + SiriReplies.partlyCloudyLines + SiriReplies.clearLines
            + SiriReplies.gratitudeLines
            + [SiriReplies.journalNightLine, SiriReplies.journalDayLine,
               SiriReplies.emptyCaptureLine]
        for line in spoken {
            XCTAssertEqual(line, line.lowercased(), "'\(line)' breaks lowercase")
            XCTAssertLessThanOrEqual(line.split(separator: " ").count, 8, "'\(line)' too long to speak softly")
            for dash in ["–", "—"] { XCTAssertFalse(line.contains(dash)) }
            // warmth in words alone — spoken lines carry no emoji
            XCTAssertTrue(line.allSatisfy { $0.isASCII }, "'\(line)' leans on emoji when spoken")
        }
    }

    func testReturnLine() {
        XCTAssertEqual(SiriReplies.returnLine(weekday: "Tuesday"),
                       "while you were away, i kept your tuesday 🌿")
    }
}
