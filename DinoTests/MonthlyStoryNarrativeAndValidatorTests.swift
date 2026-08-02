import XCTest
@testable import Dino

final class MonthlyStoryNarrativeAndValidatorTests: XCTestCase {
    func testNarrativePlanRequiresTraceableEvidenceForFactualSections() throws {
        let mood = try MonthlyStoryEvidenceID(rawValue: "evidence-mood")
        let rest = try MonthlyStoryEvidenceID(rawValue: "evidence-rest")
        let overall = try MonthlyStoryNarrativeSection(kind: .overallMonth, evidenceIDs: [mood])
        let helped = try MonthlyStoryNarrativeSection(kind: .whatHelped, evidenceIDs: [rest])
        let suggestion = try MonthlyStoryNarrativeSection(kind: .nextMonthSuggestion, evidenceIDs: [rest])
        let plan = try MonthlyStoryNarrativePlan(opening: .gentleReflection,
                                                overallMonth: overall,
                                                whatHelped: helped,
                                                nextMonthSuggestions: [suggestion],
                                                closing: .warmAndOpen,
                                                usedEvidenceIDs: [mood, rest])
        XCTAssertEqual(plan.maximumWordTarget, 300)
        XCTAssertEqual(Set(plan.usedEvidenceIDs), [mood, rest])
    }

    func testNarrativePlanRejectsUnsupportedAndEmptyEvidence() throws {
        let mood = try MonthlyStoryEvidenceID(rawValue: "evidence-mood")
        let unknown = try MonthlyStoryEvidenceID(rawValue: "evidence-unknown")
        let overall = try MonthlyStoryNarrativeSection(kind: .overallMonth, evidenceIDs: [mood])
        XCTAssertThrowsError(try MonthlyStoryNarrativePlan(opening: .quietWelcome,
                                                          overallMonth: overall,
                                                          nextMonthSuggestions: [],
                                                          closing: .simpleCompanionship,
                                                          usedEvidenceIDs: [unknown]))
        XCTAssertThrowsError(try MonthlyStoryNarrativeSection(kind: .whatWasHard, evidenceIDs: []))
    }

    func testValidScriptPasses() {
        let evidence = MonthlyStoryFixtures.richMonth.evidence
        let result = MonthlyStoryScriptValidator.validate(script: MonthlyStoryFixtures.validScript,
                                                          claimedEvidenceIDs: evidence.map(\.id),
                                                          availableEvidence: evidence)
        XCTAssertTrue(result.isValid, "\(result.errors)")
        XCTAssertTrue((80...300).contains(result.wordCount))
    }

    func testForbiddenReportingClinicalCausalAndFakeBenefitLanguage() {
        let cases: [(String, (MonthlyStoryScriptValidationError) -> Bool)] = [
            (MonthlyStoryFixtures.reportingScript, { if case .reportingLanguage = $0 { true } else { false } }),
            (MonthlyStoryFixtures.clinicalScript, { if case .diagnosisOrMedicalAdvice = $0 { true } else { false } }),
            (MonthlyStoryFixtures.fabricatedCausalScript, { if case .causalCertainty = $0 { true } else { false } }),
            (MonthlyStoryFixtures.fakeImprovementScript, { $0 == .recommendationBenefitClaim })
        ]
        for (script, matches) in cases {
            let errors = MonthlyStoryScriptValidator.validate(script: script,
                                                              claimedEvidenceIDs: [],
                                                              availableEvidence: []).errors
            XCTAssertTrue(errors.contains(where: matches), "missing expected validation error in \(errors)")
        }
    }

    func testLengthPercentCountRepeatedAndINoticedRules() {
        XCTAssertTrue(MonthlyStoryScriptValidator.validate(script: "quiet month",
                                                           claimedEvidenceIDs: [],
                                                           availableEvidence: []).errors.contains(.tooShort(minimumWords: 80)))
        XCTAssertTrue(MonthlyStoryScriptValidator.validate(script: MonthlyStoryFixtures.overWordLimitScript,
                                                           claimedEvidenceIDs: [],
                                                           availableEvidence: []).errors.contains(.tooLong(maximumWords: 300)))
        let percent = MonthlyStoryFixtures.validScript + " your mood improved by 20%."
        XCTAssertTrue(MonthlyStoryScriptValidator.validate(script: percent, claimedEvidenceIDs: [], availableEvidence: []).errors.contains(.percentage))
        let count = MonthlyStoryFixtures.validScript + " you practiced breathing 4 times."
        XCTAssertTrue(MonthlyStoryScriptValidator.validate(script: count, claimedEvidenceIDs: [], availableEvidence: []).errors.contains(.exactCount))
        XCTAssertTrue(MonthlyStoryScriptValidator.validate(script: MonthlyStoryFixtures.repeatedScript,
                                                           claimedEvidenceIDs: [],
                                                           availableEvidence: []).errors.contains(.repeatedSection))
        let noticed = MonthlyStoryFixtures.validScript + " i noticed calm. i noticed space. i noticed rest."
        XCTAssertTrue(MonthlyStoryScriptValidator.validate(script: noticed, claimedEvidenceIDs: [], availableEvidence: []).errors.contains(.excessiveINoticed))
    }

    func testUnsupportedAndNonNarratableEvidenceClaimsFail() throws {
        let unknown = try MonthlyStoryEvidenceID(rawValue: "evidence-unknown")
        var result = MonthlyStoryScriptValidator.validate(script: MonthlyStoryFixtures.validScript,
                                                          claimedEvidenceIDs: [unknown],
                                                          availableEvidence: MonthlyStoryFixtures.richMonth.evidence)
        XCTAssertTrue(result.errors.contains(.unsupportedEvidenceID(unknown)))

        let blocked = MonthlyStoryFixtures.evidence("blocked", value: .repeatedTheme(.family), allowed: false)
        result = MonthlyStoryScriptValidator.validate(script: MonthlyStoryFixtures.validScript,
                                                      claimedEvidenceIDs: [blocked.id],
                                                      availableEvidence: [blocked])
        XCTAssertTrue(result.errors.contains(.evidenceNotAllowedForNarration(blocked.id)))

        result = MonthlyStoryScriptValidator.validate(script: MonthlyStoryFixtures.validScript,
                                                      claimedEvidenceIDs: [],
                                                      availableEvidence: MonthlyStoryFixtures.richMonth.evidence)
        XCTAssertTrue(result.errors.contains(.missingEvidenceClaims))
    }

    func testTherapistMotivationalAppTechnicalAndIdentifierLanguageFails() {
        let additions = [
            " as your therapist, this is part of your healing journey.",
            " you've got this; unlock your potential and never give up.",
            " your streak and app usage showed strong engagement.",
            " moodEvidenceDays and uidHash were included.",
            " contact person@example.com using device id 123."
        ]
        for addition in additions {
            let result = MonthlyStoryScriptValidator.validate(script: MonthlyStoryFixtures.validScript + addition,
                                                              claimedEvidenceIDs: [],
                                                              availableEvidence: [])
            XCTAssertFalse(result.isValid)
        }
    }
}
