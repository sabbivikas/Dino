//
//  ReceivedLantern.swift
//  Dino
//
//  A lantern this user received — kept forever in "your lanterns 🏮".
//  Carries no sender identity: just the words, a country, and when it arrived.
//

import Foundation

struct ReceivedLantern: Codable, Identifiable, Equatable {
    var id: UUID
    var text: String
    var countryCode: String
    var receivedAt: Date

    init(id: UUID = UUID(), text: String, countryCode: String, receivedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.countryCode = countryCode
        self.receivedAt = receivedAt
    }
}
