//
//  GratitudeSlip.swift
//  Dino
//

import SwiftUI

struct GratitudeSlip: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let note: GratitudeNote
    let index: Int
    let onTap: () -> Void

    private var rotation: Double {
        let seed = Double(note.id.hashValue % 100) / 100.0
        return (seed * 10.0) - 5.0
    }

    private var color: Color {
        DinoTheme.pastel(for: index)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .font(DinoTheme.caption2Font())
                    .foregroundColor(DinoTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(8)
            .frame(width: 90, height: 60)
            .background(color.opacity(0.6))
            .cornerRadius(6)
            .shadow(color: DinoTheme.shadowColor, radius: 4, y: 2)
            .rotationEffect(.degrees(rotation))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
