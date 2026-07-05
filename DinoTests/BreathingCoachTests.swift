//
//  BreathingCoachTests.swift
//  DinoTests
//
//  The coach's pure logic: the crisis keyword net (positive AND negative
//  cases, including obfuscations), the deterministic fallback matcher, field
//  validation/clamping, cache key normalization + hashing, the concern OR
//  combination, and duration scaling through the whole-breath planner.
//

import XCTest
@testable import Dino

final class BreathingCoachTests: XCTestCase {

    // MARK: Crisis net — positives (must trigger)

    func testCrisisNetTriggersOnFirstPersonSelfHarm() {
        let positives = [
            "i want to kill myself",
            "I've been thinking about suicide",
            "i feel suicidal tonight",
            "honestly i want to end my life",
            "i just want to die",
            "everyone would be better off without me",
            "i keep wanting to hurt myself",
            "i cut myself again last night",
            "there is no point in living",
            "i cant go on",
            "i can't do this anymore",
            "i feel completely hopeless",
            "i am worthless",
            "i want to disappear forever",
            "nothing to live for now",
        ]
        for text in positives {
            XCTAssertTrue(BreathingCrisisNet.isConcerning(text), "should trigger: \(text)")
        }
    }

    func testCrisisNetCatchesObfuscations() {
        XCTAssertTrue(BreathingCrisisNet.isConcerning("k i l l m y s e l f"), "letter spacing")
        XCTAssertTrue(BreathingCrisisNet.isConcerning("self–harm thoughts again"), "en dash")
        XCTAssertTrue(BreathingCrisisNet.isConcerning("self-harm"), "hyphen")
        XCTAssertTrue(BreathingCrisisNet.isConcerning("KMS"), "shorthand, any case")
        XCTAssertTrue(BreathingCrisisNet.isConcerning("i WANT TO DIE!!!"), "caps + punctuation")
        XCTAssertTrue(BreathingCrisisNet.isConcerning("don’t want to be alive"), "curly apostrophe")
    }

    // MARK: Crisis net — negatives (must NOT trigger)

    func testCrisisNetIgnoresIdiomsAndEverydayLanguage() {
        let negatives = [
            "this deadline is killing me",          // the named case
            "my boss is killing me with meetings",
            "i could kill for a nap",
            "trying to give up sugar",
            "i give up on this crossword",
            "such a pointless meeting today",
            "my legs hurt after the gym",
            "work has been so stressful lately",
            "i'm anxious about tomorrow",
            "dead tired after today",
            "the suspense is killing me",
            "",
            "   ",
        ]
        for text in negatives {
            XCTAssertFalse(BreathingCrisisNet.isConcerning(text), "should NOT trigger: \(text)")
        }
    }

    // MARK: Fallback matcher

    func testChipMappingIsDeterministic() {
        XCTAssertEqual(BreathingFeeling.panicky.mapping.pattern.id, "steady-square")
        XCTAssertEqual(BreathingFeeling.panicky.mapping.minutes, 3)
        XCTAssertEqual(BreathingFeeling.cantSleep.mapping.pattern.id, "sleepy-cloud")
        XCTAssertEqual(BreathingFeeling.cantSleep.mapping.minutes, 8)
        XCTAssertEqual(BreathingFeeling.cantFocus.mapping.pattern.id, "calm-current")
        XCTAssertEqual(BreathingFeeling.anxious.mapping.pattern.id, "big-sigh")
        XCTAssertEqual(BreathingFeeling.anxious.mapping.minutes, 5)
    }

    func testMultiChipPriorityAcuteWins() {
        // panicky outranks everything
        let rec = BreathingCoach.localRecommendation(
            chips: [.stressed, .cantFocus, .panicky], text: "")
        XCTAssertEqual(rec.patternID, "steady-square")
        XCTAssertEqual(rec.minutes, 3)
        // can't sleep outranks anxious
        let rec2 = BreathingCoach.localRecommendation(chips: [.anxious, .cantSleep], text: "")
        XCTAssertEqual(rec2.patternID, "sleepy-cloud")
        XCTAssertEqual(rec2.minutes, 8)
    }

    func testFreeTextRouting() {
        XCTAssertEqual(BreathingCoach.localRecommendation(chips: [], text: "wide awake at 3am again").patternID, "sleepy-cloud")
        XCTAssertEqual(BreathingCoach.localRecommendation(chips: [], text: "my heart is racing").patternID, "steady-square")
        XCTAssertEqual(BreathingCoach.localRecommendation(chips: [], text: "so foggy and distracted").patternID, "calm-current")
        XCTAssertEqual(BreathingCoach.localRecommendation(chips: [], text: "everything is too much, been crying").patternID, "big-sigh")
        // unknown text → gentle default
        let fallback = BreathingCoach.localRecommendation(chips: [], text: "meh")
        XCTAssertEqual(fallback.patternID, "big-sigh")
        XCTAssertEqual(fallback.minutes, 5)
    }

    func testLocalRecommendationCarriesConcern() {
        let rec = BreathingCoach.localRecommendation(chips: [.sad], text: "i want to kill myself")
        XCTAssertTrue(rec.concern, "client net raises concern with zero network")
        XCTAssertEqual(rec.patternID, "big-sigh", "a breath is still offered, never as the fix")
    }

    // MARK: Validation / clamping

    func testCoachIDMapping() {
        XCTAssertEqual(BreathingCoach.pattern(forCoachID: "bigSigh")?.id, "big-sigh")
        XCTAssertEqual(BreathingCoach.pattern(forCoachID: "sleepyCloud")?.id, "sleepy-cloud")
        XCTAssertEqual(BreathingCoach.pattern(forCoachID: "steadySquare")?.id, "steady-square")
        XCTAssertEqual(BreathingCoach.pattern(forCoachID: "calmCurrent")?.id, "calm-current")
        XCTAssertNil(BreathingCoach.pattern(forCoachID: "boxBreathing"), "inventions rejected")
        XCTAssertNil(BreathingCoach.pattern(forCoachID: ""))
    }

    func testMinutesClampToAllowedSet() {
        XCTAssertEqual(BreathingCoach.clampMinutes(1), 1)
        XCTAssertEqual(BreathingCoach.clampMinutes(2), 1, "tie rounds down, gentler")
        XCTAssertEqual(BreathingCoach.clampMinutes(4), 3, "tie rounds down")
        XCTAssertEqual(BreathingCoach.clampMinutes(6), 5)
        XCTAssertEqual(BreathingCoach.clampMinutes(7), 8)
        XCTAssertEqual(BreathingCoach.clampMinutes(9), 8, "tie rounds down")
        XCTAssertEqual(BreathingCoach.clampMinutes(60), 10)
        XCTAssertEqual(BreathingCoach.clampMinutes(0), 1)
        XCTAssertEqual(BreathingCoach.clampMinutes(-5), 1)
    }

    // MARK: Cache key

    func testCacheKeyNormalization() {
        let a = BreathingCoach.cacheKeyHash(chips: [.anxious, .sad], text: "  Rough Day  ", dayKey: "2026-07-04")
        let b = BreathingCoach.cacheKeyHash(chips: [.sad, .anxious], text: "rough day", dayKey: "2026-07-04")
        XCTAssertEqual(a, b, "chip order and text case/whitespace must not matter")

        let c = BreathingCoach.cacheKeyHash(chips: [.sad, .anxious], text: "rough day", dayKey: "2026-07-05")
        XCTAssertNotEqual(a, c, "a new day is a new key")

        let d = BreathingCoach.cacheKeyHash(chips: [.sad], text: "rough day", dayKey: "2026-07-04")
        XCTAssertNotEqual(a, d, "different chips, different key")
    }

    func testCacheKeyIsAHashNotTheText() {
        let sensitive = "today was genuinely terrible and private"
        let key = BreathingCoach.cacheKeyHash(chips: [], text: sensitive, dayKey: "2026-07-04")
        XCTAssertEqual(key.count, 64, "sha256 hex")
        XCTAssertFalse(key.contains("terrible"), "raw text never appears in the key")
        XCTAssertTrue(key.allSatisfy { $0.isHexDigit })
    }

    // MARK: Concern combination — can rise, can never fall

    func testConcernOrCombination() {
        let calm = BreathingRecommendation(patternID: "big-sigh", minutes: 5,
                                           reason: "r", concern: false, fromAI: true)
        XCTAssertFalse(calm.raisingConcern(false).concern)
        XCTAssertTrue(calm.raisingConcern(true).concern)

        let concerned = BreathingRecommendation(patternID: "big-sigh", minutes: 5,
                                                reason: "r", concern: true, fromAI: true)
        XCTAssertTrue(concerned.raisingConcern(false).concern, "raising with false never lowers")
        XCTAssertTrue(concerned.raisingConcern(true).concern)
    }

    // MARK: Duration → whole-breath scaling (through the existing planner)

    func testCoachMinutesScaleToWholeBreaths() {
        for minutes in BreathingCoach.allowedMinutes {
            for pattern in BreathingPattern.library {
                let planned = pattern.plannedDuration(for: minutes * 60)
                XCTAssertEqual(planned % pattern.cycleLength, 0,
                               "\(pattern.id) at \(minutes)min must plan whole cycles")
                XCTAssertGreaterThan(planned, 0)
                XCTAssertLessThanOrEqual(abs(planned - minutes * 60), pattern.cycleLength,
                                         "planned stays within one cycle of the request")
            }
        }
    }

    func testRecommendationPatternResolution() {
        let rec = BreathingRecommendation(patternID: "sleepy-cloud", minutes: 8,
                                          reason: "r", concern: false, fromAI: true)
        XCTAssertEqual(rec.pattern.id, "sleepy-cloud")
        let bogus = BreathingRecommendation(patternID: "nope", minutes: 5,
                                            reason: "r", concern: false, fromAI: true)
        XCTAssertEqual(bogus.pattern.id, "big-sigh", "unknown ids resolve to the safe default")
    }
}
