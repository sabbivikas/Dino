//
//  DinoNotification.swift
//  Dino
//

import Foundation
import SwiftUI
import Combine

enum DinoNotificationCategory: String, Codable, CaseIterable, Identifiable {
    case growth, world, creative, dinoSays

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .growth:   return "\u{1F331}"   // 🌱
        case .world:    return "\u{1F30D}"   // 🌍
        case .creative: return "\u{1F3A8}"   // 🎨
        case .dinoSays: return "\u{1F4E3}"   // 📣
        }
    }

    var displayName: String {
        switch self {
        case .growth:   return "growth"
        case .world:    return "world"
        case .creative: return "creative"
        case .dinoSays: return "dino says"
        }
    }

    var pillColor: Color {
        switch self {
        case .growth:   return Color(hex: "#A8C5A0")    // soft sage
        case .world:    return Color(hex: "#A8D4E6")    // soft sky
        case .creative: return Color(hex: "#F5C6AA")    // soft coral
        case .dinoSays: return Color(hex: "#F5DC8A")    // warm yellow
        }
    }
}

struct DinoNotification: Identifiable, Codable, Equatable {
    let id: UUID
    let category: DinoNotificationCategory
    let title: String
    let subtitle: String
    let timestamp: Date
    var isRead: Bool
    let dedupeKey: String

    init(
        id: UUID = UUID(),
        category: DinoNotificationCategory,
        title: String,
        subtitle: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        dedupeKey: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.timestamp = timestamp
        self.isRead = isRead
        self.dedupeKey = dedupeKey
    }
}

@MainActor
final class NotificationStore: ObservableObject {
    static let shared = NotificationStore()

    @Published private(set) var notifications: [DinoNotification] = []
    private(set) var firedDedupeKeys: Set<String> = []

    private let storageKey = "DinoNotifications"
    private let firedKeysStorageKey = "dino.firedDedupeKeys"
    private let seedAddedKey = "dino.seedNotificationsAdded"
    private let defaults: UserDefaults = .standard

    private init() {
        load()
        loadFiredKeys()
    }

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    func unreadCount(in category: DinoNotificationCategory?) -> Int {
        notifications.filter { !$0.isRead && (category == nil || $0.category == category) }.count
    }

    func markRead(_ id: UUID) {
        guard let idx = notifications.firstIndex(where: { $0.id == id }) else { return }
        guard !notifications[idx].isRead else { return }
        notifications[idx].isRead = true
        save()
    }

    func markAllRead() {
        var changed = false
        for i in notifications.indices where !notifications[i].isRead {
            notifications[i].isRead = true
            changed = true
        }
        if changed { save() }
    }

    func delete(_ id: UUID) {
        notifications.removeAll { $0.id == id }
        save()
    }

    func deleteAll(in category: DinoNotificationCategory?) {
        if let category {
            notifications.removeAll { $0.category == category }
        } else {
            notifications.removeAll()
        }
        save()
    }

    /// Wipe every notification across all categories. Convenience for the
    /// notification-center "clear all" action.
    func clearAll() {
        guard !notifications.isEmpty else { return }
        notifications.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DinoNotification].self, from: data) else {
            notifications = []
            return
        }
        notifications = decoded.sorted { $0.timestamp > $1.timestamp }
    }

    private func save() {
        notifications.sort { $0.timestamp > $1.timestamp }
        if let data = try? JSONEncoder().encode(notifications) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func loadFiredKeys() {
        guard let data = defaults.data(forKey: firedKeysStorageKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            firedDedupeKeys = []
            return
        }
        firedDedupeKeys = Set(decoded)
    }

    private func saveFiredKeys() {
        if let data = try? JSONEncoder().encode(Array(firedDedupeKeys)) {
            defaults.set(data, forKey: firedKeysStorageKey)
        }
    }

    // MARK: - Auto-generation

    /// Insert only if dedupeKey isn't already present.
    private func insertIfNew(
        category: DinoNotificationCategory,
        title: String,
        subtitle: String,
        dedupeKey: String,
        timestamp: Date = Date()
    ) {
        if firedDedupeKeys.contains(dedupeKey) { return }
        if notifications.contains(where: { $0.dedupeKey == dedupeKey }) { return }
        notifications.append(
            DinoNotification(
                category: category,
                title: title,
                subtitle: subtitle,
                timestamp: timestamp,
                isRead: false,
                dedupeKey: dedupeKey
            )
        )
        firedDedupeKeys.insert(dedupeKey)
    }

    /// Refresh notifications based on current app data. Idempotent — safe to call repeatedly.
    func refreshFromData(
        streakDays: Int,
        journalCount: Int,
        gratitudeCount: Int,
        lastJournalDate: Date?,
        hasMonthlyPainting: Bool,
        paintingMonthKey: String,
        breathingSessionCount: Int,
        meditationSessionCount: Int
    ) {
        let countBefore = notifications.count
        let firedCountBefore = firedDedupeKeys.count

        // One-time seeds (welcome, world-welcome) — only added on first launch ever.
        if !defaults.bool(forKey: seedAddedKey) {
            insertIfNew(
                category: .dinoSays,
                title: "welcome to dino",
                subtitle: "a small, soft place to land. take your time.",
                dedupeKey: "welcome"
            )
            insertIfNew(
                category: .world,
                title: "the world is breathing with you",
                subtitle: "thousands of dinos are checking in alongside you today.",
                dedupeKey: "world-welcome"
            )
            defaults.set(true, forKey: seedAddedKey)
        }

        // Streak milestones
        let streakMilestones: [Int] = [3, 7, 14, 30]
        for m in streakMilestones where streakDays >= m {
            insertIfNew(
                category: .growth,
                title: "\(m)-day streak!",
                subtitle: streakSubtitle(for: m),
                dedupeKey: "streak-\(m)"
            )
        }

        // Daily check-in nudge if no journal in 24h (and user has journaled before)
        if journalCount > 0, let last = lastJournalDate,
           Date().timeIntervalSince(last) > 24 * 60 * 60 {
            // dedupe per-day so we don't spam
            let key = "checkin-\(StreakData.dateKey(for: Date()))"
            insertIfNew(
                category: .growth,
                title: "a quiet check-in?",
                subtitle: "haven't heard your voice in a day — even one breath counts.",
                dedupeKey: key
            )
        }

        // Journal milestones
        if journalCount >= 1 {
            insertIfNew(
                category: .creative,
                title: "first voice note saved",
                subtitle: "your story has a place to live now. keep going.",
                dedupeKey: "journal-first"
            )
        }
        if journalCount >= 10 {
            insertIfNew(
                category: .creative,
                title: "10 voice notes recorded",
                subtitle: "a small archive of your inner weather.",
                dedupeKey: "journal-10"
            )
        }

        // Gratitude jar milestones
        for m in [3, 10, 25] where gratitudeCount >= m {
            insertIfNew(
                category: .creative,
                title: "\(m) tokens in the jar",
                subtitle: "the jar is filling up with small good things.",
                dedupeKey: "gratitude-\(m)"
            )
        }

        // Breathing milestones
        if breathingSessionCount >= 1 {
            insertIfNew(
                category: .growth,
                title: "you took your first breath with dino 🫁",
                subtitle: "small breaths, big shifts.",
                dedupeKey: "breathing-first"
            )
        }
        if breathingSessionCount >= 10 {
            insertIfNew(
                category: .growth,
                title: "10 breathing sessions — your lungs thank you 🌿",
                subtitle: "a steady rhythm is taking root.",
                dedupeKey: "breathing-10"
            )
        }

        // Meditation milestones
        if meditationSessionCount >= 1 {
            insertIfNew(
                category: .growth,
                title: "you meditated for the first time 🧘",
                subtitle: "one quiet minute is its own kind of brave.",
                dedupeKey: "meditation-first"
            )
        }
        if meditationSessionCount >= 10 {
            insertIfNew(
                category: .growth,
                title: "stillness is a superpower — 10 sessions done ✨",
                subtitle: "you keep coming back to the quiet.",
                dedupeKey: "meditation-10"
            )
        }

        // Monthly painting ready
        if hasMonthlyPainting {
            insertIfNew(
                category: .creative,
                title: "your monthly painting is ready",
                subtitle: "a month of moods, painted softly. tap to see it.",
                dedupeKey: "painting-\(paintingMonthKey)"
            )
        }

        if notifications.count != countBefore {
            save()
        }
        if firedDedupeKeys.count != firedCountBefore {
            saveFiredKeys()
        }
    }

    private func streakSubtitle(for days: Int) -> String {
        switch days {
        case 3:  return "three days in a row — a tiny rhythm is forming."
        case 7:  return "a full week. that's roots beginning to grow."
        case 14: return "two weeks. you're building something real."
        case 30: return "a whole month. take a breath — this is huge."
        default: return "another day, another small showing-up."
        }
    }
}
