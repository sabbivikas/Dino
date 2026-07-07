//
//  WeeklyDigestTests.swift
//  DinoTests
//
//  Delta computation, bucket boundaries, the can't-repeat-two-weeks property,
//  journal-toggle inertness, and sparse-copy rotation.
//

import XCTest
@testable import Dino

final class WeeklyDigestTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }()

    // now = a fixed thursday evening; "this week" = the 7 days ending today
    private var now: Date { date(2024, 6, 20, 18) }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return cal.date(from: comps)!
    }

    private func daysAgo(_ n: Int) -> Date {
        cal.date(byAdding: .day, value: -n, to: now)!
    }

    private func moods(thisWeek: EmotionalWeather, lastWeek: EmotionalWeather,
                       perWeek: Int = 5) -> [MoodSample] {
        var out: [MoodSample] = []
        for i in 0..<perWeek {
            out.append(MoodSample(date: daysAgo(i), weather: thisWeek))
            out.append(MoodSample(date: daysAgo(i + 7), weather: lastWeek))
        }
        return out
    }

    private func build(moodSamples: [MoodSample] = [],
                       practiceDates: [Date] = [],
                       stepDays: [(date: Date, steps: Double)] = [],
                       sleepNights: [(date: Date, hours: Double)] = [],
                       themeTags: [(date: Date, theme: String)] = [],
                       journalToggleOn: Bool = false,
                       movementLift: Bool = false) -> WeeklyDigest {
        WeeklyDigest.build(moodSamples: moodSamples, practiceDates: practiceDates,
                           stepDays: stepDays, sleepNights: sleepNights,
                           themeTags: themeTags, journalToggleOn: journalToggleOn,
                           movementLift: movementLift, streakState: "steady",
                           now: now, calendar: cal)
    }

    // MARK: - Mood deltas + boundaries

    func testMoodDirectionUpAndDown() {
        XCTAssertEqual(build(moodSamples: moods(thisWeek: .clear, lastWeek: .drained)).moodDirection, .up)
        XCTAssertEqual(build(moodSamples: moods(thisWeek: .clear, lastWeek: .drained)).moodLean, .clearly)
        XCTAssertEqual(build(moodSamples: moods(thisWeek: .drained, lastWeek: .clear)).moodDirection, .down)
        XCTAssertEqual(build(moodSamples: moods(thisWeek: .clear, lastWeek: .clear)).moodDirection, .steady)
    }

    func testMoodBucketBoundaries() {
        // partlyCloudy(3) vs clear(4) → Δ = 1.0 → clearly
        let clearly = build(moodSamples: moods(thisWeek: .partlyCloudy, lastWeek: .clear))
        XCTAssertEqual(clearly.moodDirection, .down)
        XCTAssertEqual(clearly.moodLean, .clearly)
        // mixed week vs clear → small delta lands in gently band:
        // this week alternates clear/partlyCloudy (mean 3.5) vs clear (4) → Δ 0.5
        var samples: [MoodSample] = []
        for i in 0..<6 {
            samples.append(MoodSample(date: daysAgo(i), weather: i % 2 == 0 ? .clear : .partlyCloudy))
            samples.append(MoodSample(date: daysAgo(i + 7), weather: .clear))
        }
        let gently = build(moodSamples: samples)
        XCTAssertEqual(gently.moodDirection, .down)
        XCTAssertEqual(gently.moodLean, .gently)
    }

    func testMoodDirectionNilWithoutBothWeeks() {
        let onlyThisWeek = (0..<5).map { MoodSample(date: daysAgo($0), weather: .clear) }
        XCTAssertNil(build(moodSamples: onlyThisWeek).moodDirection)
    }

    // MARK: - Movement deltas

    private func steps(thisWeekActive: Int, lastWeekActive: Int) -> [(date: Date, steps: Double)] {
        var out: [(date: Date, steps: Double)] = []
        for i in 0..<7 {
            out.append((date: daysAgo(i), steps: i < thisWeekActive ? 8000 : 1000))
            out.append((date: daysAgo(i + 7), steps: i < lastWeekActive ? 8000 : 1000))
        }
        // pad baseline history so the 7-positive-day median gate passes
        for i in 14..<28 { out.append((date: daysAgo(i), steps: 5000)) }
        return out
    }

    func testMovementDelta() {
        let more = build(stepDays: steps(thisWeekActive: 5, lastWeekActive: 2))
        XCTAssertEqual(more.movementDelta, .more)
        XCTAssertEqual(more.movementDaysThisWeek, 5)
        XCTAssertEqual(build(stepDays: steps(thisWeekActive: 1, lastWeekActive: 4)).movementDelta, .less)
        XCTAssertEqual(build(stepDays: steps(thisWeekActive: 3, lastWeekActive: 3)).movementDelta, .same)
    }

    func testMovementSilentWithoutBaseline() {
        // fewer than 7 positive days total → no median → no movement fields
        let thin: [(date: Date, steps: Double)] = (0..<5).map { (date: daysAgo($0), steps: 4000) }
        let digest = build(stepDays: thin)
        XCTAssertNil(digest.movementDaysThisWeek)
        XCTAssertNil(digest.movementDelta)
    }

    // MARK: - Sleep deltas + boundaries

    private func nights(shortThisWeek: Int, shortLastWeek: Int) -> [(date: Date, hours: Double)] {
        var out: [(date: Date, hours: Double)] = []
        for i in 0..<6 {
            out.append((date: daysAgo(i), hours: i < shortThisWeek ? 5.0 : 7.5))
            out.append((date: daysAgo(i + 7), hours: i < shortLastWeek ? 5.0 : 7.5))
        }
        for i in 14..<24 { out.append((date: daysAgo(i), hours: 7.5)) }   // baseline pad
        return out
    }

    func testSleepDirection() {
        // fewer short nights than last week = up
        XCTAssertEqual(build(sleepNights: nights(shortThisWeek: 0, shortLastWeek: 3)).sleepDirection, .up)
        XCTAssertEqual(build(sleepNights: nights(shortThisWeek: 4, shortLastWeek: 1)).sleepDirection, .down)
        XCTAssertEqual(build(sleepNights: nights(shortThisWeek: 2, shortLastWeek: 2)).sleepDirection, .steady)
        XCTAssertEqual(build(sleepNights: nights(shortThisWeek: 4, shortLastWeek: 1)).shortNightsThisWeek, 4)
    }

    func testSleepSilentWithThinWeeks() {
        // only 2 nights this week → below minSleepNightsPerWeek → silent
        var out: [(date: Date, hours: Double)] = [(daysAgo(0), 7.0), (daysAgo(1), 7.0)]
        for i in 7..<20 { out.append((daysAgo(i), 7.0)) }
        let digest = build(sleepNights: out)
        XCTAssertNil(digest.shortNightsThisWeek)
        XCTAssertNil(digest.sleepDirection)
    }

    // MARK: - Journal toggle inertness

    func testThemesInertWhenToggleOff() {
        let tags: [(date: Date, theme: String)] = (0..<4).map { (date: daysAgo($0), theme: "sleep") }
        let off = build(themeTags: tags, journalToggleOn: false)
        XCTAssertNil(off.topTheme)
        XCTAssertFalse(off.themeIsNew)
        let on = build(themeTags: tags, journalToggleOn: true)
        XCTAssertEqual(on.topTheme, "sleep")
        XCTAssertTrue(on.themeIsNew)   // nothing last week → new
    }

    func testThemeNotNewWhenSameAsLastWeek() {
        var tags: [(date: Date, theme: String)] = (0..<3).map { (date: daysAgo($0), theme: "work") }
        tags += (7..<10).map { (date: daysAgo($0), theme: "work") }
        let digest = build(themeTags: tags, journalToggleOn: true)
        XCTAssertEqual(digest.topTheme, "work")
        XCTAssertFalse(digest.themeIsNew)
    }

    // MARK: - The can't-repeat property

    func testDifferingDeltasProduceDifferingLines() {
        var up = WeeklyDigest(); up.daysLogged = 5; up.moodDirection = .up; up.moodLean = .gently
        var down = up; down.moodDirection = .down
        XCTAssertNotEqual(WeeklyDigest.localLines(digest: up), WeeklyDigest.localLines(digest: down))

        var moreMove = up; moreMove.movementDelta = .more
        var lessMove = up; lessMove.movementDelta = .less
        XCTAssertNotEqual(WeeklyDigest.localLines(digest: moreMove), WeeklyDigest.localLines(digest: lessMove))

        var sleepDown = up; sleepDown.sleepDirection = .down
        XCTAssertNotEqual(WeeklyDigest.localLines(digest: up), WeeklyDigest.localLines(digest: sleepDown))
    }

    func testHeavyWeekNeverGetsMovementLiftLine() {
        var digest = WeeklyDigest()
        digest.daysLogged = 5
        digest.moodDirection = .down; digest.moodLean = .clearly
        digest.movementLift = true; digest.movementDaysThisWeek = 4
        XCTAssertFalse(WeeklyDigest.localLines(digest: digest).contains(WeeklyDigest.movementLiftLine))
        digest.moodDirection = .up
        XCTAssertTrue(WeeklyDigest.localLines(digest: digest).contains(WeeklyDigest.movementLiftLine))
    }

    func testShrinkingPracticeGetsNoGuiltLine() {
        var digest = WeeklyDigest()
        digest.daysLogged = 5
        digest.moodDirection = .steady
        digest.practicedDelta = .less
        let lines = WeeklyDigest.localLines(digest: digest)
        XCTAssertFalse(lines.joined().contains("showed up"))
    }

    func testLinesAreLowercaseAndDashFree() {
        var digest = WeeklyDigest()
        digest.daysLogged = 5
        digest.moodDirection = .down; digest.moodLean = .clearly
        digest.movementDelta = .more; digest.sleepDirection = .down
        for line in WeeklyDigest.localLines(digest: digest) + WeeklyDigest.sparseLines {
            XCTAssertEqual(line, line.lowercased())
            for dash in ["–", "—"] { XCTAssertFalse(line.contains(dash)) }
        }
    }

    // MARK: - Sparse weeks

    func testSparseWeekGetsRotatingCopy() {
        XCTAssertNotEqual(WeeklyDigest.sparseLine(weekIndex: 27), WeeklyDigest.sparseLine(weekIndex: 28))
        XCTAssertEqual(WeeklyDigest.sparseLine(weekIndex: 27), WeeklyDigest.sparseLine(weekIndex: 27))
        // full rotation cycles through distinct lines
        let cycle = Set((0..<4).map { WeeklyDigest.sparseLine(weekIndex: $0) })
        XCTAssertEqual(cycle.count, WeeklyDigest.sparseLines.count)
    }

    func testSparseAndEmptyClassification() {
        var sparse = WeeklyDigest(); sparse.daysLogged = 2; sparse.practicedDaysThisWeek = 1
        XCTAssertTrue(sparse.isSparse)
        XCTAssertFalse(sparse.isEmpty)
        XCTAssertTrue(WeeklyDigest.localLines(digest: sparse).isEmpty)   // sparse handled upstream
        let empty = WeeklyDigest()
        XCTAssertTrue(empty.isEmpty)
    }
}
