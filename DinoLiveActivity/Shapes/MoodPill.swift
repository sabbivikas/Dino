//
//  MoodPill.swift
//  DinoLiveActivity
//
//  Reusable capsule chip for the mood-day widget. Cream / translucent fill with
//  a soft ink stroke, using the Dino hand-drawn font. Matches widgets.html
//  `.mood-pill` styling:
//    background: rgba(255,255,255,.55);
//    border: 1.5px solid rgba(17,64,45,.12);
//    color: var(--dino-ink);
//

import SwiftUI

struct MoodPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(WidgetTheme.widgetFont(size: 13))
            .foregroundColor(DinoPalette.dinoInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(DinoPalette.moodPillBg)
            )
            .overlay(
                Capsule()
                    .stroke(DinoPalette.moodPillStroke, lineWidth: 1.5)
            )
    }
}
