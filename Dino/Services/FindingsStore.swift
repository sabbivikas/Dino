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
    var whenText: String      // "this saturday, 2pm" — DISPLAY ONLY, never scheduled from
    var whereText: String     // venue
    var why: String           // dino's lowercase warm line
    var url: String
    var outcome: String       // add_to_calendar | book_it | finish_signup | empty_handed
    var bookedAt: Date?
    var createdAt: Date

    /// THE REAL EVENT START, straight from the agent: ISO 8601 with an explicit
    /// offset. nil means the listing gave no confirmed time — and nil is HONEST,
    /// not a reason to invent one (the card offers the listing instead).
    var startISO: String?
    /// Optional end; nil → the client holds one hour.
    var endISO: String?
    /// "exact" | "approximate" | "unknown". Always "unknown" when startISO is nil.
    var dateConfidence: String
    /// The event's OWN listing image (https-sanitized server-side), or nil. nil
    /// is HONEST: the card draws a generated gradient in the same shape rather
    /// than a broken slot or an invented photo.
    var imageURL: String?
    /// Set the moment a calendar event is actually saved for this finding. The
    /// suspenders half of the duplicate guard: CalendarService (a shipping file
    /// this branch may not touch) returns only a Bool, so there is no event
    /// identifier to keep — this timestamp is what refuses the second write.
    var calendarWrittenAt: Date?

    var id: String { taskId }

    /// True when this finding carries a time we are willing to schedule.
    var hasConfirmedTime: Bool {
        guard let startISO, !startISO.isEmpty else { return false }
        return dateConfidence != "unknown"
    }

    init(taskId: String, status: String, title: String = "", whenText: String = "",
         whereText: String = "", why: String = "", url: String = "",
         outcome: String = "", bookedAt: Date? = nil, createdAt: Date = Date(),
         startISO: String? = nil, endISO: String? = nil,
         dateConfidence: String = "unknown", calendarWrittenAt: Date? = nil,
         imageURL: String? = nil) {
        self.taskId = taskId; self.status = status; self.title = title
        self.whenText = whenText; self.whereText = whereText; self.why = why
        self.url = url; self.outcome = outcome; self.bookedAt = bookedAt
        self.createdAt = createdAt
        self.startISO = startISO; self.endISO = endISO
        self.dateConfidence = dateConfidence; self.calendarWrittenAt = calendarWrittenAt
        self.imageURL = imageURL
    }

    /// BACKWARD-COMPATIBLE DECODE: items cached before the structured-date fields
    /// existed have none of the new keys. Swift's synthesized init(from:) does
    /// NOT fall back to property defaults, so every new key is decodeIfPresent
    /// here — an old shelf decodes unchanged instead of vanishing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try c.decode(String.self, forKey: .taskId)
        status = try c.decode(String.self, forKey: .status)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        whenText = try c.decodeIfPresent(String.self, forKey: .whenText) ?? ""
        whereText = try c.decodeIfPresent(String.self, forKey: .whereText) ?? ""
        why = try c.decodeIfPresent(String.self, forKey: .why) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        outcome = try c.decodeIfPresent(String.self, forKey: .outcome) ?? ""
        bookedAt = try c.decodeIfPresent(Date.self, forKey: .bookedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        startISO = try c.decodeIfPresent(String.self, forKey: .startISO)
        endISO = try c.decodeIfPresent(String.self, forKey: .endISO)
        dateConfidence = try c.decodeIfPresent(String.self, forKey: .dateConfidence) ?? "unknown"
        calendarWrittenAt = try c.decodeIfPresent(Date.self, forKey: .calendarWrittenAt)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
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
    ///
    /// A server poll does NOT know what this device already did. The plain
    /// calendar write is entirely local, so a naive overwrite would drop the
    /// write stamp and downgrade a locally-acted "confirmed" back to "found" —
    /// which is exactly how a second calendar event got offered (and written).
    /// So the merge keeps the LOCAL truth the server cannot have:
    ///   - calendarWrittenAt survives unless the incoming item already has one;
    ///   - a locally acted status is not downgraded by a still-"found" server
    ///     answer (a server answer that is itself acted still wins).
    static func upsert(_ item: FindingItem, defaults: UserDefaults = .standard) {
        var all = items(defaults: defaults)
        if let idx = all.firstIndex(where: { $0.taskId == item.taskId }) {
            let existing = all[idx]
            var merged = item
            if merged.calendarWrittenAt == nil { merged.calendarWrittenAt = existing.calendarWrittenAt }
            if merged.bookedAt == nil { merged.bookedAt = existing.bookedAt }
            if isActed(existing.status), !isActed(merged.status) {
                merged.status = existing.status
            }
            all[idx] = merged
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

    // MARK: - the duplicate-calendar guard

    /// Statuses that mean this finding has ALREADY been acted on. Tapping again
    /// must never write a second calendar event.
    static let actedStatuses: Set<String> = ["confirmed", "booked", "handoff"]

    static func isActed(_ status: String) -> Bool { actedStatuses.contains(status) }

    /// BELT + SUSPENDERS: an acted status OR a recorded write timestamp both
    /// mean "a calendar event already exists for this finding".
    static func hasCalendarWrite(_ item: FindingItem) -> Bool {
        if item.calendarWrittenAt != nil { return true }
        return item.status == "confirmed" || item.status == "booked"
    }

    /// Stamp the moment the event was actually saved. Idempotent: an existing
    /// stamp is never overwritten, so the first write stays the record.
    static func markCalendarWritten(taskId: String, at: Date = Date(),
                                    defaults: UserDefaults = .standard) {
        var all = items(defaults: defaults)
        guard let idx = all.firstIndex(where: { $0.taskId == taskId }) else { return }
        guard all[idx].calendarWrittenAt == nil else { return }
        all[idx].calendarWrittenAt = at
        persist(all, defaults: defaults)
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

    // MARK: - profile-shelf keepsake dedup (write each accepted finding once)

    /// TaskIds already written to the profile shelf as a keepsake. The redesign
    /// removed the local findings shelf; an ACCEPTED finding now rests on the
    /// EXISTING profile shelf (alongside recs) as a type-"gift" keepsake. This
    /// set guarantees exactly one keepsake per finding no matter how many times
    /// the card's action path is re-entered.
    static let shelvedKey = "dino.findings.shelved"

    static func isShelved(taskId: String, defaults: UserDefaults = .standard) -> Bool {
        guard !taskId.isEmpty else { return true }   // empty id → never shelve
        let ids = defaults.stringArray(forKey: shelvedKey) ?? []
        return ids.contains(taskId)
    }

    static func markShelved(taskId: String, defaults: UserDefaults = .standard) {
        guard !taskId.isEmpty else { return }
        var ids = defaults.stringArray(forKey: shelvedKey) ?? []
        guard !ids.contains(taskId) else { return }
        ids.append(taskId)
        if ids.count > cap { ids = Array(ids.suffix(cap)) }
        defaults.set(ids, forKey: shelvedKey)
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

// MARK: - branch-owned findings preferences

/// The findings tab's own tiny preference bag (UserDefaults, namespaced
/// dino.findings.*, nothing here syncs). Branch-owned so no shipping settings
/// file is touched.
enum FindingsPrefs {
    /// Bias the star's SOURCE LIST toward registration/signup portals. Default
    /// OFF — the plain search is the normal one. Passed to startFindingTask,
    /// which forwards it into the search prompt; it never changes the step cap.
    static let preferBookableKey = "dino.findings.preferBookable"

    static func preferBookable(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: preferBookableKey)   // absent → false
    }

    static func setPreferBookable(_ on: Bool, defaults: UserDefaults = .standard) {
        defaults.set(on, forKey: preferBookableKey)
    }
}
