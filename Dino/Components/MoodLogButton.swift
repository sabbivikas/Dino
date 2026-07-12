//
//  MoodLogButton.swift
//  Dino
//
//  The log button as a living thing: sage, breathing slowly while it waits
//  (3.2s — a resting pace, not a nag), the selected mood's glyph riding a
//  small paper token, and an honest muted face before any mood is chosen.
//  The adaptive line beneath comes from MoodButtonVoice (pure → tested).
//

import SwiftUI

/// pure strings — lowercase, zero dashes, no emoji (voice-tested)
enum MoodButtonVoice {
    static let heavyLine = "however it is, it counts"
    static let lightLine = "glad the sky is kind today"
    static let logLabel = "log this feeling"
    static let savedLabel = "saved"

    static func line(for mood: EmotionalWeather) -> String {
        switch mood {
        case .overwhelmed, .drained: return heavyLine
        case .clear, .partlyCloudy:  return lightLine
        }
    }

    static var allFixedStrings: [String] {
        [heavyLine, lightLine, logLabel, savedLabel]
    }
}

struct MoodLogButtonLabel: View {
    let selected: EmotionalWeather?
    let saved: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breath: CGFloat = 0

    private var enabled: Bool { selected != nil }
    private var breathing: Bool { enabled && !saved && !reduceMotion }

    var body: some View {
        HStack(spacing: 12) {
            if saved {
                DrawnCheck()
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 17, height: 17)
                Text(MoodButtonVoice.savedLabel)
            } else {
                if let mood = selected {
                    // the chosen weather rides a little paper token — the same
                    // colorful character as its card, in miniature
                    ZStack {
                        Circle().fill(Color(hex: "#FFFDF6"))
                        AnimatedWeatherIllustration(weather: mood, size: 26)
                    }
                    .frame(width: 34, height: 34)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                Text(MoodButtonVoice.logLabel)
            }
        }
        .font(DinoTheme.headlineFont())
        .foregroundColor(enabled || saved ? .white : Color(hex: "#7A7266"))
        .frame(maxWidth: .infinity)
        .frame(minHeight: 36)
        .padding(.vertical, 12)
        .background(
            enabled || saved
                ? DinoTheme.sageGreen
                // honest muted: clearly asleep, not a gray slab pretending
                : Color(hex: "#3D3A35").opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous))
        .shadow(
            color: breathing || saved
                ? DinoTheme.sageGreen.opacity(0.26 + 0.14 * breath)
                : .clear,
            radius: 8 + 6 * breath, y: 3
        )
        .scaleEffect(breathing ? 1.0 + 0.012 * breath : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: selected)
        .animation(.easeInOut(duration: 0.2), value: saved)
        .onAppear { startBreathingIfNeeded() }
        .onChange(of: enabled) { _, _ in startBreathingIfNeeded() }
    }

    private func startBreathingIfNeeded() {
        guard breathing else { breath = 0; return }
        breath = 0
        // 1.6s up + 1.6s back — the 3.2s resting cycle
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            breath = 1
        }
    }
}

/// a drawn check — two strokes, slightly past square
private struct DrawnCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.minY + rect.height * 0.58))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.06))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.12))
        return p
    }
}
