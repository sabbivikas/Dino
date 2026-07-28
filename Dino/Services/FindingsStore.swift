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

    // MARK: - terminal status

    /// The statuses that mean the star's trip is over on the SERVER. Mirrors
    /// the server's terminal set; "failed" is deliberately excluded (nothing
    /// came back, so there is nothing to surface).
    static let terminalStatuses: Set<String> = ["found", "empty", "booked", "handoff", "confirmed"]

    static func isTerminal(_ status: String) -> Bool { terminalStatuses.contains(status) }

    /// True when this task is ALREADY on the shelf in a terminal state — the
    /// guard that stops the return choreography + reveal from replaying on
    /// every appear/foreground once a finding has been reconciled.
    static func hasTerminal(taskId: String, defaults: UserDefaults = .standard) -> Bool {
        guard let existing = item(taskId: taskId, defaults: defaults) else { return false }
        return isTerminal(existing.status)
    }

    // MARK: - the "a star is out" marker

    /// Written the moment a send BEGINS, before the ~2 minute callable returns
    /// an id. If the app is killed mid-call the shelf holds nothing at all, so
    /// this timestamp is the only clue a cold open has that it should ask the
    /// server what happened. Cleared when a task lands.
    static let pendingSinceKey = "dino.findings.pendingSince"
    /// How long the marker is trusted (the server call itself caps well inside).
    static let pendingWindow: TimeInterval = 15 * 60

    static func markPending(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(now.timeIntervalSince1970, forKey: pendingSinceKey)
    }

    static func clearPending(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingSinceKey)
    }

    static func pendingSince(defaults: UserDefaults = .standard) -> Date? {
        let t = defaults.double(forKey: pendingSinceKey)
        guard t > 0 else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    /// A star is probably still out: the marker is set and recent. Tolerates a
    /// small backwards clock skew; a stale marker simply stops counting.
    static func isPendingRecent(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        guard let since = pendingSince(defaults: defaults) else { return false }
        let elapsed = now.timeIntervalSince(since)
        return elapsed > -60 && elapsed < pendingWindow
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
