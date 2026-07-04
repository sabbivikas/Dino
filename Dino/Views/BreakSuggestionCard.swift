//
//  BreakSuggestionCard.swift
//  Dino
//
//  Break-finder v3 — conversational + cal.com style slot picker. Shown as a
//  sheet after a low mood is logged. States: intro (free-text) → loading →
//  suggestion (acknowledgment + activity + a grid of ALL available times, with
//  the AI's pick highlighted and pre-selected) → confirmed.
//

import SwiftUI

struct BreakSuggestionCard: View {
    let mood: EmotionalWeather
    let onDismiss: () -> Void

    private enum Stage { case intro, loading, suggestion, confirmed, alreadyToday }

    @State private var stage: Stage = .intro
    @State private var userText: String = ""
    @State private var suggestion: BreakSuggestion?
    @State private var selectedSlotID: UUID?
    @State private var confirmedTime: String = ""
    @State private var pulse = false
    @State private var sleepData: HealthService.SleepData?
    @FocusState private var textFocused: Bool

    // Palette
    private let cream = Color(hex: "#FAF6EC")
    private let ink = Color(hex: "#3D3A35")
    private let ink2 = Color(hex: "#7A7266")
    private let ink3 = Color(hex: "#A8A29A")
    private let sage = Color(hex: "#7BA872")
    private let sageDark = Color(hex: "#5E8A56")
    private let peach = Color(hex: "#F5C6AA")

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            ScrollView {
                content
                    .padding(.horizontal, 22)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .contentShape(Rectangle())
        .onTapGesture { textFocused = false }
        .task {
            // once per local day on the client — the server's 5/day stays as backstop
            if BreakSchedulerService.shared.usedToday { stage = .alreadyToday }
            if let s = await HealthService.shared.lastNightSleep() { sleepData = s }
        }
    }

    private var introHeadline: String {
        if let s = sleepData {
            if s.isVeryShort { return "you slept \(s.displayString) last night and today sounds heavy 🌧️" }
            if s.isShort { return "today sounds heavy — a lighter night doesn't help 🌧️" }
        }
        return "want to tell me what's going on?".localized
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .intro:        introView
        case .loading:      loadingView
        case .suggestion:   suggestionView
        case .confirmed:    confirmedView
        case .alreadyToday: alreadyTodayView
        }
    }

    // MARK: - Already used today

    private var alreadyTodayView: some View {
        VStack(spacing: 16) {
            Text("🌿").font(.system(size: 38))
            Text("dino already helped you find a break today")
                .font(DinoTheme.dinoFont(size: 20)).foregroundColor(ink)
                .multilineTextAlignment(.center)
            Text("tomorrow brings fresh time. your calendar break is still there 🌱")
                .font(DinoTheme.dinoFont(size: 14)).foregroundColor(ink2)
                .multilineTextAlignment(.center)
            Button { onDismiss() } label: {
                Text("okay")
                    .font(DinoTheme.dinoFont(size: 15)).foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().fill(sage))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - State 1: intro

    private var introView: some View {
        VStack(spacing: 16) {
            Text("🌿").font(.system(size: 38))
            Text(introHeadline)
                .font(DinoTheme.dinoFont(size: 22)).foregroundColor(ink)
                .multilineTextAlignment(.center)

            ZStack(alignment: .topLeading) {
                if userText.isEmpty {
                    Text("whatever's on your mind…".localized)
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

            primaryButton("send →".localized) { Task { await begin(userText) } }
            Button { Task { await begin("") } } label: {
                Text("skip →".localized).font(DinoTheme.dinoFont(size: 14)).foregroundColor(ink2)
            }
            Button { onDismiss() } label: {
                Text("maybe later".localized).font(DinoTheme.dinoFont(size: 13)).foregroundColor(ink3)
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
            Text("dino is thinking…".localized)
                .font(DinoTheme.dinoFont(size: 16)).foregroundColor(ink2)
        }
        .padding(.vertical, 30)
        .onAppear { pulse = true }
    }

    // MARK: - State 3: suggestion (cal.com grid)

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

                    Text("pick a time:".localized)
                        .font(DinoTheme.dinoFont(size: 13)).foregroundColor(ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(s.slots) { slotPill($0) }
                    }

                    primaryButton("yes, hold that time 🌿".localized, enabled: selectedSlotID != nil) {
                        Task { await confirm() }
                    }
                    Button { onDismiss() } label: {
                        Text("maybe later".localized).font(DinoTheme.dinoFont(size: 13)).foregroundColor(ink3)
                    }
                    privacyNote
                }
            }
        }
    }

    private func slotPill(_ slot: SlotOption) -> some View {
        let selected = selectedSlotID == slot.id
        let rec = slot.isRecommended
        return VStack(spacing: 3) {
            Button {
                selectedSlotID = selected ? nil : slot.id   // tap again to deselect
            } label: {
                Text(slot.displayTime)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(rec ? .white : ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(rec ? sage : Color.white.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? sageDark : (rec ? Color.clear : sage.opacity(0.3)),
                                lineWidth: selected ? 2.5 : 1))
                    .scaleEffect(selected ? 1.04 : 1.0)
            }
            .buttonStyle(.plain)
            Text(rec ? "✦ suggested".localized : "")
                .font(DinoTheme.dinoFont(size: 10)).foregroundColor(sage)
                .frame(height: 12)
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    private var emptySlotsView: some View {
        VStack(spacing: 14) {
            Text("your calendar looks full for now.".localized)
                .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink2)
                .multilineTextAlignment(.center)
            Text("try again a little later 🌿".localized)
                .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink2)
                .multilineTextAlignment(.center)
            Button { onDismiss() } label: {
                Text("maybe later".localized).font(DinoTheme.dinoFont(size: 13)).foregroundColor(ink3)
            }
        }
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
            Text("only you see this".localized).font(DinoTheme.dinoFont(size: 12)).foregroundColor(ink3)
        }
        .padding(.top, 2)
    }

    // MARK: - Flow

    private func begin(_ message: String) async {
        textFocused = false
        stage = .loading
        let analysis = RhythmsDataAdapter.currentAnalysis()
        guard let s = await BreakSchedulerService.shared.suggestBreak(
            mood: mood, userMessage: message, analysis: analysis) else {
            onDismiss(); return
        }
        suggestion = s
        // DinoMind: persist the GPT-extracted theme tag (enum only, no raw text).
        if ThemeTag.isValid(s.theme) {
            SharedDataManager.shared.recordThemeTag(
                theme: s.theme, mood: mood.rawValue, source: ThemeTag.sourceBreakFinder)
        }
        selectedSlotID = s.recommendedSlot?.id   // pre-select the AI's pick
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
