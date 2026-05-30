//
//  WhatsNewView.swift
//  Dino
//
//  Modal shown once per app version. Cards walk the user through what
//  changed; the first card supports a deep link into the ambient flow.
//

import SwiftUI

// MARK: - Feature model

private struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconBackground: Color
    let title: String
    let description: String
    let deepLink: String?
    let buttonLabel: String?
}

// MARK: - Feature card row

private struct FeatureCardRow: View {
    let feature: WhatsNewFeature
    let onDeepLink: (String) -> Void
    let appeared: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(feature.iconBackground)
                        .frame(width: 44, height: 44)
                    Text(feature.icon)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.title)
                        .font(DinoTheme.dinoFont(size: 16))
                        .foregroundColor(Color(hex: "#2D3142"))
                    Text(feature.description)
                        .font(DinoTheme.dinoFont(size: 14))
                        .foregroundColor(Color(hex: "#2D3142").opacity(0.65))
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if let deepLink = feature.deepLink, let label = feature.buttonLabel {
                Button(action: { onDeepLink(deepLink) }) {
                    Text(label)
                        .font(DinoTheme.dinoFont(size: 13))
                        .foregroundColor(Color(hex: "#A8C5A0"))
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .padding(.leading, 58)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#FEFBF3"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#E8DDD0"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .opacity(appeared ? 1 : 0)
        .offset(y: (appeared || reduceMotion) ? 0 : 20)
    }
}

// MARK: - What's New

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mascotAppeared: Bool = false
    @State private var cardsAppeared: [Bool] = Array(repeating: false, count: 5)

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5"
    }

    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "\u{1F30A}",
            iconBackground: Color(hex: "#A8C5A0"),
            title: "ambient sounds",
            description: "step into a living forest waterfall. close your eyes and let the sounds carry you in. day and night cycles, fireflies, and jumping fish.",
            deepLink: "dino://ambient",
            buttonLabel: "enter the forest \u{2192}"
        ),
        WhatsNewFeature(
            icon: "\u{2728}",
            iconBackground: Color(hex: "#FDDCB5"),
            title: "onboarding redesign",
            description: "a completely new first experience \u{2014} premium animations, breathing circle, gratitude slips, and a forest letter welcoming you in.",
            deepLink: nil,
            buttonLabel: nil
        ),
        WhatsNewFeature(
            icon: "\u{1F331}",
            iconBackground: Color(hex: "#C8E0C4"),
            title: "sunflower fixed",
            description: "your garden now correctly reads your most recent practice. one check-in a day keeps it healthy.",
            deepLink: nil,
            buttonLabel: nil
        ),
        WhatsNewFeature(
            icon: "\u{2B50}",
            iconBackground: Color(hex: "#F9C784").opacity(0.3),
            title: "share the love",
            description: "enjoying dino? a new rating screen helps you share dino with others who might need it.",
            deepLink: nil,
            buttonLabel: nil
        ),
        WhatsNewFeature(
            icon: "\u{1F3A8}",
            iconBackground: Color(hex: "#E8E0F5"),
            title: "design polish",
            description: "typography, pill states, card borders, breathing animations \u{2014} everything feels a little more refined.",
            deepLink: nil,
            buttonLabel: nil
        )
    ]

    var body: some View {
        ZStack {
            Color(hex: "#FAF6EC").ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 24)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                            FeatureCardRow(
                                feature: feature,
                                onDeepLink: { link in handleDeepLink(link) },
                                appeared: reduceMotion ? true : cardsAppeared[safe: index] ?? true,
                                reduceMotion: reduceMotion
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }

                bottomCTA
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .onAppear { startEntrance() }
    }

    private var header: some View {
        VStack(spacing: 0) {
            Image("cut-DinoMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .scaleEffect(reduceMotion ? 1.0 : (mascotAppeared ? 1.0 : 0))
                .opacity(mascotAppeared ? 1 : 0)

            Text("what's new in dino")
                .font(DinoTheme.dinoFont(size: 28))
                .foregroundColor(Color(hex: "#2D3142"))
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Text("v\(appVersion)")
                .font(DinoTheme.dinoFont(size: 12))
                .foregroundColor(Color(hex: "#A8C5A0"))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(hex: "#A8C5A0").opacity(0.12))
                .clipShape(Capsule())
                .padding(.top, 8)
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: 8) {
            Button {
                HapticManager.shared.light()
                dismiss()
            } label: {
                Text("let's explore")
                    .font(DinoTheme.dinoFont(size: 17))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(hex: "#A8C5A0"))
                    .cornerRadius(16)
                    .shadow(color: Color(hex: "#A8C5A0").opacity(0.4), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Text("released May 2026")
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(Color(hex: "#2D3142").opacity(0.35))
        }
    }

    // MARK: Animation

    private func startEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.35)
                    : .spring(response: 0.5, dampingFraction: 0.6)
            ) {
                mascotAppeared = true
            }
        }

        for i in 0..<features.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.08) {
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.3)
                        : .spring(response: 0.5, dampingFraction: 0.75)
                ) {
                    if i < cardsAppeared.count {
                        cardsAppeared[i] = true
                    }
                }
            }
        }
    }

    // MARK: Deep link

    private func handleDeepLink(_ link: String) {
        guard let url = URL(string: link) else { return }
        HapticManager.shared.light()
        dismiss()
        // Wait for the sheet dismiss animation, then ask the app to handle
        // the URL through the existing deep-link pipeline.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NotificationCenter.default.post(name: .dinoOpenURL, object: url)
        }
    }
}

// MARK: - Safe-index helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
