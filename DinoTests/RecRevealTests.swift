//
//  RecRevealTests.swift
//  DinoTests
//
//  Rec delivery F4 — the reveal: the unwrap state machine (card revealed =
//  opened; dismissed while wrapped = stays announced), the image pipeline's
//  fallback selection (never a broken image), the share payload, the poster
//  path gate, and the one new catalog string.
//

import XCTest
@testable import Dino

final class RecRevealTests: XCTestCase {

    // MARK: - the state machine (announced → opened rule)

    func testParcelTapWaitsForThePayload() {
        XCTAssertEqual(RecRevealMachine.afterParcelTap(
            phase: .wrapped, payloadReady: false, reduceMotion: false), .wrapped,
            "an empty parcel never unwraps — offline stays a wrapped parcel, not a broken card")
    }

    func testParcelTapUnwrapsWhenReady() {
        XCTAssertEqual(RecRevealMachine.afterParcelTap(
            phase: .wrapped, payloadReady: true, reduceMotion: false), .unwrapping)
    }

    func testReduceMotionSkipsTheFoldAndFadesStraightToTheCard() {
        XCTAssertEqual(RecRevealMachine.afterParcelTap(
            phase: .wrapped, payloadReady: true, reduceMotion: true), .revealed)
    }

    func testATapMidUnwrapOrPostRevealChangesNothing() {
        XCTAssertEqual(RecRevealMachine.afterParcelTap(
            phase: .unwrapping, payloadReady: true, reduceMotion: false), .unwrapping)
        XCTAssertEqual(RecRevealMachine.afterParcelTap(
            phase: .revealed, payloadReady: true, reduceMotion: false), .revealed)
    }

    func testUnwrapAnimationEndsInRevealed() {
        XCTAssertEqual(RecRevealMachine.afterUnwrapAnimation(phase: .unwrapping), .revealed)
        XCTAssertEqual(RecRevealMachine.afterUnwrapAnimation(phase: .wrapped), .wrapped)
    }

    func testCardRevealedEqualsOpenedOnlyForAnAnnouncedDelivery() {
        // THE RULE: revealed + announced → mark opened
        XCTAssertTrue(RecRevealMachine.shouldMarkOpened(phase: .revealed, deliveryStatus: "announced"))
        // a stale re-tap (already opened) shows the card but writes nothing
        XCTAssertFalse(RecRevealMachine.shouldMarkOpened(phase: .revealed, deliveryStatus: "opened"))
        XCTAssertFalse(RecRevealMachine.shouldMarkOpened(phase: .revealed, deliveryStatus: nil))
        // never before the card actually shows
        XCTAssertFalse(RecRevealMachine.shouldMarkOpened(phase: .wrapped, deliveryStatus: "announced"))
        XCTAssertFalse(RecRevealMachine.shouldMarkOpened(phase: .unwrapping, deliveryStatus: "announced"))
    }

    func testDismissedWhileWrappedStaysAnnouncedForTheShelfCatch() {
        XCTAssertTrue(RecRevealMachine.parcelStaysForLater(phase: .wrapped))
        XCTAssertTrue(RecRevealMachine.parcelStaysForLater(phase: .unwrapping))
        XCTAssertFalse(RecRevealMachine.parcelStaysForLater(phase: .revealed))
    }

    func testStalePurgedRevealDismissesToTheShelfNeverAnUnopenableParcel() {
        // an already-opened delivery whose server payload was purged: readable
        // status, but no recs → dismiss to the shelf (keepsake already there)
        XCTAssertTrue(RecRevealMachine.shouldDismissToShelf(deliveryReadable: true, hasRecs: false))
        // a real reveal with content never dismisses
        XCTAssertFalse(RecRevealMachine.shouldDismissToShelf(deliveryReadable: true, hasRecs: true))
        // a full miss (offline / still held — unreadable) stays a wrapped parcel
        XCTAssertFalse(RecRevealMachine.shouldDismissToShelf(deliveryReadable: false, hasRecs: false))
    }

    // MARK: - image pipeline: fallback selection (never a broken image)

    private func rec(type: String, posterPath: String? = nil) -> RichRec {
        RichRec(type: type, title: "a gentle thing", creator: "someone kind", year: 2000,
                why: "w", flags: ["a soft one"], feel: "quiet", length: "no rush at all",
                posterPath: posterPath)
    }

    func testFilmWithPosterPathGoesStraightToTheTmdbImageBase() {
        let s = RecArtwork.strategy(for: rec(type: "film", posterPath: "/abc.jpg"))
        XCTAssertEqual(s, .direct(URL(string: "https://image.tmdb.org/t/p/w500/abc.jpg")!))
    }

    func testFilmWithoutPosterPathMakesZeroNetworkAttempts() {
        XCTAssertEqual(RecArtwork.strategy(for: rec(type: "film")), .none,
                       "absent poster = the paper card design, no request, no broken frame")
    }

    func testBookAndMusicRouteThroughTheirKeylessLookups() {
        guard case .lookup(let bookURL) = RecArtwork.strategy(for: rec(type: "book")) else {
            return XCTFail("book should look up open library")
        }
        XCTAssertEqual(bookURL.host, "openlibrary.org")
        guard case .lookup(let musicURL) = RecArtwork.strategy(for: rec(type: "music")) else {
            return XCTFail("music should look up itunes search")
        }
        XCTAssertEqual(musicURL.host, "itunes.apple.com")
    }

    func testGiftTypeStaysPaper() {
        XCTAssertEqual(RecArtwork.strategy(for: rec(type: "gift")), .none)
    }

    func testTmdbPosterURLRejectsAnythingButTmdbsShape() {
        XCTAssertNil(RecArtwork.tmdbPosterURL(posterPath: nil))
        XCTAssertNil(RecArtwork.tmdbPosterURL(posterPath: ""))
        XCTAssertNil(RecArtwork.tmdbPosterURL(posterPath: "abc.jpg"))
        XCTAssertNil(RecArtwork.tmdbPosterURL(posterPath: "/nested/x.jpg"))
        XCTAssertNil(RecArtwork.tmdbPosterURL(posterPath: "https://evil.example/x.jpg"))
        XCTAssertNil(RecArtwork.tmdbPosterURL(posterPath: "/x.jpg?y=1"))
        XCTAssertNotNil(RecArtwork.tmdbPosterURL(posterPath: "/rtGDOeG9LzoerkDGZF9dnVeLppL.jpg"))
    }

    func testItunesArtworkParsingUpscalesAndSurvivesJunk() {
        let good = #"{"results":[{"artworkUrl100":"https://a.mzstatic.com/img/100x100bb.jpg"}]}"#
        XCTAssertEqual(RecArtwork.itunesArtworkURL(fromSearchData: Data(good.utf8))?.absoluteString,
                       "https://a.mzstatic.com/img/600x600bb.jpg")
        XCTAssertNil(RecArtwork.itunesArtworkURL(fromSearchData: Data("{}".utf8)))
        XCTAssertNil(RecArtwork.itunesArtworkURL(fromSearchData: Data(#"{"results":[]}"#.utf8)))
        XCTAssertNil(RecArtwork.itunesArtworkURL(fromSearchData: Data("not json".utf8)))
        let insecure = #"{"results":[{"artworkUrl100":"http://a.mzstatic.com/img/100x100bb.jpg"}]}"#
        XCTAssertNil(RecArtwork.itunesArtworkURL(fromSearchData: Data(insecure.utf8)))
    }

    func testOpenLibraryCoverParsingSurvivesJunk() {
        let good = #"{"docs":[{"cover_i":12345}]}"#
        XCTAssertEqual(RecArtwork.openLibraryCoverURL(fromSearchData: Data(good.utf8))?.absoluteString,
                       "https://covers.openlibrary.org/b/id/12345-L.jpg")
        XCTAssertNil(RecArtwork.openLibraryCoverURL(fromSearchData: Data(#"{"docs":[{}]}"#.utf8)))
        XCTAssertNil(RecArtwork.openLibraryCoverURL(fromSearchData: Data(#"{"docs":[]}"#.utf8)))
        XCTAssertNil(RecArtwork.openLibraryCoverURL(fromSearchData: Data("junk".utf8)))
        XCTAssertNil(RecArtwork.openLibraryCoverURL(fromSearchData: Data(#"{"docs":[{"cover_i":0}]}"#.utf8)))
    }

    // MARK: - sanitizer carries the poster path (film only, exact shape)

    func testSanitizerAcceptsAFilmPosterPath() {
        let dict: [String: Any] = ["type": "film", "title": "t", "creator": "c", "year": 1999,
                                   "posterPath": "/abc-1.jpg"]
        XCTAssertEqual(ComfortRecSanitizer.rec(from: dict)?.posterPath, "/abc-1.jpg")
    }

    func testSanitizerDropsPosterPathOffFilmsAndOffShape() {
        let music: [String: Any] = ["type": "music", "title": "t", "creator": "c", "year": 1999,
                                    "posterPath": "/abc.jpg"]
        XCTAssertNil(ComfortRecSanitizer.rec(from: music)?.posterPath)
        let sneaky: [String: Any] = ["type": "film", "title": "t", "creator": "c", "year": 1999,
                                     "posterPath": "https://evil.example/x.jpg"]
        XCTAssertNil(ComfortRecSanitizer.rec(from: sneaky)?.posterPath)
        let traversal: [String: Any] = ["type": "film", "title": "t", "creator": "c", "year": 1999,
                                        "posterPath": "/../secrets.jpg"]
        XCTAssertNil(ComfortRecSanitizer.rec(from: traversal)?.posterPath)
    }

    func testOldCachedRecsDecodeWithoutAPosterPath() throws {
        let old = #"{"type":"music","title":"t","creator":"c","year":1999,"why":"w","flags":["a soft one"],"feel":"quiet","length":"l"}"#
        let decoded = try JSONDecoder().decode(RichRec.self, from: Data(old.utf8))
        XCTAssertNil(decoded.posterPath)
    }

    // MARK: - share payload (title + link, locked spec)

    func testSharePayloadCarriesTitleCreatorAndTheReopenLink() {
        let film = RichRec(type: "film", title: "my neighbor totoro", creator: "hayao miyazaki",
                           year: 1988, why: "w", flags: ["a soft one"], feel: "hopeful",
                           length: "about 86 minutes",
                           watchProvider: "max", watchLink: "https://www.themoviedb.org/movie/8392/watch")
        XCTAssertEqual(RecRevealShare.message(for: film), "my neighbor totoro \u{00B7} hayao miyazaki")
        XCTAssertEqual(RecRevealShare.url(for: film)?.absoluteString,
                       "https://www.themoviedb.org/movie/8392/watch")
    }

    // MARK: - the source pill (watch-provider or source)

    func testSourcePillPrefersTheWatchProviderThenFallsBack() {
        let film = rec(type: "film")
        XCTAssertEqual(RecRevealVoice.sourcePill(
            for: RichRec(type: "film", title: "t", creator: "c", year: 2000, why: "w",
                         flags: [], feel: "quiet", length: "l",
                         watchProvider: "max", watchLink: "https://www.themoviedb.org/x"),
            rememberedMusicApp: nil), "max")
        XCTAssertEqual(RecRevealVoice.sourcePill(for: film, rememberedMusicApp: nil),
                       "film".localized)
        XCTAssertEqual(RecRevealVoice.sourcePill(for: rec(type: "music"), rememberedMusicApp: "spotify"),
                       "spotify")
        XCTAssertEqual(RecRevealVoice.sourcePill(for: rec(type: "music"), rememberedMusicApp: nil),
                       RecOpenMemory.appleMusic)
        XCTAssertEqual(RecRevealVoice.sourcePill(for: rec(type: "book"), rememberedMusicApp: nil),
                       "apple books")
    }

    // MARK: - the one new string (×4 with the shipped voice)

    func testOpenItCarriesAllFourTranslationsInTheCatalog() throws {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Dino/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = (json?["strings"] as? [String: Any]) ?? [:]
        guard let entry = strings["open it"] as? [String: Any],
              let locs = entry["localizations"] as? [String: Any] else {
            return XCTFail("missing catalog entry: open it")
        }
        for lang in ["en", "es", "ja", "ko", "vi"] {
            guard let l = locs[lang] as? [String: Any],
                  let unit = l["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String, !value.isEmpty else {
                XCTFail("open it missing \(lang)"); continue
            }
            XCTAssertEqual(value, value.lowercased(), "case in \(lang)")
            XCTAssertFalse(value.contains("\u{2014}") || value.contains("\u{2013}") || value.contains(" - "),
                           "dash in \(lang): \(value)")
        }
        XCTAssertEqual((locs["en"] as? [String: Any])
            .flatMap { $0["stringUnit"] as? [String: Any] }?["value"] as? String, "open it")
    }

    // MARK: - qa fixtures stay out of production paths

    @MainActor
    func testQAFixturesOnlyAnswerQaPrefixedIds() {
        XCTAssertNil(RecRevealService.qaDelivery(for: "real-delivery-id", arguments: ["-recRevealQA"]))
        XCTAssertEqual(RecRevealService.qaDelivery(for: "qa-parcel", arguments: ["-recRevealQA"])?
            .recs.first?.type, "film")
        XCTAssertNil(RecRevealService.qaDelivery(for: "qa-parcel", arguments: ["-recRevealQAPaper"])?
            .recs.first?.posterPath, "the paper fixture must carry no poster")
    }
}