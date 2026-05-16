//
//  MoodPaintingGalleryView.swift
//  Dino
//

import SwiftUI

private enum GalleryPalette {
    static let bg     = Color(hex: "#1A1A2E")
    static let cream  = Color(hex: "#FAF6EC")
    static let mute   = Color(hex: "#8B7A6A")
    static let pill   = Color(hex: "#F5F0E8")
}

struct MoodPaintingGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = MoodPaintingService.shared

    @State private var fullscreenItem: PaintingItem?

    private struct PaintingItem: Identifiable {
        let id: String
        let date: Date
        let image: UIImage
    }

    private var items: [PaintingItem] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return service.monthlyPaintings
            .reversed()
            .map { PaintingItem(id: f.string(from: $0.date), date: $0.date, image: $0.image) }
    }

    var body: some View {
        ZStack {
            GalleryPalette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if items.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            ForEach(items) { item in
                                paintingCard(item)
                                    .onTapGesture { fullscreenItem = item }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 80)
                    }
                }
            }

            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GalleryPalette.mute)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(GalleryPalette.pill))
                            .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 20)
                    .padding(.top, 16)
                    Spacer()
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $fullscreenItem) { item in
            PaintingZoomView(image: item.image, caption: caption(for: item.date))
        }
        .onAppear {
            _ = service.loadAllPaintings()
            AnalyticsManager.shared.trackPaintingGalleryOpened()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("your emotional gallery")
                .font(.custom(DinoTheme.customFontName, size: 22))
                .foregroundColor(GalleryPalette.cream)
            Text("each painting is a month of your inner world")
                .font(.custom(DinoTheme.customFontName, size: 12))
                .foregroundColor(GalleryPalette.cream.opacity(0.6))
        }
        .padding(.top, 64)
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("\u{1F995}")
                .font(.system(size: 64))
            Text("your first painting generates at the end of this month \u{1F3A8}")
                .font(.custom(DinoTheme.customFontName, size: 16))
                .foregroundColor(GalleryPalette.cream.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func paintingCard(_ item: PaintingItem) -> some View {
        let width = UIScreen.main.bounds.width - 40
        return ZStack(alignment: .bottomLeading) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 300)
                .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 110)
            .frame(maxWidth: .infinity, alignment: .bottom)

            HStack(alignment: .bottom) {
                Text(caption(for: item.date))
                    .font(.custom(DinoTheme.customFontName, size: 14))
                    .foregroundColor(GalleryPalette.cream)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: width, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func caption(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date).lowercased()
    }
}

// MARK: - Zoomable fullscreen viewer

private struct PaintingZoomView: View {
    let image: UIImage
    let caption: String
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { v in
                            scale = max(1.0, min(5.0, lastScale * v))
                        }
                        .onEnded { _ in lastScale = scale }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { v in
                            offset = CGSize(
                                width: lastOffset.width + v.translation.width,
                                height: lastOffset.height + v.translation.height
                            )
                        }
                        .onEnded { _ in
                            if scale <= 1.05 && abs(offset.height) > 120 {
                                dismiss()
                                return
                            }
                            lastOffset = offset
                        }
                )

            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(GalleryPalette.cream)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 20)
                    .padding(.top, 16)
                    Spacer()
                }
                Spacer()
                Text(caption)
                    .font(.custom(DinoTheme.customFontName, size: 14))
                    .foregroundColor(GalleryPalette.cream)
                    .padding(.bottom, 32)
            }
        }
        .onTapGesture(count: 2) {
            withAnimation(.spring()) {
                scale = scale > 1.0 ? 1.0 : 2.0
                lastScale = scale
                if scale == 1.0 {
                    offset = .zero
                    lastOffset = .zero
                }
            }
        }
    }
}
