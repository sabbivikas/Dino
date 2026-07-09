//
//  JournalMomentsTests.swift
//  DinoTests
//
//  Invitation gating (empty-only, dismissed-today, once-per-session,
//  availability), daypart mapping, and every seed-line template + fallback.
//

import XCTest
@testable import Dino

final class JournalMomentsTests: XCTestCase {

    // MARK: - Invitation gate

    private func invite(composerEmpty: Bool = true,
                        dismissedDayKey: String? = nil,
                        todayKey: String = "2026-07-09",
                        shownThisSession: Bool = false,
                        available: Bool = true) -> Bool {
        JournalMoments.shouldInvite(composerEmpty: composerEmpty,
                                    dismissedDayKey: dismissedDayKey,
                                    todayKey: todayKey,
                                    shownThisSession: shownThisSession,
                                    available: available)
    }

    func testInviteOnlyInEmptyComposer() {
        XCTAssertTrue(invite(composerEmpty: true))
        XCTAssertFalse(invite(composerEmpty: false))   // any text or photo kills it
    }

    func testDismissedTodayStaysQuietUntilTomorrow() {
        XCTAssertFalse(invite(dismissedDayKey: "2026-07-09", todayKey: "2026-07-09"))
        XCTAssertTrue(invite(dismissedDayKey: "2026-07-08", todayKey: "2026-07-09"))
    }

    func testOncePerComposerSession() {
        XCTAssertFalse(invite(shownThisSession: true))
    }

    func testUnavailableOSNeverInvites() {
        XCTAssertFalse(invite(available: false))
        // even when everything else is perfect
        XCTAssertFalse(invite(composerEmpty: true, dismissedDayKey: nil,
                              shownThisSession: false, available: false))
    }

    // MARK: - Daypart

    func testDaypartMapping() {
        XCTAssertEqual(JournalMoments.daypart(hour: 9), "morning")
        XCTAssertEqual(JournalMoments.daypart(hour: 5), "morning")
        XCTAssertEqual(JournalMoments.daypart(hour: 15), "afternoon")
        XCTAssertEqual(JournalMoments.daypart(hour: 20), "evening")
        XCTAssertNil(JournalMoments.daypart(hour: 2))     // deep night → "today"
        XCTAssertNil(JournalMoments.daypart(hour: 23))
    }

    // MARK: - Seed lines (one per type + every fallback)

    func testLocationLines() {
        XCTAssertEqual(JournalMoments.seedLine(for: .location(place: "The Lake", daypart: "afternoon")),
                       "the lake, this afternoon 🌿")
        XCTAssertEqual(JournalMoments.seedLine(for: .location(place: "Golden Gate Park", daypart: nil)),
                       "golden gate park, today 🌿")
        XCTAssertEqual(JournalMoments.seedLine(for: .location(place: nil, daypart: "morning")),
                       "somewhere that held today 🌿")
        XCTAssertEqual(JournalMoments.seedLine(for: .locationGroup(firstPlace: "North Beach")),
                       "north beach, and a little wandering 🌿")
        XCTAssertEqual(JournalMoments.seedLine(for: .locationGroup(firstPlace: nil)),
                       "somewhere that held today 🌿")
    }

    func testWorkoutAndMotionLines() {
        XCTAssertEqual(JournalMoments.seedLine(for: .workout(activity: "Running")),
                       "my body did some running today 🌿")
        XCTAssertEqual(JournalMoments.seedLine(for: .workout(activity: nil)),
                       "my body did something good today 🌿")
        XCTAssertEqual(JournalMoments.seedLine(for: .motion),
                       "today had a walk in it 🌿")
    }

    func testMediaLines() {
        XCTAssertEqual(JournalMoments.seedLine(for: .song(title: "Golden Hour")),
                       "golden hour has been in my ears today 🎧")
        XCTAssertEqual(JournalMoments.seedLine(for: .song(title: nil)),
                       "music carried a bit of today 🎧")
        XCTAssertEqual(JournalMoments.seedLine(for: .podcast(show: "Radiolab")),
                       "listened to radiolab today 🎧")
        XCTAssertEqual(JournalMoments.seedLine(for: .podcast(show: nil)),
                       "a voice kept me company today 🎧")
        XCTAssertEqual(JournalMoments.seedLine(for: .genericMedia),
                       "something i watched stayed with me today")
    }

    func testContactLineIsNeutralByOwnerDecision() {
        // no heart emoji: time with a person isn't always warm; the writer
        // brings the feeling
        XCTAssertEqual(JournalMoments.seedLine(for: .contact(name: "Sarah")),
                       "time with sarah today")
    }

    func testEverySeedLineIsSingleLineLowercaseDashFree() {
        let kinds: [MomentKind] = [
            .location(place: "Lake", daypart: "morning"), .location(place: nil, daypart: nil),
            .locationGroup(firstPlace: "Pier"), .locationGroup(firstPlace: nil),
            .workout(activity: "Yoga"), .workout(activity: nil),
            .motion, .song(title: "Song"), .song(title: nil),
            .podcast(show: "Show"), .podcast(show: nil),
            .contact(name: "Ana"), .genericMedia,
        ]
        for kind in kinds {
            let line = JournalMoments.seedLine(for: kind)
            XCTAssertFalse(line.contains("\n"), "\(kind) seeds more than one line")
            XCTAssertEqual(line, line.lowercased(), "\(kind) breaks lowercase voice")
            for dash in ["–", "—"] { XCTAssertFalse(line.contains(dash)) }
        }
    }
}
