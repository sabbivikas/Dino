//
//  RecKeepsakesView.swift
//  Dino
//
//  Feature 3 of the 2.1 comfort recs arc: the little shelf. Every pick dino
//  made rests here, newest first — the jar keepsakes pattern (2 column
//  pastel grid, seeded scatter, tap to act) wearing the rec card's paper.
//  A tap re opens the pick through the same open it flow, remembered music
//  app respected. Local only: reads RichRecStore.keepsakes, never syncs.
//

import SwiftUI

struct RecKeepsakesView: View {
    @Environment(\.dismiss) private var dismiss
    // Kept gifts re open inside dino; a dead page gets the drift line.
    @State private var readerLink: ReaderLink?
    @State private var showDrifted = false

    private let palette: [Color] = [
        Color(hex: "#F5D5C0"),
        Color(hex: "#D4C5E8"),
        Color(hex: "#B8D8E8"),
        Color(hex: "#C8DFC0"),
        Color(hex: "#F0C4C8")
    ]

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    private let kept: [RichRecStore.Keepsake] = RichRecStore.keepsakes()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "#FAF6EC").ignoresSafeArea()

            if kept.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        titleBlock
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(Array(kept.enumerated()), id: \.offset) { idx, keepsake in
                                slipCard(keepsake: keepsake, index: idx)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 60)
                    }
                    .padding(.top, 70)
                }
                .scrollIndicators(.hidden)
            }

            closeButton

            // the drift line — a kept gift whose page has gone quiet.
            // opacity only: reduce motion safe.
            if showDrifted {
                Text(ExpeditionVoice.driftedAway)
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(Color(hex: "#7A6F5F"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#F5F0E8")))
                    .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 30)
                    .transition(.opacity)
            }
        }
        .sheet(item: $readerLink) { link in
            GiftReaderView(url: link.url)
                .ignoresSafeArea()
        }
    }

    private func open(_ keepsake: RichRecStore.Keepsake) {
        HapticManager.shared.light()
        guard let link = keepsake.rec.reopenLink() else { return }
        guard keepsake.rec.type == "gift" else {
            UIApplication.shared.open(link.url)   // recs keep their store doors
            return
        }
        Task {
            if await ExpeditionReader.pageAlive(url: link.url) {
                readerLink = ReaderLink(url: link.url)
            } else {
                withAnimation(.easeInOut(duration: 0.25)) { showDrifted = true }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation(.easeInOut(duration: 0.25)) { showDrifted = false }
            }
        }
    }

    private func slipCard(keepsake: RichRecStore.Keepsake, index: Int) -> some View {
        let seed = keepsake.rec.title.hashValue ^ index
        let dx = seededRandom(seed: seed &+ 1, range: -6.0...6.0)
        let dy = seededRandom(seed: seed &+ 2, range: -4.0...4.0)
        let rot = seededRandom(seed: seed &+ 3, range: -8.0...8.0)
        let appearDelay = min(Double(index) * 0.04, 0.6)
        return RecSlipView(
            keepsake: keepsake,
            color: palette[index % palette.count],
            offsetX: dx,
            offsetY: dy,
            rotation: rot,
            appearDelay: appearDelay,
            onTap: { open(keepsake) }
        )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ComfortRecVoice.shelfTitle)
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(Color(hex: "#4A3520"))
            Text(ComfortRecVoice.shelfKept(kept.count))
                .font(DinoTheme.dinoFont(size: 12))
                .italic()
                .foregroundColor(Color(hex: "#7A6F5F"))
        }
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#7A6F5F"))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(hex: "#F5F0E8")))
                .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.top, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(ComfortRecVoice.shelfEmpty)
                .font(DinoTheme.dinoFont(size: 24))
                .foregroundColor(Color(hex: "#7A6F5F"))
            Text(ComfortRecVoice.shelfEmptySub)
                .font(DinoTheme.dinoFont(size: 14))
                .italic()
                .foregroundColor(Color(hex: "#A89F90"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SeededGen: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private func seededRandom(seed: Int, range: ClosedRange<Double>) -> Double {
    var rng = SeededGen(seed: UInt64(abs(seed) & 0xFFFFFF))
    return Double.random(in: range, using: &rng)
}

private struct RecSlipView: View {
    let keepsake: RichRecStore.Keepsake
    let color: Color
    let offsetX: Double
    let offsetY: Double
    let rotation: Double
    let appearDelay: Double
    let onTap: () -> Void

    @State private var visible: Bool = false

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: keepsake.shownAt).lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Spacer()
                Text(ComfortRecVoice.icon(type: keepsake.rec.type))
                    .font(.system(size: 18))
            }
            Text(keepsake.rec.title)
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(Color(hex: "#2E2A24"))
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(keepsake.rec.creator)
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(Color(hex: "#2E2A24").opacity(0.6))
            Spacer(minLength: 0)
            HStack {
                Text(keepsake.rec.feel)
                    .font(DinoTheme.dinoFont(size: 11))
                    .italic()
                    .foregroundColor(Color(hex: "#2E2A24").opacity(0.55))
                Spacer()
                Text(dateText)
                    .font(DinoTheme.dinoFont(size: 11))
                    .italic()
                    .foregroundColor(Color(hex: "#2E2A24").opacity(0.55))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
        )
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(rotation))
        .offset(x: offsetX, y: offsetY)
        .scaleEffect(visible ? 1.0 : 0.85)
        .opacity(visible ? 1.0 : 0.0)
        .onTapGesture(perform: onTap)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(appearDelay)) {
                visible = true
            }
        }
    }
}
