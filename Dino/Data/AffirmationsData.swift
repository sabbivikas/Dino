//
//  AffirmationsData.swift
//  Dino
//

import Foundation

struct AffirmationsData {
    static let all: [String] = [
        "you are enough, exactly as you are.",
        "progress, not perfection.",
        "it's okay to rest.",
        "your feelings are valid.",
        "small steps still move you forward.",
        "you don't have to have it all figured out.",
        "be gentle with yourself today.",
        "this moment is enough.",
        "you are doing better than you think.",
        "rest is productive.",
        "healing is not linear.",
        "you deserve the same kindness you give others.",
        "breathe. you've survived every hard day so far.",
        "you are worthy of love and belonging.",
        "it's okay to take up space.",
        "you don't have to earn rest.",
        "growth happens slowly, then all at once.",
        "your pace is the right pace.",
        "you are allowed to change your mind.",
        "one day at a time — sometimes one hour.",
        "you are more resilient than you know.",
        "not every day needs to be productive.",
        "you are allowed to feel what you feel.",
        "asking for help is a form of strength.",
        "your best looks different every day — and that's okay.",
        "you matter beyond what you produce.",
        "it's okay to outgrow things that no longer serve you.",
        "you are not your worst day.",
        "comparison steals joy — come back to yourself.",
        "your story is still being written.",
        "today, you showed up. that's enough.",
        "kindness to yourself creates space for everything else.",
        "there is no rush — you are right on time.",
        "you carry more light than you realize.",
        "let yourself be a work in progress.",
    ]

    static var randomAffirmation: String {
        all.randomElement() ?? all[0]
    }

    static func affirmationsForToday(count: Int = 5) -> [String] {
        var shuffled = all.shuffled()
        return Array(shuffled.prefix(count))
    }
}
