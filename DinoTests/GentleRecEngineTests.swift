//
//  GentleRecEngineTests.swift
//  DinoTests
//
//  Moment-engine gates: 3-day scarcity, absolute crisis suppression, time
//  slots, heavy-signal logic (toggle interplay + the {sleep, self} subset),
//  and the 3-ignores learning loop.
//

import XCTest
@testable import Dino

final class GentleRecEngineTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 18) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return cal.date(from: comps)!
    }

    private func daysAgo(_ n: Int, from now: Date) -> Date {
        cal.date(byAdding: .day, value: -n, to: now)!
    }

    /// Baseline: evening, heavy mood, nothing shown recently, no crisis.
    private func offer(now: Date? = nil,
                       lastShownAt: Date? = nil,
                       crisisDate: Date? = nil,
                       heavyMoodToday: Bool = true,
                       journalToggleOn: Bool = false,
                       journalThemesToday: [String] = [],
                       ignoreCounts: [String: Int] = [:]) -> GentleRecEngine.Offer? {
        GentleRecEngine.shouldOffer(now: now ?? date(2024, 6, 20, 18), calendar: cal,
                                    lastShownAt: lastShownAt, crisisDate: crisisDate,
                                    heavyMoodToday: heavyMoodToday,
                                    journalToggleOn: journalToggleOn,
                                    journalThemesToday: journalThemesToday,
                                    ignoreCounts: ignoreCounts)
    }

    // MARK: - Time slots

    func testTimeSlots() {
        XCTAssertNil(GentleRecEngine.timeSlot(hour: 9))
        XCTAssertEqual(GentleRecEngine.timeSlot(hour: 11), .midday)
        XCTAssertEqual(GentleRecEngine.timeSlot(hour: 16), .midday)
        XCTAssertEqual(GentleRecEngine.timeSlot(hour: 17), .evening)
        XCTAssertEqual(GentleRecEngine.timeSlot(hour: 22), .evening)
        XCTAssertNil(GentleRecEngine.timeSlot(hour: 23))
        XCTAssertNil(GentleRecEngine.timeSlot(hour: 2))
    }

    func testOfferCarriesTimeOfDay() {
        XCTAssertEqual(offer(now: date(2024, 6, 20, 19))?.timeOfDay, "evening")
        XCTAssertEqual(offer(now: date(2024, 6, 20, 13))?.timeOfDay, "midday")
        XCTAssertNil(offer(now: date(2024, 6, 20, 8)))   // morning → no slot, no rec
    }

    // MARK: - Scarcity (3 days)

    func testScarcityGate() {
        let now = date(2024, 6, 20, 18)
        XCTAssertNil(offer(now: now, lastShownAt: daysAgo(1, from: now)))
        XCTAssertNil(offer(now: now, lastShownAt: daysAgo(2, from: now)))
        XCTAssertNotNil(offer(now: now, lastShownAt: daysAgo(3, from: now)))
        XCTAssertNotNil(offer(now: now, lastShownAt: nil))
    }

    // MARK: - Crisis suppression (absolute)

    func testCrisisWindowSuppressesEverything() {
        let now = date(2024, 6, 20, 18)
        XCTAssertNil(offer(now: now, crisisDate: now))
        XCTAssertNil(offer(now: now, crisisDate: daysAgo(6, from: now)))
        XCTAssertNotNil(offer(now: now, crisisDate: daysAgo(7, from: now)))
        XCTAssertNotNil(offer(now: now, crisisDate: daysAgo(30, from: now)))
    }

    func testCrisisBeatsEveryOtherClearedGate() {
        // all other gates pass — crisis alone must still silence
        let now = date(2024, 6, 20, 18)
        XCTAssertNil(offer(now: now, lastShownAt: daysAgo(30, from: now),
                           crisisDate: daysAgo(2, from: now),
                           heavyMoodToday: true))
    }

    // MARK: - Heavy signal

    func testNoHeavySignalMeansSilence() {
        XCTAssertNil(offer(heavyMoodToday: false))
    }

    func testJournalSignalRequiresToggle() {
        // toggle off → journal themes are inert
        XCTAssertNil(offer(heavyMoodToday: false, journalToggleOn: false,
                           journalThemesToday: ["sleep"]))
        // toggle on + heavy theme → fires
        XCTAssertNotNil(offer(heavyMoodToday: false, journalToggleOn: true,
                              journalThemesToday: ["sleep"]))
        XCTAssertNotNil(offer(heavyMoodToday: false, journalToggleOn: true,
                              journalThemesToday: ["self"]))
    }

    func testStressorAndHealthThemesDoNotFire() {
        // health deliberately excluded (physical illness → tone-deaf risk),
        // stressor themes say stressed, not depleted
        for theme in ["health", "work", "money", "relationships"] {
            XCTAssertNil(offer(heavyMoodToday: false, journalToggleOn: true,
                               journalThemesToday: [theme]),
                         "theme \(theme) must not fire a rec")
        }
    }

    // MARK: - Ignore learning

    func testQuietTypesAfterThreeIgnores() {
        XCTAssertEqual(GentleRecEngine.quietTypes(ignoreCounts: [:]), [])
        XCTAssertEqual(GentleRecEngine.quietTypes(ignoreCounts: ["music": 2]), [])
        XCTAssertEqual(GentleRecEngine.quietTypes(ignoreCounts: ["music": 3]), ["music"])
        XCTAssertEqual(offer(ignoreCounts: ["music": 3])?.quietTypes, ["music"])
    }

    func testAllTypesQuietMeansSilence() {
        XCTAssertNil(offer(ignoreCounts: ["music": 3, "film": 4, "cozy": 3]))
    }

    func testTapWakesATypeBackUp() {
        let old = UserDefaults.standard.dictionary(forKey: GentleRecStore.ignoreCountsKey)
        defer {
            if let old { UserDefaults.standard.set(old, forKey: GentleRecStore.ignoreCountsKey) }
            else { UserDefaults.standard.removeObject(forKey: GentleRecStore.ignoreCountsKey) }
        }
        UserDefaults.standard.removeObject(forKey: GentleRecStore.ignoreCountsKey)

        GentleRecStore.recordIgnored(type: "film")
        GentleRecStore.recordIgnored(type: "film")
        GentleRecStore.recordIgnored(type: "film")
        XCTAssertEqual(GentleRecEngine.quietTypes(ignoreCounts: GentleRecStore.ignoreCounts), ["film"])

        GentleRecStore.recordTapped(type: "film")
        XCTAssertEqual(GentleRecEngine.quietTypes(ignoreCounts: GentleRecStore.ignoreCounts), [])
    }
}
