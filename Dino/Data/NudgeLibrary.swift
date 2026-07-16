//
//  NudgeLibrary.swift
//  Dino
//
//  Centralized message variations for all notification categories.
//  Empathetic, lowercase, Gen Z friendly — never repeats verbatim across days.
//

import Foundation

struct NudgeLibrary {

    // MARK: - Daily Check-in (morning / configurable)
    static let dailyCheckIn: [String] = [
        String(localized: "hey, how are you feeling today? take a sec to check in 🌱"),
        String(localized: "no pressure — but how's your heart doing right now?"),
        String(localized: "your dino is curious how you're feeling today 🦕"),
        String(localized: "a tiny check-in goes a long way. how are you, really?"),
        String(localized: "soft reminder: your feelings deserve a moment today")
    ]

    // MARK: - Streak Reminder (evening fallback)
    static let streakReminder: [String] = [
        String(localized: "you've been showing up — don't lose your streak tonight 💚"),
        String(localized: "one tiny check-in keeps the streak alive. you've got this"),
        String(localized: "your future self will thank you for showing up today"),
        String(localized: "the streak misses you. it's literally just one moment"),
        String(localized: "you've come this far — keep the chain going tonight")
    ]

    // MARK: - Wind-down (night)
    static let windDown: [String] = [
        String(localized: "the day is softening, so can you 🌙"),
        String(localized: "time to wind down gently — close the day kindly"),
        String(localized: "rest is a practice too. tuck yourself in"),
        String(localized: "a quiet moment is waiting for you before bed"),
        String(localized: "let the day go. you did enough today")
    ]

    // MARK: - Self-care: water
    static let drinkWater: [String] = [
        String(localized: "hey, when did you last have water? 💧 dino thinks you're due"),
        String(localized: "hydration check — a sip rn would be elite"),
        String(localized: "your body's been asking for water. one glass, that's it 💧"),
        String(localized: "tiny reminder: water counts as self-care too"),
        String(localized: "dino just chugged a glass of water. you should too 💧")
    ]

    // MARK: - Self-care: eat
    static let eatSomething: [String] = [
        String(localized: "have you eaten today? a snack counts 🍎"),
        String(localized: "fueling up is self-care. grab something small 🍽"),
        String(localized: "dino is hungry — are you? eat something gentle"),
        String(localized: "no skipping meals today, ok? even a snack helps"),
        String(localized: "your brain runs on food. let's feed it something kind 🥪")
    ]

    // MARK: - Self-care: rest
    static let rest: [String] = [
        String(localized: "your body needs a pause. five minutes is enough 😴"),
        String(localized: "rest isn't lazy — it's repair. close your eyes a sec"),
        String(localized: "the world will be there after you rest 🌙"),
        String(localized: "scheduled stillness incoming. let yourself be tired"),
        String(localized: "soft reminder: you're allowed to slow down rn")
    ]

    // MARK: - Self-care: check in with yourself
    static let checkInWithYourself: [String] = [
        String(localized: "how are you really doing? not the autopilot answer 🌿"),
        String(localized: "pause for one breath and notice how you feel"),
        String(localized: "your inner weather check — what's it like in there?"),
        String(localized: "no one's watching. how are you actually feeling?"),
        String(localized: "name one feeling you have right now. just one 💭")
    ]

    // MARK: - Plant: dying (streak just dropped)
    static let plantDying: [String] = [
        String(localized: "your plant is wilting a little 🥀 a quick check-in would help"),
        String(localized: "psst — your dino's plant misses you. come water it 🌱"),
        String(localized: "the streak slipped, but your plant's still hanging on 🌿"),
        String(localized: "your plant is thirsty. one tiny moment brings it back"),
        String(localized: "no judgment — but the plant could use some love today 💚")
    ]

    // MARK: - Plant: blooming (level up / big milestone)
    static let plantBlooming: [String] = [
        String(localized: "your plant just bloomed 🌸 look what showing up does"),
        String(localized: "huge bloom moment — you grew this 🌷"),
        String(localized: "petals everywhere. you earned every one of them 🌺"),
        String(localized: "your plant is fully thriving rn. and so are you 🌼"),
        String(localized: "bloom unlocked. that's all you 🌸✨")
    ]

    // MARK: - Plant: progressing (7/14/21 day streak milestones)
    static let plantProgressing: [String] = [
        String(localized: "your plant grew a new leaf 🌱 keep going"),
        String(localized: "new growth spotted. you're doing the thing 🌿"),
        String(localized: "look at that — a fresh sprout. proud of you"),
        String(localized: "your plant is visibly happier today 🌱 thank you"),
        String(localized: "small leaf, big deal. progress looks like this")
    ]

    // MARK: - Routine: breathing reminder
    static let breathingReminder = [
        String(localized: "hey take a breath with dino 🌬️ even one minute helps"),
        String(localized: "your nervous system wants a reset 🌬️ breathe with dino"),
        String(localized: "one breathing session today. you got this 🌬️"),
        String(localized: "dino is waiting to breathe with you 🦕🌬️"),
        String(localized: "two minutes of breathing can change everything 🌬️")
    ]

    // MARK: - Routine: journal reminder
    static let journalReminder = [
        String(localized: "hey what's been on your mind lately? 🌿 write it down"),
        String(localized: "your journal is waiting 📝 even one line counts"),
        String(localized: "something happened today worth remembering 🌿 write it down"),
        String(localized: "dino wants to know how your day went ✍️"),
        String(localized: "two minutes. one thought. open your journal 🌿")
    ]

    // MARK: - Routine: gratitude reminder
    static let gratitudeReminder = [
        String(localized: "drop one small good thing in the jar today 🫙 even tiny counts"),
        String(localized: "your jar is waiting for something good 🫙"),
        String(localized: "what was one okay thing today? drop it in 🫙"),
        String(localized: "dino wants you to find one good thing 🦕🫙"),
        String(localized: "gratitude jar time 🫙 one small thing. go.")
    ]

    // MARK: - Helper

    static func random(from array: [String]) -> String {
        array.randomElement() ?? array.first ?? ""
    }
}
