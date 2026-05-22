//
//  JournalEntry.swift
//  Dino
//

import Foundation

struct JournalEntry: Codable, Identifiable {
    var id: UUID
    var date: Date
    var audioFileName: String
    var title: String
    var summary: String
    var moodTag: String
    var isFavorite: Bool
    var durationSeconds: Double
    var photoFileName: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        audioFileName: String,
        title: String,
        summary: String = "voice note recorded",
        moodTag: String = "reflective",
        isFavorite: Bool = false,
        durationSeconds: Double = 0,
        photoFileName: String? = nil
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
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, audioFileName, title, summary, moodTag, isFavorite, durationSeconds, photoFileName
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
