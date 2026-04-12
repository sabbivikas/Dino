//
//  GratitudeNote.swift
//  Dino
//

import Foundation

struct GratitudeNote: Codable, Identifiable {
    var id: UUID
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}
