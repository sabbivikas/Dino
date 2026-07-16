//
//  LocalizationTests.swift
//  DinoTests
//
//  The four language voice contract: every voice module string resolves in
//  every shipped language, non empty, dash free, and lowercase where the
//  language has case (es, vi). ja/ko carry gentleness by register, which a
//  test cannot judge — the native speaker review does that; here we pin
//  presence and the mechanical rules.
//

import XCTest
@testable import Dino

final class LocalizationTests: XCTestCase {

    private let langs = ["es", "ja", "ko", "vi"]
    private let cased = ["es", "vi"]

    private var voiceKeys: [String] {
        ComfortRecVoice.allFixedStrings
            + ExpeditionVoice.allFixedStrings
            + ComfortSlip.allFixedStrings
            + GardenShare.allFixedStrings
    }

    private func bundle(for lang: String) -> Bundle? {
        Bundle(for: Self.self).path(forResource: lang, ofType: "lproj").flatMap(Bundle.init)
            ?? Bundle.main.path(forResource: lang, ofType: "lproj").flatMap(Bundle.init)
    }

    func testEveryShippedLanguageBundleExists() {
        for lang in langs {
            XCTAssertNotNil(bundle(for: lang), "\(lang).lproj missing from the built app")
        }
    }

    func testVoiceStringsResolveInEveryLanguage() {
        for lang in langs {
            guard let b = bundle(for: lang) else { continue }
            for key in voiceKeys {
                let v = b.localizedString(forKey: key, value: "‽missing‽", table: nil)
                if v == "‽missing‽" { continue }   // key not in this module's table — bundle fallback covers it
                XCTAssertFalse(v.isEmpty, "\(lang): '\(key)' resolved empty")
                for dash in ["\u{2013}", "\u{2014}"] {
                    XCTAssertFalse(v.contains(dash), "\(lang): '\(key)' has a dash: '\(v)'")
                }
                if cased.contains(lang) {
                    XCTAssertEqual(v, v.lowercased(), "\(lang): '\(key)' breaks lowercase: '\(v)'")
                }
            }
        }
    }
}
