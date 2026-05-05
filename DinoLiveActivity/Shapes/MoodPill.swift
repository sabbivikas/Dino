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

/// Dashed-border mood pill used by the systemLarge mood scenes,
/// matching the v5 spec (white .55 fill + dashed ink stroke).
struct MoodPillDashed: View {
    let label: String
    var textColor: Color = DinoPalette.dinoInk
    var strokeColor: Color = Color(hex: "#11402D").opacity(0.35)

    var body: some View {
        Text(label)
            .font(WidgetTheme.widgetFont(size: 13))
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                Capsule()
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
            )
    }
}
