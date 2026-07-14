//
//  ComfortRecService.swift
//  Dino
//
//  Feature 1 of the 2.1 comfort recs arc: personalized recs. On a fully
//  cleared heavy moment dino asks the server for THREE personal picks (one
//  shown, two cached locally), each written for this person's day by the
//  cheapest capable model. Every GentleRecEngine gate is unchanged —
//  scarcity is still the feature; this only changes what a cleared moment
//  fetches. The classic pool (GentleRecCoordinator) remains the silent
//  fallback, and silence remains the deepest default.
//
//  Privacy: only enum buckets leave the device (mood, time slot, 3 bucket
//  trend, theme enums, quiet types, locale) plus titles of PRIOR AI RECS
//  (model output, not user content). No journal text, no step counts, no
//  sleep hours, no streaks, no names. The server rejects unexpected fields.
//

import Foundation
import SwiftUI
import FirebaseFunctions

/// One personalized pick, exactly as the card renders it.
struct RichRec: Codable, Equatable {
    let type: String        // music | book | film
    let title: String
    let creator: String
    let year: Int
    let why: String         // dino's fresh personal line, never templated
    let flags: [String]     // content flags from the fixed allowlist
    let feel: String        // cozy | hopeful | quiet
    let length: String      // honest time commitment, "about 2 hours"
}

/// A plain search link — no APIs, no tracking, just where to look.
struct RecLink: Equatable, Identifiable {
    let label: String
    let url: URL
    var id: String { label }
}

enum ComfortRecVoice {
    // fixed strings (lowercase, zero dashes — voice tested)
    static let whyLabel = "why this fits your day"
    static let feelPrefix = "feels"
    static let lengthPrefix = "asks for"
    static let openAppleMusic = "listen on apple music"
    static let openSpotify = "listen on spotify"
    static let openBooks = "read it on apple books"
    static let openTV = "watch it on apple tv"
    static let fallbackWhy = "it felt like a soft match for today"
    static let fallbackLength = "no rush at all"
    static let flagSeparator = " \u{00B7} "
    // feature 2: the one time ask, then dino remembers their place
    static let askWhich = "listen on apple music or spotify?"
    static let orPrefix = "or"
    // feature 3: the little shelf
    static let shelfTitle = "your little shelf"
    static let shelfEmpty = "nothing here yet"
    static let shelfEmptySub = "when dino picks something for you, it rests here"

    static func shelfKept(_ n: Int) -> String { "\(n) kept" }
    static func shelfRowLine(_ n: Int) -> String { "\(shelfTitle) \u{00B7} \(shelfKept(n))" }

    static let allowedTypes = ["music", "book", "film"]
    static let allowedFeels = ["cozy", "hopeful", "quiet"]
    static let allowedFlags = ["not graphic", "no distressing themes", "a soft one",
                               "gentle pacing", "some bittersweet moments"]

    /// the header follows the hour — no forced moon at midday (owner tweak).
    static func header(hour: Int) -> String {
        (5..<17).contains(hour) ? "dino picked this for you 🌿"
                                : "dino picked this for you 🌙"
    }

    static func metaLine(_ rec: RichRec) -> String {
        "\(rec.creator) \u{00B7} \(rec.type) \u{00B7} \(String(rec.year))"
    }

    static func feelLine(_ rec: RichRec) -> String {
        "\(feelPrefix) \(rec.feel) \u{00B7} \(lengthPrefix) \(rec.length)"
    }

    static func icon(type: String) -> String {
        switch type {
        case "music": return "🎧"
        case "film":  return "🎬"
        default:      return "📖"
        }
    }

    static func iconTint(type: String) -> Color {
        switch type {
        case "music": return Color(red: 196/255, green: 184/255, blue: 212/255).opacity(0.30)
        case "film":  return Color(red: 232/255, green: 136/255, blue: 154/255).opacity(0.26)
        default:      return Color(red: 168/255, green: 212/255, blue: 230/255).opacity(0.32)
        }
    }

    static var allFixedStrings: [String] {
        [whyLabel, feelPrefix, lengthPrefix, openAppleMusic, openSpotify,
         openBooks, openTV, fallbackWhy, fallbackLength, askWhich, orPrefix,
         shelfTitle, shelfEmpty, shelfEmptySub, shelfRowLine(3),
         header(hour: 13), header(hour: 21)]
            + allowedFlags + allowedFeels
    }
}

/// The 3 privacy buckets from the last 7 days of moods — only the bucket
/// word ever leaves the device, never a count.
enum ComfortRecTrend {
    static func bucket(heavyDaysInLastWeek n: Int) -> String {
        switch n {
        case ..<2:  return "steady"
        case 2...3: return "wobbly"
        default:    return "heavy"
        }
    }
}

/// Client-side belt and suspenders: the server already validates, but dino's
/// voice (lowercase, zero dashes) is enforced again here before display.
enum ComfortRecSanitizer {
    static func voiceLine(_ s: String, cap: Int) -> String {
        var t = s.lowercased()
        for dash in ["-", "\u{2013}", "\u{2014}"] {
            t = t.replacingOccurrences(of: dash, with: " ")
        }
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        return String(t.trimmingCharacters(in: .whitespacesAndNewlines).prefix(cap))
    }

    /// Parse + validate one server rec dict; nil when anything load bearing
    /// is off — a dropped rec is silence, never a broken card.
    static func rec(from dict: [String: Any]) -> RichRec? {
        guard let type = (dict["type"] as? String)?.lowercased(),
              ComfortRecVoice.allowedTypes.contains(type),
              let rawTitle = dict["title"] as? String, !rawTitle.isEmpty,
              let rawCreator = dict["creator"] as? String, !rawCreator.isEmpty
        else { return nil }
        let year = (dict["year"] as? Int) ?? Int(dict["year"] as? String ?? "") ?? 0
        let maxYear = Calendar.current.component(.year, from: Date()) + 1
        guard (1900...maxYear).contains(year) else { return nil }
        let why = voiceLine((dict["why"] as? String) ?? "", cap: 140)
        let feelRaw = ((dict["feel"] as? String) ?? "").lowercased()
        let flags = ((dict["flags"] as? [Any]) ?? [])
            .compactMap { ($0 as? String)?.lowercased() }
            .filter { ComfortRecVoice.allowedFlags.contains($0) }
        let length = voiceLine((dict["length"] as? String) ?? "", cap: 40)
        return RichRec(
            type: type,
            title: String(rawTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)),
            creator: String(rawCreator.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)),
            year: year,
            why: why.isEmpty ? ComfortRecVoice.fallbackWhy : why,
            flags: flags.isEmpty ? ["a soft one"] : flags,
            feel: ComfortRecVoice.allowedFeels.contains(feelRaw) ? feelRaw : "quiet",
            length: length.isEmpty ? ComfortRecVoice.fallbackLength : length)
    }
}

/// Feature 2: remembers which music app they chose last time — the ask
/// happens once, then dino defaults to their place. Local only, switchable
/// from the card any time.
enum RecOpenMemory {
    static let key = "dino.recs.musicAppChoice"
    static let appleMusic = "apple music"
    static let spotify = "spotify"

    static func remembered(defaults: UserDefaults = .standard) -> String? {
        let v = defaults.string(forKey: key)
        return (v == appleMusic || v == spotify) ? v : nil
    }

    static func remember(_ choice: String, defaults: UserDefaults = .standard) {
        guard choice == appleMusic || choice == spotify else { return }
        defaults.set(choice, forKey: key)
    }

    static func forget(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    static func other(than choice: String) -> String {
        choice == spotify ? appleMusic : spotify
    }
}

extension RichRec {
    var searchTerm: String { "\(title) \(creator)" }

    /// The search link for a remembered music app choice; nil off music.
    func musicLink(for app: String) -> RecLink? {
        let label = app == RecOpenMemory.spotify ? ComfortRecVoice.openSpotify
                                                 : ComfortRecVoice.openAppleMusic
        return searchLinks.first { $0.label == label }
    }

    /// The link a shelf tap re opens (feature 3): the remembered music app
    /// when there is one, otherwise the single door for the type.
    func reopenLink(defaults: UserDefaults = .standard) -> RecLink? {
        if type == "music" {
            return musicLink(for: RecOpenMemory.remembered(defaults: defaults) ?? RecOpenMemory.appleMusic)
        }
        return searchLinks.first
    }

    /// plain search URLs only — NO APIs (owner decision).
    var searchLinks: [RecLink] {
        let query = searchTerm.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        func link(_ label: String, _ raw: String) -> RecLink? {
            URL(string: raw).map { RecLink(label: label, url: $0) }
        }
        switch type {
        case "music":
            return [link(ComfortRecVoice.openAppleMusic, "https://music.apple.com/search?term=\(query)"),
                    link(ComfortRecVoice.openSpotify, "https://open.spotify.com/search/\(query)")]
                .compactMap { $0 }
        case "film":
            return [link(ComfortRecVoice.openTV, "https://tv.apple.com/search?term=\(query)")]
                .compactMap { $0 }
        default:
            return [link(ComfortRecVoice.openBooks, "https://books.apple.com/search?term=\(query)")]
                .compactMap { $0 }
        }
    }
}

/// One fetched batch: show one, keep the rest for future cleared moments.
struct RichRecBatch: Codable, Equatable {
    let recs: [RichRec]
    let fetchedAt: Date
}

/// Local-only cache + keepsakes (UserDefaults; nothing here ever syncs).
enum RichRecStore {
    static let cacheKey = "dino.recs.richCache"
    static let keepsakesKey = "dino.recs.keepsakes"
    static let staleDays = 45
    static let keepsakeCap = 24

    static func loadCache(defaults: UserDefaults = .standard, now: Date = Date()) -> RichRecBatch? {
        guard let data = defaults.data(forKey: cacheKey),
              let batch = try? JSONDecoder().decode(RichRecBatch.self, from: data) else { return nil }
        let age = Calendar.current.dateComponents([.day], from: batch.fetchedAt, to: now).day ?? 0
        guard age < staleDays, !batch.recs.isEmpty else {
            defaults.removeObject(forKey: cacheKey)
            return nil
        }
        return batch
    }

    /// Pop one cached rec (oldest batch order first); persists the rest.
    static func consumeOne(defaults: UserDefaults = .standard, now: Date = Date()) -> RichRec? {
        guard let batch = loadCache(defaults: defaults, now: now) else { return nil }
        var recs = batch.recs
        let first = recs.removeFirst()
        save(RichRecBatch(recs: recs, fetchedAt: batch.fetchedAt), defaults: defaults)
        return first
    }

    static func save(_ batch: RichRecBatch, defaults: UserDefaults = .standard) {
        if batch.recs.isEmpty { defaults.removeObject(forKey: cacheKey); return }
        if let data = try? JSONEncoder().encode(batch) { defaults.set(data, forKey: cacheKey) }
    }

    /// Every rec dino actually showed — the keepsakes shelf (feature 3).
    struct Keepsake: Codable, Equatable {
        let rec: RichRec
        let shownAt: Date
    }

    static func keepsakes(defaults: UserDefaults = .standard) -> [Keepsake] {
        guard let data = defaults.data(forKey: keepsakesKey),
              let kept = try? JSONDecoder().decode([Keepsake].self, from: data) else { return [] }
        return kept
    }

    static func recordKeepsake(_ rec: RichRec, now: Date = Date(), defaults: UserDefaults = .standard) {
        var kept = keepsakes(defaults: defaults)
        kept.insert(Keepsake(rec: rec, shownAt: now), at: 0)
        if kept.count > keepsakeCap { kept = Array(kept.prefix(keepsakeCap)) }
        if let data = try? JSONEncoder().encode(kept) { defaults.set(data, forKey: keepsakesKey) }
    }

    /// Titles the model should not repeat (cache + shelf, capped at 10).
    static func excludeTitles(defaults: UserDefaults = .standard) -> [String] {
        let cached = loadCache(defaults: defaults)?.recs.map(\.title) ?? []
        let kept = keepsakes(defaults: defaults).map(\.rec.title)
        return Array((cached + kept).prefix(10))
    }
}

@MainActor
enum ComfortRecCoordinator {

    /// Same gates as the classic path (one source of truth: GentleRecEngine),
    /// cache first, one network call fetches three. Returns nil on any miss —
    /// the caller falls back to the classic pool, then to silence.
    static func fetchIfMomentIsRight(dataManager: SharedDataManager,
                                     freshHeavyMood: EmotionalWeather? = nil,
                                     now: Date = Date(),
                                     calendar: Calendar = .current) async -> RichRec? {
        // gate inputs — identical math to GentleRecCoordinator
        let heavyToday: Bool = {
            if let m = freshHeavyMood { return m == .drained || m == .overwhelmed }
            return dataManager.moodEntries.contains {
                calendar.isDate($0.date, inSameDayAs: now)
                    && ($0.weatherType == .drained || $0.weatherType == .overwhelmed)
            }
        }()
        let journalThemesToday = dataManager.themeTags
            .filter { $0.source == ThemeTag.sourceJournal && calendar.isDate($0.date, inSameDayAs: now) }
            .map { $0.theme }

        guard let offer = GentleRecEngine.shouldOffer(
            now: now, calendar: calendar,
            lastShownAt: GentleRecStore.lastShownAt,
            crisisDate: CrisisMarker.lastTriggered(calendar: calendar),
            heavyMoodToday: heavyToday,
            journalToggleOn: dataManager.journalThemeLearningEnabled,
            journalThemesToday: journalThemesToday,
            ignoreCounts: GentleRecStore.ignoreCounts) else { return nil }

        // cache first — one call covers many cleared moments
        if let cached = RichRecStore.consumeOne(now: now) { return cached }

        let heavyMoodValue = freshHeavyMood.flatMap { m in
            (m == .drained || m == .overwhelmed) ? m.rawValue : nil
        } ?? dataManager.moodEntries.first {
            calendar.isDate($0.date, inSameDayAs: now)
                && ($0.weatherType == .drained || $0.weatherType == .overwhelmed)
        }?.weatherType.rawValue ?? ""

        let trend = ComfortRecTrend.bucket(
            heavyDaysInLastWeek: heavyDays(dataManager: dataManager, now: now, calendar: calendar))
        let recentThemes = Array(dataManager.themeTags.prefix(3)).map { $0.theme }

        var payload: [String: Any] = [
            "timeOfDay": offer.timeOfDay,
            "moodTrend": trend,
            "recentThemes": recentThemes,
            // classic "cozy" has no rich analog yet — music/film carry over
            "quietTypes": offer.quietTypes.filter { $0 != "cozy" },
            "userLocale": Locale.current.language.languageCode?.identifier ?? "en",
            "excludeTitles": RichRecStore.excludeTitles(),
        ]
        if !heavyMoodValue.isEmpty { payload["mood"] = heavyMoodValue }

        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("generateComfortRecs").call(payload)
            guard let data = result.data as? [String: Any],
                  let raw = data["recs"] as? [[String: Any]] else { return nil }
            let recs = raw.compactMap { ComfortRecSanitizer.rec(from: $0) }
            guard let first = recs.first else { return nil }
            if recs.count > 1 {
                RichRecStore.save(RichRecBatch(recs: Array(recs.dropFirst()), fetchedAt: now))
            }
            return first
        } catch {
            #if DEBUG
            print("🌙 comfort rec error: \(error)")
            #endif
            return nil
        }
    }

    /// Heavy days across the last 7 — feeds the 3 bucket trend, on device only.
    static func heavyDays(dataManager: SharedDataManager, now: Date, calendar: Calendar) -> Int {
        (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
            .filter { day in
                dataManager.moodEntries.contains {
                    calendar.isDate($0.date, inSameDayAs: day)
                        && ($0.weatherType == .drained || $0.weatherType == .overwhelmed)
                }
            }
            .count
    }
}

#if DEBUG
extension RichRecStore {
    /// -richRecQA3 seed — a shelf worth of picks for screenshot verification.
    static func seedQAKeepsakes(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: keepsakesKey)
        let samples: [RichRec] = [
            RichRec(type: "music", title: "clair de lune", creator: "claude debussy", year: 1905,
                    why: "w", flags: ["a soft one"], feel: "quiet", length: "about 5 minutes"),
            RichRec(type: "film", title: "my neighbor totoro", creator: "hayao miyazaki", year: 1988,
                    why: "w", flags: ["not graphic"], feel: "hopeful", length: "about 86 minutes"),
            RichRec(type: "book", title: "the wind in the willows", creator: "kenneth grahame", year: 1908,
                    why: "w", flags: ["no distressing themes"], feel: "cozy", length: "a slow weekend read"),
            RichRec(type: "music", title: "music for airports", creator: "brian eno", year: 1978,
                    why: "w", flags: ["a soft one"], feel: "quiet", length: "about 48 minutes"),
        ]
        for r in samples { recordKeepsake(r, defaults: defaults) }
    }
}

extension RichRec {
    /// -richRecQA sample — screenshot verification only, never ships a path.
    static let qaSample = RichRec(
        type: "music",
        title: "music for airports",
        creator: "brian eno",
        year: 1978,
        why: "your week has been asking a lot. this asks nothing back, it just hums beside you",
        flags: ["not graphic", "a soft one"],
        feel: "quiet",
        length: "about 48 minutes")
}
#endif
