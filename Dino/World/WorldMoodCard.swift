//
//  WorldMoodCard.swift
//  Dino
//
//  The mood screen's doorway into DINO WORLD — a lightweight 2D glowing orb
//  (no SceneKit here, deliberately) plus today's headline stat.
//

import SwiftUI

struct WorldMoodCard: View {
    let bucket: WorldDayBucket?
    let onTap: () -> Void

    @State private var pulse = false

    private let ink = Color(hex: "#3D3A35")
    private let ink2 = Color(hex: "#7A7266")
    private let peach = Color(hex: "#F5C6AA")

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                orb
                VStack(alignment: .leading, spacing: 3) {
                    Text("dino world")
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundColor(ink)
                    Text(headline)
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(ink2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ink2.opacity(0.6))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                    .fill(Color(hex: "#FEFBF3"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DinoDesignSystem.radiusMD, style: .continuous)
                    .stroke(peach.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
    }

    private var headline: String {
        guard let b = bucket, b.global.total > 0, let mood = b.global.dominantMood else {
            return "see everyone's inner weather 🌎"
        }
        let pct = Int((b.global.share(of: mood) * 100).rounded())
        return "\(pct)% of dinos are \(mood.label) today"
    }

    /// Tiny glowing globe: peach halo, cream sphere, 3 pulsing mood dots.
    private var orb: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [peach.opacity(0.55), peach.opacity(0)],
                                     center: .center, startRadius: 4, endRadius: 30))
                .frame(width: 58, height: 58)
            Circle()
                .fill(Color(hex: "#FAF6EC"))
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color(hex: "#E8E2D4"), lineWidth: 1))
            dot(color: DinoWorldPalette.moodSwiftUIColor(bucket?.global.dominantMood ?? .clear),
                offset: CGSize(width: -8, height: -6), delay: 0)
            dot(color: DinoWorldPalette.moodSwiftUIColor(.partlyCloudy),
                offset: CGSize(width: 9, height: 2), delay: 0.4)
            dot(color: DinoWorldPalette.moodSwiftUIColor(.drained),
                offset: CGSize(width: -1, height: 10), delay: 0.8)
        }
    }

    private func dot(color: Color, offset: CGSize, delay: Double) -> some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.9), radius: 3)
            .offset(offset)
            .scaleEffect(pulse ? 1.2 : 0.8)
            .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true).delay(delay), value: pulse)
    }
}
