//
//  JarTokenView.swift
//  Dino
//
//  Phase 5 — v6 Gratitude Jar: a single keepsake token (dino / heart /
//  leaf) that renders inside the jar. On first appearance with
//  `isNewDrop == true` it plays a 4-phase drop animation (fall → settle
//  → overshoot → rest). After settling (or immediately when
//  `isNewDrop == false`) it idle-floats + gently sways.
//

import SwiftUI

struct JarTokenView: View {
    let assetName: String      // "jar-dino" | "jar-heart" | "jar-leaf"
    let indexInJar: Int         // for staggered float phase & jitter
    let totalInJar: Int         // for size scaling
    let isNewDrop: Bool         // true → play drop animation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Deterministic rotation jitter ±12° seeded by indexInJar
    private var jitterRot: Double {
        let seed = (indexInJar &* 2654435761) % 1000
        let norm = Double(seed) / 1000.0   // 0..1
        return (norm - 0.5) * 24.0          // -12..+12
    }

    private var size: CGFloat {
        totalInJar > 12 ? 36 : 48
    }

    private var floatDelay: Double {
        Double(indexInJar) * 0.1
    }

    // Drop animation phases: 0 = start (above jar), 1 = settled, 2 = overshoot, 3 = rest
    private enum DropPhase: Int, CaseIterable { case start, settle, overshoot, rest }

    var body: some View {
        Group {
            if reduceMotion {
                // Static at rest
                tokenImage
                    .rotationEffect(.degrees(jitterRot))
            } else if isNewDrop {
                // Drop animation via phaseAnimator (iOS 17+; target iOS 26)
                tokenImage
                    .phaseAnimator(DropPhase.allCases, trigger: true) { view, phase in
                        view
                            .opacity(phase == .start ? 0 : 1)
                            .offset(y: yOffset(for: phase))
                            .scaleEffect(scale(for: phase))
                            .rotationEffect(.degrees(rotation(for: phase)))
                    } animation: { phase in
                        switch phase {
                        case .start:     return .easeOut(duration: 0.001)
                        case .settle:    return .easeIn(duration: 0.66)
                        case .overshoot: return .easeOut(duration: 0.22)
                        case .rest:      return .easeInOut(duration: 0.22)
                        }
                    }
            } else {
                // Already settled — idle float + sway
                IdleFloatingToken(
                    content: tokenImage,
                    jitterRot: jitterRot,
                    delay: floatDelay
                )
            }
        }
        .frame(width: size, height: size)
    }

    private var tokenImage: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }

    // MARK: - Drop phase helpers

    private func yOffset(for phase: DropPhase) -> CGFloat {
        // Expressed in multiples of token size; negative = above rest position.
        switch phase {
        case .start:     return -size * 2.4
        case .settle:    return -size * 0.2
        case .overshoot: return  size * 0.1
        case .rest:      return  0
        }
    }

    private func scale(for phase: DropPhase) -> CGFloat {
        switch phase {
        case .start:     return 0.92
        case .settle:    return 1.0
        case .overshoot: return 1.02
        case .rest:      return 1.0
        }
    }

    private func rotation(for phase: DropPhase) -> Double {
        switch phase {
        case .start:     return 0
        case .settle:    return jitterRot
        case .overshoot: return jitterRot + 2
        case .rest:      return jitterRot
        }
    }
}

// MARK: - Idle floating token

private struct IdleFloatingToken<Content: View>: View {
    let content: Content
    let jitterRot: Double
    let delay: Double

    @State private var animating = false

    var body: some View {
        content
            .offset(y: animating ? -2 : 0)
            .rotationEffect(.degrees(jitterRot + (animating ? 1.5 : -1.5)))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 4.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    animating = true
                }
            }
    }
}
