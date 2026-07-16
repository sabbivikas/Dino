//
//  MemoryShelfLocalizationTests.swift
//  DinoTests
//
//  Permanent rule (memory + shelf arc): new user-facing strings never ship
//  english-only. This branch predates the localization merge, so the
//  sentinels assert against the catalog SOURCE — every new shelf key must
//  carry es/ja/ko/vi values, lowercase where cased, dash-free.
//

import XCTest
@testable import Dino

final class MemoryShelfLocalizationTests: XCTestCase {

    private let newKeys = [
        "your little shelf · %lld things dino has brought you",
        "your little shelf · 1 thing dino has brought you",
        "everything",
        "kept",
        "keep this",
        "when dino brings you something, it will rest here 🌿",
        "%lld kept",
    ]

    private func loadCatalog() throws -> [String: Any] {
        // DinoTests/…/this file → repo root → Dino/Localizable.xcstrings
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Dino/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["strings"] as? [String: Any]) ?? [:]
    }

    func testShelfKeysCarryAllFourLanguages() throws {
        let strings = try loadCatalog()
        for key in newKeys {
            guard let entry = strings[key] as? [String: Any],
                  let locs = entry["localizations"] as? [String: Any] else {
                XCTFail("missing catalog entry: \(key)"); continue
            }
            for lang in ["es", "ja", "ko", "vi"] {
                guard let l = locs[lang] as? [String: Any],
                      let unit = l["stringUnit"] as? [String: Any],
                      let value = unit["value"] as? String, !value.isEmpty else {
                    XCTFail("\(key) missing \(lang)"); continue
                }
                XCTAssertFalse(value.contains("—") || value.contains("–"),
                               "dash in \(lang) of \(key)")
                if lang == "es" || lang == "vi" {
                    XCTAssertEqual(value, value.lowercased(), "case in \(lang) of \(key)")
                }
            }
        }
    }

    func testKeepsakeMigrationDefaultsToKept() throws {
        // an old-format entry (no kept field) decodes as kept — continuity
        let old = """
        [{"rec": {"type": "music", "title": "t", "creator": "c", "year": 2020,
                  "why": "w", "flags": [], "feel": "quiet", "length": ""},
          "shownAt": 700000000}]
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let items = try decoder.decode([RichRecStore.Keepsake].self, from: old)
        XCTAssertTrue(items[0].kept)
        XCTAssertNil(items[0].ledgerId)
    }
}
