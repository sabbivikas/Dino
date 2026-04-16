//
//  ResourcesView.swift
//  Dino
//

import SwiftUI
import UIKit

struct ResourcesView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @Environment(\.dismiss) private var dismiss

    struct HotlineResource {
        let emoji: String
        let name: String
        let description: String
        let action: String
        let urlString: String
    }

    let resources: [HotlineResource] = [
        HotlineResource(
            emoji: "📞",
            name: "988 Suicide & Crisis Lifeline",
            description: "call or text 988 — available 24/7",
            action: "Call 988",
            urlString: "tel://988"
        ),
        HotlineResource(
            emoji: "💬",
            name: "Crisis Text Line",
            description: "text HOME to 741741 — free, 24/7 crisis counseling",
            action: "Text 741741",
            urlString: "sms://741741"
        ),
        HotlineResource(
            emoji: "🧠",
            name: "NAMI Helpline",
            description: "1-800-950-NAMI (6264) — Mon–Fri, 10am–10pm ET",
            action: "Call NAMI",
            urlString: "tel://18009506264"
        ),
        HotlineResource(
            emoji: "🌿",
            name: "SAMHSA Helpline",
            description: "1-800-662-HELP (4357) — treatment referrals, free & confidential",
            action: "Call SAMHSA",
            urlString: "tel://18006624357"
        )
    ]

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
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, DinoTheme.padding)

                    // Resource cards
                    VStack(spacing: 14) {
                        ForEach(resources, id: \.name) { resource in
                            ResourceCard(resource: resource)
                        }
                    }
                    .padding(.horizontal, DinoTheme.padding)

                    // Disclaimer
                    Text("if you are in immediate danger, please call 911.")
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
struct ResourceCard: View {
    let resource: ResourcesView.HotlineResource

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(resource.emoji)
                    .font(DinoTheme.dinoFont(size: 28))

                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.name)
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(DinoTheme.textPrimary)

                    Text(resource.description)
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
            }

            Button(action: {
                if let url = URL(string: resource.urlString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text(resource.action)
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
