//
//  MascotView.swift
//  Dino
//
//  Mascot image with sage aura, breathing, random emotes, and tap response.
//  Gated by reduceMotion.
//

import SwiftUI

public struct MascotView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let imageName: String
    private let size: CGFloat

    @State private var emoteOffset: CGSize = .zero
    @State private var emoteRotation: Double = 0
    @State private var emoteScaleBoost: CGFloat = 0
    @State private var tapScale: CGFloat = 1
    @State private var emoteTimer: Timer? = nil

    public init(imageName: String, size: CGFloat = 180) {
        self.imageName = imageName
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let auraPhase = sin(t * 2 * .pi / 6.0)
            let auraScale: CGFloat = reduceMotion ? 1.0 : 1.0 + 0.04 * CGFloat(auraPhase + 1)
            let auraOpacity: Double = reduceMotion ? 0.35 : 0.35 + 0.1 * (auraPhase + 1)

            let breathePhase = sin(t * 2 * .pi / 4.5)
            let breatheScale: CGFloat = reduceMotion ? 1.0 : 1.0 + 0.02 * CGFloat(breathePhase)

            ZStack {
                // Aura
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#A8C5A0").opacity(0.35),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)
                    .scaleEffect(auraScale)
                    .opacity(auraOpacity)
                    .allowsHitTesting(false)

                // Mascot image
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .shadow(color: Color(hex: "#4A3520").opacity(0.18), radius: 12, x: 0, y: 6)
                    .scaleEffect(breatheScale * (1 + emoteScaleBoost) * tapScale)
                    .rotationEffect(.degrees(reduceMotion ? 0 : emoteRotation))
                    .offset(reduceMotion ? .zero : emoteOffset)
                    .onTapGesture { handleTap() }
            }
        }
        .onAppear { startEmoteTimer() }
        .onDisappear { emoteTimer?.invalidate(); emoteTimer = nil }
    }

    private func handleTap() {
        if reduceMotion {
            withAnimation(.linear(duration: 0.01)) { tapScale = 1.05 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                tapScale = 1.0
            }
            return
        }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) {
            tapScale = 0.98
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                tapScale = 1.12
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                tapScale = 1.0
            }
        }
    }

    private func startEmoteTimer() {
        guard !reduceMotion else { return }
        scheduleNextEmote()
    }

    private func scheduleNextEmote() {
        let interval = Double.random(in: 5...8)
        emoteTimer?.invalidate()
        emoteTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            playRandomEmote()
            scheduleNextEmote()
        }
    }

    private enum Emote: CaseIterable { case bob, sway, bounce, float }

    private func playRandomEmote() {
        guard !reduceMotion else { return }
        let choice = Emote.allCases.randomElement() ?? .bob
        switch choice {
        case .bob:
            // offset y 0 → -6 → 0 over 800ms
            withAnimation(.easeInOut(duration: 0.4)) { emoteOffset = CGSize(width: 0, height: -6) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.4)) { emoteOffset = .zero }
            }
        case .sway:
            withAnimation(.easeInOut(duration: 0.4)) { emoteRotation = -1.5 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.4)) { emoteRotation = 1.5 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.2)) { emoteRotation = 0 }
            }
        case .bounce:
            // scale 1→1.04→1.02→1 + y 0→-10→-4→0 over 700ms
            withAnimation(.easeOut(duration: 0.18)) {
                emoteScaleBoost = 0.04
                emoteOffset = CGSize(width: 0, height: -10)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeInOut(duration: 0.20)) {
                    emoteScaleBoost = 0.02
                    emoteOffset = CGSize(width: 0, height: -4)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.easeInOut(duration: 0.32)) {
                    emoteScaleBoost = 0
                    emoteOffset = .zero
                }
            }
        case .float:
            withAnimation(.easeInOut(duration: 0.27)) {
                emoteOffset = CGSize(width: 3, height: -4)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) {
                withAnimation(.easeInOut(duration: 0.27)) {
                    emoteOffset = CGSize(width: -3, height: -2)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
                withAnimation(.easeInOut(duration: 0.26)) {
                    emoteOffset = .zero
                }
            }
        }
    }
}
