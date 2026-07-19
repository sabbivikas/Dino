//
//  StreakBadge.swift
//  Dino
//

import SwiftUI

struct StreakBadge: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let streak: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("🔥")
                .font(DinoTheme.dinoFont(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(streak == 1 ? String(localized: "\(streak) day") : String(localized: "\(streak) days"))
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(DinoTheme.textPrimary)

                Text("current streak")
                    .font(DinoTheme.caption2Font())
                    .foregroundColor(DinoTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DinoTheme.surfacePrimary)
        .cornerRadius(DinoTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
        )
    }
}
