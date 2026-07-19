//
//  AffirmationsData.swift
//  Dino
//

import Foundation

struct AffirmationsData {
    static let all: [String] = [
        String(localized: "you are enough, exactly as you are."),
        String(localized: "progress, not perfection."),
        String(localized: "it's okay to rest."),
        String(localized: "your feelings are valid."),
        String(localized: "small steps still move you forward."),
        String(localized: "you don't have to have it all figured out."),
        String(localized: "be gentle with yourself today."),
        String(localized: "this moment is enough."),
        String(localized: "you are doing better than you think."),
        String(localized: "rest is productive."),
        String(localized: "healing is not linear."),
        String(localized: "you deserve the same kindness you give others."),
        String(localized: "breathe. you've survived every hard day so far."),
        String(localized: "you are worthy of love and belonging."),
        String(localized: "it's okay to take up space."),
        String(localized: "you don't have to earn rest."),
        String(localized: "growth happens slowly, then all at once."),
        String(localized: "your pace is the right pace."),
        String(localized: "you are allowed to change your mind."),
        String(localized: "one day at a time — sometimes one hour."),
        String(localized: "you are more resilient than you know."),
        String(localized: "not every day needs to be productive."),
        String(localized: "you are allowed to feel what you feel."),
        String(localized: "asking for help is a form of strength."),
        String(localized: "your best looks different every day — and that's okay."),
        String(localized: "you matter beyond what you produce."),
        String(localized: "it's okay to outgrow things that no longer serve you."),
        String(localized: "you are not your worst day."),
        String(localized: "comparison steals joy — come back to yourself."),
        String(localized: "your story is still being written."),
        String(localized: "today, you showed up. that's enough."),
        String(localized: "kindness to yourself creates space for everything else."),
        String(localized: "there is no rush — you are right on time."),
        String(localized: "you carry more light than you realize."),
        String(localized: "let yourself be a work in progress."),
    ]

    static var randomAffirmation: String {
        all.randomElement() ?? all[0]
    }

    static func affirmationsForToday(count: Int = 5) -> [String] {
        var shuffled = all.shuffled()
        return Array(shuffled.prefix(count))
    }
}
