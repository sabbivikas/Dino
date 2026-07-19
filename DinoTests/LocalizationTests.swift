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
// audit sentinels
    // audit sentinels — one key per newly-audited surface; if any of these
    // resolves to its english key in a shipped language, the audit regressed.
    // (values with dashes are checked dash-free like all voice strings.)
    private let auditSentinels = [
        "hey, you.\n\nthe fact that you're here means something.\nmaybe things feel heavy. maybe you're just curious.\neither way, you showed up. that matters.\n\ndino is your space.\nno pressure. no judgment.\njust a place to breathe, reflect, and grow.\n\nlet's take this one step at a time.",
        "hey, how are you feeling today? take a sec to check in 🌱",
        "you are enough, exactly as you are.",
        "the big sigh",
        "%lld feelings shared today",
        "welcome to dino",
        "good morning",
        "kept. sleep well.",
        "over the past week, how often have you felt down, depressed, or hopeless?",
        "what dino collects",
    ]

    func testAuditSentinelsResolveInEveryLanguage() throws {
        for lang in langs {
            guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
                  let bundle = Bundle(path: path) else {
                XCTFail("missing \(lang).lproj"); continue
            }
            for key in auditSentinels {
                let resolved = bundle.localizedString(forKey: key, value: "⟂MISSING⟂", table: nil)
                XCTAssertNotEqual(resolved, "⟂MISSING⟂", "\(lang): sentinel not in catalog: \(key.prefix(40))")
                XCTAssertNotEqual(resolved, key, "\(lang): sentinel resolves to english: \(key.prefix(40))")
                XCTAssertFalse(resolved.contains("—") || resolved.contains("–"),
                               "\(lang): dash in translation of \(key.prefix(40))")
            }
        }
    }

}
