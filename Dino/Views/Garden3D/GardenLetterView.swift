//
//  GardenLetterView.swift
//  Dino
//
//  The letter the hummingbird carries. Content comes from the pipelines
//  that already exist — the rhythms letter first when today is a predicted
//  hard day (cached the night before), otherwise the forest daily letter.
//  The bird is the delivery ritual, never a new generator.
//

import SwiftUI

/// One letter per local day — unread letters ride with her again tomorrow.
enum GardenLetterStore {
    private static let key = "dino.gardenLetter.readDayKey"

    static func isUnreadToday(now: Date = Date()) -> Bool {
        if GardenDebug.forceLetter { return true }
        return GardenLetterGate.isUnread(
            readDayKey: UserDefaults.standard.string(forKey: key),
            todayKey: GardenLetterGate.dayKey(for: now)
        )
    }

    static func markReadToday(now: Date = Date()) {
        UserDefaults.standard.set(GardenLetterGate.dayKey(for: now), forKey: key)
    }
}

struct GardenLetterView: View {
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var letter: ForestDailyLetter?
    @State private var loading = true
    @State private var isRhythmsLetter = false

    var body: some View {
        ZStack {
            // a soft morning backdrop — she flies at first light
            LinearGradient(colors: [Color(hex: "#FFE6B8"), Color(hex: "#F5EFE0")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ForestLetterOverlay(
                letter: letter,
                loading: loading,
                savedToJar: isRhythmsLetter ? true : (letter?.savedToJar ?? false),
                reduceMotion: reduceMotion,
                onSave: {
                    guard !isRhythmsLetter, let current = letter, !current.savedToJar else { return }
                    Task {
                        await ForestLetterService.shared.saveToGratitudeJar(current)
                        letter?.savedToJar = true
                    }
                },
                onClose: onDismiss
            )
        }
        .task { await load() }
    }

    private func load() async {
        let today = GardenLetterGate.dayKey(for: Date())
        if let rhythms = await RhythmsLetterService.shared.cachedLetter(forDayKey: today) {
            isRhythmsLetter = true
            letter = ForestDailyLetter(date: today, content: rhythms.content, savedToJar: true)
        } else {
            letter = await ForestLetterService.shared.getTodaysLetter()
        }
        loading = false
    }
}
