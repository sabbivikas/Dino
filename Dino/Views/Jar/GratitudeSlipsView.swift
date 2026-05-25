//
//  GratitudeSlipsView.swift
//  Dino
//
//  v11 — 2-column LazyVGrid of square-ish pastel slip cards.
//

import SwiftUI

struct GratitudeSlipsView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID? = nil

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

    private var notes: [GratitudeNote] {
        dataManager.gratitudeNotes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(hex: "#FAF6EC").ignoresSafeArea()

            if notes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        titleBlock
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                                slipCard(note: note, index: idx)
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
        }
    }

    private func slipCard(note: GratitudeNote, index: Int) -> some View {
        let seed = note.id.hashValue ^ index
        let dx = seededRandom(seed: seed &+ 1, range: -6.0...6.0)
        let dy = seededRandom(seed: seed &+ 2, range: -4.0...4.0)
        let rot = seededRandom(seed: seed &+ 3, range: -8.0...8.0)
        let appearDelay = min(Double(index) * 0.04, 0.6)
        return SlipView(
            note: note,
            color: palette[index % palette.count],
            tokenEmoji: tokenEmoji(for: note.tokenType),
            isSelected: selected == note.id,
            offsetX: dx,
            offsetY: dy,
            rotation: rot,
            appearDelay: appearDelay,
            onTap: {
                HapticManager.shared.light()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    selected = (selected == note.id) ? nil : note.id
                }
            }
        )
    }

    private func tokenEmoji(for type: String) -> String {
        switch type {
        case "heart": return "💗"
        case "leaf":  return "🌿"
        case "dino":  return "🦕"
        default:      return "🌿"
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("your keepsakes")
                .font(.custom(DinoTheme.customFontName, size: 22))
                .foregroundColor(Color(hex: "#4A3520"))
            Text("\(notes.count) notes")
                .font(.custom(DinoTheme.customFontName, size: 12))
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
            Text("your jar is empty 🫙")
                .font(.custom(DinoTheme.customFontName, size: 24))
                .foregroundColor(Color(hex: "#7A6F5F"))
            Text("add your first little joy")
                .font(.custom(DinoTheme.customFontName, size: 14))
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

private struct SlipView: View {
    let note: GratitudeNote
    let color: Color
    let tokenEmoji: String
    let isSelected: Bool
    let offsetX: Double
    let offsetY: Double
    let rotation: Double
    let appearDelay: Double
    let onTap: () -> Void

    @State private var visible: Bool = false

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: note.createdAt).lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Spacer()
                Text(tokenEmoji)
                    .font(.system(size: 18))
            }
            Text(note.text)
                .font(.custom(DinoTheme.customFontName, size: 16))
                .foregroundColor(Color(hex: "#2E2A24"))
                .multilineTextAlignment(.leading)
                .lineLimit(isSelected ? nil : 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Text(dateText)
                    .font(.custom(DinoTheme.customFontName, size: 11))
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
        .scaleEffect(isSelected ? 1.1 : (visible ? 1.0 : 0.85))
        .opacity(visible ? 1.0 : 0.0)
        .onTapGesture(perform: onTap)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(appearDelay)) {
                visible = true
            }
        }
        .zIndex(isSelected ? 100 : 0)
    }
}
