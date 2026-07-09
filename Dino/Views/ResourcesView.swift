//
//  ResourcesView.swift
//  Dino
//
//  Regional crisis resources — rendered from the human-verified directory in
//  CrisisResources.swift. Region comes from the device setting (no location
//  permission, works offline); unknown regions get the international block.
//

import SwiftUI
import UIKit

struct ResourcesView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private let regional = CrisisResources.resources(for: Locale.current.region?.identifier)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 10) {
                        Text("💙")
                            .font(.system(size: 52))

                        Text("you're not alone")
                            .font(DinoTheme.dinoDisplayFont(size: 28))
                            .foregroundColor(DinoTheme.textPrimary)

                        Text("reaching out is one of the bravest things you can do. these resources are here for you, any time.")
                            .font(DinoTheme.bodyFont())
                            .foregroundColor(DinoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        if regional.isFallback {
                            Text(CrisisResources.fallbackLine)
                                .font(DinoTheme.dinoFont(size: 14))
                                .foregroundColor(DinoTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, DinoTheme.padding)

                    // Resource cards (regional or international fallback)
                    VStack(spacing: 14) {
                        ForEach(regional.list, id: \.name) { resource in
                            RegionalResourceCard(resource: resource)
                        }
                    }
                    .padding(.horizontal, DinoTheme.padding)

                    // Region-neutral emergency footer
                    Text(CrisisResources.emergencyFooter)
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DinoTheme.largePadding)
                        .padding(.bottom, 32)
                }
            }
            .background(DinoTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close") { dismiss() }
                        .foregroundColor(DinoTheme.sageGreen)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Resource Card

private struct RegionalResourceCard: View {
    let resource: RegionalResource

    private var emoji: String {
        switch resource.kind {
        case .call:     return "📞"
        case .text:     return "💬"
        case .whatsapp: return "💬"
        case .link:     return "🌍"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(DinoTheme.dinoFont(size: 28))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(resource.name)
                            .font(DinoTheme.headlineFont())
                            .foregroundColor(DinoTheme.textPrimary)
                        if resource.is24h {
                            Text("24/7")
                                .font(DinoTheme.dinoFont(size: 10))
                                .foregroundColor(DinoTheme.sageGreen)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(DinoTheme.sageGreen.opacity(0.14)))
                        }
                    }
                    Text(resource.detail)
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
            }

            Button(action: {
                if let url = resource.actionURL {
                    UIApplication.shared.open(url)
                }
            }) {
                Text(resource.actionLabel)
                    .font(DinoTheme.subheadlineFont())
                    .fontWeight(.semibold)
                    .foregroundColor(DinoTheme.warmRose)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DinoTheme.warmRose.opacity(0.1))
                    .cornerRadius(DinoTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                            .stroke(DinoTheme.warmRose.opacity(0.3), lineWidth: 1.5)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(DinoTheme.padding)
        .background(DinoTheme.surfacePrimary)
        .cornerRadius(DinoTheme.largeCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius)
                .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: DinoTheme.shadowColor, radius: DinoTheme.shadowRadius, y: DinoTheme.shadowY)
    }
}
