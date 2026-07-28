//
//  FindingsStore.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo. Local-only cache of the star's tasks +
//  results for the shelf (UserDefaults; nothing here ever syncs). Mirrors
//  RichRecStore's static/UserDefaults shape, namespaced dino.findings.*.
//
//  English-only demo (owner decision): plain string literals only.
//

import Foundation

/// One finding the star brought back (or a task still in flight), exactly as the
/// shelf + reveal card render it. All optional-friendly so old cached entries
/// decode unchanged.
struct FindingItem: Codable, Equatable, Identifiable {
    let taskId: String
    var status: String        // searching | found | empty | booked | handoff | confirmed | failed
    var title: String
    var whenText: String      // "this saturday, 2pm"
    var whereText: String     // venue
    var why: String           // dino's lowercase warm line
    var url: String
    var outcome: String       // add_to_calendar | book_it | finish_signup | empty_handed
    var bookedAt: Date?
    var createdAt: Date

    var id: String { taskId }

    init(taskId: String, status: String, title: String = "", whenText: String = "",
         whereText: String = "", why: String = "", url: String = "",
         outcome: String = "", bookedAt: Date? = nil, createdAt: Date = Date()) {
        self.taskId = taskId; self.status = status; self.title = title
        self.whenText = whenText; self.whereText = whereText; self.why = why
        self.url = url; self.outcome = outcome; self.bookedAt = bookedAt
        self.createdAt = createdAt
    }
}

enum FindingsStore {
    static let itemsKey = "dino.findings.items"
    static let cap = 100   // a small demo shelf

    static func items(defaults: UserDefaults = .standard) -> [FindingItem] {
        guard let data = defaults.data(forKey: itemsKey),
              let list = try? JSONDecoder().decode([FindingItem].self, from: data) else { return [] }
        return list
    }

    /// Insert or update a finding by taskId, newest first. Capped.
    static func upsert(_ item: FindingItem, defaults: UserDefaults = .standard) {
        var all = items(defaults: defaults)
        if let idx = all.firstIndex(where: { $0.taskId == item.taskId }) {
            all[idx] = item
        } else {
            all.insert(item, at: 0)
        }
        if all.count > cap { all = Array(all.prefix(cap)) }
        persist(all, defaults: defaults)
    }

    /// Patch just the status/outcome/bookedAt of an existing task (server poll).
    static func markStatus(taskId: String, status: String, bookedAt: Date? = nil,
                           defaults: UserDefaults = .standard) {
        var all = items(defaults: defaults)
        guard let idx = all.firstIndex(where: { $0.taskId == taskId }) else { return }
        all[idx].status = status
        if let bookedAt { all[idx].bookedAt = bookedAt }
        persist(all, defaults: defaults)
    }

    static func item(taskId: String, defaults: UserDefaults = .standard) -> FindingItem? {
        items(defaults: defaults).first { $0.taskId == taskId }
    }

    /// Today's tasks (local view of the 5/day cap; the server is the real gate).
    static func countToday(now: Date = Date(), calendar: Calendar = .current,
                           defaults: UserDefaults = .standard) -> Int {
        items(defaults: defaults).filter { calendar.isDate($0.createdAt, inSameDayAs: now) }.count
    }

    private static func persist(_ all: [FindingItem], defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: itemsKey) }
    }
}
