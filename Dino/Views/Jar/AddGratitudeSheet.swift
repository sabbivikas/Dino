//
//  AddGratitudeSheet.swift
//  Dino
//
//  Phase 5 — v6 Gratitude Jar: redesigned bottom-sheet composer that
//  replaces the in-view sheet previously inside `GratitudeJarView.swift`.
//  Preserves the existing call-site contract `AddGratitudeSheet(viewModel:onSaved:)`
//  and the existing ViewModel save flow (`viewModel.addNote()`).
//

import SwiftUI

enum JarTokenKind: String, CaseIterable, Identifiable {
    case dino, heart, leaf
    var id: String { rawValue }

    var assetName: String {
        switch self {
        case .dino:  return "jar-dino"
        case .heart: return "jar-heart"
        case .leaf:  return "jar-leaf"
        }
    }

    var label: String {
        switch self {
        case .dino:  return "dino"
        case .heart: return "heart"
        case .leaf:  return "leaf"
        }
    }
}

struct AddGratitudeSheet: View {
    @ObservedObject var viewModel: GratitudeViewModel
    var onSaved: (() -> Void)? = nil

    @FocusState private var focused: Bool
    @State private var selectedTokenType: JarTokenKind = .dino

    private var trimmed: String {
        viewModel.newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmpty: Bool { trimmed.isEmpty }

    var body: some View {
        VStack(spacing: 16) {
            // Drag handle
            Capsule()
                .fill(Color(hex: "#4A3520").opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            // Title
            Text("what made you smile?")
                .font(.custom(DinoTheme.customFontName, size: 18))
                .foregroundColor(DinoTheme.ink)
                .padding(.top, 8)

            // TextEditor with placeholder overlay
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#4A3520").opacity(0.18), lineWidth: 1.2)
                    )

                if viewModel.newNoteText.isEmpty {
                    Text("today I'm grateful for…")
                        .font(.custom(DinoTheme.customFontName, size: 16))
                        .italic()
                        .foregroundColor(DinoTheme.obPlaceholder)
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.newNoteText)
                    .font(.custom(DinoTheme.customFontName, size: 16))
                    .foregroundColor(DinoTheme.ink)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .onChange(of: viewModel.newNoteText) { _, val in
                        if val.count > 200 {
                            viewModel.newNoteText = String(val.prefix(200))
                        }
                    }
            }
            .frame(minHeight: 120)

            // Token type selector
            HStack(spacing: 12) {
                ForEach(JarTokenKind.allCases) { kind in
                    tokenChip(kind)
                }
            }

            // Submit button
            Button(action: submit) {
                Text("drop it in ↓")
                    .font(.custom(DinoTheme.customFontName, size: 17))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isEmpty
                                  ? DinoTheme.streakSage.opacity(0.4)
                                  : DinoTheme.streakSage)
                    )
                    .shadow(
                        color: DinoTheme.streakSage.opacity(isEmpty ? 0 : 0.40),
                        radius: 12, x: 0, y: 4
                    )
            }
            .buttonStyle(.plain)
            .disabled(isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear { focused = true }
    }

    private func tokenChip(_ kind: JarTokenKind) -> some View {
        let isSelected = selectedTokenType == kind
        return Button {
            selectedTokenType = kind
        } label: {
            VStack(spacing: 6) {
                Image(kind.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(kind.label)
                    .font(.custom(DinoTheme.customFontName, size: 13))
                    .foregroundColor(DinoTheme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? DinoTheme.streakSage : Color(hex: "#4A3520").opacity(0.12),
                        lineWidth: isSelected ? 1.8 : 1.0
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        guard !isEmpty else { return }
        HapticManager.shared.success()
        viewModel.addNote(tokenType: selectedTokenType.rawValue)
        onSaved?()
    }
}
