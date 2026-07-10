//
//  ResourcesRedesignTests.swift
//  DinoTests
//
//  The paper-cards presentation model: state selection, the tape rule
//  (hero only, never in fallback), tilt bounds, understated badges, the
//  988 secondary, number preservation at any type size, string contract.
//

import XCTest
@testable import Dino

final class ResourcesRedesignTests: XCTestCase {

    // MARK: - State selection

    func testRegionalModelPutsTheCrisisLineFirstAsHero() {
        let model = ResourceScreen.model(for: "US")
        XCTAssertFalse(model.isFallback)
        XCTAssertEqual(model.hero?.name, "988 suicide & crisis lifeline")
        XCTAssertEqual(model.rows.count, 3)
        XCTAssertEqual(model.header, "support is always close 🌿")
    }

    func testJapanModelHeroWithHonestHours() {
        let model = ResourceScreen.model(for: "JP")
        XCTAssertFalse(model.isFallback)
        XCTAssertEqual(model.hero?.is24h, false)   // hours vary — never overclaimed
        XCTAssertNil(model.hero?.secondaryLabel)   // no invented secondaries
    }

    func testUnknownRegionFallsBackToBareDirectoryCards() {
        let model = ResourceScreen.model(for: "ZZ")
        XCTAssertTrue(model.isFallback)
        // the tape rule: tape renders only on a hero — fallback has none
        XCTAssertNil(model.hero)
        XCTAssertEqual(model.rows.count, 3)
        XCTAssertEqual(model.header, "wherever you are, help exists 🌍")
    }

    // MARK: - Tilt bounds (paper warmth, straight eye path)

    func testEveryTiltStaysUnderTheLimitAndAlternates() {
        XCTAssertLessThan(abs(ResourceScreen.heroTilt), 1.2)
        var lastSign = 0.0
        for i in 0..<6 {
            let tilt = ResourceScreen.rowTilt(index: i)
            XCTAssertLessThan(abs(tilt), 1.2)
            if lastSign != 0 { XCTAssertNotEqual(tilt.sign, lastSign.sign, "tilts must alternate") }
            lastSign = tilt
        }
    }

    // MARK: - Badges understate

    func testBadgesNeverOverclaim() {
        XCTAssertEqual(ResourceScreen.badge(is24h: true), "24/7")
        XCTAssertEqual(ResourceScreen.badge(is24h: false), "hours vary")
    }

    // MARK: - The 988 secondary (owner-approved data change)

    func testOnlyUS988CarriesTheTextSecondary() {
        let us = CrisisResources.directory["US"] ?? []
        XCTAssertEqual(us.first?.textNumber, "988")
        XCTAssertEqual(us.first?.secondaryLabel, "text 988 instead")
        XCTAssertEqual(us.first?.secondaryURL?.absoluteString, "sms:988")
        // nothing else grew a secondary in the same change
        for (region, list) in CrisisResources.directory {
            for resource in list where !(region == "US" && resource.contact == "988") {
                XCTAssertNil(resource.textNumber, "\(region)/\(resource.name) has an unreviewed secondary")
            }
        }
    }

    // MARK: - Numbers survive any type size

    func testAccessibilityLabelsAlwaysCarryTheFullNumber() {
        // the vo label and the visible action label both contain the full
        // contact for every callable line — shrink, never truncate
        for (region, list) in CrisisResources.directory {
            for resource in list where resource.kind == .call {
                let vo = ResourceScreen.voCallLabel(name: resource.name, contact: resource.contact)
                XCTAssertTrue(vo.contains(resource.contact), "\(region)/\(resource.name) vo label drops the number")
                XCTAssertTrue(resource.actionLabel.contains(resource.contact), "\(region)/\(resource.name) action label drops the number")
            }
        }
    }

    // MARK: - String contract

    func testResourceScreenStringsObeyTheVoiceContract() {
        var strings = ResourceScreen.allFixedStrings
        strings.append(CrisisResources.emergencyFooter)
        if let secondary = CrisisResources.directory["US"]?.first?.secondaryLabel {
            strings.append(secondary)
        }
        for s in strings {
            XCTAssertEqual(s, s.lowercased(), "'\(s)' breaks lowercase")
            for dash in ["-", "\u{2013}", "\u{2014}"] {
                XCTAssertFalse(s.contains(dash), "'\(s)' contains a dash")
            }
        }
    }
}
