//
//  WorldCountryList.swift
//  Dino
//
//  "lights around the world" as calm glowing rows: a mood dot whose glow
//  scales with volume, the country name in starlight, and a soft glow bar
//  (sqrt of the day's max, floored so tiny countries still show). Top 5 by
//  default; the rest fold behind "and a few from elsewhere". Tap a row to
//  reveal its count. No raw numbers by default; no ranks shouted.
//

import SwiftUI

// MARK: - Pure layout math (tested)

enum WorldCountryLayout {

    /// Spec palette for the redesign — softer/warmer than the globe fireflies.
    static func moodColor(_ mood: EmotionalWeather) -> Color {
        switch mood {
        case .clear:        return Color(hex: "#f6da63")
        case .partlyCloudy: return Color(hex: "#93c6a6")
        case .overwhelmed:  return Color(hex: "#c4b8d4")
        case .drained:      return Color(hex: "#e08b9a")
        }
    }

    /// bar width as a fraction of the track: sqrt vs the day's max, floored at
    /// 10% so the smallest sky is still clearly a light.
    static func barFraction(count: Int, max: Int) -> Double {
        guard max > 0 else { return 0.10 }
        let f = (Double(count) / Double(max)).squareRoot()
        return Swift.max(0.10, Swift.min(1.0, f))
    }

    /// glow radius rides the same curve — present but never blinding.
    static func glowRadius(count: Int, max: Int) -> CGFloat {
        2 + 9 * CGFloat(barFraction(count: count, max: max))
    }

    /// top 5 real countries by volume; the rest (incl. the "elsewhere" bucket)
    /// fold into the quieter lights.
    static func split(_ countries: [String: WorldMoodCounts])
        -> (top: [(code: String, counts: WorldMoodCounts)], rest: [(code: String, counts: WorldMoodCounts)]) {
        let real = countries.filter { $0.key != "elsewhere" }
            .sorted { $0.value.total > $1.value.total }
            .map { (code: $0.key, counts: $0.value) }
        let top = Array(real.prefix(5))
        var rest = Array(real.dropFirst(5))
        if let elsewhere = countries["elsewhere"] {
            rest.append((code: "elsewhere", counts: elsewhere))
        }
        return (top, rest)
    }

    static func maxTotal(_ countries: [String: WorldMoodCounts]) -> Int {
        countries.values.map(\.total).max() ?? 0
    }
}

// MARK: - The section

struct WorldCountryList: View {
    let bucket: WorldDayBucket
    let isToday: Bool
    let countryName: (String) -> String

    @State private var revealed: Set<String>
    @State private var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(bucket: WorldDayBucket, isToday: Bool, countryName: @escaping (String) -> String) {
        self.bucket = bucket
        self.isToday = isToday
        self.countryName = countryName
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        _expanded = State(initialValue: args.contains("-worldQAExpanded"))
        if args.contains("-worldQAReveal"),
           let top = WorldCountryLayout.split(bucket.countries).top.first {
            _revealed = State(initialValue: [top.code])
        } else {
            _revealed = State(initialValue: [])
        }
        #else
        _expanded = State(initialValue: false)
        _revealed = State(initialValue: [])
        #endif
    }

    private let starlight = Color(hex: "#ede8d6")
    private let ink2 = Color(hex: "#9aa0cc")

    var body: some View {
        let parts = WorldCountryLayout.split(bucket.countries)
        let maxTotal = WorldCountryLayout.maxTotal(bucket.countries)

        VStack(alignment: .leading, spacing: 0) {
            Text("lights around the world")
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(ink2)
                .padding(.bottom, 12)

            ForEach(Array(parts.top.enumerated()), id: \.element.code) { i, entry in
                row(code: entry.code, counts: entry.counts, maxTotal: maxTotal, soft: false)
                if i < parts.top.count - 1 || !parts.rest.isEmpty {
                    separator
                }
            }

            if !parts.rest.isEmpty {
                expander
                if expanded {
                    ForEach(Array(parts.rest.enumerated()), id: \.element.code) { i, entry in
                        row(code: entry.code, counts: entry.counts, maxTotal: maxTotal, soft: true)
                        if i < parts.rest.count - 1 { separator }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: Row

    private func row(code: String, counts: WorldMoodCounts, maxTotal: Int, soft: Bool) -> some View {
        let mood = counts.dominantMood ?? .partlyCloudy
        let color = WorldCountryLayout.moodColor(mood)
        let fraction = WorldCountryLayout.barFraction(count: counts.total, max: maxTotal)
        let glow = WorldCountryLayout.glowRadius(count: counts.total, max: maxTotal) * (soft ? 0.7 : 1.0)
        let isRevealed = revealed.contains(code)

        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                if isRevealed { revealed.remove(code) } else { revealed.insert(code) }
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(color.opacity(soft ? 0.85 : 1.0))
                    .frame(width: 11, height: 11)
                    .shadow(color: color.opacity(soft ? 0.6 : 0.85), radius: glow)

                Text(countryName(code))
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(starlight.opacity(soft ? 0.82 : 1.0))
                    .fixedSize(horizontal: false, vertical: true)

                if isRevealed {
                    Text(WorldRedesignVoice.rowCount(counts.total, isToday: isToday))
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(ink2)
                        .transition(.opacity)
                }

                Spacer(minLength: 12)

                glowBar(fraction: fraction, color: color, soft: soft)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WorldRedesignVoice.rowAccessibility(
            country: countryName(code), count: counts.total, isToday: isToday))
        .accessibilityAddTraits(.isButton)
    }

    private func glowBar(fraction: Double, color: Color, soft: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                    .frame(height: 6)
                Capsule().fill(color.opacity(soft ? 0.75 : 1.0))
                    .frame(width: Swift.max(6, geo.size.width * fraction), height: 6)
                    .shadow(color: color.opacity(soft ? 0.4 : 0.6), radius: 4)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(width: 70, height: 14)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }

    // MARK: Expander

    private var expander: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { expanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text(expanded ? WorldRedesignVoice.expanderExpanded : WorldRedesignVoice.expanderCollapsed)
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(ink2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ink2)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? WorldRedesignVoice.expanderExpanded : WorldRedesignVoice.expanderCollapsed)
        .accessibilityValue(expanded ? "expanded" : "collapsed")
        .accessibilityAddTraits(.isButton)
    }
}
