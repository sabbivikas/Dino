//
//  MeditationSession.swift
//  Dino
//

import Foundation

struct MeditationSession: Codable, Identifiable {
    var id: UUID
    var date: Date
    var durationSeconds: Int
    var completed: Bool

    init(id: UUID = UUID(), date: Date = Date(), durationSeconds: Int, completed: Bool = true) {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
        self.completed = completed
    }

    var formattedDuration: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        if mins > 0 {
            return String(localized: "\(mins) min \(secs) sec")
        } else {
            return String(localized: "\(secs) sec")
        }
    }
}
