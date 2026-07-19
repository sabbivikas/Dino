//
//  RecRevealPlaceholderView.swift
//  Dino
//
//  ⚠️ F4 PLACEHOLDER (built in F3, REPLACED BY F4) — deliberately minimal.
//  F3 owns the announcement (push + parcel live activity); this view is
//  only where the parcel's deep link lands so the door works end to end.
//  F4 replaces this destination with the real reveal (status-gated payload
//  read, the unwrap moment, shelf write-through, 'opened' flip).
//  RULE: existing catalog strings only — no new copy may be born here.
//

import SwiftUI

struct RecRevealPlaceholderView: View {
    let deliveryId: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.984, green: 0.965, blue: 0.922).ignoresSafeArea()   // cream paper

            VStack(spacing: 28) {
                Spacer()

                RecParcelView(size: 150, glowing: true)

                // existing key ("dino picked this for you 🌿") — zero new strings
                Text("dino picked this for you 🌿")
                    .font(DinoTheme.dinoFont(size: 26))
                    .foregroundColor(Color(red: 0.067, green: 0.251, blue: 0.176))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            // the parcel was opened — the lock-screen presence ends here
            DinoLiveActivityManager.shared.endRecParcelActivities()
        }
        .accessibilityAddTraits(.isButton)
    }
}
