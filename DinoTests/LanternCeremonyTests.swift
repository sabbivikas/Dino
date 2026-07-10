//
//  LanternCeremonyTests.swift
//  DinoTests
//
//  Phase machine transitions (timings exact, taps advance everything),
//  post-log stack priority with lantern present/absent, comfort slip
//  template (3 and 12 word titles, daypart, tape tints), the string
//  contract, and the country distance helper.
//

import XCTest
@testable import Dino

final class LanternCeremonyTests: XCTestCase {

    // MARK: - Phase machine: exact timer durations

    func testTimerDurationsMatchTheHandoffExactly() {
        XCTAssertEqual(LanternCeremonyMachine.timerDuration(for: .beat), 0.95)
        XCTAssertEqual(LanternCeremonyMachine.timerDuration(for: .hush), 2.6)
        XCTAssertEqual(LanternCeremonyMachine.timerDuration(for: .drift), 5.2)
        XCTAssertNil(LanternCeremonyMachine.timerDuration(for: .hover))   // waits for the person
        XCTAssertNil(LanternCeremonyMachine.timerDuration(for: .open))    // waits for keep
        XCTAssertEqual(LanternCeremonyMachine.timerDuration(for: .keep), 1.7)
        XCTAssertEqual(LanternCeremonyMachine.timerDuration(for: .kept), 2.6)
        XCTAssertEqual(LanternCeremonyMachine.timerDuration(for: .lift), 2.8)
        XCTAssertNil(LanternCeremonyMachine.timerDuration(for: .after))   // terminal
        XCTAssertEqual(LanternCeremonyMachine.openUnfold, 0.7)
    }

    func testTimerChainWalksTheWholeCeremony() {
        var m = LanternCeremonyMachine()
        XCTAssertEqual(m.phase, .beat)
        m.timerFired(); XCTAssertEqual(m.phase, .hush)
        m.timerFired(); XCTAssertEqual(m.phase, .drift)
        m.timerFired(); XCTAssertEqual(m.phase, .hover)
        m.timerFired(); XCTAssertEqual(m.phase, .hover)   // hover has no timer path
        m.tapped();     XCTAssertEqual(m.phase, .open)
        m.timerFired(); XCTAssertEqual(m.phase, .open)    // open waits for keep
        m.keepTapped(); XCTAssertEqual(m.phase, .keep)
        m.timerFired(); XCTAssertEqual(m.phase, .kept)
        m.timerFired(); XCTAssertEqual(m.phase, .lift)
        m.timerFired(); XCTAssertEqual(m.phase, .after)
    }

    func testTapAnywhereAdvancesEveryPhase() {
        // fully skippable — the house accessibility rule
        for (start, expected): (CeremonyPhase, CeremonyPhase) in
            [(.beat, .hover), (.hush, .hover), (.drift, .hover),
             (.hover, .open), (.open, .keep),
             (.keep, .after), (.kept, .after), (.lift, .after)] {
            var m = Self.machine(at: start)
            m.tapped()
            XCTAssertEqual(m.phase, expected, "tap in \(start) should reach \(expected)")
        }
    }

    func testKeepTapOnlyActsOnOpen() {
        var m = Self.machine(at: .hover)
        m.keepTapped()
        XCTAssertEqual(m.phase, .hover)
    }

    private static func machine(at phase: CeremonyPhase) -> LanternCeremonyMachine {
        var m = LanternCeremonyMachine()
        let path: [CeremonyPhase] = [.beat, .hush, .drift, .hover, .open, .keep, .kept, .lift, .after]
        for step in path.dropFirst() {
            if m.phase == phase { break }
            switch step {
            case .open: m.tapped()
            case .keep: m.keepTapped()
            default: m.timerFired()
            }
        }
        return m
    }

    // MARK: - Flight geometry spot checks

    func testBeatIsPerfectStillness() {
        let f = CeremonyLayout.frame(phase: .beat, dt: 500)
        XCTAssertEqual(f.night, 0)
        XCTAssertFalse(f.visible)
        XCTAssertEqual(f.glowAlpha, 0)
    }

    func testDriftSettlesAtHoverHeight() {
        let f = CeremonyLayout.frame(phase: .drift, dt: 5200)
        XCTAssertEqual(f.y, 268, accuracy: 0.5)
        XCTAssertEqual(f.night, 1)
        XCTAssertEqual(f.glowAlpha, 0.9, accuracy: 0.01)
    }

    func testKeepLandsInTheJar() {
        let f = CeremonyLayout.frame(phase: .keep, dt: 1600)
        XCTAssertEqual(f.y, 470, accuracy: 0.5)
        XCTAssertEqual(f.scale, 0.42, accuracy: 0.005)
        XCTAssertEqual(f.jarGlow, 0.9, accuracy: 0.01)
    }

    func testLiftReturnsTheDay() {
        let f = CeremonyLayout.frame(phase: .lift, dt: 2800)
        XCTAssertEqual(f.night, 0, accuracy: 0.01)
        XCTAssertFalse(f.visible)
    }

    // MARK: - Post-log stack priority

    func testCeremonyHeadlinesButNeverBuriesSupport() {
        let plan = PostLogStack.plan(lanternAvailable: true, siriReturn: false,
                                     supportEligible: true, shareEligible: false,
                                     recAvailable: true)
        XCTAssertEqual(plan, [.ceremony, .supportRow])   // support follows, rec quiet
        XCTAssertEqual(plan.first, .ceremony)
    }

    func testStackWithoutLanternIsTodaysOrder() {
        XCTAssertEqual(PostLogStack.plan(lanternAvailable: false, siriReturn: true,
                                         supportEligible: true, shareEligible: true,
                                         recAvailable: true),
                       [.siriReturn, .supportRow, .shareRow])
        XCTAssertEqual(PostLogStack.plan(lanternAvailable: false, siriReturn: false,
                                         supportEligible: false, shareEligible: false,
                                         recAvailable: true),
                       [.comfortSlip])
    }

    // MARK: - Comfort slip template

    func testSlipDaypartBoundaries() {
        XCTAssertEqual(ComfortSlip.kicker(hour: 22), "a small comfort · for tonight")
        XCTAssertEqual(ComfortSlip.kicker(hour: 2), "a small comfort · for tonight")
        XCTAssertEqual(ComfortSlip.kicker(hour: 18), "a small comfort · for this evening")
        XCTAssertEqual(ComfortSlip.kicker(hour: 8), "a small comfort · for this morning")
        XCTAssertEqual(ComfortSlip.kicker(hour: 14), "a small comfort · for today")
    }

    func testSlipTypeMappings() {
        XCTAssertEqual(ComfortSlip.icon(type: "music"), "🎧")
        XCTAssertEqual(ComfortSlip.icon(type: "film"), "🎬")
        XCTAssertEqual(ComfortSlip.icon(type: "cozy"), "🍵")
        XCTAssertEqual(ComfortSlip.source(link: "https://www.letterboxd.com/film/x"), "from letterboxd.com")
        XCTAssertEqual(ComfortSlip.source(link: ""), "from somewhere gentle")
    }

    func testSlipTitlesPassThroughUntruncated() {
        // 3 words and the design's own 12 word fixture — the template must
        // carry both verbatim (the view wraps; it never lineLimits)
        let short = GentleRec(itemId: "a", type: "film", title: "my neighbor sea",
                              link: "https://letterboxd.com", line: "a gentle one.")
        let twelve = GentleRec(itemId: "b", type: "cozy",
                               title: "twelve cozy books for reading under a blanket when the world feels loud",
                               link: "https://thestorygraph.com", line: "for slow mornings. one page counts.")
        XCTAssertEqual(short.title.split(separator: " ").count, 3)
        // the design's own long fixture (13 words — even longer than the
        // 12-word requirement) must pass through verbatim
        XCTAssertEqual(twelve.title.split(separator: " ").count, 13)
        XCTAssertEqual(twelve.title, "twelve cozy books for reading under a blanket when the world feels loud")
        let exactTwelve = GentleRec(itemId: "c", type: "music",
                                    title: "a warm mix of quiet songs for the end of long days",
                                    link: "https://open.spotify.com", line: "no hurry, it keeps.")
        XCTAssertEqual(exactTwelve.title.split(separator: " ").count, 12)
    }

    // MARK: - String contract (lowercase, zero dashes)

    func testEveryCeremonyAndSlipStringObeysTheVoiceContract() {
        for s in CeremonyStrings.allFixedStrings + ComfortSlip.allFixedStrings {
            XCTAssertEqual(s, s.lowercased(), "'\(s)' breaks lowercase")
            for dash in ["-", "\u{2013}", "\u{2014}"] {
                XCTAssertFalse(s.contains(dash), "'\(s)' contains a dash")
            }
        }
    }

    // MARK: - Distance

    func testDistanceLineFormats() {
        XCTAssertEqual(CeremonyStrings.distanceLine(kilometers: nil, metric: false),
                       "a long way · just for you")
        XCTAssertEqual(CeremonyStrings.distanceLine(kilometers: 6400, metric: true),
                       "6,400 km · just for you")
        XCTAssertEqual(CeremonyStrings.distanceLine(kilometers: 6437, metric: false),
                       "4,000 miles · just for you")
    }

    func testHaversineKnownPair() {
        // london → new york ≈ 5,570 km
        let km = CeremonyDistance.haversineKm(lat1: 51.5, lon1: -0.12, lat2: 40.7, lon2: -74.0)
        XCTAssertEqual(km, 5570, accuracy: 60)
    }
}
