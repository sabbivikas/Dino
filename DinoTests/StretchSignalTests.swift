//
//  StretchSignalTests.swift
//  DinoTests
//
//  Support-row triggers, the single-heavy-log-shows-NOTHING rule, the 7-day
//  cooldown, region resolution incl. unknown→fallback, directory integrity,
//  and the share once-ever logic.
//

import XCTest
@testable import Dino

final class StretchSignalTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }()

    private var now: Date { date(2024, 6, 20, 18) }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return cal.date(from: comps)!
    }

    private func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }

    private func offer(moods: [(date: Date, weather: EmotionalWeather)],
                       toggleOn: Bool = false,
                       themesToday: [String] = [],
                       lastShownAt: Date? = nil) -> Bool {
        StretchSignal.shouldOffer(moodEntries: moods, journalToggleOn: toggleOn,
                                  journalThemesToday: themesToday,
                                  lastShownAt: lastShownAt, now: now, calendar: cal)
    }

    // MARK: - The cardinal rule

    func testSingleIsolatedHeavyLogShowsNothing() {
        // a tired tuesday is not a crisis
        XCTAssertFalse(offer(moods: [(now, .drained)]))
        XCTAssertFalse(offer(moods: [(now, .overwhelmed)]))
        // even with the journal toggle on but no self theme
        XCTAssertFalse(offer(moods: [(now, .drained)], toggleOn: true, themesToday: ["work"]))
    }

    // MARK: - Trigger a: 3+ heavy logs within 5 days

    func testThreeHeavyLogsInFiveDaysFires() {
        let moods: [(Date, EmotionalWeather)] = [
            (hoursAgo(2), .drained),
            (hoursAgo(50), .overwhelmed),
            (hoursAgo(100), .drained),   // ~4.2 days ago, inside the window
        ]
        XCTAssertTrue(offer(moods: moods))
    }

    func testHeavyLogsOutsideWindowDoNotCount() {
        let moods: [(Date, EmotionalWeather)] = [
            (hoursAgo(2), .drained),
            (hoursAgo(24 * 6), .drained),    // 6 days ago — outside
            (hoursAgo(24 * 8), .overwhelmed),
        ]
        XCTAssertFalse(offer(moods: moods))
    }

    func testClearLogsNeverCount() {
        let moods: [(Date, EmotionalWeather)] = [
            (hoursAgo(2), .drained),
            (hoursAgo(20), .clear),
            (hoursAgo(40), .partlyCloudy),
        ]
        XCTAssertFalse(offer(moods: moods))
    }

    // MARK: - Trigger b: overwhelmed twice within 48h

    func testOverwhelmedTwiceWithin48HoursFires() {
        XCTAssertTrue(offer(moods: [(hoursAgo(1), .overwhelmed), (hoursAgo(40), .overwhelmed)]))
    }

    func testOverwhelmedPairBeyond48HoursDoesNotFire() {
        XCTAssertFalse(offer(moods: [(hoursAgo(1), .overwhelmed), (hoursAgo(50), .overwhelmed)]))
    }

    func testStaleOverwhelmedPairDoesNotFire() {
        // an old pair (both >48h ago) must not fire today
        XCTAssertFalse(offer(moods: [(hoursAgo(60), .overwhelmed), (hoursAgo(80), .overwhelmed)]))
    }

    // MARK: - Trigger c: heavy today + journal theme "self" (toggle-gated)

    func testHeavyPlusSelfThemeFiresOnlyWithToggle() {
        let moods: [(Date, EmotionalWeather)] = [(now, .drained)]
        XCTAssertTrue(offer(moods: moods, toggleOn: true, themesToday: ["self"]))
        XCTAssertFalse(offer(moods: moods, toggleOn: false, themesToday: ["self"]))
        XCTAssertFalse(offer(moods: moods, toggleOn: true, themesToday: ["money"]))
    }

    func testSelfThemeAloneWithoutHeavyLogDoesNotFire() {
        XCTAssertFalse(offer(moods: [(now, .clear)], toggleOn: true, themesToday: ["self"]))
    }

    // MARK: - Cooldown

    func testCooldownBlocksForSevenDays() {
        let firing: [(Date, EmotionalWeather)] = [
            (hoursAgo(1), .overwhelmed), (hoursAgo(30), .overwhelmed),
        ]
        XCTAssertTrue(offer(moods: firing, lastShownAt: nil))
        XCTAssertFalse(offer(moods: firing, lastShownAt: cal.date(byAdding: .day, value: -2, to: now)))
        XCTAssertFalse(offer(moods: firing, lastShownAt: cal.date(byAdding: .day, value: -6, to: now)))
        XCTAssertTrue(offer(moods: firing, lastShownAt: cal.date(byAdding: .day, value: -7, to: now)))
    }

    // MARK: - Region resolution

    func testKnownRegionsResolve() {
        for code in ["US", "GB", "JP", "KR", "IN", "BR"] {
            let r = CrisisResources.resources(for: code)
            XCTAssertFalse(r.isFallback, "\(code) should have its own directory")
            XCTAssertFalse(r.list.isEmpty)
        }
        // lowercase device values resolve too
        XCTAssertFalse(CrisisResources.resources(for: "us").isFallback)
    }

    func testUnknownRegionFallsBackInternational() {
        for code in ["ZZ", "", "USA", nil] as [String?] {
            let r = CrisisResources.resources(for: code)
            XCTAssertTrue(r.isFallback, "\(String(describing: code)) should fall back")
            XCTAssertEqual(r.list.map(\.name), CrisisResources.international.map(\.name))
        }
    }

    // MARK: - Directory integrity (every number renders an actionable URL)

    func testEveryDirectoryEntryHasAValidAction() {
        for (region, list) in CrisisResources.directory {
            XCTAssertFalse(list.isEmpty, "\(region) is empty")
            for resource in list {
                XCTAssertNotNil(resource.actionURL, "\(region)/\(resource.name) has no action url")
                XCTAssertFalse(resource.name.isEmpty)
                XCTAssertFalse(resource.detail.isEmpty)
            }
        }
        for resource in CrisisResources.international {
            XCTAssertNotNil(resource.actionURL)
        }
    }

    func testItalyShipsOnlyTheNonPremiumNumber() {
        // owner decision: 199 284 284 is deprecated premium-rate, must never ship
        let italy = CrisisResources.directory["IT"] ?? []
        XCTAssertFalse(italy.contains { $0.contact.contains("199") })
        XCTAssertTrue(italy.contains { $0.contact == "02 2327 2327" })
    }

    // MARK: - Share frequency

    func testContextualShareShowsOnceEver() {
        XCTAssertTrue(ShareDino.shouldShowContextual(alreadyShown: false))
        XCTAssertFalse(ShareDino.shouldShowContextual(alreadyShown: true))
    }
}
