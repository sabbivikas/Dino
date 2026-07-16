//
//  LanternComposeView.swift
//  Dino
//
//  Compose + send a lantern. 140 chars, three tap-to-use phrases, a clear
//  disclosure that dino reads every lantern, honest reject copy with a rewrite
//  path (the user's words are never silently rewritten), and the release
//  ceremony on approval.
//

import SwiftUI

struct LanternComposeView: View {
    let onDismiss: () -> Void

    private enum Stage { case compose, sending, ceremony }

    @State private var stage: Stage = .compose
    @State private var text = ""
    @State private var notice: String?
    @FocusState private var focused: Bool

    private let cream = Color(hex: "#FAF6EC")
    private let ink = Color(hex: "#3D3A35")
    private let ink2 = Color(hex: "#7A7266")
    private let ink3 = Color(hex: "#A8A29A")
    private let sage = Color(hex: "#7BA872")
    private let peach = Color(hex: "#F5C6AA")

    var body: some View {
        ZStack {
            if stage == .ceremony {
                LanternCeremonyView(words: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    onDismiss()
                }
                .transition(.opacity)
            } else {
                composeBody
            }
        }
        .animation(.easeInOut(duration: 0.5), value: stage == .ceremony)
        .onAppear { AnalyticsManager.shared.trackLanternComposed() }
    }

    private var composeBody: some View {
        ZStack {
            cream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text("🏮").font(.system(size: 40)).padding(.top, 18)
                    Text("send a lantern to someone having a hard day")
                        .font(.custom(DinoTheme.customFontName, size: 22))
                        .foregroundColor(ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("something kind…")
                                .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink3)
                                .padding(.top, 12).padding(.leading, 12)
                        }
                        TextEditor(text: $text)
                            .font(DinoTheme.inputFont(size: 15)).foregroundColor(ink)
                            .focused($focused)
                            .frame(height: 96)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .onChange(of: text) { _, v in
                                if v.count > LanternService.maxChars { text = String(v.prefix(LanternService.maxChars)) }
                            }
                    }
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.65)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(peach.opacity(0.5), lineWidth: 1))
                    .padding(.horizontal, 22)

                    Text("\(text.count)/\(LanternService.maxChars)")
                        .font(DinoTheme.dinoFont(size: 11)).foregroundColor(ink3)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 26)

                    // tap-to-use phrases
                    VStack(spacing: 8) {
                        ForEach(LanternService.suggestions, id: \.self) { phrase in
                            Button {
                                HapticManager.shared.light()
                                text = phrase
                            } label: {
                                Text(phrase)
                                    .font(DinoTheme.dinoFont(size: 13))
                                    .foregroundColor(ink2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.5)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)

                    if let notice {
                        Text(notice)
                            .font(DinoTheme.dinoFont(size: 13))
                            .foregroundColor(ink2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                            .transition(.opacity)
                    }

                    Button {
                        Task { await send() }
                    } label: {
                        HStack(spacing: 8) {
                            if stage == .sending { ProgressView().tint(.white) }
                            Text(stage == .sending ? String(localized: "dino is reading it…") : String(localized: "let it fly 🏮"))
                        }
                        .font(DinoTheme.dinoFont(size: 16)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(canSend ? sage : sage.opacity(0.4)))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canSend)
                    .padding(.horizontal, 22)

                    Button { onDismiss() } label: {
                        Text("maybe later").font(DinoTheme.dinoFont(size: 13)).foregroundColor(ink3)
                    }

                    Text("dino reads every lantern before it flies. only kind ones travel.")
                        .font(DinoTheme.dinoFont(size: 11))
                        .foregroundColor(ink3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var canSend: Bool {
        stage == .compose && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() async {
        focused = false
        withAnimation { notice = nil }
        stage = .sending
        let result = await LanternService.sendLantern(text: text)
        switch result {
        case .approved:
            HapticManager.shared.success()
            stage = .ceremony
        case .rejected:
            stage = .compose
            withAnimation {
                notice = String(localized: "dino couldn't carry this one 🦕 lanterns only travel when they're gentle. want to rewrite it?")
            }
        case .limitReached:
            stage = .compose
            withAnimation { notice = String(localized: "dino's pouch is empty for today. three lanterns a day 🏮") }
        case .failed:
            stage = .compose
            withAnimation { notice = String(localized: "the wind isn't right just now. try again in a moment 🌬️") }
        }
    }
}
