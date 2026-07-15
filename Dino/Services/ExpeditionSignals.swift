//
//  ExpeditionSignals.swift
//  Dino
//
//  F1 of the expedition engine: the on device side of the watcher. Once a
//  day it computes ENUM BUCKETS ONLY (never raw numbers, never text) and
//  writes one small signal doc the nightly watcher reads. Privacy lines:
//    • the crisis window gates HERE — the marker is local only, the server
//      never sees even the fact of it (ineligible == a calm week).
//    • users with no heavy signal in 7 days are ineligible → zero model
//      calls for them, ever.
//    • journal text, names, and raw counts never leave the phone; the
//      firestore rules reject anything off the enum allowlist.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum ExpeditionSignals {

    static let enabledKey = "dino.expeditions.enabled"          // settings toggle (surfaced in F3)
    static let lastSyncKey = "dino.expeditions.lastSignalSync"
    static let ignoreCountKey = "dino.expeditions.ignoreCount"
    static let cooloffUntilKey = "dino.expeditions.cooloffUntil"
    static let lastDeliveredKey = "dino.expeditions.lastDeliveredAt"

    // MARK: - Pure bucketizers (raw numbers stop here)

    static func heavyDaysBucket(_ n: Int) -> String {
        switch n {
        case ..<1:  return "0"
        case 1:     return "1"
        case 2...3: return "2to3"
        default:    return "4plus"
        }
    }

    static func sleepBucket(hours: Double?) -> String {
        guard let h = hours else { return "none" }
        if h < 6 { return "short" }
        if h <= 9 { return "ok" }
        return "long"
    }

    static func stepsBucket(steps: Int?) -> String {
        guard let s = steps else { return "none" }
        if s < 3000 { return "low" }
        if s <= 8000 { return "mid" }
        return "high"
    }

    static func daysSinceBucket(_ days: Int?) -> String {
        guard let d = days else { return "14plus" }
        switch d {
        case ..<3:   return "0to2"
        case 3...7:  return "3to7"
        case 8...13: return "8to13"
        default:     return "14plus"
        }
    }

    /// One source of truth with the recs trend bucket.
    static func moodTrendBucket(heavyDays: Int) -> String {
        ComfortRecTrend.bucket(heavyDaysInLastWeek: heavyDays)
    }

    // MARK: - Eligibility (entirely on device)

    /// Crisis window FIRST and absolute; then the 2 ignore cooloff; then the
    /// settings toggle; then the heavy signal requirement.
    static func isEligible(heavyDays: Int, crisisDate: Date?, now: Date = Date(),
                           calendar: Calendar = .current,
                           defaults: UserDefaults = .standard) -> Bool {
        if let c = crisisDate {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: c),
                                               to: calendar.startOfDay(for: now)).day ?? 0
            if days >= 0 && days < BodyNudge.crisisQuietDays { return false }
        }
        if let until = defaults.object(forKey: cooloffUntilKey) as? Date, until > now { return false }
        guard defaults.object(forKey: enabledKey) as? Bool ?? true else { return false }
        return heavyDays >= 1
    }

    /// "not tonight" learning: two ignores → the watcher goes quiet for 30 days.
    static func recordIgnore(now: Date = Date(), defaults: UserDefaults = .standard) {
        let n = defaults.integer(forKey: ignoreCountKey) + 1
        defaults.set(n, forKey: ignoreCountKey)
        if n >= 2 {
            defaults.set(now.addingTimeInterval(30 * 86400), forKey: cooloffUntilKey)
            defaults.set(0, forKey: ignoreCountKey)
        }
    }

    static func lastExpeditionDays(now: Date = Date(), calendar: Calendar = .current,
                                   defaults: UserDefaults = .standard) -> Int? {
        guard let d = defaults.object(forKey: lastDeliveredKey) as? Date else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: d),
                                       to: calendar.startOfDay(for: now)).day
    }

    // MARK: - Daily sync (fire and forget, once per local day)

    @MainActor
    static func syncIfNeeded(dataManager: SharedDataManager,
                             sleepHours: Double? = nil, steps: Int? = nil,
                             now: Date = Date(), calendar: Calendar = .current) async {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastSyncKey) as? Date,
           calendar.isDate(last, inSameDayAs: now) { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let heavy = ComfortRecCoordinator.heavyDays(dataManager: dataManager, now: now, calendar: calendar)
        let eligible = isEligible(heavyDays: heavy,
                                  crisisDate: CrisisMarker.lastTriggered(calendar: calendar),
                                  now: now, calendar: calendar)
        let lastRecDays = GentleRecStore.lastShownAt.map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0),
                                    to: calendar.startOfDay(for: now)).day ?? 0
        }
        let themes = Array(dataManager.themeTags.prefix(3)).map { $0.theme }

        let doc: [String: Any] = [
            "eligible": eligible,
            "moodTrend": moodTrendBucket(heavyDays: heavy),
            "heavyDays7": heavyDaysBucket(heavy),
            "themes": themes,
            "sleepBucket": sleepBucket(hours: sleepHours),
            "stepsBucket": stepsBucket(steps: steps),
            "sinceLastRec": daysSinceBucket(lastRecDays),
            "sinceLastExpedition": daysSinceBucket(lastExpeditionDays(now: now, calendar: calendar)),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        do {
            try await Firestore.firestore().collection("expeditionSignals").document(uid).setData(doc)
            defaults.set(now, forKey: lastSyncKey)
        } catch {
            #if DEBUG
            print("\u{1F54A} expedition signal sync failed: \(error.localizedDescription)")
            #endif
        }
    }
}
