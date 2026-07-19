//
//  RecKeepsakesView.swift
//  Dino
//
//  Feature 3 of the 2.1 comfort recs arc: the little shelf. Every pick dino
//  made rests here, newest first — the jar keepsakes pattern (2 column
//  pastel grid, seeded scatter, tap to act) wearing the rec card's paper.
//
//  Rec delivery F5 — the shelf catch. The shelf now unifies two sources:
//    • WRAPPED PARCELS — deliveries still 'announced' and never opened. They
//      show as a still-wrapped parcel ("still wrapped · tap to open"); a tap
//      opens the SAME F4 reveal (RecRevealView) for that deliveryId. After
//      opening, the delivery becomes an opened keepsake like any other.
//    • OPENED KEEPSAKES — the local archive: each opened rec with its image
//      thumbnail (RecArtwork's per-type pipeline, paper-only when no image,
//      never a broken frame) + the existing washi mark.
//  RecShelf.merge holds the ordering/dedupe rule (wrapped first, then the
//  archive newest-first; a just-opened delivery is deduped by identity).
//

import SwiftUI

struct RecKeepsakesView: View {
    @Environment(\.dismiss) private var dismiss
    // Injected so the shared reveal (RecRevealView) can read moods for the
    // ledger 'shown' write, exactly as ContentView's cover does.
    @EnvironmentObject var dataManager: SharedDataManager
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

    // the opened archive — everything dino ever brought and the user unwrapped
    // (F4). mutable so a late "keep this" or a fresh reveal refreshes in place.
    @State private var keepsakeItems: [RichRecStore.Keepsake] = RichRecStore.keepsakes()
    // the still-wrapped parcels — announced deliveries never opened (F5).
    @State private var wrapped: [WrappedDelivery] = []
    // deliveries opened on this device — dedupes a just-opened parcel out of
    // the wrapped list before the server flip lands.
    @State private var openedIds: Set<String> = RichRecStore.openedDeliveryIds()
    @State private var showKeptOnly = false
    // the shared F4 reveal, presented locally over the shelf (matches F4's
    // fullScreenCover presentation — reuse, never a fork).
    @State private var revealLink: RecRevealLink?

    private var entries: [RecShelf.Entry] {
        RecShelf.merge(wrapped: wrapped, keepsakes: keepsakeItems, openedIds: openedIds)
    }

    private var visibleEntries: [RecShelf.Entry] {
        RecShelf.visible(entries, keptOnly: showKeptOnly)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "#FAF6EC").ignoresSafeArea()

            if entries.isEmpty {
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
                            ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { idx, entry in
                                entryCard(entry: entry, index: idx)
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
        .task { await refreshWrapped() }
        .sheet(item: $readerLink) { link in
            GiftReaderView(url: link.url)
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $revealLink, onDismiss: { refreshAfterReveal() }) { link in
            // the SAME F4 reveal, by deliveryId — reuse, never a fork.
            RecRevealView(
                deliveryId: link.deliveryId,
                onDismiss: { revealLink = nil })
                .environmentObject(dataManager)
        }
    }

    // MARK: - loading + refresh

    private func refreshWrapped() async {
        let fetched = await RecRevealService.announcedDeliveries()
        wrapped = fetched
    }

    /// After a reveal dismisses: the local archive may now hold a fresh
    /// keepsake, and the opened-id set may have grown — re-read both, then
    /// re-fetch the wrapped list (the opened delivery drops out).
    private func refreshAfterReveal() {
        revealLink = nil
        keepsakeItems = RichRecStore.keepsakes()
        openedIds = RichRecStore.openedDeliveryIds()
        Task { await refreshWrapped() }
    }

    // MARK: - entry cards

    @ViewBuilder
    private func entryCard(entry: RecShelf.Entry, index: Int) -> some View {
        switch entry {
        case .wrapped(let w):
            wrappedSlip(w, index: index)
        case .opened(let keepsake):
            slipCard(keepsake: keepsake, index: index)
        }
    }

    private func openReveal(_ w: WrappedDelivery) {
        HapticManager.shared.light()
        revealLink = RecRevealLink(deliveryId: w.deliveryId)
    }

    private func wrappedSlip(_ w: WrappedDelivery, index: Int) -> some View {
        let seed = w.deliveryId.hashValue ^ index
        let dx = seededRandom(seed: seed &+ 1, range: -6.0...6.0)
        let dy = seededRandom(seed: seed &+ 2, range: -4.0...4.0)
        let rot = seededRandom(seed: seed &+ 3, range: -8.0...8.0)
        let appearDelay = min(Double(index) * 0.04, 0.6)
        return WrappedParcelSlip(
            offsetX: dx, offsetY: dy, rotation: rot, appearDelay: appearDelay,
            onTap: { openReveal(w) })
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
        keepsakeItems = RichRecStore.keepsakes()
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
            Text(ComfortRecVoice.shelfKept(keepsakeItems.filter(\.kept).count))
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

// MARK: - the wrapped parcel slip (F5 — still wrapped, tap to open)

/// A still-wrapped parcel resting on the shelf: the drawn RecParcelView (the
/// same paper parcel the reveal and the live activity use) on cream paper
/// with a gift-dashed edge and the "still wrapped · tap to open" caption. A
/// tap opens the F4 reveal. Reduce Motion safe (no appear animation; the
/// parcel's own glow self-gates).
private struct WrappedParcelSlip: View {
    let offsetX: Double
    let offsetY: Double
    let rotation: Double
    let appearDelay: Double
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        VStack(spacing: 10) {
            RecParcelView(size: 72, glowing: true)
            Text(ComfortRecVoice.shelfStillWrapped)
                .font(DinoTheme.dinoFont(size: 12))
                .italic()
                .multilineTextAlignment(.center)
                .foregroundColor(Color(hex: "#7A6F5F"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#FBF6EB"))   // the parcel's own cream paper
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(hex: "#EAD9A8").opacity(0.7),
                                      style: StrokeStyle(lineWidth: 1.3, dash: [4, 3]))
                )
        )
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(rotation))
        .offset(x: offsetX, y: offsetY)
        .scaleEffect(visible ? 1.0 : (reduceMotion ? 1.0 : 0.85))
        .opacity((visible || reduceMotion) ? 1.0 : 0.0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(ComfortRecVoice.shelfStillWrapped)
        .onAppear {
            guard !reduceMotion else { visible = true; return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(appearDelay)) {
                visible = true
            }
        }
    }
}

// MARK: - the opened keepsake slip

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
    // F5: the opened rec's image thumbnail (RecArtwork's per-type pipeline).
    // nil = the paper-only design (the emoji token), never a broken frame.
    @State private var thumb: UIImage?

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: keepsake.shownAt).lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Spacer()
                // the image thumbnail when one loads; otherwise the paper-only
                // type token (never a broken frame, never a gray box).
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
                        .transition(.opacity)
                } else {
                    Text(ComfortRecVoice.icon(type: keepsake.rec.type))
                        .font(.system(size: 18))
                }
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
                Text(keepsake.rec.feel.localized)
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
        .task(id: keepsake.rec.title) {
            // lazy (LazyVGrid renders only visible cells) + URLCache-backed,
            // so a scrolled/repeated shelf reloads nothing — no memory growth.
            let image = await RecArtwork.loadImage(for: keepsake.rec)
            withAnimation(.easeInOut(duration: 0.3)) { thumb = image }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(appearDelay)) {
                visible = true
            }
        }
    }
}
