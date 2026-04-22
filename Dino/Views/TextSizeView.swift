//
//  TextSizeView.swift
//  Dino
//

import SwiftUI

struct TextSizeView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("text_size_scale") private var scale: Double = 1.0

    @State private var showSavedToast = false

    // Palette
    private let paperCream  = Color(hex: "#FBF5E4")
    private let paperWhite  = Color(hex: "#FFFDF5")
    private let sage        = Color(hex: "#7BA872")
    private let nearBlack   = Color(hex: "#2D3A2B")
    private let mutedText   = Color(hex: "#9E9E9E")
    private let cardBorder  = Color(hex: "#E8E0D0")
    private let washiPeach  = Color(hex: "#F5C5A3")
    private let washiSage   = Color(hex: "#B8D4B0")
    private let washiSky    = Color(hex: "#A8D4E6")

    var body: some View {
        NavigationStack {
            ZStack {
                paperCream.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 22) {
                        headerCard
                            .rotationEffect(.degrees(-1.2))

                        previewCard
                            .rotationEffect(.degrees(-0.8))

                        sliderCard
                            .rotationEffect(.degrees(1.1))

                        resetPill
                            .rotationEffect(.degrees(-0.5))

                        saveButton
                            .rotationEffect(.degrees(1.3))
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("text size")
                        .font(DinoTheme.dinoFont(size: 18))
                        .foregroundStyle(nearBlack)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close") { dismiss() }
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundStyle(sage)
                }
            }
            .overlay(alignment: .top) {
                if showSavedToast {
                    savedToast
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        scrapbookCard(tapeColor: washiPeach) {
            HStack(spacing: 16) {
                Image("DinoFlower")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text("text size")
                        .font(DinoTheme.dinoFont(size: 26))
                        .foregroundStyle(nearBlack)
                    Text("make it comfortable to read")
                        .font(DinoTheme.dinoFont(size: 14))
                        .foregroundStyle(sage)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var previewCard: some View {
        scrapbookCard(tapeColor: washiSky) {
            VStack(alignment: .leading, spacing: 10) {
                Text("preview")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundStyle(mutedText)

                Text("little moments")
                    .font(DinoTheme.dinoFont(size: 28))
                    .foregroundStyle(nearBlack)

                Text("a small paragraph of body text showing how it reads at this size. kindness grows in quiet minutes.")
                    .font(DinoTheme.dinoFont(size: 17))
                    .foregroundStyle(nearBlack.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sliderCard: some View {
        scrapbookCard(tapeColor: washiSage) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("size")
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundStyle(mutedText)

                    Spacer()

                    Text(String(format: "%.2f×", scale))
                        .font(DinoTheme.numericFont(size: 14))
                        .foregroundStyle(sage)
                }

                HStack(spacing: 10) {
                    Text("A")
                        .font(DinoTheme.dinoFont(size: 14))
                        .foregroundStyle(mutedText)

                    Slider(value: $scale, in: 0.8...1.4, step: 0.05)
                        .tint(sage)

                    Text("A")
                        .font(DinoTheme.dinoFont(size: 22))
                        .foregroundStyle(mutedText)
                }
            }
        }
    }

    private var resetPill: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                scale = 1.0
            }
        } label: {
            Text("reset to default")
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundStyle(sage)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(paperCream)
                        .overlay(
                            Capsule().stroke(sage.opacity(0.4),
                                             style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("save")
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(sage))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    private var savedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(sage)
            Text("saved")
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundStyle(nearBlack)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(paperWhite)
                .overlay(Capsule().stroke(sage, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .rotationEffect(.degrees(1))
    }

    // MARK: - Scrapbook card helper

    @ViewBuilder
    private func scrapbookCard<Content: View>(
        tapeColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16)
                .fill(paperWhite)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardBorder, lineWidth: 1)
                )

            content()
                .padding(18)
                .padding(.top, 6)

            // Washi tape accent
            RoundedRectangle(cornerRadius: 2)
                .fill(tapeColor.opacity(0.8))
                .frame(width: 70, height: 18)
                .rotationEffect(.degrees(-4))
                .offset(y: -6)
        }
    }

    // MARK: - Save

    private func save() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                showSavedToast = false
            }
        }
    }
}

#Preview {
    TextSizeView()
}
