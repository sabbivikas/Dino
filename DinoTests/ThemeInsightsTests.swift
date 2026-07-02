//
//  ThemeInsightsTests.swift
//  DinoTests
//
//  Deterministic tests for PatternEngine's theme-tag statistics (DinoMind).
//  Mirrors PatternEngineTests' fixture style. Gates: minThemeTags=12 (overall
//  confidence), minPerThemeCount=4 (per-theme slices).
//

import XCTest
@testable import Dino

final class ThemeInsightsTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }()
    private let tol = 1e-9

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(timeZone: cal.timeZone, year: y, month: m, day: d, hour: h))!
    }
    private func mood(_ y: Int, _ m: Int, _ d: Int, _ w: EmotionalWeather) -> MoodSample {
        MoodSample(date: date(y, m, d), weather: w)
    }
    private func theme(_ y: Int, _ m: Int, _ d: Int, _ t: String) -> ThemeSample {
        ThemeSample(date: date(y, m, d), theme: t)
    }
    private func engine(moods: [MoodSample] = [], practices: [Date] = [],
                        themes: [ThemeSample], now: Date, window: Int = 120) -> PatternEngine {
        PatternEngine(moodSamples: moods, practiceDates: practices, themeSamples: themes,
                      now: now, calendar: cal, windowDays: window)
    }

    // 1) No theme samples → nil.
    func testNilWhenNoThemes() {
        let e = engine(themes: [], now: date(2024, 1, 15))
        XCTAssertNil(e.themeInsights())
    }

    // 2) Frequency counts per theme.
    func testFrequencyCounts() {
        var themes: [ThemeSample] = []
        for i in 0..<5 { themes.append(theme(2024, 1, 1 + i, "work")) }
        for i in 0..<2 { themes.append(theme(2024, 1, 10 + i, "sleep")) }
        let ti = engine(themes: themes, now: date(2024, 1, 20)).themeInsights()
        XCTAssertEqual(ti?.frequency["work"], 5)
        XCTAssertEqual(ti?.frequency["sleep"], 2)
        XCTAssertEqual(ti?.totalTags, 7)
    }

    // 3) Overall confidence gate at minThemeTags (12).
    func testConfidenceGate() {
        func tags(_ n: Int) -> ThemeInsights? {
            let themes = (0..<n).map { theme(2024, 1, 1 + $0, "work") }
            return engine(themes: themes, now: date(2024, 2, 1)).themeInsights()
        }
        XCTAssertEqual(tags(11)?.confident, false)   // 11 < 12
        XCTAssertEqual(tags(11)?.totalTags, 11)
        XCTAssertEqual(tags(12)?.confident, true)    // 12 >= 12
    }

    // 4) Per-theme slices require minPerThemeCount (4).
    func testPerThemeWeekdayGate() {
        var themes: [ThemeSample] = []
        for i in 0..<4 { themes.append(theme(2024, 1, 1 + i, "work")) }   // 4 → included
        for i in 0..<3 { themes.append(theme(2024, 1, 10 + i, "sleep")) } // 3 → excluded
        let ti = engine(themes: themes, now: date(2024, 1, 20)).themeInsights()
        XCTAssertNotNil(ti?.perThemeWeekday["work"])
        XCTAssertNil(ti?.perThemeWeekday["sleep"])
        // Jan 1..4 2024 = Mon(2),Tue(3),Wed(4),Thu(5)
        XCTAssertEqual(ti?.perThemeWeekday["work"], [2: 1, 3: 1, 4: 1, 5: 1])
    }

    // 5) Per-theme recovery: work-tagged dips each recover in 1 day.
    func testPerThemeRecovery() {
        // 8 clear + 4 drained (each drained day tagged work, followed by clear).
        // baseline = (8*4 + 4*1)/12 = 3.0; dip threshold 2.5; each drained→next clear = 1 day.
        let moods: [MoodSample] = [
            mood(2024, 1, 1, .clear),  mood(2024, 1, 2, .drained),
            mood(2024, 1, 3, .clear),  mood(2024, 1, 4, .drained),
            mood(2024, 1, 5, .clear),  mood(2024, 1, 6, .drained),
            mood(2024, 1, 7, .clear),  mood(2024, 1, 8, .drained),
            mood(2024, 1, 9, .clear),  mood(2024, 1, 10, .clear),
            mood(2024, 1, 11, .clear), mood(2024, 1, 12, .clear),
        ]
        let themes = [theme(2024, 1, 2, "work"), theme(2024, 1, 4, "work"),
                      theme(2024, 1, 6, "work"), theme(2024, 1, 8, "work")]
        let ti = engine(moods: moods, themes: themes, now: date(2024, 1, 20)).themeInsights()
        XCTAssertEqual(ti?.perThemeRecoveryDays["work"] ?? -1, 1.0, accuracy: tol)
    }

    // 6) Per-theme practice lift: practiced work-days recover higher next day.
    func testPerThemePracticeLift() {
        // 4 work-tagged drained days; d2,d4 practiced → next clear(4); d6,d8 not → next overwhelmed(2).
        let moods: [MoodSample] = [
            mood(2024, 1, 2, .drained), mood(2024, 1, 3, .clear),
            mood(2024, 1, 4, .drained), mood(2024, 1, 5, .clear),
            mood(2024, 1, 6, .drained), mood(2024, 1, 7, .overwhelmed),
            mood(2024, 1, 8, .drained), mood(2024, 1, 9, .overwhelmed),
        ]
        let themes = [theme(2024, 1, 2, "work"), theme(2024, 1, 4, "work"),
                      theme(2024, 1, 6, "work"), theme(2024, 1, 8, "work")]
        let practices = [date(2024, 1, 2), date(2024, 1, 4)]
        let ti = engine(moods: moods, practices: practices, themes: themes,
                        now: date(2024, 1, 20)).themeInsights()
        let c = ti?.perThemePractice["work"]
        XCTAssertEqual(c?.withMoodMean ?? -1, 4.0, accuracy: tol)
        XCTAssertEqual(c?.withoutMoodMean ?? -1, 2.0, accuracy: tol)
        XCTAssertEqual(c?.liftRatio ?? -1, 2.0, accuracy: tol)
    }

    // 7) Invalid theme strings are ignored.
    func testInvalidThemesIgnored() {
        let themes = [theme(2024, 1, 1, "work"), theme(2024, 1, 2, "banana"), theme(2024, 1, 3, "")]
        let ti = engine(themes: themes, now: date(2024, 1, 10)).themeInsights()
        XCTAssertEqual(ti?.totalTags, 1)
        XCTAssertEqual(ti?.frequency["work"], 1)
        XCTAssertNil(ti?.frequency["banana"])
    }
}
