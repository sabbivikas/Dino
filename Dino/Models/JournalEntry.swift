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

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        audioFileName: String,
        title: String,
        summary: String = "voice note recorded",
        moodTag: String = "reflective",
        isFavorite: Bool = false,
        durationSeconds: Double = 0
    ) {
        self.id = id
        self.date = date
        self.audioFileName = audioFileName
        self.title = title
        self.summary = summary
        self.moodTag = moodTag
        self.isFavorite = isFavorite
        self.durationSeconds = durationSeconds
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
