//
//  WorldConstellation.swift
//  Dino
//
//  "lights around the world" as a sky, not a scoreboard: country names float
//  in a centered cloud, tinted by their dominant mood, sized and glowing by
//  volume on a sqrt curve — no rows, no ranks, no digits. One warm total
//  carries the number; a tap on any name reveals its count in a quiet bubble.
//  Order is a stable shuffle seeded by the day key, so the sky drifts gently
//  from one day to the next. Breathing stills under Reduce Motion.
//

import SwiftUI

// MARK: - Voice (pure → tested; lowercase, zero dashes)

enum WorldConstellationVoice {
    static func totalLine(total: Int, isToday: Bool) -> String {
        switch (total == 1, isToday) {
        case (true, true):   return String(localized: "1 feeling shared today")
        case (false, true):  return String(localized: "\(total) feelings shared today")
        case (true, false):  return String(localized: "1 feeling shared this day")
        case (false, false): return String(localized: "\(total) feelings shared this day")
        }
    }

    static func subLine(countries: Int) -> String {
        countries == 1
            ? String(localized: "across 1 country, under one sky \u{1F30D}")
            : String(localized: "across \(countries) countries, under one sky \u{1F30D}")
    }

    static func bubbleLine(count: Int, isToday: Bool) -> String {
        switch (count == 1, isToday) {
        case (true, true):   return String(localized: "1 dino under this sky tonight")
        case (false, true):  return String(localized: "\(count) dinos under this sky tonight")
        case (true, false):  return String(localized: "1 dino was under this sky")
        case (false, false): return String(localized: "\(count) dinos were under this sky")
        }
    }

    static var allFixedStrings: [String] {
        [totalLine(total: 1, isToday: true), totalLine(total: 7, isToday: true),
         totalLine(total: 1, isToday: false), totalLine(total: 7, isToday: false),
         subLine(countries: 1), subLine(countries: 9),
         bubbleLine(count: 1, isToday: true), bubbleLine(count: 9, isToday: true),
         bubbleLine(count: 1, isToday: false), bubbleLine(count: 9, isToday: false)]
    }
}

// MARK: - Math (pure → tested)

enum WorldConstellationMath {
    /// sqrt presence curve — 0 at the day's min, 1 at its max; flat days sit mid.
    static func presence(count: Int, minCount: Int, maxCount: Int) -> Double {
        guard maxCount > minCount else { return 0.5 }
        let clamped = Double(max(min(count, maxCount), minCount))
        return ((clamped - Double(minCount)) / Double(maxCount - minCount)).squareRoot()
    }

    /// 13pt floor (small countries clearly present) → 28pt cap (never blinding)
    static func fontSize(_ presence: Double) -> CGFloat {
        13 + 15 * CGFloat(presence)
    }

    /// glow opacity 0.18 → 0.55, radius 3 → 10 — same curve as the type
    static func glowOpacity(_ presence: Double) -> Double { 0.18 + 0.37 * presence }
    static func glowRadius(_ presence: Double) -> CGFloat { 3 + 7 * CGFloat(presence) }

    /// ±(0.5...1.2)°, deterministic by index, sign alternating — sky, not tag cloud
    static func tilt(index: Int) -> Double {
        let magnitude = 0.5 + Double((index * 37) % 8) / 10.0
        return index.isMultiple(of: 2) ? magnitude : -magnitude
    }

    /// each name breathes on its own 3.0...4.5s cycle, phase staggered
    static func breatheCycle(index: Int) -> Double { 3.0 + Double((index * 53) % 16) / 10.0 }
    static func breathePhase(index: Int) -> Double { Double((index * 29) % 12) / 12.0 * 2 * .pi }

    /// stable per-day shuffle: same day → same sky, tomorrow → gently different
    static func shuffled(codes: [String], dayKey: String) -> [String] {
        var arr = codes.sorted()
        guard arr.count > 1 else { return arr }
        var state = GradientSeed.hash(dayKey) | 1
        func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
        var i = arr.count - 1
        while i > 0 {
            let j = Int(next() >> 33) % (i + 1)
            arr.swapAt(i, j)
            i -= 1
        }
        return arr
    }
}

// MARK: - Centered flow layout

/// Wraps subviews into rows and centers each row — a cloud, not a table.
/// A name wider than the row wraps within itself rather than truncating.
struct CenteredFlowLayout: Layout {
    var spacingX: CGFloat = 14
    var spacingY: CGFloat = 10

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for (i, sub) in subviews.enumerated() {
            let ideal = sub.sizeThatFits(.unspecified)
            let size = ideal.width > maxWidth
                ? sub.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                : ideal
            let advance = size.width + (current.items.isEmpty ? 0 : spacingX)
            if !current.items.isEmpty, current.width + advance > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width += size.width + (current.items.isEmpty ? 0 : spacingX)
            current.items.append((i, size))
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let computed = rows(maxWidth: maxWidth, subviews: subviews)
        let height = computed.reduce(0) { $0 + $1.height }
            + spacingY * CGFloat(max(computed.count - 1, 0))
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let computed = rows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in computed {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size))
                x += item.size.width + spacingX
            }
            y += row.height + spacingY
        }
    }
}

// MARK: - The constellation section

struct WorldConstellationSection: View {
    let bucket: WorldDayBucket
    let isToday: Bool
    let dayKey: String
    let countryName: (String) -> String

    @State private var selectedCode: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ink = Color(hex: "#F2EEE3")
    private let ink2 = Color(hex: "#BFB9AA")
    private let peach = Color(hex: "#F5C6AA")

    var body: some View {
        let entries = bucket.countries
        let minCount = entries.values.map(\.total).min() ?? 0
        let maxCount = entries.values.map(\.total).max() ?? 0
        let order = WorldConstellationMath.shuffled(codes: Array(entries.keys), dayKey: dayKey)

        VStack(spacing: 14) {
            // the one warm total — the section's emotional headline
            VStack(spacing: 3) {
                Text(WorldConstellationVoice.totalLine(total: bucket.global.total, isToday: isToday))
                    .font(.custom(DinoTheme.customFontName, size: 19))
                    .foregroundColor(ink)
                    .shadow(color: peach.opacity(0.55), radius: 9)
                Text(WorldConstellationVoice.subLine(countries: entries.count))
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(ink2)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            // the cloud — one shared clock, every name on its own breath
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                CenteredFlowLayout(spacingX: 14, spacingY: 10) {
                    ForEach(Array(order.enumerated()), id: \.element) { index, code in
                        let total = entries[code]?.total ?? 0
                        let tint = DinoWorldPalette.moodSwiftUIColor(entries[code]?.dominantMood ?? .partlyCloudy)
                        let presence = WorldConstellationMath.presence(count: total, minCount: minCount, maxCount: maxCount)
                        let breathe = reduceMotion ? 1.0 : 0.8 + 0.2 * sin(
                            time * 2 * .pi / WorldConstellationMath.breatheCycle(index: index)
                                + WorldConstellationMath.breathePhase(index: index))
                        Text(countryName(code))
                            .font(DinoTheme.dinoFont(size: WorldConstellationMath.fontSize(presence)))
                            .foregroundColor(tint)
                            .multilineTextAlignment(.center)
                            .shadow(color: tint.opacity(WorldConstellationMath.glowOpacity(presence) * breathe),
                                    radius: WorldConstellationMath.glowRadius(presence))
                            .rotationEffect(.degrees(WorldConstellationMath.tilt(index: index)))
                            .onTapGesture {
                                HapticManager.shared.light()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCode = selectedCode == code ? nil : code
                                }
                            }
                            .accessibilityElement()
                            .accessibilityLabel("\(countryName(code)), \(WorldConstellationVoice.bubbleLine(count: total, isToday: isToday))")
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }

            // the quiet reveal — one bubble beneath the cloud
            if let code = selectedCode, let counts = entries[code] {
                Text(WorldConstellationVoice.bubbleLine(count: counts.total, isToday: isToday))
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(ink)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: "#232B42").opacity(0.95)))
                    .shadow(color: .black.opacity(0.30), radius: 6, y: 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // tap-away within the section dismisses the bubble
            withAnimation(.easeInOut(duration: 0.2)) { selectedCode = nil }
        }
        .onChange(of: dayKey) { _, _ in selectedCode = nil }
    }
}
