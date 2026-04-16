//
//  AffirmationsView.swift
//  Dino
//

import SwiftUI

struct AffirmationsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 6) {
                        Text("affirmations")
                            .font(DinoTheme.dinoDisplayFont(size: 28))
                            .foregroundColor(DinoTheme.textPrimary)
                        Text("swipe to explore • tap ⭐️ to save")
                            .font(DinoTheme.captionFont())
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                    .padding(.top, 8)

                    // Swipeable card stack
                    TabView(selection: $currentIndex) {
                        ForEach(Array(AffirmationsData.all.enumerated()), id: \.offset) { i, text in
                            AffirmationCard(
                                text: text,
                                index: i,
                                isSaved: dataManager.isAffirmationSaved(text),
                                onSave: {
                                    withAnimation {
                                        if dataManager.isAffirmationSaved(text) {
                                            dataManager.removeAffirmation(text)
                                        } else {
                                            dataManager.saveAffirmation(text)
                                        }
                                    }
                                }
                            )
                            .padding(.horizontal, DinoTheme.padding)
                            .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: 240)

                    // Page indicator
                    Text("\(currentIndex + 1) of \(AffirmationsData.all.count)")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)

                    Divider()
                        .padding(.horizontal, DinoTheme.padding)

                    // Saved affirmations
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("saved")
                                .font(DinoTheme.headlineFont())
                                .foregroundColor(DinoTheme.textPrimary)
                            Spacer()
                            Text("\(dataManager.savedAffirmations.count)")
                                .font(DinoTheme.captionFont())
                                .foregroundColor(DinoTheme.textSecondary)
                        }
                        .padding(.horizontal, DinoTheme.padding)

                        if dataManager.savedAffirmations.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Text("⭐️")
                                        .font(DinoTheme.dinoFont(size: 32))
                                    Text("tap the star on any card to save it here")
                                        .font(DinoTheme.captionFont())
                                        .foregroundColor(DinoTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 16)
                                Spacer()
                            }
                        } else {
                            ForEach(dataManager.savedAffirmations) { affirmation in
                                SavedAffirmationRow(
                                    text: affirmation.text,
                                    onRemove: { dataManager.removeAffirmation(affirmation.text) }
                                )
                                .padding(.horizontal, DinoTheme.padding)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(DinoTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(DinoTheme.sageGreen)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SavedAffirmationRow: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundColor(.yellow)

            Text(text)
                .font(DinoTheme.bodyFont())
                .foregroundColor(DinoTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(DinoTheme.dinoFont(size: 18))
                    .foregroundColor(DinoTheme.textSecondary.opacity(0.4))
            }
        }
        .padding(14)
        .background(DinoTheme.cardBackground)
        .cornerRadius(DinoTheme.cornerRadius)
    }
}
