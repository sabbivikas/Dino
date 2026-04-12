//
//  AssessmentResult.swift
//  Dino
//

import Foundation

struct AssessmentResult: Codable, Identifiable {
    var id: UUID
    var date: Date
    var score: Int
    var answers: [Int]

    init(id: UUID = UUID(), date: Date = Date(), score: Int, answers: [Int]) {
        self.id = id
        self.date = date
        self.score = score
        self.answers = answers
    }

    var supportiveMessage: String {
        switch score {
        case 20...25:
            return "you're doing really well — keep nurturing yourself. 🌟"
        case 15...19:
            return "you're in a good place. keep building those healthy habits."
        case 10...14:
            return "things feel a bit mixed. small steps forward still count."
        default:
            return "this week felt heavy. be extra gentle with yourself. 💙"
        }
    }
}
