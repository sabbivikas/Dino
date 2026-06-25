//
//  BreakSuggestionCard.swift
//  Dino
//
//  Break-finder v2 — conversational. Shown as a sheet after a low mood is logged.
//  Four states: intro (free-text “what's going on?”) → loading → suggestion
//  (acknowledgment + suggested activity + slot picker) → confirmed.
//  Cream background, sage/peach accents, lowercase. The text field is optional
//  — skip is always one tap away. The user's text is sent to the cloud function
//  only (never logged, never stored).
//

import SwiftUI

struct BreakSuggestionCard: View {
    let mood: EmotionalWeather
    let onDismiss: () -> Void

    private enum Stage { case intro, loading, suggestion, confirmed }

    @State private var stage: Stage = .intro
    @State private var userText: String = ""
    @State private var lastMessage: String = ""
    @State private var suggestion: BreakSuggestion?
    @State private var selectedSlotID: UUID?
    @State private var confirmedTime: String = ""
    @State private var triedTomorrow = false
    @State private var pulse = false
    @FocusState private var textFocused: Bool

    // Palette
    private let cream = Color(hex: "#FAF6EC")
    private let ink = Color(hex: "#3D3A35")
    private let ink2 = Color(hex: "#7A7266")
    private let ink3 = Color(hex: "#A8A29A")
    private let sage = Color(hex: "#7BA872")
    private let peach = Color(hex: "#F5C6AA")

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            ScrollView {
                content
                    .padding(.horizontal, 26)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .contentShape(Rectangle())
        .onTapGesture { textFocused = false }   // tap outside → dismiss keyboard
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .intro:      introView
        case .loading:    loadingView
        case .suggestion: suggestionView
        case .confirmed:  confirmedView
        }
    }

    // MARK: - State 1: intro (free text)

    private var introView: some View {
        VStack(spacing: 16) {
            Text("🌿").font(.system(size: 38))
            Text("want to tell me what's going on?")
                .font(DinoTheme.dinoFont(size: 22)).foregroundColor(ink)
                .multilineTextAlignment(.center)

            ZStack(alignment: .topLeading) {
                if userText.isEmpty {
                    Text("whatever's on your mind…")
                        .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink3)
                        .padding(.top, 12).padding(.leading, 12)
                }
                TextEditor(text: $userText)
                    .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink)
                    .focused($textFocused)
                    .frame(height: 92)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .onChange(of: userText) { _, v in
                        if v.count > 200 { userText = String(v.prefix(200)) }
                    }
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(sage.opacity(0.25), lineWidth: 1))

            primaryButton("send →") { Task { await begin(userText) } }

            Button { Task { await begin("") } } label: {
                Text("skip →").font(DinoTheme.dinoFont(size: 14)).foregroundColor(ink2)
            }
            Button { onDismiss() } label: {
                Text("maybe later").font(DinoTheme.dinoFont(size: 13)).foregroundColor(ink3)
            }
        }
    }

    // MARK: - State 2: loading

    private var loadingView: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(sage.opacity(0.18))
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: "leaf.fill").font(.system(size: 22)).foregroundColor(sage))
                .scaleEffect(pulse ? 1.08 : 0.92)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
            Text("dino is thinking…")
                .font(DinoTheme.dinoFont(size: 16)).foregroundColor(ink2)
        }
        .padding(.vertical, 30)
        .onAppear { pulse = true }
    }

    // MARK: - State 3: suggestion

    private var suggestionView: some View {
        VStack(spacing: 16) {
            if let s = suggestion {
                Text(s.acknowledgment)
                    .font(DinoTheme.dinoFont(size: 21)).foregroundColor(ink)
                    .multilineTextAlignment(.center).lineSpacing(2)

                if s.slots.isEmpty {
                    emptySlotsView
                } else {
                    Text("i think \(s.suggestedActivity) would help —")
                        .font(DinoTheme.dinoFont(size: 16)).foregroundColor(ink)
                        .multilineTextAlignment(.center)
                    Text(s.reason)
                        .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink2)
                        .multilineTextAlignment(.center).lineSpacing(3)

                    Text("here are some quiet moments:")
                        .font(DinoTheme.dinoFont(size: 13)).foregroundColor(ink3)
                        .padding(.top, 4)

                    VStack(spacing: 10) {
                        ForEach(s.slots) { slot in slotRow(slot) }
                    }

                    primaryButton("yes, hold that time 🌿", enabled: selectedSlotID != nil) {
                        Task { await confirm() }
                    }
                    Button { onDismiss() } label: {
                        Text("maybe later").font(DinoTheme.dinoFont(size: 13)).foregroundColor(ink3)
                    }
                    privacyNote
                }
            }
        }
    }

    private var emptySlotsView: some View {
        VStack(spacing: 14) {
            Text("your calendar looks full today.")
                .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink2)
                .multilineTextAlignment(.center)
            if !triedTomorrow {
                Text("want me to find time tomorrow instead?")
                    .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink2)
                    .multilineTextAlignment(.center)
                primaryButton("find tomorrow") { Task { await beginTomorrow() } }
            }
            Button { onDismiss() } label: {
                Text("maybe later").font(DinoTheme.dinoFont(size: 13)).foregroundColor(ink3)
            }
        }
    }

    private func slotRow(_ slot: SlotOption) -> some View {
        let selected = selectedSlotID == slot.id
        return Button {
            selectedSlotID = slot.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18)).foregroundColor(selected ? sage : ink3)
                Text(slot.displayTime)
                    .font(DinoTheme.dinoFont(size: 16)).foregroundColor(ink)
                Text("· \(slot.duration) min")
                    .font(DinoTheme.dinoFont(size: 14)).foregroundColor(ink2)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? sage.opacity(0.14) : Color.white.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? sage.opacity(0.6) : sage.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - State 4: confirmed

    private var confirmedView: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(sage.opacity(0.18))
                .frame(width: 60, height: 60)
                .overlay(Image(systemName: "checkmark").font(.system(size: 26, weight: .semibold)).foregroundColor(sage))
            Text("done. i'll remind you at \(confirmedTime) 🌱")
                .font(DinoTheme.dinoFont(size: 18)).foregroundColor(ink)
                .multilineTextAlignment(.center).lineSpacing(2)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Shared

    private func primaryButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DinoTheme.dinoFont(size: 17)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(enabled ? sage : sage.opacity(0.4)))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    private var privacyNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 10)).foregroundColor(ink3)
            Text("only you see this").font(DinoTheme.dinoFont(size: 12)).foregroundColor(ink3)
        }
        .padding(.top, 2)
    }

    // MARK: - Flow

    private func begin(_ message: String) async {
        textFocused = false
        lastMessage = message
        stage = .loading
        let analysis = RhythmsDataAdapter.currentAnalysis()
        guard let s = await BreakSchedulerService.shared.suggestBreak(
            mood: mood, userMessage: message, analysis: analysis) else {
            onDismiss(); return
        }
        suggestion = s
        selectedSlotID = nil
        stage = .suggestion
    }

    private func beginTomorrow() async {
        triedTomorrow = true
        stage = .loading
        let analysis = RhythmsDataAdapter.currentAnalysis()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        guard let s = await BreakSchedulerService.shared.suggestBreak(
            mood: mood, userMessage: lastMessage, analysis: analysis, forDate: tomorrow) else {
            onDismiss(); return
        }
        suggestion = s
        selectedSlotID = nil
        stage = .suggestion
    }

    private func confirm() async {
        guard let s = suggestion,
              let slot = s.slots.first(where: { $0.id == selectedSlotID }) else { return }
        HapticManager.shared.success()
        let ok = await BreakSchedulerService.shared.confirmBreak(slot: slot, suggestion: s)
        guard ok else { onDismiss(); return }
        confirmedTime = slot.displayTime
        stage = .confirmed
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        onDismiss()
    }
}
