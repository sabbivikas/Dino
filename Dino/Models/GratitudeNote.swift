//
//  GratitudeNote.swift
//  Dino
//

import Foundation

struct GratitudeNote: Codable, Identifiable {
    var id: UUID
    var text: String
    var createdAt: Date
    var tokenType: String

    init(id: UUID = UUID(), text: String, createdAt: Date = Date(), tokenType: String = "heart") {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.tokenType = tokenType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.text = try c.decode(String.self, forKey: .text)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.tokenType = try c.decodeIfPresent(String.self, forKey: .tokenType) ?? "heart"
    }
}
