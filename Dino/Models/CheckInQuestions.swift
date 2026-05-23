//
//  CheckInQuestions.swift
//  Dino
//

import Foundation

enum CheckInCategory: String, Codable {
    case phq9, gad7, who5, pss
}

enum AnswerOption: Int, CaseIterable, Codable {
    case notAtAll = 0
    case severalDays = 1
    case moreThanHalf = 2
    case nearlyEveryDay = 3

    var label: String {
        switch self {
        case .notAtAll: return "not at all"
        case .severalDays: return "several days"
        case .moreThanHalf: return "more than half the days"
        case .nearlyEveryDay: return "nearly every day"
        }
    }
}

struct CheckInQuestion: Codable, Equatable {
    let category: CheckInCategory
    let text: String
}

enum CheckInQuestions {
    // PHQ-9 (depression) — 7 items used
    static let phq9: [CheckInQuestion] = [
        CheckInQuestion(category: .phq9, text: "little interest or pleasure in doing things"),
        CheckInQuestion(category: .phq9, text: "feeling down, depressed, or hopeless"),
        CheckInQuestion(category: .phq9, text: "trouble falling or staying asleep, or sleeping too much"),
        CheckInQuestion(category: .phq9, text: "feeling tired or having little energy"),
        CheckInQuestion(category: .phq9, text: "poor appetite or overeating"),
        CheckInQuestion(category: .phq9, text: "feeling bad about yourself — or that you are a failure"),
        CheckInQuestion(category: .phq9, text: "trouble concentrating on things like reading or watching tv")
    ]

    // GAD-7 (anxiety) — 7 items
    static let gad7: [CheckInQuestion] = [
        CheckInQuestion(category: .gad7, text: "feeling nervous, anxious, or on edge"),
        CheckInQuestion(category: .gad7, text: "not being able to stop or control worrying"),
        CheckInQuestion(category: .gad7, text: "worrying too much about different things"),
        CheckInQuestion(category: .gad7, text: "trouble relaxing"),
        CheckInQuestion(category: .gad7, text: "being so restless that it's hard to sit still"),
        CheckInQuestion(category: .gad7, text: "becoming easily annoyed or irritable"),
        CheckInQuestion(category: .gad7, text: "feeling afraid as if something awful might happen")
    ]

    // WHO-5 (well-being) — 5 items
    static let who5: [CheckInQuestion] = [
        CheckInQuestion(category: .who5, text: "i have felt cheerful and in good spirits"),
        CheckInQuestion(category: .who5, text: "i have felt calm and relaxed"),
        CheckInQuestion(category: .who5, text: "i have felt active and vigorous"),
        CheckInQuestion(category: .who5, text: "i woke up feeling fresh and rested"),
        CheckInQuestion(category: .who5, text: "my daily life has been filled with things that interest me")
    ]

    // PSS (perceived stress) — 5 items
    static let pss: [CheckInQuestion] = [
        CheckInQuestion(category: .pss, text: "felt unable to control the important things in your life"),
        CheckInQuestion(category: .pss, text: "felt confident about your ability to handle problems"),
        CheckInQuestion(category: .pss, text: "felt that things were going your way"),
        CheckInQuestion(category: .pss, text: "felt difficulties piling up so high you couldn't overcome them"),
        CheckInQuestion(category: .pss, text: "felt overwhelmed by what you had to do")
    ]

    /// 10 questions per week: 3 PHQ + 3 GAD + 2 WHO + 2 PSS,
    /// rotating across the pool using `(weekNumber + i) % pool.count`.
    static func forWeek(_ weekNumber: Int) -> [CheckInQuestion] {
        func pick(_ pool: [CheckInQuestion], count: Int) -> [CheckInQuestion] {
            guard !pool.isEmpty else { return [] }
            return (0..<count).map { i in pool[(weekNumber + i) % pool.count] }
        }
        return pick(phq9, count: 3)
            + pick(gad7, count: 3)
            + pick(who5, count: 2)
            + pick(pss,  count: 2)
    }
}
