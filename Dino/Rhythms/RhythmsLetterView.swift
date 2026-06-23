//
//  RhythmsLetterView.swift
//  Dino
//
//  Presents the rhythms "letter from the forest" using the SAME envelope +
//  parchment letter UI as the forest letter (ForestLetterOverlay), over a calm
//  dimmed night backdrop. Loads the letter cached the evening it was scheduled;
//  falls back to the static line if nothing is cached.
//

import SwiftUI

struct RhythmsLetterView: View {
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var letter: ForestDailyLetter?
    @State private var loading: Bool = true

    var body: some View {
        ZStack {
            // Calm dim night backdrop; the envelope + letter float above it.
            LinearGradient(
                colors: [Color(hex: "#0B1120"), Color(hex: "#1B2C4C")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Reuse the forest letter's envelope/parchment UI verbatim.
            // savedToJar:true + no-op onSave keeps the jar affordance inert —
            // rhythms letters are not saved to the gratitude jar.
            ForestLetterOverlay(
                letter: letter,
                loading: loading,
                savedToJar: true,
                reduceMotion: reduceMotion,
                onSave: { AnalyticsManager.shared.trackRhythmsLetterSaved() },
                onClose: onDismiss
            )
        }
        .task { await load() }
    }

    private func load() async {
        let cached = await RhythmsLetterService.shared.latestCachedLetter()
        let content = cached?.content ?? RhythmsLetterService.fallbackLetter
        let key = cached?.dayKey
            ?? RhythmsLetterService.dayKey(for: Date(), calendar: .current)
        letter = ForestDailyLetter(date: key, content: content, savedToJar: true)
        loading = false
        AnalyticsManager.shared.trackRhythmsLetterReceived()
    }
}
