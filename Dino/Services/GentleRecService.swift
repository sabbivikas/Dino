//
//  GentleRecService.swift
//  Dino
//
//  Fetch + learning layer for gentle recommendations. The coordinator runs
//  every GentleRecEngine gate locally; only a fully cleared moment touches
//  the network. Analytics are exactly rec_shown {type} / rec_tapped /
//  rec_ignored — never titles, links, or moods.
//

import Foundation
import FirebaseFunctions

struct GentleRec: Equatable {
    let itemId: String
    let type: String     // music | film | cozy
    let title: String
    let link: String
    let line: String     // dino's one warm delivery line
}

/// Local learning + scarcity state (UserDefaults only).
enum GentleRecStore {
    static let lastShownKey = "dino.recs.lastShownAt"
    static let ignoreCountsKey = "dino.recs.ignoreCounts"

    static var lastShownAt: Date? {
        UserDefaults.standard.object(forKey: lastShownKey) as? Date
    }
    static var ignoreCounts: [String: Int] {
        (UserDefaults.standard.dictionary(forKey: ignoreCountsKey) as? [String: Int]) ?? [:]
    }
    static func recordShown(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: lastShownKey)
    }
    static func recordTapped(type: String) {
        var counts = ignoreCounts
        counts[type] = 0                        // a tap wakes the type back up
        UserDefaults.standard.set(counts, forKey: ignoreCountsKey)
    }
    static func recordIgnored(type: String) {
        var counts = ignoreCounts
        counts[type] = (counts[type] ?? 0) + 1
        UserDefaults.standard.set(counts, forKey: ignoreCountsKey)
    }
}

@MainActor
enum GentleRecCoordinator {

    /// Evaluates every gate locally; returns a rec only when the moment is
    /// right AND the server found a genuine fit. Any failure = quiet nil.
    static func fetchIfMomentIsRight(dataManager: SharedDataManager,
                                     freshHeavyMood: EmotionalWeather? = nil,
                                     now: Date = Date(),
                                     calendar: Calendar = .current) async -> GentleRec? {
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

        // Mood travels only when a heavy mood actually exists today — a
        // journal-signal moment sends "" rather than faking one.
        let heavyMoodValue = freshHeavyMood.flatMap { m in
            (m == .drained || m == .overwhelmed) ? m.rawValue : nil
        } ?? dataManager.moodEntries.first {
            calendar.isDate($0.date, inSameDayAs: now)
                && ($0.weatherType == .drained || $0.weatherType == .overwhelmed)
        }?.weatherType.rawValue ?? ""

        let recentThemes = Array(dataManager.themeTags.prefix(3)).map { $0.theme }
        return await pick(mood: heavyMoodValue, timeOfDay: offer.timeOfDay,
                          recentThemes: recentThemes, quietTypes: offer.quietTypes)
    }

    private static func pick(mood: String, timeOfDay: String,
                             recentThemes: [String], quietTypes: [String]) async -> GentleRec? {
        var payload: [String: Any] = [
            "timeOfDay": timeOfDay,
            "recentThemes": recentThemes,
            "quietTypes": quietTypes,
            "userLocale": AppLanguage.current,
        ]
        if !mood.isEmpty { payload["mood"] = mood }
        do {
            let functions = Functions.functions(region: "us-central1")
            let result = try await functions.httpsCallable("pickGentleRec").call(payload)
            guard let data = result.data as? [String: Any],
                  let itemId = data["itemId"] as? String, !itemId.isEmpty,
                  let type = data["type"] as? String,
                  let title = data["title"] as? String, !title.isEmpty,
                  let link = data["link"] as? String, link.hasPrefix("https://"),
                  let line = data["line"] as? String, !line.isEmpty
            else { return nil }
            return GentleRec(itemId: itemId, type: type, title: title, link: link, line: line)
        } catch {
            #if DEBUG
            print("🌙 gentle rec error: \(error)")
            #endif
            return nil
        }
    }
}
