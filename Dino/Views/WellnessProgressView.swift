//
//  WellnessProgressView.swift
//  Dino
//
//  Weekly wellness journey — a smooth line graph aggregating mood energy
//  and assessment scores across the last 8 weeks, with a small "this week"
//  summary card underneath.
//

import SwiftUI

fileprivate struct WellnessWeekPoint: Identifiable {
    let id = UUID()
    let weekIndex: Int          // 0 = oldest, weekCount-1 = current
    let label: String           // "w1", "w2" …
    let value: Double           // 0...1 normalized wellness score
    let hasData: Bool
}

struct WellnessProgressView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private let weekCount = 8
    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                graphCard
                summaryCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(DinoTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarBackButtonHidden(false)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("your wellness journey")
                .font(.custom(DinoTheme.customFontName, size: 22))
                .foregroundColor(DinoTheme.textPrimary)
            Text("how you've been feeling over time")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundColor(DinoTheme.textSecondary)
        }
    }

    // MARK: - Graph card

    private var graphCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            let points = weeklyPoints()
            let anyData = points.contains { $0.hasData }

            if anyData {
                WellnessLineGraph(points: points)
                    .frame(height: 200)
                    .padding(.top, 8)

                HStack {
                    ForEach(points) { p in
                        Text(p.label)
                            .font(.custom(DinoTheme.customFontName, size: 9))
                            .foregroundColor(DinoTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                emptyState
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DinoTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🌱")
                .font(.system(size: 36))
            Text("start logging your mood to see your journey")
                .font(.custom(DinoTheme.customFontName, size: 14))
                .foregroundColor(DinoTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        let summary = thisWeekSummary()
        return VStack(alignment: .leading, spacing: 12) {
            Text("this week")
                .font(.custom(DinoTheme.customFontName, size: 14))
                .foregroundColor(DinoTheme.textSecondary)

            HStack(alignment: .center, spacing: 16) {
                Text(summary.weatherEmoji)
                    .font(.system(size: 36))
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.moodLabel)
                        .font(.custom(DinoTheme.customFontName, size: 18))
                        .foregroundColor(DinoTheme.textPrimary)
                    Text("\(summary.activeDays) days active")
                        .font(.custom(DinoTheme.customFontName, size: 11))
                        .foregroundColor(DinoTheme.textSecondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("avg energy")
                    .font(.custom(DinoTheme.customFontName, size: 11))
                    .foregroundColor(DinoTheme.textSecondary)
                EnergyBar(level: summary.avgEnergy)
                    .frame(height: 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DinoTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DinoTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Aggregation

    /// Returns 8 WeekPoints, oldest → newest. Value is 0...1 from combined
    /// normalized assessment score (5..25 → 0..1) and mood energy (0..10 → 0..1).
    private func weeklyPoints() -> [WellnessWeekPoint] {
        let now = Date()
        let thisWeekStart = startOfWeek(for: now)
        return (0..<weekCount).map { offset in
            let weeksAgo = weekCount - 1 - offset // oldest first
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeekStart) ?? thisWeekStart
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart

            let assessments = dataManager.assessmentResults.filter {
                $0.date >= weekStart && $0.date < weekEnd
            }
            let moods = dataManager.moodEntries.filter {
                $0.date >= weekStart && $0.date < weekEnd
            }

            var components: [Double] = []
            if !assessments.isEmpty {
                let avg = Double(assessments.reduce(0) { $0 + $1.score }) / Double(assessments.count)
                components.append((avg - 5) / 20)
            }
            if !moods.isEmpty {
                let avgEnergy = Double(moods.reduce(0) { $0 + $1.energyLevel }) / Double(moods.count)
                components.append(avgEnergy / 10)
            }

            let value = components.isEmpty ? 0 : components.reduce(0, +) / Double(components.count)
            return WellnessWeekPoint(
                weekIndex: offset,
                label: "w\(offset + 1)",
                value: max(0, min(1, value)),
                hasData: !components.isEmpty
            )
        }
    }

    private func startOfWeek(for date: Date) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? date
    }

    // MARK: - Summary computations

    private struct ThisWeekSummary {
        let weatherEmoji: String
        let moodLabel: String
        let avgEnergy: Double  // 0...1
        let activeDays: Int
    }

    private func thisWeekSummary() -> ThisWeekSummary {
        let now = Date()
        let weekStart = startOfWeek(for: now)
        let moods = dataManager.moodEntries.filter { $0.date >= weekStart }

        let avgEnergyVal: Double
        if moods.isEmpty {
            avgEnergyVal = 0
        } else {
            avgEnergyVal = Double(moods.reduce(0) { $0 + $1.energyLevel }) / Double(moods.count) / 10
        }

        // Most common weather this week (mode)
        let weather: EmotionalWeather? = {
            var counts: [EmotionalWeather: Int] = [:]
            for m in moods { counts[m.weatherType, default: 0] += 1 }
            return counts.max(by: { $0.value < $1.value })?.key
        }()

        // Active days: any mood / journal / breathing / gratitude touched
        let activeDays: Int = {
            var days = Set<String>()
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            for d in dataManager.moodEntries.map(\.date) where d >= weekStart { days.insert(f.string(from: d)) }
            for d in dataManager.journalEntries.map(\.date) where d >= weekStart { days.insert(f.string(from: d)) }
            for d in dataManager.gratitudeNotes.map(\.createdAt) where d >= weekStart { days.insert(f.string(from: d)) }
            for d in dataManager.breathingSessions.map(\.date) where d >= weekStart { days.insert(f.string(from: d)) }
            return days.count
        }()

        return ThisWeekSummary(
            weatherEmoji: weather?.emoji ?? "🌱",
            moodLabel: weather?.label ?? "no mood logged yet",
            avgEnergy: avgEnergyVal,
            activeDays: activeDays
        )
    }
}

// MARK: - Line graph

private struct WellnessLineGraph: View {
    let points: [WellnessWeekPoint]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = max(points.count - 1, 1)
            let xStep = w / CGFloat(n)

            ZStack {
                // Gradient fill below the curve
                fillPath(width: w, height: h, xStep: xStep)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#A8C5A0").opacity(0.30),
                                Color(hex: "#A8C5A0").opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Stroke curve
                strokePath(width: w, height: h, xStep: xStep)
                    .stroke(
                        Color(hex: "#A8C5A0"),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                // Data points
                ForEach(points) { p in
                    let x = CGFloat(p.weekIndex) * xStep
                    let y = h - CGFloat(p.value) * h
                    pointDot(isToday: p.weekIndex == points.count - 1)
                        .position(x: x, y: y)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func strokePath(width: CGFloat, height: CGFloat, xStep: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        let firstY = height - CGFloat(first.value) * height
        path.move(to: CGPoint(x: 0, y: firstY))

        for i in 1..<points.count {
            let prevX = CGFloat(i - 1) * xStep
            let prevY = height - CGFloat(points[i - 1].value) * height
            let curX = CGFloat(i) * xStep
            let curY = height - CGFloat(points[i].value) * height
            let cp1 = CGPoint(x: (prevX + curX) / 2, y: prevY)
            let cp2 = CGPoint(x: (prevX + curX) / 2, y: curY)
            path.addCurve(to: CGPoint(x: curX, y: curY), control1: cp1, control2: cp2)
        }
        return path
    }

    private func fillPath(width: CGFloat, height: CGFloat, xStep: CGFloat) -> Path {
        var path = strokePath(width: width, height: height, xStep: xStep)
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }

    @ViewBuilder
    private func pointDot(isToday: Bool) -> some View {
        if isToday {
            ZStack {
                Circle()
                    .fill(Color(hex: "#A8C5A0"))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
            }
        } else {
            Circle()
                .fill(Color(hex: "#A8C5A0"))
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Energy bar

private struct EnergyBar: View {
    let level: Double // 0...1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DinoTheme.divider)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#F5D98C"), Color(hex: "#A8C5A0")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(level))))
            }
        }
    }
}
