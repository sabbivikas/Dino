//
//  StreakBadge.swift
//  Dino
//

import SwiftUI

struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("🔥")
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak) day\(streak == 1 ? "" : "s")")
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(DinoTheme.textPrimary)

                Text("current streak")
                    .font(DinoTheme.caption2Font())
                    .foregroundColor(DinoTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color.orange.opacity(0.1)
                .cornerRadius(DinoTheme.cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}
