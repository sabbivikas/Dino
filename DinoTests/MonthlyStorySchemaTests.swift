import XCTest
@testable import Dino

final class MonthlyStorySchemaTests: XCTestCase {
    func testSignalRoundTripsWithStrictStructuredSchema() throws {
        let data = try JSONEncoder().encode(MonthlyStoryFixtures.richMonth)
        let decoded = try JSONDecoder().decode(MonthlyStorySignal.self, from: data)
        XCTAssertEqual(decoded, MonthlyStoryFixtures.richMonth)
        XCTAssertTrue(decoded.isUploadable)
    }

    func testProhibitedAndUnknownFieldsAreRejected() {
        XCTAssertThrowsError(try JSONDecoder().decode(MonthlyStorySignal.self,
                                                      from: MonthlyStoryFixtures.arbitraryStringInjectionJSON)) { error in
            XCTAssertEqual(error as? MonthlyStorySchemaError, .unknownField("rawJournalText"))
        }
        XCTAssertThrowsError(try JSONDecoder().decode(MonthlyStorySignal.self,
                                                      from: MonthlyStoryFixtures.malformedSchemaJSON))
    }

    func testNestedSchemaObjectsAlsoRejectUnknownFields() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(MonthlyStoryFixtures.richMonth)) as? [String: Any])
        var permissions = try XCTUnwrap(object["permissions"] as? [String: Any])
        permissions["gratitudeText"] = "not allowed"
        object["permissions"] = permissions
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(MonthlyStorySignal.self, from: data)) { error in
            XCTAssertEqual(error as? MonthlyStorySchemaError, .unknownField("gratitudeText"))
        }
    }

    func testEvidenceRejectsArbitraryFieldInjection() throws {
        let evidence = MonthlyStoryFixtures.recommendationOpened
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(evidence)) as? [String: Any])
        object["recommendationTitle"] = "A private title"
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(MonthlyStoryEvidence.self, from: data)) { error in
            XCTAssertEqual(error as? MonthlyStorySchemaError, .unknownField("recommendationTitle"))
        }

        var valueObject = try XCTUnwrap(object["value"] as? [String: Any])
        valueObject["theme"] = "family"
        object.removeValue(forKey: "recommendationTitle")
        object["value"] = valueObject
        let mixedValueData = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(MonthlyStoryEvidence.self, from: mixedValueData)) { error in
            XCTAssertEqual(error as? MonthlyStorySchemaError, .unknownField("theme"))
        }
    }

    func testArrayBoundsAndDuplicateIDsAreEnforced() throws {
        let tooMany = (0...64).map {
            MonthlyStoryFixtures.evidence(String(format: "item-%02d", $0),
                                          value: .restorativePractice(.focus))
        }
        XCTAssertThrowsError(try MonthlyStoryFixtures.signal(evidence: tooMany)) { error in
            XCTAssertEqual(error as? MonthlyStorySchemaError, .tooManyValues)
        }

        let duplicate = MonthlyStoryFixtures.evidence("duplicate", value: .restorativePractice(.focus))
        XCTAssertThrowsError(try MonthlyStoryFixtures.signal(evidence: [duplicate, duplicate])) { error in
            XCTAssertEqual(error as? MonthlyStorySchemaError, .duplicateValue)
        }
    }

    func testPermissionsMakeUnauthorizedEvidenceImpossible() {
        let noJournal = MonthlyStoryPermissions(featureEnabled: true,
                                                journalThemesEnabled: false,
                                                healthPatternsEnabled: true,
                                                audioEnabled: false)
        XCTAssertThrowsError(try MonthlyStoryFixtures.signal(permissions: noJournal, evidence: [
            MonthlyStoryFixtures.evidence("theme-denied", value: .repeatedTheme(.family), source: .authorizedJournalTheme)
        ]))

        let noHealth = MonthlyStoryPermissions(featureEnabled: true,
                                               journalThemesEnabled: true,
                                               healthPatternsEnabled: false,
                                               audioEnabled: false)
        XCTAssertThrowsError(try MonthlyStoryFixtures.signal(permissions: noHealth, evidence: [
            MonthlyStoryFixtures.evidence("sleep-denied", value: .sleepPattern(.steady), source: .authorizedHealthSummary)
        ]))
    }

    func testSafetyHoldRemovesEvidenceAndBlocksUpload() {
        XCTAssertFalse(MonthlyStorySafetyDecision.hold.isStorySafetyEligible)
        XCTAssertTrue(MonthlyStorySafetyDecision.eligible.isStorySafetyEligible)
        let signal = MonthlyStoryFixtures.sensitiveMonth
        XCTAssertFalse(signal.isUploadable)
        XCTAssertTrue(signal.evidence.isEmpty)
    }

    func testSafeThemeAllowlistIncludesOnlyApprovedBroadThemes() {
        XCTAssertEqual(MonthlyStoryThemeAllowlist.theme(forExistingTag: "work"), .workPressure)
        XCTAssertEqual(MonthlyStoryThemeAllowlist.theme(forExistingTag: "relationships"), .relationships)
        XCTAssertEqual(MonthlyStoryThemeAllowlist.theme(forExistingTag: "sleep"), .rest)
        for excluded in ["self-harm", "suicide", "abuse", "trauma", "grief", "medical", "money", "legal", "Acme Corp", "Taylor"] {
            XCTAssertNil(MonthlyStoryThemeAllowlist.theme(forExistingTag: excluded))
        }
    }

    func testSyntheticSignalsContainNoRawPrivateContentOrIdentifiers() throws {
        let fixtures = [MonthlyStoryFixtures.richMonth,
                        MonthlyStoryFixtures.moodOnlyMonth,
                        MonthlyStoryFixtures.sparseMonth,
                        MonthlyStoryFixtures.noJournalPermission,
                        MonthlyStoryFixtures.noHealthPermission,
                        MonthlyStoryFixtures.noJournalOrHealthPermission,
                        MonthlyStoryFixtures.sensitiveMonth]
        let prohibited = ["journaltext", "gratitudetext", "email", "uid", "deviceid", "stepcount", "sleepduration", "recommendationtitle", "url", "reporttext", "checkinanswer", "prompt", "crisisreason"]
        for fixture in fixtures {
            let json = String(decoding: try JSONEncoder().encode(fixture), as: UTF8.self).lowercased()
            for key in prohibited { XCTAssertFalse(json.contains(key), "fixture leaked prohibited key: \(key)") }
        }
    }
}
