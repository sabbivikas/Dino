//
//  WorldLanternGrid.swift
//  Dino
//
//  "your lanterns" as warm paper cards — the latest four in a 2x2 on the
//  world screen, each with a glowing lantern whose glass is a seeded gradient
//  unique to that lantern (echoing the ceremony's no-two-alike papers). Tap a
//  card to read it whole (LanternReceivedCard — report path intact).
//

import SwiftUI

// MARK: - The seeded lantern mark

/// A little paper lantern. Glass = a seeded gradient (per lantern id), warm
/// gold caps, a soft glow halo. Pass seed: nil for the plain section mark.
struct SeededLanternIcon: View {
    var seed: String?
    var size: CGFloat = 26

    private let gold = Color(hex: "#f6da63")

    var body: some View {
        let glassShape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
        VStack(spacing: 0) {
            Capsule().fill(gold).frame(width: size * 0.34, height: size * 0.13)
            ZStack {
                if let seed {
                    SeededMeshGradient(seed: seed, radius: size)
                        .clipShape(glassShape)
                } else {
                    glassShape.fill(gold.opacity(0.85))
                }
                glassShape.stroke(Color.white.opacity(0.45), lineWidth: 1)
                // faint ribbing
                VStack(spacing: size * 0.18) {
                    Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.6)
                    Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.6)
                }
                .padding(.horizontal, 2)
            }
            .frame(width: size * 0.74, height: size)
            Capsule().fill(gold).frame(width: size * 0.18, height: size * 0.13)
        }
        .shadow(color: gold.opacity(0.55), radius: size * 0.28)
        .accessibilityHidden(true)
    }
}

// MARK: - One card

struct LanternCard: View {
    let lantern: ReceivedLantern
    var onTap: () -> Void

    private let ink = Color(hex: "#3d3a35")
    private let meta = Color(hex: "#a8a29a")

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text("\u{201C}\(lantern.text)\u{201D}")
                        .font(DinoTheme.dinoFont(size: 14))
                        .foregroundColor(ink)
                        .lineSpacing(3)
                        .lineLimit(4)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 6)
                    SeededLanternIcon(seed: lantern.id.uuidString, size: 24)
                }
                Spacer(minLength: 0)
                Text(WorldRedesignVoice.cardMeta(
                    country: LanternService.countryName(lantern.countryCode),
                    date: lantern.receivedAt.formatted(.dateTime.month(.abbreviated).day()).lowercased()))
                    .font(DinoTheme.dinoFont(size: 11))
                    .foregroundColor(meta)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#fbf6e8"), Color(hex: "#f2e9d3")],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        Canvas { ctx, size in
                            var y: CGFloat = 0
                            while y < size.height {
                                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 2)),
                                         with: .color(Color(hex: "#3d3a35").opacity(0.012)))
                                y += 4
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
                    .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("lantern from \(LanternService.countryName(lantern.countryCode)): \(lantern.text)")
    }
}

// MARK: - The 2x2 on the world screen

struct WorldLanternGrid: View {
    let lanterns: [ReceivedLantern]
    var onSeeAll: () -> Void

    @State private var reading: ReceivedLantern?

    private let ink = Color(hex: "#ede8d6")
    private let ink2 = Color(hex: "#9aa0cc")
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SeededLanternIcon(seed: nil, size: 20)
                Text(WorldRedesignVoice.lanternHeader)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(ink)
                Spacer()
                if lanterns.count > 4 {
                    Button(action: onSeeAll) {
                        Text(WorldRedesignVoice.seeAll(lanterns.count))
                            .font(DinoTheme.dinoFont(size: 13))
                            .foregroundColor(ink2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("opens all your kept lanterns")
                }
            }

            Text(WorldRedesignVoice.lanternSubline)
                .font(DinoTheme.dinoFont(size: 12))
                .foregroundColor(ink2)
                .padding(.bottom, 2)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(lanterns.prefix(4))) { lantern in
                    LanternCard(lantern: lantern) { reading = lantern }
                }
            }
        }
        .padding(.horizontal, 16)
        .fullScreenCover(item: $reading) { lantern in
            LanternReceivedCard(lantern: lantern) { reading = nil }
                .presentationBackground(.clear)
        }
    }
}
