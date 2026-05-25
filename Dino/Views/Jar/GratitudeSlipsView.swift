//
//  GratitudeSlipsView.swift
//  Dino
//
//  v10 — full-screen scattered pastel slips for every saved gratitude
//  note. Presented when the user taps the jar in `GratitudeJarView`.
//

import SwiftUI

struct GratitudeSlipsView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID? = nil

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
                    LazyVStack(spacing: -20) {
                        ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                            slipCard(note: note, index: idx)
                                .padding(.leading, slipLeadingPadding(for: idx))
                                .padding(.trailing, slipTrailingPadding(for: idx))
                        }
                    }
                    .padding(.top, 80)
                    .padding(.bottom, 60)
                }
                .scrollIndicators(.hidden)
            }

            header
        }
    }

    private func slipCard(note: GratitudeNote, index: Int) -> some View {
        let appearDelay = min(Double(index) * 0.04, 0.6)
        return SlipView(
            note: note,
            tilt: deterministicTilt(for: note.id),
            color: slipColor(for: index),
            tokenEmoji: tokenEmoji(for: note.tokenType),
            isSelected: selected == note.id,
            appearDelay: appearDelay,
            onTap: {
                HapticManager.shared.light()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    selected = (selected == note.id) ? nil : note.id
                }
            }
        )
    }

    private func slipColor(for index: Int) -> Color {
        let palette: [Color] = [
            Color(hex: "#F5C6AA"),
            Color(hex: "#C4B8D4"),
            Color(hex: "#A8D4E6"),
            Color(hex: "#A8C5A0"),
            Color(hex: "#E8B4B8")
        ]
        return palette[index % palette.count].opacity(0.85)
    }

    private func deterministicTilt(for id: UUID) -> Double {
        let hash = abs(id.hashValue)
        return Double(hash % 240) / 10.0 - 12.0
    }

    private func slipLeadingPadding(for index: Int) -> CGFloat {
        let offsets: [CGFloat] = [24, 60, 16, 44, 32, 20, 52]
        return offsets[index % offsets.count]
    }

    private func slipTrailingPadding(for index: Int) -> CGFloat {
        let offsets: [CGFloat] = [52, 20, 44, 16, 60, 32, 24]
        return offsets[index % offsets.count]
    }

    private func tokenEmoji(for type: String) -> String {
        switch type {
        case "heart": return "💗"
        case "leaf":  return "🌿"
        case "dino":  return "🦕"
        default:      return "🌿"
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("your keepsakes")
                    .font(.custom(DinoTheme.customFontName, size: 22))
                    .foregroundColor(Color(hex: "#4A3520"))
                Text("\(notes.count) little joys")
                    .font(.custom(DinoTheme.customFontName, size: 13))
                    .italic()
                    .foregroundColor(Color(hex: "#7A6F5F"))
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#7A6F5F"))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(hex: "#F5F0E8")))
                    .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
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

private struct SlipView: View {
    let note: GratitudeNote
    let tilt: Double
    let color: Color
    let tokenEmoji: String
    let isSelected: Bool
    let appearDelay: Double
    let onTap: () -> Void

    @State private var visible: Bool = false

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: note.createdAt).lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(note.text)
                    .font(.custom(DinoTheme.customFontName, size: 15))
                    .foregroundColor(Color(hex: "#2E2A24"))
                    .multilineTextAlignment(.leading)
                    .lineLimit(isSelected ? nil : 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(tokenEmoji)
                    .font(.system(size: 18))
            }
            HStack {
                Spacer()
                Text(dateText)
                    .font(.custom(DinoTheme.customFontName, size: 11))
                    .italic()
                    .foregroundColor(Color(hex: "#2E2A24").opacity(0.55))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .rotationEffect(.degrees(tilt))
        .scaleEffect(isSelected ? 1.08 : (visible ? 1.0 : 0.85))
        .opacity(visible ? 1.0 : 0.0)
        .offset(y: visible ? 0 : -20)
        .onTapGesture(perform: onTap)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(appearDelay)) {
                visible = true
            }
        }
        .zIndex(isSelected ? 100 : 0)
    }
}
