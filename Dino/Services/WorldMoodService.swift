//
//  WorldMoodService.swift
//  Dino
//
//  Data layer for DINO WORLD — the anonymous global mood map.
//
//  WRITE: on every mood log, one anonymous doc goes to `worldMoods`:
//  {mood, countryCode, dayKey, createdAt, expiresAt}. No UID, no location —
//  country comes from Locale.current.region (device region setting), never
//  from GPS. Raw docs expire after 48h via a Firestore TTL policy; clients
//  can only CREATE them (rules), never read them back.
//
//  READ: clients read ONLY the single `worldAggregate/current` doc that the
//  hourly cloud function builds (per-country counts with a <5/day privacy
//  floor folded into "elsewhere", last 7 days retained for the week rewind).
//

import Foundation
import FirebaseFirestore

// MARK: - Aggregate model (parse is pure → unit-testable)

struct WorldMoodCounts: Equatable {
    var clear: Int = 0
    var partlyCloudy: Int = 0
    var overwhelmed: Int = 0
    var drained: Int = 0
    var total: Int = 0

    func count(for mood: EmotionalWeather) -> Int {
        switch mood {
        case .clear: return clear
        case .partlyCloudy: return partlyCloudy
        case .overwhelmed: return overwhelmed
        case .drained: return drained
        }
    }

    /// 0...1 share of `mood`, 0 when the bucket is empty.
    func share(of mood: EmotionalWeather) -> Double {
        guard total > 0 else { return 0 }
        return Double(count(for: mood)) / Double(total)
    }

    /// The most-logged mood, ties broken by the canonical case order. Nil when empty.
    var dominantMood: EmotionalWeather? {
        guard total > 0 else { return nil }
        return EmotionalWeather.allCases.max { count(for: $0) < count(for: $1) }
    }

    static func parse(_ dict: [String: Any]) -> WorldMoodCounts {
        var c = WorldMoodCounts()
        c.clear = dict["clear"] as? Int ?? 0
        c.partlyCloudy = dict["partlyCloudy"] as? Int ?? 0
        c.overwhelmed = dict["overwhelmed"] as? Int ?? 0
        c.drained = dict["drained"] as? Int ?? 0
        c.total = dict["total"] as? Int ?? (c.clear + c.partlyCloudy + c.overwhelmed + c.drained)
        return c
    }
}

struct WorldDayBucket: Equatable {
    let global: WorldMoodCounts
    let countries: [String: WorldMoodCounts]   // ISO-3166 alpha-2 + "elsewhere"

    static func parse(_ dict: [String: Any]) -> WorldDayBucket {
        let global = WorldMoodCounts.parse(dict["global"] as? [String: Any] ?? [:])
        var countries: [String: WorldMoodCounts] = [:]
        for (code, raw) in dict["countries"] as? [String: Any] ?? [:] {
            if let d = raw as? [String: Any] { countries[code] = WorldMoodCounts.parse(d) }
        }
        return WorldDayBucket(global: global, countries: countries)
    }
}

struct WorldAggregate: Equatable {
    let days: [String: WorldDayBucket]         // dayKey "yyyy-MM-dd" → bucket, ≤ 7 entries

    /// Sorted newest-first for the rewind chips.
    var sortedDayKeys: [String] { days.keys.sorted(by: >) }

    func bucket(for dayKey: String) -> WorldDayBucket? { days[dayKey] }

    /// Pure — parses the raw Firestore doc data. Unknown/malformed entries are skipped.
    static func parse(_ data: [String: Any]) -> WorldAggregate {
        var days: [String: WorldDayBucket] = [:]
        for (dayKey, raw) in data["days"] as? [String: Any] ?? [:] {
            guard dayKey.count == 10, let d = raw as? [String: Any] else { continue }
            days[dayKey] = WorldDayBucket.parse(d)
        }
        return WorldAggregate(days: days)
    }
}

// MARK: - Service

@MainActor
enum WorldMoodService {
    private static var cachedAggregate: WorldAggregate?
    private static var cacheFetchedAt: Date?
    private static let cacheMaxAge: TimeInterval = 15 * 60   // aggregate rebuilds hourly

    /// Local-day key, matching the app's other yyyy-MM-dd keys.
    static func todayKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: now)
    }

    /// Device-region country code (never GPS). Pure validation → testable.
    static func countryCode(from identifier: String?) -> String {
        guard let id = identifier?.uppercased(), id.count == 2,
              id.allSatisfy({ $0.isLetter && $0.isASCII }) else { return "elsewhere" }
        return id
    }

    /// Fire-and-forget anonymous write. Never blocks or fails mood logging.
    static func logWorldMood(_ mood: EmotionalWeather,
                             now: Date = Date(),
                             calendar: Calendar = .current) async {
        let doc: [String: Any] = [
            "mood": mood.rawValue,
            "countryCode": countryCode(from: Locale.current.region?.identifier),
            "dayKey": todayKey(now: now, calendar: calendar),
            "createdAt": FieldValue.serverTimestamp(),
            // TTL field — Firestore's TTL policy deletes the raw doc ~48h later.
            "expiresAt": Timestamp(date: now.addingTimeInterval(48 * 3600)),
        ]
        do {
            try await Firestore.firestore().collection("worldMoods").addDocument(data: doc)
        } catch {
            #if DEBUG
            print("🌍 world mood write failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// The shared aggregate, cached for 15 min. Nil when offline with no cache —
    /// callers show nothing rather than blocking.
    static func fetchAggregate(force: Bool = false) async -> WorldAggregate? {
        #if DEBUG
        // Simulator/dev verification: launch with -worldTestAggregate to see a
        // populated globe without touching Firestore.
        // constellation QA shapes first — they ride alongside -worldTestAggregate
        // (which also drives the auto-open in HomeView)
        if ProcessInfo.processInfo.arguments.contains("-worldQAEven") {
            return debugEvenAggregate()
        }
        if ProcessInfo.processInfo.arguments.contains("-worldQASingle") {
            return debugSingleAggregate()
        }
        if ProcessInfo.processInfo.arguments.contains("-worldTestAggregate") {
            return debugTestAggregate()
        }
        #endif
        if !force, let cached = cachedAggregate, let at = cacheFetchedAt,
           Date().timeIntervalSince(at) < cacheMaxAge {
            return cached
        }
        do {
            let snap = try await Firestore.firestore()
                .collection("worldAggregate").document("current").getDocument()
            guard let data = snap.data() else { return cachedAggregate }
            let agg = WorldAggregate.parse(data)
            cachedAggregate = agg
            cacheFetchedAt = Date()
            return agg
        } catch {
            #if DEBUG
            print("🌍 world aggregate fetch failed: \(error.localizedDescription)")
            #endif
            return cachedAggregate
        }
    }

    /// Cached-only accessor for instant UI (post-log moment, home tile tint).
    static var cachedTodayBucket: WorldDayBucket? {
        cachedAggregate?.bucket(for: todayKey())
    }

    #if DEBUG
    /// A rich fake day for visual verification on the simulator: several
    /// countries across all four moods, spread around the planet.
    static func debugTestAggregate() -> WorldAggregate {
        func counts(_ clear: Int, _ pc: Int, _ ow: Int, _ dr: Int) -> WorldMoodCounts {
            var c = WorldMoodCounts()
            c.clear = clear; c.partlyCloudy = pc; c.overwhelmed = ow; c.drained = dr
            c.total = clear + pc + ow + dr
            return c
        }
        // realistic shape: a few big english-speaking + sea countries lead,
        // a tail folds into the quieter lights. totals strictly descending;
        // dominant moods vary so the list shows the full dot palette.
        let countries: [String: WorldMoodCounts] = [
            "US": counts(35, 18, 12, 10),   // 75 — clear (gold)
            "GB": counts(8, 10, 9, 15),     // 42 — drained (rose)
            "PH": counts(7, 16, 5, 4),      // 32 — partly cloudy (sage)
            "SG": counts(4, 5, 13, 3),      // 25 — overwhelmed (lavender)
            "MY": counts(11, 4, 3, 2),      // 20 — clear (gold)
            "IN": counts(2, 7, 2, 1),       // 12 — partly (sage), quieter
            "AU": counts(1, 2, 1, 4),       // 8  — drained (rose)
            "JP": counts(1, 1, 4, 1),       // 7  — overwhelmed (lavender)
            "elsewhere": counts(3, 1, 1, 0) // 5  — clear (gold)
        ]
        var global = WorldMoodCounts()
        for c in countries.values {
            global.clear += c.clear; global.partlyCloudy += c.partlyCloudy
            global.overwhelmed += c.overwhelmed; global.drained += c.drained
            global.total += c.total
        }
        let bucket = WorldDayBucket(global: global, countries: countries)
        return WorldAggregate(days: [todayKey(): bucket])
    }

    private static func debugAggregate(from countries: [String: WorldMoodCounts]) -> WorldAggregate {
        var global = WorldMoodCounts()
        for c in countries.values {
            global.clear += c.clear; global.partlyCloudy += c.partlyCloudy
            global.overwhelmed += c.overwhelmed; global.drained += c.drained
            global.total += c.total
        }
        return WorldAggregate(days: [todayKey(): WorldDayBucket(global: global, countries: countries)])
    }

    /// Constellation QA: a dozen countries at near-equal volume.
    static func debugEvenAggregate() -> WorldAggregate {
        func counts(_ clear: Int, _ pc: Int, _ ow: Int, _ dr: Int) -> WorldMoodCounts {
            var c = WorldMoodCounts()
            c.clear = clear; c.partlyCloudy = pc; c.overwhelmed = ow; c.drained = dr
            c.total = clear + pc + ow + dr
            return c
        }
        let countries: [String: WorldMoodCounts] = [
            "JP": counts(4, 1, 1, 1), "US": counts(1, 1, 1, 4), "BR": counts(1, 4, 1, 1),
            "DE": counts(1, 1, 4, 1), "IN": counts(3, 1, 1, 1), "GB": counts(1, 3, 1, 1),
            "AU": counts(4, 1, 1, 0), "FR": counts(1, 1, 3, 1), "CA": counts(3, 1, 1, 1),
            "MX": counts(1, 3, 1, 1), "KR": counts(1, 1, 1, 3), "elsewhere": counts(2, 2, 1, 1),
        ]
        return debugAggregate(from: countries)
    }

    /// Screenshot fixtures for the lantern grid/gallery — distinct ids give
    /// each lantern a different seeded glow. Non-persisting (view-local use).
    static func debugLanternFixtures() -> [ReceivedLantern] {
        let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let raw: [(String, String, Int)] = [
            ("you matter more than the hardest day tells you", "JP", 0),
            ("someone far away is rooting for you tonight", "BR", 1),
            ("rest is allowed. you have done enough today", "DE", 3),
            ("the sky is wide and there is room for you in it", "US", 5),
            ("go gently. small steps still move you forward", "IN", 8),
            ("you are not as alone as the quiet makes you feel", "GB", 12),
        ]
        return raw.map { text, code, daysAgo in
            ReceivedLantern(text: text, countryCode: code,
                            receivedAt: base.addingTimeInterval(Double(-daysAgo) * 86_400))
        }
    }

    /// Constellation QA: a single-country day.
    static func debugSingleAggregate() -> WorldAggregate {
        var c = WorldMoodCounts()
        c.clear = 9; c.partlyCloudy = 3; c.overwhelmed = 1; c.drained = 1
        c.total = 14
        return debugAggregate(from: ["JP": c])
    }
    #endif

    // MARK: - Post-log world moment copy (pure → testable)

    /// One soft line connecting the user's log to the world. Nil when the
    /// aggregate is missing or too quiet — callers show nothing, never block.
    static func worldMomentLine(mood: EmotionalWeather, bucket: WorldDayBucket?) -> String? {
        guard let bucket, bucket.global.total >= 5 else { return nil }
        let pct = Int((bucket.global.share(of: mood) * 100).rounded())
        guard pct > 0 else { return nil }
        switch mood {
        case .clear:
            return "you and \(pct)% of dinos are clear today ✨"
        case .partlyCloudy:
            return "you and \(pct)% of dinos are under soft clouds today"
        case .overwhelmed:
            return "you're not alone. \(pct)% of dinos are under clouds today"
        case .drained:
            return "you're not alone. \(pct)% of dinos are running low today"
        }
    }
}
