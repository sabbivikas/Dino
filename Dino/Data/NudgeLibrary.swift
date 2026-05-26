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
        "hey, how are you feeling today? take a sec to check in 🌱",
        "no pressure — but how's your heart doing right now?",
        "your dino is curious how you're feeling today 🦕",
        "a tiny check-in goes a long way. how are you, really?",
        "soft reminder: your feelings deserve a moment today"
    ]

    // MARK: - Streak Reminder (evening fallback)
    static let streakReminder: [String] = [
        "you've been showing up — don't lose your streak tonight 💚",
        "one tiny check-in keeps the streak alive. you've got this",
        "your future self will thank you for showing up today",
        "the streak misses you. it's literally just one moment",
        "you've come this far — keep the chain going tonight"
    ]

    // MARK: - Wind-down (night)
    static let windDown: [String] = [
        "the day is softening, so can you 🌙",
        "time to wind down gently — close the day kindly",
        "rest is a practice too. tuck yourself in",
        "a quiet moment is waiting for you before bed",
        "let the day go. you did enough today"
    ]

    // MARK: - Self-care: water
    static let drinkWater: [String] = [
        "hey, when did you last have water? 💧 dino thinks you're due",
        "hydration check — a sip rn would be elite",
        "your body's been asking for water. one glass, that's it 💧",
        "tiny reminder: water counts as self-care too",
        "dino just chugged a glass of water. you should too 💧"
    ]

    // MARK: - Self-care: eat
    static let eatSomething: [String] = [
        "have you eaten today? a snack counts 🍎",
        "fueling up is self-care. grab something small 🍽",
        "dino is hungry — are you? eat something gentle",
        "no skipping meals today, ok? even a snack helps",
        "your brain runs on food. let's feed it something kind 🥪"
    ]

    // MARK: - Self-care: rest
    static let rest: [String] = [
        "your body needs a pause. five minutes is enough 😴",
        "rest isn't lazy — it's repair. close your eyes a sec",
        "the world will be there after you rest 🌙",
        "scheduled stillness incoming. let yourself be tired",
        "soft reminder: you're allowed to slow down rn"
    ]

    // MARK: - Self-care: check in with yourself
    static let checkInWithYourself: [String] = [
        "how are you really doing? not the autopilot answer 🌿",
        "pause for one breath and notice how you feel",
        "your inner weather check — what's it like in there?",
        "no one's watching. how are you actually feeling?",
        "name one feeling you have right now. just one 💭"
    ]

    // MARK: - Plant: dying (streak just dropped)
    static let plantDying: [String] = [
        "your plant is wilting a little 🥀 a quick check-in would help",
        "psst — your dino's plant misses you. come water it 🌱",
        "the streak slipped, but your plant's still hanging on 🌿",
        "your plant is thirsty. one tiny moment brings it back",
        "no judgment — but the plant could use some love today 💚"
    ]

    // MARK: - Plant: blooming (level up / big milestone)
    static let plantBlooming: [String] = [
        "your plant just bloomed 🌸 look what showing up does",
        "huge bloom moment — you grew this 🌷",
        "petals everywhere. you earned every one of them 🌺",
        "your plant is fully thriving rn. and so are you 🌼",
        "bloom unlocked. that's all you 🌸✨"
    ]

    // MARK: - Plant: progressing (7/14/21 day streak milestones)
    static let plantProgressing: [String] = [
        "your plant grew a new leaf 🌱 keep going",
        "new growth spotted. you're doing the thing 🌿",
        "look at that — a fresh sprout. proud of you",
        "your plant is visibly happier today 🌱 thank you",
        "small leaf, big deal. progress looks like this"
    ]

    // MARK: - Helper

    static func random(from array: [String]) -> String {
        array.randomElement() ?? array.first ?? ""
    }

    /// Maps a string category name to the fallback array. Used by
    /// NudgeGeneratorService when OpenAI is unavailable or returns nothing.
    static func fallbacks(for category: String) -> [String] {
        switch category {
        case "dailyCheckIn":         return dailyCheckIn
        case "streakReminder":       return streakReminder
        case "windDown":             return windDown
        case "drinkWater":           return drinkWater
        case "eatSomething":         return eatSomething
        case "rest":                 return rest
        case "checkInWithYourself":  return checkInWithYourself
        case "plantDying":           return plantDying
        case "plantBlooming":        return plantBlooming
        case "plantProgressing":     return plantProgressing
        default:                     return dailyCheckIn
        }
    }
}
