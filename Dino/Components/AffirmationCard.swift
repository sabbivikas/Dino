//
//  AffirmationCard.swift
//  Dino
//

import SwiftUI

struct AffirmationCard: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let text: String
    let index: Int
    let isSaved: Bool
    let onSave: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius)
                .fill(DinoTheme.surfacePrimary)
                .shadow(color: DinoTheme.shadowColor, radius: DinoTheme.shadowRadius, y: DinoTheme.shadowY)

            RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius)
                .fill(DinoTheme.pastel(for: index).opacity(0.15))

            VStack(spacing: 20) {
                Text(text)
                    .font(DinoTheme.dinoFont(size: 20))
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button(action: onSave) {
                    Image(systemName: isSaved ? "star.fill" : "star")
                        .font(DinoTheme.dinoFont(size: 22))
                        .foregroundColor(isSaved ? .yellow : DinoTheme.textSecondary)
                }
            }
            .padding(.vertical, 32)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .overlay(
            RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius)
                .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
        )
    }
}
