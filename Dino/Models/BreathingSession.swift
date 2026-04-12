//
//  BreathingSession.swift
//  Dino
//

import Foundation

struct BreathingSession: Codable, Identifiable {
    var id: UUID
    var date: Date
    var durationSeconds: Int
    var type: String

    init(id: UUID = UUID(), date: Date = Date(), durationSeconds: Int, type: String = "4-4-4") {
        self.id = id
        self.date = date
        self.durationSeconds = durationSeconds
        self.type = type
    }

    var formattedDuration: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        if mins > 0 {
            return "\(mins) min \(secs) sec"
        } else {
            return "\(secs) sec"
        }
    }
}
