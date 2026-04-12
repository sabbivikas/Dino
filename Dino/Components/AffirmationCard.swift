//
//  AffirmationCard.swift
//  Dino
//

import SwiftUI

struct AffirmationCard: View {
    let text: String
    let index: Int
    let isSaved: Bool
    let onSave: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius)
                .fill(DinoTheme.pastel(for: index).opacity(0.25))
                .shadow(color: DinoTheme.shadowColor, radius: DinoTheme.shadowRadius, y: DinoTheme.shadowY)

            VStack(spacing: 20) {
                Text(text)
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button(action: onSave) {
                    Image(systemName: isSaved ? "star.fill" : "star")
                        .font(.system(size: 22))
                        .foregroundColor(isSaved ? .yellow : DinoTheme.textSecondary)
                }
            }
            .padding(.vertical, 32)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}
