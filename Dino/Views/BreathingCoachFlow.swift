//
//  BreathingCoachFlow.swift
//  Dino
//
//  The adaptive breathing entry: feeling → thinking → recommendation.
//  Reuses the pattern library, card styling, and session engine — this is
//  only the front door. The session NEVER auto-starts; every path (crisis
//  included) begins only from an explicit tap on the begin button.
//

import SwiftUI
import UIKit

struct BreathingCoachFlow: View {
    /// Hands the chosen pattern + minutes back to BreathingView, which drives
    /// the existing engine. Called only from the begin button.
    let onBegin: (BreathingPattern, Int) -> Void

    private enum Stage { case feeling, thinking, recommendation }

    @State private var stage: Stage = .feeling
    @State private var selectedChips: Set<BreathingFeeling> = []
    @State private var feelingText: String = ""
    @State private var rec: BreathingRecommendation?
    @State private var chosenPatternID: String = BreathingPattern.bigSigh.id
    @State private var chosenMinutes: Int = 5
    @State private var showAlternatives = false
    @FocusState private var textFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch stage {
            case .feeling: feelingScreen
            case .thinking: thinkingScreen
            case .recommendation: recommendationScreen
            }
        }
        .onAppear {
            #if DEBUG
            // Layout QA: render the crisis screen without typing crisis text.
            if ProcessInfo.processInfo.arguments.contains("-breathCrisisQA"), rec == nil {
                let qa = BreathingCoach.localRecommendation(chips: [.sad], text: "")
                    .raisingConcern(true)
                rec = qa
                chosenPatternID = qa.patternID
                chosenMinutes = qa.minutes
                stage = .recommendation
            }
            #endif
        }
    }

    // MARK: - Screen 1: feeling

    private var feelingScreen: some View {
        VStack(spacing: 18) {
            Text("how are you feeling right now?")
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(DinoTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(BreathingFeeling.allCases) { chip in
                    let selected = selectedChips.contains(chip)
                    Button {
                        HapticManager.shared.light()
                        if selected { selectedChips.remove(chip) } else { selectedChips.insert(chip) }
                    } label: {
                        Text(chip.label)
                            .font(DinoTheme.dinoFont(size: 15))
                            .foregroundColor(DinoTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                                    .fill(selected ? chip.accent.opacity(0.14) : DinoTheme.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                                    .stroke(selected ? chip.accent : DinoTheme.divider,
                                            lineWidth: selected ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            ZStack(alignment: .topLeading) {
                if feelingText.isEmpty {
                    Text("or tell dino in your words…")
                        .font(DinoTheme.inputFont(size: 15))
                        .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
                        .padding(.top, 12).padding(.leading, 12)
                }
                TextEditor(text: $feelingText)
                    .font(DinoTheme.inputFont(size: 15))
                    .foregroundColor(DinoTheme.textPrimary)
                    .focused($textFocused)
                    .frame(height: 84)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .onChange(of: feelingText) { _, v in
                        if v.count > 300 { feelingText = String(v.prefix(300)) }
                    }
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DinoTheme.sageGreen.opacity(0.25), lineWidth: 1))

            Button {
                Task { await find() }
            } label: {
                Text("find my breath 🌿")
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSubmit ? DinoTheme.sageGreen : DinoTheme.sageGreen.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusLG, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSubmit)
        }
        .padding(.bottom, 24)
    }

    private var canSubmit: Bool {
        !selectedChips.isEmpty ||
        !feelingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Screen 2: thinking

    private var thinkingScreen: some View {
        VStack(spacing: 20) {
            ThinkingDots(reduceMotion: reduceMotion)
                .padding(.top, 60)
            Text("finding the right breath for you…")
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(DinoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func find() async {
        textFocused = false
        let trimmed = feelingText.trimmingCharacters(in: .whitespacesAndNewlines)
        AnalyticsManager.shared.trackBreathingFeelingSubmitted(
            chipCount: selectedChips.count, hadText: !trimmed.isEmpty)
        withAnimation { stage = .thinking }

        let started = Date()
        let result = await BreathingCoachService.shared.recommend(
            chips: Array(selectedChips), text: feelingText)
        // let the moment breathe — even instant local answers pause ~1s
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < 1.0 {
            try? await Task.sleep(nanoseconds: UInt64((1.0 - elapsed) * 1_000_000_000))
        }

        rec = result
        chosenPatternID = result.patternID
        chosenMinutes = result.minutes
        AnalyticsManager.shared.trackBreathingAIRecommended(
            pattern: result.patternID, minutes: result.minutes, concern: result.concern)
        if result.concern {
            AnalyticsManager.shared.trackBreathingConcernShown()
        }
        withAnimation { stage = .recommendation }
    }

    // MARK: - Screen 3: recommendation

    @ViewBuilder private var recommendationScreen: some View {
        let recommendation = rec ?? BreathingCoach.localRecommendation(chips: [], text: "")
        let chosen = BreathingPattern.library.first { $0.id == chosenPatternID } ?? recommendation.pattern

        VStack(spacing: 16) {
            if recommendation.concern {
                crisisBlock
            } else {
                Text(recommendation.reason)
                    .font(DinoTheme.dinoFont(size: 17))
                    .foregroundColor(DinoTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }

            // the pattern: hero normally, quiet and secondary after crisis copy
            BreathingPatternCard(
                pattern: chosen,
                isSelected: true,
                reduceMotion: reduceMotion,
                onSelect: {}
            )
            .scaleEffect(recommendation.concern ? 0.94 : 1)
            .padding(.top, recommendation.concern ? 0 : 2)

            Button {
                withAnimation { showAlternatives.toggle() }
            } label: {
                Text(showAlternatives ? "keep dino's pick" : "try a different rhythm")
                    .font(DinoTheme.captionFont())
                    .foregroundColor(DinoTheme.textSecondary)
            }
            .buttonStyle(.plain)

            if showAlternatives {
                HStack(spacing: 8) {
                    ForEach(BreathingPattern.library.filter { $0.id != chosenPatternID }) { alt in
                        Button {
                            HapticManager.shared.light()
                            withAnimation { chosenPatternID = alt.id }
                        } label: {
                            Text(alt.shortName)
                                .font(DinoTheme.dinoFont(size: 12))
                                .foregroundColor(DinoTheme.textPrimary)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(Capsule().fill(alt.accent.opacity(0.10)))
                                .overlay(Capsule().stroke(alt.accent.opacity(0.6), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            durationTiles(recommended: recommendation.minutes)

            Button {
                HapticManager.shared.light()
                onBegin(chosen, chosenMinutes)
            } label: {
                Text("begin · \(chosenMinutes) min")
                    .font(DinoTheme.headlineFont())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DinoTheme.sageGreen)
                    .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusLG, style: .continuous))
                    .shadow(color: DinoTheme.sageGreen.opacity(0.3), radius: 8, y: 3)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                withAnimation {
                    stage = .feeling
                    rec = nil
                    showAlternatives = false
                }
            } label: {
                Text("start over")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
    }

    private func durationTiles(recommended: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(BreathingCoach.allowedMinutes, id: \.self) { m in
                let selected = m == chosenMinutes
                Button {
                    guard m != chosenMinutes else { return }
                    HapticManager.shared.light()
                    chosenMinutes = m
                    AnalyticsManager.shared.trackBreathingDurationAdjusted(minutes: m)
                } label: {
                    VStack(spacing: 2) {
                        Text(m == recommended ? "\(m) ⭐" : "\(m)")
                            .font(DinoTheme.numericFont(size: 16))
                            .foregroundColor(selected ? .white : DinoTheme.textPrimary)
                        Text("min")
                            .font(DinoTheme.dinoFont(size: 10))
                            .foregroundColor(selected ? .white.opacity(0.85) : DinoTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                            .fill(selected ? DinoTheme.sageGreen : DinoTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                            .stroke(selected ? DinoTheme.sageGreen : DinoTheme.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Crisis block (renders entirely from LOCAL data — never gated
    // on the network; detector #1 alone is enough to bring it here)

    private var crisisBlock: some View {
        VStack(spacing: 14) {
            Text(BreathingCrisisCopy.heading)
                .font(DinoTheme.dinoFont(size: 18))
                .foregroundColor(DinoTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Text(BreathingCrisisCopy.listeners)
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundColor(DinoTheme.textSecondary)

            ForEach(CrisisResource.usDefaults) { resource in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resource.title)
                            .font(DinoTheme.dinoFont(size: 16))
                            .foregroundColor(DinoTheme.textPrimary)
                        Text(resource.subtitle)
                            .font(DinoTheme.dinoFont(size: 12))
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    ForEach(resource.actions, id: \.label) { action in
                        Button {
                            AnalyticsManager.shared.trackBreathingResourceTapped(which: resource.id)
                            if let url = URL(string: action.url) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(action.label)
                                .font(DinoTheme.dinoFont(size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(Capsule().fill(DinoTheme.sageGreen))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                    .fill(Color.white.opacity(0.75)))
                .overlay(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                    .stroke(DinoTheme.sageGreen.opacity(0.35), lineWidth: 1))
            }

            Rectangle()
                .fill(DinoTheme.divider)
                .frame(height: 0.5)
                .padding(.horizontal, 40)
                .padding(.top, 4)

            Text(BreathingCrisisCopy.breathOffer)
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(DinoTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Thinking dots

private struct ThinkingDots: View {
    let reduceMotion: Bool
    @State private var on = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DinoTheme.sageGreen)
                    .frame(width: 12, height: 12)
                    .opacity(reduceMotion ? 0.7 : (on ? 1.0 : 0.25))
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: on
                    )
            }
        }
        .onAppear { on = true }
    }
}
