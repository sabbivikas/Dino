//
//  JournalEntry.swift
//  Dino
//

import Foundation

struct JournalEntry: Codable, Identifiable {
    var id: UUID
    var date: Date               // the USER-FACING entry date (backdatable)
    var audioFileName: String
    var title: String
    var summary: String
    var moodTag: String
    var isFavorite: Bool
    var durationSeconds: Double
    var photoFileName: String?
    var createdAt: Date?         // when it was actually written; nil on legacy docs
    var updatedAt: Date?         // last text edit; nil until first edited

    /// Legacy entries (pre-createdAt) fall back to their entry date.
    var effectiveCreatedAt: Date { createdAt ?? date }

    /// Display order everywhere: the user's chosen date, newest first;
    /// same-moment ties broken by write time, then by id — a TOTAL order, so
    /// the list can never flip between launches or after a sync shuffles the
    /// underlying array (Swift's sort is not stable for equal keys).
    static func sortedForDisplay(_ entries: [JournalEntry]) -> [JournalEntry] {
        entries.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            if $0.effectiveCreatedAt != $1.effectiveCreatedAt {
                return $0.effectiveCreatedAt > $1.effectiveCreatedAt
            }
            return $0.id.uuidString > $1.id.uuidString
        }
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        audioFileName: String,
        title: String,
        summary: String = "voice note recorded",
        moodTag: String = "reflective",
        isFavorite: Bool = false,
        durationSeconds: Double = 0,
        photoFileName: String? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.audioFileName = audioFileName
        self.title = title
        self.summary = summary
        self.moodTag = moodTag
        self.isFavorite = isFavorite
        self.durationSeconds = durationSeconds
        self.photoFileName = photoFileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, audioFileName, title, summary, moodTag, isFavorite, durationSeconds, photoFileName, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.date = try c.decode(Date.self, forKey: .date)
        self.audioFileName = try c.decode(String.self, forKey: .audioFileName)
        self.title = try c.decode(String.self, forKey: .title)
        self.summary = try c.decode(String.self, forKey: .summary)
        self.moodTag = try c.decode(String.self, forKey: .moodTag)
        self.isFavorite = try c.decode(Bool.self, forKey: .isFavorite)
        self.durationSeconds = try c.decode(Double.self, forKey: .durationSeconds)
        self.photoFileName = try c.decodeIfPresent(String.self, forKey: .photoFileName)
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    /// Pure text-edit semantics (unit-tested): trims, edits in place by id,
    /// preserves date/createdAt and every other field, stamps updatedAt.
    /// Returns nil (no-op) for empty text, unknown ids, or unchanged text —
    /// an accidental empty save must never silently blank an entry.
    static func applyingTextEdit(to entries: [JournalEntry], id: UUID,
                                 newText: String, now: Date = Date()) -> [JournalEntry]? {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = entries.firstIndex(where: { $0.id == id }),
              entries[idx].summary != trimmed else { return nil }
        var copy = entries
        copy[idx].summary = trimmed
        copy[idx].updatedAt = now
        return copy
    }

    var formattedDuration: String {
        let mins = Int(durationSeconds) / 60
        let secs = Int(durationSeconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
