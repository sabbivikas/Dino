//
//  StreakCalendarView.swift
//  Dino
//
//  v6 design-system rebuild — warm hand-drawn streak calendar.
//

import SwiftUI

// MARK: - Day State

private enum DayState {
    case empty        // outside the current month grid or future
    case past         // a previously visited day (sage)
    case streak       // a day in the current active streak run (peach)
    case today        // today (dashed sage ring)
    case future       // future dates (plain, dim)
}

private struct DayInfo: Hashable {
    let date: Date
    let state: DayState
    let isMilestone: Bool
    let dayNumber: Int
    let gridIndex: Int   // 0..n-1 position in the LazyVGrid
}

// MARK: - StreakCalendarView

struct StreakCalendarView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    HeroBand(reduceMotion: reduceMotion)

                    StatsRow(
                        currentStreak: dataManager.streakData.currentStreak,
                        longestStreak: dataManager.streakData.longestStreak,
                        monthCount: daysVisitedInDisplayedMonth
                    )

                    CalendarCard(
                        displayedMonth: $displayedMonth,
                        dayInfos: computedDayInfos(),
                        reduceMotion: reduceMotion,
                        canGoForward: canGoForward,
                        onPrev: { shiftMonth(-1) },
                        onNext: { shiftMonth(1) }
                    )

                    MonthProgressRibbon(
                        monthCount: daysVisitedInDisplayedMonth,
                        goal: 30
                    )

                    LegendRow()

                    WarmNoteCard(currentStreak: dataManager.streakData.currentStreak)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120) // room for FAB
            }
            .background(DinoTheme.cream.ignoresSafeArea())

            StreakFAB(
                streakDays: dataManager.streakData.currentStreak,
                action: openGratitudeAddSheet
            )
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("streaks")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func openGratitudeAddSheet() {
        // Route through the existing deep-link tab mechanism (Jar tab = 3),
        // and raise a minimal flag the jar observes to auto-open its add sheet.
        dataManager.presentAddGratitude = true
        dataManager.deepLinkTab = 3
    }

    // MARK: - Month nav

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                displayedMonth = newMonth
            }
        }
    }

    private var canGoForward: Bool {
        let c = calendar.component(.month, from: Date())
        let y = calendar.component(.year, from: Date())
        let dm = calendar.component(.month, from: displayedMonth)
        let dy = calendar.component(.year, from: displayedMonth)
        return dy < y || (dy == y && dm < c)
    }

    // MARK: - Data derivation

    private var daysVisitedInDisplayedMonth: Int {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return 0 }

        var count = 0
        for d in range {
            if let date = calendar.date(byAdding: .day, value: d - 1, to: first),
               dataManager.streakData.isActiveDate(date) {
                count += 1
            }
        }
        return count
    }

    /// Compute the sparkle-milestone dates (days 7/14/30 of the current streak run).
    private var milestoneDates: Set<String> {
        let streak = dataManager.streakData.currentStreak
        guard streak > 0 else { return [] }

        // The current run ends at the most recent active day (lastActiveDate or today).
        let endOfRun = calendar.startOfDay(for: dataManager.streakData.lastActiveDate)
        // streakStartDate = endOfRun − (streak − 1) days
        guard let runStart = calendar.date(byAdding: .day, value: -(streak - 1), to: endOfRun) else {
            return []
        }

        var result = Set<String>()
        for m in [7, 14, 30] where streak >= m {
            if let milestone = calendar.date(byAdding: .day, value: m - 1, to: runStart) {
                result.insert(StreakData.dateKey(for: milestone))
            }
        }
        return result
    }

    /// Days of the current active streak run (as "yyyy-MM-dd" keys).
    private var currentStreakDateKeys: Set<String> {
        let streak = dataManager.streakData.currentStreak
        guard streak > 0 else { return [] }
        let endOfRun = calendar.startOfDay(for: dataManager.streakData.lastActiveDate)
        guard let runStart = calendar.date(byAdding: .day, value: -(streak - 1), to: endOfRun) else {
            return []
        }
        var result = Set<String>()
        for i in 0..<streak {
            if let d = calendar.date(byAdding: .day, value: i, to: runStart) {
                result.insert(StreakData.dateKey(for: d))
            }
        }
        return result
    }

    /// Build the full 7-col grid with day-states for the displayed month.
    private func computedDayInfos() -> [DayInfo?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth) - 1 // 0 = Sunday
        let milestoneKeys = milestoneDates
        let streakKeys = currentStreakDateKeys
        let todayStart = calendar.startOfDay(for: Date())

        var out: [DayInfo?] = Array(repeating: nil, count: weekdayOfFirst)

        for d in range {
            guard let date = calendar.date(byAdding: .day, value: d - 1, to: firstOfMonth) else {
                out.append(nil); continue
            }
            let key = StreakData.dateKey(for: date)
            let isActive = dataManager.streakData.activeDates.contains(key)
            let isToday = calendar.isDate(date, inSameDayAs: todayStart)
            let isFuture = date > todayStart
            let inCurrentStreak = streakKeys.contains(key)

            let state: DayState
            if isToday {
                state = .today
            } else if isFuture {
                state = .future
            } else if inCurrentStreak {
                state = .streak
            } else if isActive {
                state = .past
            } else {
                state = .empty
            }

            out.append(DayInfo(
                date: date,
                state: state,
                isMilestone: milestoneKeys.contains(key),
                dayNumber: d,
                gridIndex: out.count
            ))
        }

        // pad to complete week
        while out.count % 7 != 0 { out.append(nil) }
        return out
    }
}

// MARK: - HeroBand

private struct HeroBand: View {
    let reduceMotion: Bool
    @State private var bloom = false
    @State private var sway = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Warm sky gradient
            LinearGradient(
                colors: [
                    Color(hex: "#FFF6DF"),
                    Color(hex: "#FDEEC2"),
                    Color(hex: "#FAE6A8")
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Dotted hills (3 layers)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    hillPath(width: w, height: h, yBase: h * 0.62, amplitude: 10)
                        .stroke(Color(hex: "#C7B279"), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 6]))
                    hillPath(width: w, height: h, yBase: h * 0.70, amplitude: 8)
                        .stroke(Color(hex: "#C7B279").opacity(0.85), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 6]))
                    hillPath(width: w, height: h, yBase: h * 0.78, amplitude: 6)
                        .stroke(Color(hex: "#C7B279").opacity(0.7), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 6]))
                }
            }

            // Sun (top-right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#FFF2B3"),
                            Color(hex: "#FFD56E"),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 42
                    )
                )
                .frame(width: 84, height: 84)
                .scaleEffect(reduceMotion ? 1.02 : (bloom ? 1.04 : 1.0))
                .opacity(reduceMotion ? 0.92 : (bloom ? 1.0 : 0.85))
                .padding(.top, 20)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 5).repeatForever(autoreverses: true),
                    value: bloom
                )

            // Title
            Text("your streak")
                .font(.custom(DinoTheme.customFontName, size: 32))
                .foregroundColor(DinoTheme.ink)
                .padding(.leading, 20)
                .padding(.top, 20)

            // Mascot, centered at bottom
            Image("dino-only")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(reduceMotion ? 0 : (sway ? 1.2 : -1.2)))
                .offset(y: reduceMotion ? 0 : (sway ? -4 : 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 5.5).repeatForever(autoreverses: true),
                    value: sway
                )
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            if !reduceMotion {
                bloom = true
                sway = true
            }
        }
    }

    private func hillPath(width: CGFloat, height: CGFloat, yBase: CGFloat, amplitude: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: yBase))
        p.addQuadCurve(
            to: CGPoint(x: width * 0.5, y: yBase - amplitude),
            control: CGPoint(x: width * 0.25, y: yBase - amplitude * 2)
        )
        p.addQuadCurve(
            to: CGPoint(x: width, y: yBase),
            control: CGPoint(x: width * 0.75, y: yBase + amplitude)
        )
        return p
    }
}

// MARK: - StatsRow

private struct StatsRow: View {
    let currentStreak: Int
    let longestStreak: Int
    let monthCount: Int

    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: AnyView(
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#F5A25D"), Color(hex: "#E8793B")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                ),
                label: "current streak",
                value: "\(currentStreak)"
            )
            StatCard(
                icon: AnyView(
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DinoTheme.goldStar)
                ),
                label: "best streak",
                value: "\(longestStreak)"
            )
            StatCard(
                icon: AnyView(
                    Image(systemName: "calendar")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#6B8A52"))
                ),
                label: "this month",
                value: "\(monthCount)"
            )
        }
    }
}

private struct StatCard: View {
    let icon: AnyView
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            icon
                .frame(height: 24)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .tracking(0.4)
                .foregroundColor(DinoTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.custom(DinoTheme.customFontName, size: 28))
                .foregroundColor(DinoTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DinoTheme.paper)
        .cornerRadius(20)
        .shadow(color: Color(hex: "#78652D").opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - CalendarCard

private struct CalendarCard: View {
    @Binding var displayedMonth: Date
    let dayInfos: [DayInfo?]
    let reduceMotion: Bool
    let canGoForward: Bool
    let onPrev: () -> Void
    let onNext: () -> Void

    private let weekdayLabels = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

    var body: some View {
        VStack(spacing: 14) {
            // Month ribbon header
            HStack {
                Button(action: onPrev) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#A8886B"))
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Text(monthName.lowercased())
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(DinoTheme.monthRibbonText)
                Spacer()
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(canGoForward ? Color(hex: "#A8886B") : Color(hex: "#A8886B").opacity(0.3))
                        .frame(width: 32, height: 32)
                }
                .disabled(!canGoForward)
            }

            // Weekday row
            HStack(spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label.uppercased())
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(DinoTheme.mutedCalendar)
                        .frame(maxWidth: .infinity)
                }
            }

            // Grid with thread-connector overlay
            calendarGrid
        }
        .padding(20)
        .background(DinoTheme.paper)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    Color(hex: "#A88C5A").opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
                )
                .padding(6)
        )
        .shadow(color: Color(hex: "#78652D").opacity(0.10), radius: 16, x: 0, y: 6)
    }

    private var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    // Grid + thread connectors overlay (Canvas reads gridIndex positions)
    @ViewBuilder
    private var calendarGrid: some View {
        GeometryReader { geo in
            let cols = 7
            let cellW = geo.size.width / CGFloat(cols)
            let cellH: CGFloat = 44
            let rows = Int(ceil(Double(dayInfos.count) / Double(cols)))
            let totalH = cellH * CGFloat(rows)

            ZStack(alignment: .topLeading) {
                // Thread connectors drawn behind cells
                Canvas { ctx, size in
                    let activeIndices: Set<Int> = Set(
                        dayInfos.enumerated().compactMap { (i, info) -> Int? in
                            guard let info = info else { return nil }
                            switch info.state {
                            case .past, .streak, .today: return i
                            default: return nil
                            }
                        }
                    )

                    var path = Path()

                    // Horizontal connectors within a row
                    for i in 0..<dayInfos.count {
                        guard activeIndices.contains(i) else { continue }
                        let col = i % cols
                        if col < cols - 1, activeIndices.contains(i + 1) {
                            let y = (CGFloat(i / cols) + 0.5) * cellH
                            let x1 = (CGFloat(col) + 0.5) * cellW + 16
                            let x2 = (CGFloat(col + 1) + 0.5) * cellW - 16
                            path.move(to: CGPoint(x: x1, y: y))
                            path.addLine(to: CGPoint(x: x2, y: y))
                        }
                    }

                    // Vertical connectors between rows (same col, next row)
                    for i in 0..<dayInfos.count {
                        guard activeIndices.contains(i) else { continue }
                        let below = i + cols
                        if below < dayInfos.count, activeIndices.contains(below) {
                            let col = i % cols
                            let x = (CGFloat(col) + 0.5) * cellW
                            let y1 = (CGFloat(i / cols) + 0.5) * cellH + 16
                            let y2 = (CGFloat(below / cols) + 0.5) * cellH - 16
                            path.move(to: CGPoint(x: x, y: y1))
                            path.addLine(to: CGPoint(x: x, y: y2))
                        }
                    }

                    ctx.stroke(
                        path,
                        with: .color(DinoTheme.threadTan),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 3])
                    )
                }
                .frame(height: totalH)

                // The day grid itself
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: cols),
                    spacing: 0
                ) {
                    ForEach(Array(dayInfos.enumerated()), id: \.offset) { _, info in
                        if let info = info {
                            DayCell(info: info, reduceMotion: reduceMotion)
                                .frame(height: cellH)
                        } else {
                            Color.clear.frame(height: cellH)
                        }
                    }
                }
            }
            .frame(height: totalH)
        }
        .frame(height: CGFloat(Int(ceil(Double(dayInfos.count) / 7.0))) * 44)
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let info: DayInfo
    let reduceMotion: Bool
    @State private var halo = false
    @State private var twinkle = false

    var body: some View {
        ZStack {
            switch info.state {
            case .streak:
                // Halo behind the peach circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DinoTheme.peach.opacity(reduceMotion ? 0.55 : (halo ? 0.8 : 0.5)),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)
                    .scaleEffect(reduceMotion ? 1.04 : (halo ? 1.08 : 1.0))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true),
                        value: halo
                    )

                Circle()
                    .fill(DinoTheme.peach)
                    .frame(width: 32, height: 32)

                Text("\(info.dayNumber)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

            case .past:
                Circle()
                    .fill(DinoTheme.streakSage)
                    .frame(width: 32, height: 32)
                Text("\(info.dayNumber)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white)

            case .today:
                Circle()
                    .fill(DinoTheme.paper)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(
                                Color(hex: "#7BA872"),
                                style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                            )
                    )
                Text("\(info.dayNumber)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(DinoTheme.ink)

            case .future:
                Text("\(info.dayNumber)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(DinoTheme.ink.opacity(0.3))

            case .empty:
                Text("\(info.dayNumber)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(DinoTheme.ink.opacity(0.5))
            }
        }
        .frame(width: 44, height: 44)
        .overlay(alignment: .topTrailing) {
            if info.isMilestone {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DinoTheme.goldStar)
                    .opacity(reduceMotion ? 1 : (twinkle ? 1 : 0.4))
                    .offset(x: 2, y: -2)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 3).repeatForever(autoreverses: true),
                        value: twinkle
                    )
            }
        }
        .onAppear {
            if !reduceMotion {
                halo = true
                twinkle = true
            }
        }
    }
}

// MARK: - MonthProgressRibbon

private struct MonthProgressRibbon: View {
    let monthCount: Int
    let goal: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("this month")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DinoTheme.muted)
                Spacer()
                Text("\(monthCount) of \(goal)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(DinoTheme.ink)
            }

            GeometryReader { geo in
                let w = geo.size.width
                let progress = min(1.0, Double(monthCount) / Double(goal))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#A88C5A").opacity(0.18))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [DinoTheme.streakSage, DinoTheme.peach],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * CGFloat(progress), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(DinoTheme.paper)
        .cornerRadius(18)
        .shadow(color: Color(hex: "#78652D").opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - LegendRow

private struct LegendRow: View {
    var body: some View {
        HStack(spacing: 16) {
            chip(swatch: AnyView(
                Circle().fill(DinoTheme.streakSage).frame(width: 6, height: 6)
            ), label: "past")

            chip(swatch: AnyView(
                Circle().fill(DinoTheme.peach).frame(width: 6, height: 6)
            ), label: "streak")

            chip(swatch: AnyView(
                Circle()
                    .stroke(
                        Color(hex: "#7BA872"),
                        style: StrokeStyle(lineWidth: 1, dash: [1.5, 1.5])
                    )
                    .frame(width: 6, height: 6)
            ), label: "today")

            chip(swatch: AnyView(
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundColor(DinoTheme.goldStar)
            ), label: "milestone")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func chip(swatch: AnyView, label: String) -> some View {
        HStack(spacing: 6) {
            swatch.frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(Color(hex: "#6B5A3C"))
        }
    }
}

// MARK: - WarmNoteCard

private struct WarmNoteCard: View {
    let currentStreak: Int

    var body: some View {
        HStack(spacing: 12) {
            Image("dino-only")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
            Text("small steps, big bloom.")
                .font(.system(size: 14, design: .rounded).italic())
                .foregroundColor(DinoTheme.jarMuted)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(DinoTheme.paper)
        .cornerRadius(18)
        .shadow(color: Color(hex: "#78652D").opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - StreakFAB

private struct StreakFAB: View {
    let streakDays: Int
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if streakDays > 0 {
                HStack(spacing: 4) {
                    Text("🔥").font(.system(size: 12))
                    Text("\(streakDays) day streak")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(DinoTheme.ink)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(DinoTheme.paper)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            }

            Button(action: action) {
                Circle()
                    .fill(DinoTheme.streakSage)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(
                        color: DinoTheme.streakSage.opacity(0.40),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("add gratitude note")
        }
    }
}
