//
//  SavedAffirmation.swift
//  Dino
//

import Foundation

struct SavedAffirmation: Codable, Identifiable {
    var id: UUID
    var text: String
    var savedAt: Date

    init(id: UUID = UUID(), text: String, savedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.savedAt = savedAt
    }
}
