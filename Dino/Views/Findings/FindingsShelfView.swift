//
//  FindingsShelfView.swift
//  Dino
//
//  EXPERIMENTAL star-findings demo. The shelf under the star: the star's own
//  findings (from FindingsStore) AND the real comfort recs, read-only
//  (RichRecStore.keepsakes()). The opened-keepsake slip + its seeded-scatter
//  helpers are COPIED from RecKeepsakesView.swift and renamed private to this
//  file (isolation — the demo forks nothing on main).
//
//  English-only demo (owner decision): plain string literals only.
//

import SwiftUI

struct FindingsShelfView: View {
    let findings: [FindingItem]
    var onOpenFinding: (FindingItem) -> Void = { _ in }

    /// The paper-family cream (mirrors RecRevealView's cream) for headers on
    /// the dark space backdrop — readable, still soft (owner fix #4).
    static let creamHeader = Color(red: 0.984, green: 0.965, blue: 0.922)

    // the real comfort recs, read-only (display only — no keeping here).
    private let keepsakes: [RichRecStore.Keepsake] = RichRecStore.keepsakes()

    private let palette: [Color] = [
        Color(hex: "#F5D5C0"), Color(hex: "#D4C5E8"), Color(hex: "#B8D8E8"),
        Color(hex: "#C8DFC0"), Color(hex: "#F0C4C8")
    ]
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("the shelf")
                .font(DinoTheme.dinoFont(size: 20))
                .foregroundColor(Self.creamHeader)   // light cream on the dark sky (owner fix #4)
                .padding(.horizontal, 20)

            if findings.isEmpty && keepsakes.isEmpty {
                Text("when the star brings something back, it will rest here 🌿")
                    .font(DinoTheme.dinoFont(size: 14))
                    .italic()
                    .foregroundColor(Self.creamHeader.opacity(0.72))
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 30)
            } else {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(Array(findings.enumerated()), id: \.element.id) { idx, f in
                        FindingSlip(
                            finding: f,
                            color: palette[abs(f.taskId.hashValue) % palette.count],
                            index: idx,
                            onTap: { onOpenFinding(f) })
                    }
                    ForEach(Array(keepsakes.enumerated()), id: \.offset) { idx, k in
                        FindingsRecSlip(
                            keepsake: k,
                            color: palette[abs(k.rec.title.hashValue) % palette.count],
                            index: idx + findings.count)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - the finding slip (a past finding resting on the shelf)

private struct FindingSlip: View {
    let finding: FindingItem
    let color: Color
    let index: Int
    let onTap: () -> Void

    @State private var visible = false

    private var statusLine: String {
        switch finding.status {
        case "booked":    return "booked"
        case "confirmed": return "on your calendar"
        case "handoff":   return "handed to you to finish"
        case "empty":     return "open paws"
        case "searching": return "still looking"
        default:          return "found"
        }
    }

    /// The acted marker: a slip you have already done something with says so at
    /// a glance, so the shelf never reads as "still waiting on you".
    private var actedMarker: String? {
        switch finding.status {
        case "confirmed": return "added"
        case "booked":    return "booked"
        case "handoff":   return "handed off"
        default:          return nil
        }
    }

    var body: some View {
        let seed = finding.taskId.hashValue ^ index
        let dx = findingsSeededRandom(seed: seed &+ 1, range: -6.0...6.0)
        let dy = findingsSeededRandom(seed: seed &+ 2, range: -4.0...4.0)
        let rot = findingsSeededRandom(seed: seed &+ 3, range: -8.0...8.0)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                if let actedMarker {
                    Text(actedMarker)
                        .font(DinoTheme.dinoFont(size: 10))
                        .foregroundColor(Color(hex: "#2E2A24").opacity(0.72))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.45)))
                }
                Spacer()
                Text("⭐️").font(.system(size: 18))
            }
            Text(finding.title.isEmpty ? "a gentle outing" : finding.title)
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(Color(hex: "#2E2A24"))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !finding.whereText.isEmpty {
                Text(finding.whereText)
                    .font(DinoTheme.dinoFont(size: 11))
                    .foregroundColor(Color(hex: "#2E2A24").opacity(0.6))
            }
            Spacer(minLength: 0)
            HStack {
                Text(statusLine)
                    .font(DinoTheme.dinoFont(size: 11))
                    .italic()
                    .foregroundColor(Color(hex: "#2E2A24").opacity(0.55))
                Spacer()
                if !finding.whenText.isEmpty {
                    Text(finding.whenText)
                        .font(DinoTheme.dinoFont(size: 11))
                        .italic()
                        .lineLimit(1)
                        .foregroundColor(Color(hex: "#2E2A24").opacity(0.55))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(RoundedRectangle(cornerRadius: 8).fill(color))
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(rot))
        .offset(x: dx, y: dy)
        .scaleEffect(visible ? 1.0 : 0.85)
        .opacity(visible ? 1.0 : 0.0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)
                .delay(min(Double(index) * 0.04, 0.6))) { visible = true }
        }
    }
}

// MARK: - the opened keepsake slip (COPIED from RecKeepsakesView, read-only)

private struct FindingsRecSlip: View {
    let keepsake: RichRecStore.Keepsake
    let color: Color
    let index: Int

    @State private var visible: Bool = false
    @State private var thumb: UIImage?

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: keepsake.shownAt).lowercased()
    }

    private func open() {
        HapticManager.shared.light()
        guard let link = keepsake.rec.reopenLink() else { return }
        UIApplication.shared.open(link.url)   // read-only: just reopen the door
    }

    var body: some View {
        let seed = keepsake.rec.title.hashValue ^ index
        let dx = findingsSeededRandom(seed: seed &+ 1, range: -6.0...6.0)
        let dy = findingsSeededRandom(seed: seed &+ 2, range: -4.0...4.0)
        let rot = findingsSeededRandom(seed: seed &+ 3, range: -8.0...8.0)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Spacer()
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable().scaledToFill()
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
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(keepsake.rec.creator)
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(Color(hex: "#2E2A24").opacity(0.6))
            Spacer(minLength: 0)
            HStack {
                Text(keepsake.rec.feel.localized)
                    .font(DinoTheme.dinoFont(size: 11)).italic()
                    .foregroundColor(Color(hex: "#2E2A24").opacity(0.55))
                Spacer()
                Text(dateText)
                    .font(DinoTheme.dinoFont(size: 11)).italic()
                    .foregroundColor(Color(hex: "#2E2A24").opacity(0.55))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(RoundedRectangle(cornerRadius: 8).fill(color).opacity(keepsake.kept ? 1.0 : 0.82))
        .overlay(alignment: .top) {
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
        .rotationEffect(.degrees(rot))
        .offset(x: dx, y: dy)
        .scaleEffect(visible ? 1.0 : 0.85)
        .opacity(visible ? 1.0 : 0.0)
        .onTapGesture(perform: open)
        .task(id: keepsake.rec.title) {
            let image = await RecArtwork.loadImage(for: keepsake.rec)
            withAnimation(.easeInOut(duration: 0.3)) { thumb = image }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)
                .delay(min(Double(index) * 0.04, 0.6))) { visible = true }
        }
    }
}

// MARK: - seeded scatter (COPIED from RecKeepsakesView, renamed private)

private struct FindingsSeededGen: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private func findingsSeededRandom(seed: Int, range: ClosedRange<Double>) -> Double {
    var rng = FindingsSeededGen(seed: UInt64(abs(seed) & 0xFFFFFF))
    return Double.random(in: range, using: &rng)
}
