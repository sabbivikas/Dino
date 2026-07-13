//
//  LanternGalleryView.swift
//  Dino
//
//  The full keepsakes gallery — every lantern strangers sent, kept forever.
//  Mirrors the gratitude-jar keepsakes gallery: a dedicated screen with a
//  back chevron, a 2-column scrolling grid newest-first, tap to read whole.
//  Presentation only — claim/report/ordering mechanics untouched.
//

import SwiftUI

struct LanternGalleryView: View {
    let lanterns: [ReceivedLantern]
    @Environment(\.dismiss) private var dismiss

    @State private var reading: ReceivedLantern?

    private let space = Color(hex: "#161C2E")
    private let spaceDeep = Color(hex: "#0E1220")
    private let ink = Color(hex: "#ede8d6")
    private let ink2 = Color(hex: "#9aa0cc")
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var countryCount: Int {
        Set(lanterns.map(\.countryCode)).count
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [space, spaceDeep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            WorldStarField()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(WorldRedesignVoice.galleryHeader)
                        .font(.custom(DinoTheme.customFontName, size: 24))
                        .foregroundColor(ink)
                    Text(WorldRedesignVoice.gallerySubline(total: lanterns.count, countries: countryCount))
                        .font(DinoTheme.dinoFont(size: 13))
                        .foregroundColor(ink2)
                        .padding(.bottom, 14)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(lanterns) { lantern in
                            LanternCard(lantern: lantern) { reading = lantern }
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 64)
            }

            backButton
        }
        .fullScreenCover(item: $reading) { lantern in
            LanternReceivedCard(lantern: lantern) { reading = nil }
                .presentationBackground(.clear)
        }
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ink2)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .accessibilityLabel("back")
    }
}
