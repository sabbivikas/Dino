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

    // the full archive — everything dino ever brought (F4). mutable so the
    // late "keep this" refreshes in place.
    @State private var items: [RichRecStore.Keepsake] = RichRecStore.keepsakes()
    @State private var showKeptOnly = false

    private var visibleItems: [RichRecStore.Keepsake] {
        showKeptOnly ? items.filter(\.kept) : items
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "#FAF6EC").ignoresSafeArea()

            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        titleBlock
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        filterPills
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(Array(visibleItems.enumerated()), id: \.offset) { idx, keepsake in
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
            // color rides the title, not the grid slot — stable across filters
            color: palette[abs(keepsake.rec.title.hashValue) % palette.count],
            offsetX: dx,
            offsetY: dy,
            rotation: rot,
            appearDelay: appearDelay,
            onTap: { open(keepsake) },
            onKeep: { keepLate(keepsake) }
        )
    }

    /// Retroactive keeping from the shelf — marks the local entry and writes
    /// the enum twin (lateKept) when the entry carries its ledger id.
    private func keepLate(_ keepsake: RichRecStore.Keepsake) {
        HapticManager.shared.light()
        if let ledgerId = RichRecStore.markKept(title: keepsake.rec.title,
                                                shownAt: keepsake.shownAt) {
            OutcomeLedger.recordLateKeep(entryId: ledgerId)
        }
        items = RichRecStore.keepsakes()
    }

    /// everything · kept — a quiet two-pill filter, default everything.
    private var filterPills: some View {
        HStack(spacing: 8) {
            filterPill(ComfortRecVoice.shelfFilterEverything, active: !showKeptOnly) {
                showKeptOnly = false
            }
            filterPill(ComfortRecVoice.shelfFilterKept, active: showKeptOnly) {
                showKeptOnly = true
            }
            Spacer()
        }
    }

    private func filterPill(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DinoTheme.dinoFont(size: 12))
                .foregroundColor(active ? Color(hex: "#4A3520") : Color(hex: "#A89F90"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(active ? Color(hex: "#F0E7D3") : Color(hex: "#F7F3E9")))
        }
        .buttonStyle(.plain)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ComfortRecVoice.shelfTitle)
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(Color(hex: "#4A3520"))
            Text(ComfortRecVoice.shelfKept(items.filter(\.kept).count))
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
            Text(ComfortRecVoice.shelfEmptyRest)
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
    var onKeep: (() -> Void)? = nil

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
            if !keepsake.kept, let onKeep {
                Button(action: onKeep) {
                    Text(ComfortRecVoice.shelfKeepThis)
                        .font(DinoTheme.dinoFont(size: 11))
                        .foregroundColor(Color(hex: "#4A3520"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.55)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .opacity(keepsake.kept ? 1.0 : 0.82)   // unkept sit plainer
        )
        .overlay(alignment: .top) {
            // the washi-tape mark — kept slips only. static, reduce motion safe.
            if keepsake.kept {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#EAD9A8").opacity(0.85))
                    .frame(width: 44, height: 14)
                    .rotationEffect(.degrees(-4))
                    .offset(y: -6)
                    .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
            }
        }
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
