//
//  BreakSuggestionCard.swift
//  Dino
//
//  The gentle break-finder card, shown as a sheet after a low mood is logged
//  (or from the rhythms hard-day forecast). Standalone view — drives
//  BreakSchedulerService. Cream background, sage/peach accents, lowercase voice.
//  If there are no free slots / no calendar access, it degrades silently:
//  the UNAVAILABLE state simply dismisses without ever showing an error.
//

import SwiftUI

struct BreakSuggestionCard: View {
    let mood: EmotionalWeather
    var initialTargetDay: TargetDay = .today
    let onDismiss: () -> Void

    private enum Stage { case intro, loading, afterSevenChoice, suggestion, confirmed, unavailable }

    @State private var stage: Stage = .intro
    @State private var suggestion: BreakSuggestion?
    @State private var chosenDay: TargetDay = .today
    @State private var confirmedTime: String = ""
    @State private var pulse = false

    // Palette (Dino design system)
    private let cream = Color(hex: "#FAF6EC")
    private let card = Color(hex: "#FEFBF3")
    private let ink = Color(hex: "#3D3A35")
    private let ink2 = Color(hex: "#7A7266")
    private let ink3 = Color(hex: "#A8A29A")
    private let sage = Color(hex: "#7BA872")
    private let peach = Color(hex: "#F5C6AA")

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            content
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity)
        }
        // No async work on appear — the intro card shows instantly; calendar
        // access only happens after the user taps "yes, find me some time".
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .intro:            introView
        case .loading:          loadingView
        case .afterSevenChoice: afterSevenView
        case .suggestion:       suggestionView
        case .confirmed:        confirmedView
        case .unavailable:      Color.clear.onAppear { onDismiss() }
        }
    }

    // MARK: - States

    /// Warm intro — shown instantly after a low mood is logged. NO calendar
    /// access yet. Tapping "yes" is what kicks off begin().
    private var introView: some View {
        VStack(spacing: 16) {
            Image("DinoMascot")
                .resizable().scaledToFit()
                .frame(width: 76, height: 76)
            Text(introHeadline)
                .font(DinoTheme.dinoFont(size: 22)).foregroundColor(ink)
                .multilineTextAlignment(.center)
            Text("want me to find you a quiet moment to breathe?")
                .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink2)
                .multilineTextAlignment(.center).lineSpacing(3)
            Button {
                Task { await begin() }
            } label: {
                Text("yes, find me some time")
                    .font(DinoTheme.dinoFont(size: 17)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(sage))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 4)
            maybeLater
        }
    }

    private var introHeadline: String {
        switch mood {
        case .drained:     return "today sounds heavy 🌧️"
        case .overwhelmed: return "sounds like a lot today 🌿"
        default:           return "today sounds like a lot 🌿"
        }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(sage.opacity(0.18))
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: "leaf.fill").font(.system(size: 22)).foregroundColor(sage))
                .scaleEffect(pulse ? 1.08 : 0.92)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
            Text("dino is checking your calendar…")
                .font(DinoTheme.dinoFont(size: 16)).foregroundColor(ink2)
        }
        .onAppear { pulse = true }
    }

    private var afterSevenView: some View {
        VStack(spacing: 18) {
            Text("today's almost over.")
                .font(DinoTheme.dinoFont(size: 22)).foregroundColor(ink)
            Text("want time tonight, or first thing tomorrow?")
                .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink2)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                choiceButton("tonight", fill: peach) { Task { await choose(.tonight) } }
                choiceButton("tomorrow morning", fill: sage.opacity(0.85)) { Task { await choose(.tomorrow) } }
            }
            .padding(.top, 4)
            maybeLater
        }
    }

    private var suggestionView: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(peach.opacity(0.25))
                .frame(width: 60, height: 60)
                .overlay(Text("🌿").font(.system(size: 28)))

            Text("you have some time at \(slotTimeText)")
                .font(DinoTheme.dinoFont(size: 21)).foregroundColor(ink)
                .multilineTextAlignment(.center).lineSpacing(2)

            if let reason = suggestion?.reason {
                Text(reason)
                    .font(DinoTheme.dinoFont(size: 15)).foregroundColor(ink2)
                    .multilineTextAlignment(.center).lineSpacing(3)
            }

            Text("\(suggestion?.duration ?? 20) min")
                .font(DinoTheme.dinoFont(size: 12)).foregroundColor(sage)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(sage.opacity(0.14)))

            Button { Task { await confirm() } } label: {
                Text("yes, hold that time 🌿")
                    .font(DinoTheme.dinoFont(size: 17)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(sage))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 4)

            maybeLater
            privacyNote
        }
    }

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
    }

    // MARK: - Shared bits

    private var maybeLater: some View {
        Button { onDismiss() } label: {
            Text("maybe later").font(DinoTheme.dinoFont(size: 14)).foregroundColor(ink3)
        }
        .padding(.top, 2)
    }

    private var privacyNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 10)).foregroundColor(ink3)
            Text("only you see this").font(DinoTheme.dinoFont(size: 12)).foregroundColor(ink3)
        }
        .padding(.top, 2)
    }

    private func choiceButton(_ title: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DinoTheme.dinoFont(size: 15)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var slotTimeText: String {
        guard let s = suggestion else { return "" }
        return BreakSchedulerService.shared.timeLabel(s.slotStart, .current)
    }

    // MARK: - Flow

    private func begin() async {
        stage = .loading   // show "checking your calendar…" while access + lookup run
        chosenDay = initialTargetDay
        let date = initialTargetDay == .tomorrow ? tomorrow() : Date()
        guard let s = await BreakSchedulerService.shared.suggestBreak(
            mood: mood, forDate: date) else {
            stage = .unavailable
            return
        }
        suggestion = s
        stage = (s.isAfter7pm && initialTargetDay == .today) ? .afterSevenChoice : .suggestion
    }

    private func choose(_ day: TargetDay) async {
        chosenDay = day
        if day == .tonight {
            stage = .suggestion   // keep the already-found today suggestion
            return
        }
        stage = .loading
        guard let s = await BreakSchedulerService.shared.suggestBreak(
            mood: mood, forDate: tomorrow()) else {
            stage = .unavailable
            return
        }
        suggestion = s
        stage = .suggestion
    }

    private func confirm() async {
        guard let s = suggestion else { onDismiss(); return }
        HapticManager.shared.success()
        let ok = await BreakSchedulerService.shared.confirmBreak(s, targetDay: chosenDay)
        guard ok else { onDismiss(); return }
        confirmedTime = BreakSchedulerService.shared.timeLabel(s.slotStart, .current)
        stage = .confirmed
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        onDismiss()
    }

    private func tomorrow() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
}
