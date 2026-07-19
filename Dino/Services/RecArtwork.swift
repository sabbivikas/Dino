//
//  RecArtwork.swift
//  Dino
//
//  Rec delivery F4 — the image-led card's artwork pipeline, one keyless
//  path per media type:
//    • film  → the tmdb poster path already in the payload + the documented
//              image base (no api call at all)
//    • book  → open library search → covers.openlibrary.org by cover id
//    • music → itunes search → artworkUrl100 upscaled to 600x600
//  NEVER a broken image: every step returns nil on any doubt (timeout,
//  parse miss, blank cover) and the card renders its paper-only design —
//  no gray boxes, no placeholder icons. URLCache (URLSession default)
//  keeps a repeat reveal free.
//

import Foundation
import UIKit

enum RecArtwork {

    /// The documented TMDB image base (w500 — plenty for a 150pt card).
    static let tmdbImageBase = "https://image.tmdb.org/t/p/w500"
    /// Graceful timeout — past this the card simply stays paper.
    static let requestTimeout: TimeInterval = 5

    enum Strategy: Equatable {
        case direct(URL)     // the artwork url is already known (film poster)
        case lookup(URL)     // one keyless search first (book / music)
        case none            // paper-only card, zero network
    }

    /// Pure routing — tested. A film without a poster path makes NO network
    /// attempt: absent image = the paper card design, by construction.
    static func strategy(for rec: RichRec) -> Strategy {
        switch rec.type {
        case "film":
            if let url = tmdbPosterURL(posterPath: rec.posterPath) { return .direct(url) }
            return .none
        case "book":
            if let url = openLibrarySearchURL(title: rec.title, creator: rec.creator) { return .lookup(url) }
            return .none
        case "music":
            if let url = itunesSearchURL(title: rec.title, creator: rec.creator) { return .lookup(url) }
            return .none
        default:
            return .none   // gifts and anything unknown stay paper
        }
    }

    // MARK: pure builders + parsers (tested)

    static func tmdbPosterURL(posterPath: String?) -> URL? {
        guard let p = posterPath,
              p.range(of: "^/[A-Za-z0-9._-]{1,95}\\.(jpg|png)$",
                      options: .regularExpression) != nil else { return nil }
        return URL(string: tmdbImageBase + p)
    }

    static func itunesSearchURL(title: String, creator: String) -> URL? {
        var comps = URLComponents(string: "https://itunes.apple.com/search")
        comps?.queryItems = [
            URLQueryItem(name: "term", value: "\(title) \(creator)"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        return comps?.url
    }

    static func itunesArtworkURL(fromSearchData data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["results"] as? [[String: Any]])?.first,
              let raw = first["artworkUrl100"] as? String,
              raw.hasPrefix("https://") else { return nil }
        return URL(string: raw.replacingOccurrences(of: "100x100", with: "600x600"))
    }

    static func openLibrarySearchURL(title: String, creator: String) -> URL? {
        var comps = URLComponents(string: "https://openlibrary.org/search.json")
        comps?.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "author", value: creator),
            URLQueryItem(name: "limit", value: "1"),
        ]
        return comps?.url
    }

    static func openLibraryCoverURL(fromSearchData data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["docs"] as? [[String: Any]])?.first,
              let coverId = first["cover_i"] as? Int, coverId > 0 else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-L.jpg")
    }

    // MARK: network (graceful — nil on any failure, the card stays paper)

    static func loadImage(for rec: RichRec, session: URLSession = .shared) async -> UIImage? {
        let artworkURL: URL?
        switch strategy(for: rec) {
        case .none:
            return nil
        case .direct(let url):
            artworkURL = url
        case .lookup(let search):
            guard let data = await fetch(search, session: session) else { return nil }
            artworkURL = rec.type == "book"
                ? openLibraryCoverURL(fromSearchData: data)
                : itunesArtworkURL(fromSearchData: data)
        }
        guard let artworkURL,
              let data = await fetch(artworkURL, session: session),
              let image = UIImage(data: data),
              image.size.width > 10, image.size.height > 10   // a 1x1 blank is not a cover
        else { return nil }
        return image
    }

    private static func fetch(_ url: URL, session: URLSession) async -> Data? {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad,
                                 timeoutInterval: requestTimeout)
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true
        else { return nil }
        return data
    }
}