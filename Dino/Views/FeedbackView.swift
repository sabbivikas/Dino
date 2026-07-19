//
//  FeedbackView.swift
//  Dino
//

import SwiftUI
import FirebaseAuth

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    @State private var selectedCategory: FeedbackCategory = .bug
    @State private var text: String = ""
    @State private var state: FeedbackState = .idle

    private let bg = Color(hex: "#FAF6EC")
    private let ink = Color(hex: "#3D3A35")
    private let muted = Color(hex: "#7A7266")
    private let sage = Color(hex: "#A8C5A0")
    private let sageBorder = Color(hex: "#E8E4D5")
    private let paper = Color(hex: "#FEFBF3")
    private let pillBorder = Color(red: 60/255, green: 55/255, blue: 50/255, opacity: 0.16)

    private let maxChars = 500

    private enum FeedbackState: Equatable {
        case idle
        case sending
        case success
        case failure(String)
    }

    enum FeedbackCategory: String, CaseIterable, Identifiable {
        case bug, suggestion, love, help
        var id: String { rawValue }
        var label: String {
            switch self {
            case .bug: return String(localized: "🐛 bug")
            case .suggestion: return String(localized: "💡 suggestion")
            case .love: return String(localized: "❤️ love note")
            case .help: return String(localized: "🆘 help")
            }
        }
        var backendId: String {
            switch self {
            case .bug: return "bug_report"
            case .suggestion: return "suggestion"
            case .love: return "love_note"
            case .help: return "need_help"
            }
        }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            switch state {
            case .success:
                successView
            default:
                formView
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("send us a note 🦕")
                        .font(DinoTheme.dinoFont(size: 24))
                        .foregroundColor(ink)

                    Text("we read every message")
                        .font(DinoTheme.serifFont(size: 13).italic())
                        .foregroundColor(muted)

                    categoryPills

                    messageEditor

                    HStack {
                        Text("your message comes from \(authManager.currentUser?.email ?? String(localized: "anonymous"))")
                            .font(DinoTheme.dinoFont(size: 11))
                            .foregroundColor(muted)
                        Spacer()
                    }

                    if case .failure(let msg) = state {
                        Text(msg)
                            .font(DinoTheme.dinoFont(size: 12))
                            .foregroundColor(Color(hex: "#B85C5C"))
                    }

                    sendButton
                        .padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(muted)
                    .padding(8)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FeedbackCategory.allCases) { cat in
                    CategoryPill(
                        label: cat.label,
                        active: selectedCategory == cat,
                        activeBG: ink,
                        bg: bg,
                        inactiveText: muted,
                        border: pillBorder
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = cat }
                    }
                }
            }
        }
    }

    private var messageEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(sageBorder, lineWidth: 1)
                )

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 150)
                .foregroundColor(ink)
                .font(.system(size: 15))
                .onChange(of: text) { _, newValue in
                    if newValue.count > maxChars {
                        text = String(newValue.prefix(maxChars))
                    }
                }

            if text.isEmpty {
                Text("what's on your mind?")
                    .font(.system(size: 15))
                    .foregroundColor(muted.opacity(0.7))
                    .padding(.horizontal, 17)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("\(text.count)/\(maxChars)")
                        .font(DinoTheme.numericFont(size: 11))
                        .foregroundColor(muted)
                        .padding(.trailing, 12)
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(minHeight: 150)
    }

    private var sendButton: some View {
        Button {
            send()
        } label: {
            HStack(spacing: 8) {
                if state == .sending {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("send it →")
                        .font(DinoTheme.dinoFont(size: 16))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(sage))
            .opacity(canSend ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
    }

    private var canSend: Bool {
        guard state != .sending else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && text.count <= maxChars
    }

    private func send() {
        state = .sending
        let category = selectedCategory.backendId
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await FeedbackService.shared.submitFeedback(category: category, message: message)
                await MainActor.run { state = .success }
            } catch {
                await MainActor.run {
                    state = .failure(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("got it! we'll be in touch 🌿")
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            dismiss()
        }
    }
}

// MARK: - CategoryPill

private struct CategoryPill: View {
    let label: String
    let active: Bool
    let activeBG: Color
    let bg: Color
    let inactiveText: Color
    let border: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DinoTheme.dinoFont(size: 14))
                .tracking(0.14)
                .foregroundColor(active ? bg : inactiveText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(active ? activeBG : Color.clear))
                .overlay(Capsule().strokeBorder(active ? activeBG : border, lineWidth: 1))
                .fixedSize()
        }
        .buttonStyle(.plain)
    }
}
