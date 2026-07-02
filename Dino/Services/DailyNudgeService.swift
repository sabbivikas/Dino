//
//  DailyNudgeService.swift
//  Dino
//
//  DinoMind smart nudges: fetches ONE warm, context-aware check-in line per day
//  from generateDailyNudge, caches it locally, and falls back to the static
//  NudgeLibrary copy on any failure. Mirrors the rhythms-letter service.
//

import Foundation
import FirebaseFunctions

enum DailyNudgeService {
    private static let cacheKey = "dino.dailyNudge"

    private struct CachedNudge: Codable { let dayKey: String; let content: String }

    /// Local-day key (timezone-safe), matching the rest of the app.
    static func todayKey(_ calendar: Calendar = .current, now: Date = Date()) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: now)
    }

    /// The cached nudge for `dayKey`, or nil if none/stale/empty.
    static func cachedNudge(for dayKey: String) -> String? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let n = try? JSONDecoder().decode(CachedNudge.self, from: data),
              n.dayKey == dayKey, !n.content.isEmpty else { return nil }
        return n.content
    }

    static func cache(_ content: String, dayKey: String) {
        if let data = try? JSONEncoder().encode(CachedNudge(dayKey: dayKey, content: content)) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    /// Calls generateDailyNudge; returns the line or nil (caller falls back).
    static func generate(payload: [String: Any]) async -> String? {
        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("generateDailyNudge").call(payload)
            if let data = result.data as? [String: Any],
               let nudge = data["nudge"] as? String, !nudge.isEmpty {
                return nudge
            }
            return nil
        } catch {
            #if DEBUG
            print("🌙 daily nudge error: \(error)")
            #endif
            let ns = error as NSError
            AnalyticsManager.shared.trackDailyNudgeFailed(domain: ns.domain, code: ns.code)
            return nil
        }
    }
}
