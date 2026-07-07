//
//  WhatsNewView.swift
//  Dino
//
//  The once-per-version "what's new" carousel. Shown after an update (never
//  to fresh installs — onboarding seeds the version as seen), then never
//  again until the marketing version changes. Slides are DATA: swap the
//  array for the next release, and Chloe's illustrations drop into the
//  named asset slots ("whatsnew_<id>") with zero code changes.
//

import SwiftUI

// MARK: - Gate (pure → unit-tested)

enum WhatsNewGate {
    /// Once per marketing version. Empty current version never shows;
    /// an empty lastSeen means a pre-seeding updater — they DO see it
    /// (fresh installs are seeded at onboarding completion instead).
    static func shouldShow(lastSeen: String, current: String) -> Bool {
        guard !current.isEmpty else { return false }
        return lastSeen != current
    }
}

// MARK: - Slide data

struct WhatsNewSlide: Identifiable {
    enum Tag: String { case new, better }

    let id: String          // also the illustration slot: asset "whatsnew_<id>"
    let tag: Tag
    let accent: Color
    let title: String
    let body: String
    let emoji: [String]     // placeholder illustration until the asset exists

    static let current: [WhatsNewSlide] = [
        WhatsNewSlide(
            id: "intelligence",
            tag: .new,
            accent: Color(hex: "#7BA872"),
            title: "personal intelligence",
            body: "dino now gently understands your sleep, your movement, and your moments. it learns your rhythms, only ever compares you to you, and knows when to speak and when to just be there",
            emoji: ["🌙", "🚶"]
        ),
        WhatsNewSlide(
            id: "recs",
            tag: .new,
            accent: Color(hex: "#F5C842"),
            title: "gentle suggestions",
            body: "on a heavy day, once in a while, dino offers one soft thing. a playlist, a comfort film, a cozy game. never a feed, always a friend",
            emoji: ["🎧", "🍵"]
        ),
        WhatsNewSlide(
            id: "weather",
            tag: .new,
            accent: DinoTheme.skyBlue,
            title: "real weather in dino's world",
            body: "rain outside your window means rain in the garden now. dino's world breathes with yours",
            emoji: ["🌦️", "🌻"]
        ),
        WhatsNewSlide(
            id: "care",
            tag: .better,
            accent: Color(hex: "#C4B8D4"),
            title: "quieter care",
            body: "smarter check ins that know when you slept short, and nudges that lean gentler on heavy days",
            emoji: ["💬", "🌿"]
        ),
    ]
}

// MARK: - The carousel

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    private let slides = WhatsNewSlide.current

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    private var accent: Color { slides[index].accent }
    private var isLast: Bool { index == slides.count - 1 }

    var body: some View {
        ZStack {
            Color(hex: "#FAF6EC").ignoresSafeArea()

            VStack(spacing: 0) {
                // skip — quiet, top right
                HStack {
                    Spacer()
                    Button {
                        AnalyticsManager.shared.trackWhatsNewSkipped()
                        dismiss()
                    } label: {
                        Text("skip")
                            .font(DinoTheme.dinoFont(size: 14))
                            .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 6) {
                    Text("what's new in dino")
                        .font(DinoTheme.dinoFont(size: 24))
                        .foregroundColor(DinoTheme.textPrimary)
                    Text("v\(appVersion)")
                        .font(DinoTheme.dinoFont(size: 11))
                        .foregroundColor(accent)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.14)))
                        .animation(.easeInOut(duration: 0.3), value: index)
                }

                TabView(selection: $index) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { i, slide in
                        SlideView(slide: slide)
                            .tag(i)
                            .padding(.horizontal, 28)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: index) { _, newIndex in
                    AnalyticsManager.shared.trackWhatsNewSlideViewed(index: newIndex)
                }

                // tappable dots, tinted by the current slide
                HStack(spacing: 8) {
                    ForEach(slides.indices, id: \.self) { i in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { index = i }
                        } label: {
                            Capsule()
                                .fill(i == index ? accent : DinoTheme.divider)
                                .frame(width: i == index ? 22 : 8, height: 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
                .padding(.top, 4)

                Button {
                    HapticManager.shared.light()
                    if isLast {
                        AnalyticsManager.shared.trackWhatsNewCompleted()
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { index += 1 }
                    }
                } label: {
                    Text(isLast ? "start exploring 🦕" : "next")
                        .font(DinoTheme.dinoFont(size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: accent.opacity(0.35), radius: 10, y: 3)
                        .animation(.easeInOut(duration: 0.3), value: index)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            AnalyticsManager.shared.trackWhatsNewShown(version: appVersion)
            AnalyticsManager.shared.trackWhatsNewSlideViewed(index: 0)
        }
    }
}

// MARK: - One slide

private struct SlideView: View {
    let slide: WhatsNewSlide

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            SlideIllustration(slide: slide)
                .frame(height: 190)

            Text(slide.tag.rawValue)
                .font(DinoTheme.dinoFont(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Capsule().fill(slide.accent))

            Text(slide.title)
                .font(DinoTheme.dinoFont(size: 23))
                .foregroundColor(DinoTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(slide.body)
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundColor(DinoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Spacer(minLength: 8)
        }
    }
}

// MARK: - Illustration slot (asset wins, cozy placeholder otherwise)

private struct SlideIllustration: View {
    let slide: WhatsNewSlide

    var body: some View {
        if let ui = UIImage(named: "whatsnew_\(slide.id)") {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
        } else {
            // placeholder: a soft accent pool with the feature's emoji resting
            // in it — replaced wholesale when chloe's art lands in the slot
            ZStack {
                Circle()
                    .fill(slide.accent.opacity(0.16))
                    .frame(width: 170, height: 170)
                Circle()
                    .fill(slide.accent.opacity(0.12))
                    .frame(width: 130, height: 130)
                    .offset(x: 26, y: 18)
                HStack(spacing: 2) {
                    ForEach(Array(slide.emoji.enumerated()), id: \.offset) { i, e in
                        Text(e)
                            .font(.system(size: i == 0 ? 64 : 44))
                            .offset(y: i == 0 ? 0 : 22)
                            .rotationEffect(.degrees(i == 0 ? 0 : 8))
                    }
                }
                .shadow(color: slide.accent.opacity(0.3), radius: 14, y: 6)
            }
        }
    }
}
