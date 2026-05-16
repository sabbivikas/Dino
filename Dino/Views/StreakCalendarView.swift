//
//  StreakCalendarView.swift
//  Dino
//
//  Phone-optimized streak calendar (iPhone 15 Pro 393x852pt).
//  Source spec: /tmp/dino_design_v8/preview/streak-calendar v2.html
//

import SwiftUI

struct StreakCalendarView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())

    // ── Spec colors (from streak-calendar v2.html) ────────────────
    fileprivate static let INK     = Color(hex: "#3D3A35")
    fileprivate static let INK2    = Color(hex: "#7A7266")
    fileprivate static let INK3    = Color(hex: "#A8A29A")
    fileprivate static var CREAM: Color { DinoTheme.background }
    fileprivate static var PAPER: Color { DinoTheme.cardBackground }
    fileprivate static let PAPER2  = Color(hex: "#F3EDDC")
    fileprivate static let SAGE    = Color(hex: "#A8C5A0")
    fileprivate static let SAGE_D  = Color(hex: "#7BA872")
    fileprivate static let PEACH   = Color(hex: "#F5C6AA")
    fileprivate static let PEACH_D = Color(hex: "#D08060")
    fileprivate static let SKY     = Color(hex: "#A8D4E6")
    fileprivate static let BORDER  = Color(red: 168/255, green: 197/255, blue: 160/255, opacity: 0.28)

    var body: some View {
        ZStack {
            Self.CREAM.ignoresSafeArea()

            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    HeroHeader(displayedMonth: displayedMonth)
                        .onAppear {
                            AnalyticsManager.shared.trackStreakCalendarOpened()
                        }
                        .frame(height: 220)

                    StatCardsRow(
                        currentStreak: dataManager.streakData.currentStreak,
                        longestStreak: dataManager.streakData.longestStreak,
                        totalVisits: dataManager.streakData.activeDates.count
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    CalendarCard(
                        displayedMonth: $displayedMonth,
                        activeDates: dataManager.streakData.activeDates
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                    ClosingNote(currentStreak: dataManager.streakData.currentStreak)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Self.INK2)
                }
            }
        }
    }
}

// MARK: - Hero header (capped at 220pt)
private struct HeroHeader: View {
    let displayedMonth: Date

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: "#FBE9C4"), Color(hex: "#F5C6AA").opacity(0.33), StreakCalendarView.CREAM],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(hex: "#F9D8CC"), Color.clear],
                center: UnitPoint(x: 0.10, y: 0.30), startRadius: 0, endRadius: 200
            )
            RadialGradient(
                colors: [Color(hex: "#FBE9C4"), Color(hex: "#F5D28A"), Color.clear],
                center: UnitPoint(x: 0.80, y: 0.10), startRadius: 0, endRadius: 230
            )

            Hills()
                .frame(height: 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            Sun()
                .frame(width: 70, height: 70)
                .position(x: UIScreen.main.bounds.width - 55, y: 60)

            Image.cached("cut-DinoChecklist")
                .resizable()
                .scaledToFit()
                .frame(width: 120)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .offset(y: 6)
                .allowsHitTesting(false)

            Text(monthYearLabel)
                .font(.custom(DinoTheme.customFontName, size: 13))
                .tracking(0.5)
                .foregroundColor(Color(hex: "#8A5A28"))
                .padding(.top, 24)
                .padding(.leading, 20)

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text("your streaks")
                    .font(.custom(DinoTheme.customFontName, size: 32))
                    .foregroundColor(StreakCalendarView.INK)
                Text("a gentle nudge, not a scoreboard")
                    .font(.custom(DinoTheme.customFontName, size: 13))
                    .foregroundColor(StreakCalendarView.INK2)
                    .padding(.bottom, 24)
            }
            .padding(.leading, 20)
        }
        .clipped()
    }

    private var monthYearLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        let month = f.string(from: displayedMonth).lowercased()
        let yf = DateFormatter()
        yf.dateFormat = "yyyy"
        let year = yf.string(from: displayedMonth)
        return "\(month) \u{00B7} \(year)"
    }
}

// MARK: - Hills
private struct Hills: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Path { p in
                    let scaleX = w / 390
                    let scaleY = h / 120
                    p.move(to: CGPoint(x: 0, y: 90 * scaleY))
                    p.addQuadCurve(to: CGPoint(x: 130 * scaleX, y: 75 * scaleY),
                                   control: CGPoint(x: 60 * scaleX, y: 55 * scaleY))
                    p.addQuadCurve(to: CGPoint(x: 290 * scaleX, y: 60 * scaleY),
                                   control: CGPoint(x: 210 * scaleX, y: 95 * scaleY))
                    p.addQuadCurve(to: CGPoint(x: 390 * scaleX, y: 70 * scaleY),
                                   control: CGPoint(x: 350 * scaleX, y: 40 * scaleY))
                    p.addLine(to: CGPoint(x: 390 * scaleX, y: 120 * scaleY))
                    p.addLine(to: CGPoint(x: 0, y: 120 * scaleY))
                    p.closeSubpath()
                }
                .fill(Color(hex: "#F5D28A").opacity(0.55))

                Path { p in
                    let scaleX = w / 390
                    let scaleY = h / 120
                    p.move(to: CGPoint(x: 0, y: 105 * scaleY))
                    p.addQuadCurve(to: CGPoint(x: 160 * scaleX, y: 95 * scaleY),
                                   control: CGPoint(x: 80 * scaleX, y: 80 * scaleY))
                    p.addQuadCurve(to: CGPoint(x: 320 * scaleX, y: 85 * scaleY),
                                   control: CGPoint(x: 240 * scaleX, y: 108 * scaleY))
                    p.addQuadCurve(to: CGPoint(x: 390 * scaleX, y: 90 * scaleY),
                                   control: CGPoint(x: 370 * scaleX, y: 74 * scaleY))
                    p.addLine(to: CGPoint(x: 390 * scaleX, y: 120 * scaleY))
                    p.addLine(to: CGPoint(x: 0, y: 120 * scaleY))
                    p.closeSubpath()
                }
                .fill(Color(hex: "#E8B98A").opacity(0.65))

                Path { p in
                    let scaleX = w / 390
                    let scaleY = h / 120
                    p.move(to: CGPoint(x: 0, y: 78 * scaleY))
                    p.addQuadCurve(to: CGPoint(x: 200 * scaleX, y: 70 * scaleY),
                                   control: CGPoint(x: 100 * scaleX, y: 55 * scaleY))
                    p.addQuadCurve(to: CGPoint(x: 390 * scaleX, y: 60 * scaleY),
                                   control: CGPoint(x: 295 * scaleX, y: 65 * scaleY))
                }
                .stroke(
                    Color(hex: "#C4925A").opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [1, 5])
                )
            }
        }
    }
}

// MARK: - Sun
private struct Sun: View {
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * 45.0
                let rad = angle * .pi / 180
                let cx: CGFloat = 35
                let cy: CGFloat = 35
                let x1 = cx + CGFloat(cos(rad)) * 18
                let y1 = cy + CGFloat(sin(rad)) * 18
                let x2 = cx + CGFloat(cos(rad)) * 26
                let y2 = cy + CGFloat(sin(rad)) * 26
                Path { p in
                    p.move(to: CGPoint(x: x1, y: y1))
                    p.addLine(to: CGPoint(x: x2, y: y2))
                }
                .stroke(Color(hex: "#D49020"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            Circle()
                .fill(Color(hex: "#F5C84F"))
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(Color(hex: "#D49020"), lineWidth: 1.5))
        }
    }
}

// MARK: - Stat cards row
private struct StatCardsRow: View {
    let currentStreak: Int
    let longestStreak: Int
    let totalVisits: Int

    var body: some View {
        HStack(spacing: 8) {
            StatCard(
                background: Color(hex: "#F5C6AA"),
                iconName: "flame.fill",
                iconColor: Color(hex: "#A8503A"),
                value: currentStreak,
                label: "days blooming"
            )
            StatCard(
                background: Color(hex: "#A8C5A0"),
                iconName: "trophy.fill",
                iconColor: Color(hex: "#5A7A50"),
                value: longestStreak,
                label: "personal best"
            )
            StatCard(
                background: Color(hex: "#A8D4E6"),
                iconName: "calendar",
                iconColor: Color(hex: "#3F6F88"),
                value: totalVisits,
                label: "total visits"
            )
        }
    }
}

private struct StatCard: View {
    let background: Color
    let iconName: String
    let iconColor: Color
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(iconColor)
            Text("\(value)")
                .font(.custom(DinoTheme.customFontName, size: 32))
                .foregroundColor(Color(hex: "#2E2A24"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.custom(DinoTheme.customFontName, size: 10))
                .foregroundColor(Color(hex: "#7A7266"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(background)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Calendar card
private struct CalendarCard: View {
    @Binding var displayedMonth: Date
    let activeDates: Set<String>

    private let dayLabels = ["s", "m", "t", "w", "t", "f", "s"]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                monthNavRow
                    .padding(.horizontal, 6)
                    .padding(.bottom, 12)

                UnderlineDoodle()
                    .stroke(StreakCalendarView.SAGE.opacity(0.6), lineWidth: 1.2)
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)

                HStack(spacing: 0) {
                    ForEach(Array(dayLabels.enumerated()), id: \.offset) { idx, d in
                        Text(d)
                            .font(.custom(DinoTheme.customFontName, size: 13))
                            .foregroundColor((idx == 0 || idx == 6) ? StreakCalendarView.PEACH_D : StreakCalendarView.INK2)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 6)

                grid
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 24).fill(StreakCalendarView.PAPER)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(StreakCalendarView.BORDER, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        StreakCalendarView.SAGE_D.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 4])
                    )
                    .padding(8)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 9, x: 0, y: 6)

            PaperFoldCorner()
                .frame(width: 38, height: 38)
        }
    }

    private var monthNavRow: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                navArrow(left: true)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(monthName(displayedMonth))
                    .font(.custom(DinoTheme.customFontName, size: 22))
                    .foregroundColor(StreakCalendarView.INK)
                Text(yearString(displayedMonth))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .tracking(1)
                    .foregroundColor(StreakCalendarView.INK2)
            }

            Spacer()

            Button { shiftMonth(1) } label: {
                navArrow(left: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func navArrow(left: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(StreakCalendarView.SAGE.opacity(0.15))
                .frame(width: 34, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(StreakCalendarView.BORDER, lineWidth: 1)
                )
            Image(systemName: left ? "chevron.left" : "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(StreakCalendarView.SAGE_D)
        }
    }

    private func shiftMonth(_ delta: Int) {
        let cal = Calendar.current
        if let new = cal.date(byAdding: .month, value: delta, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.18)) {
                displayedMonth = new
            }
        }
    }

    private func monthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: date).lowercased()
    }

    private func yearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }

    // MARK: - Grid
    private var grid: some View {
        let cells = monthCells(for: displayedMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                DayCell(
                    cell: cell,
                    activeDates: activeDates
                )
                .frame(height: 44)
            }
        }
    }

    fileprivate struct CellModel {
        let date: Date?
        let dayNumber: Int?
        let inMonth: Bool
        let isToday: Bool
        let isFuture: Bool
    }

    private func monthCells(for monthDate: Date) -> [CellModel] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        guard let monthInterval = cal.dateInterval(of: .month, for: monthDate) else { return [] }
        let firstOfMonth = monthInterval.start

        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1

        var cells: [CellModel] = []
        for _ in 0..<firstWeekday {
            cells.append(CellModel(date: nil, dayNumber: nil, inMonth: false, isToday: false, isFuture: false))
        }
        for d in 1...daysInMonth {
            guard let date = cal.date(byAdding: .day, value: d - 1, to: firstOfMonth) else { continue }
            let isToday = cal.isDate(date, inSameDayAs: today)
            let isFuture = cal.startOfDay(for: date) > today
            cells.append(CellModel(date: date, dayNumber: d, inMonth: true, isToday: isToday, isFuture: isFuture))
        }
        while cells.count % 7 != 0 {
            cells.append(CellModel(date: nil, dayNumber: nil, inMonth: false, isToday: false, isFuture: false))
        }
        return cells
    }
}

// MARK: - Day cell
private struct DayCell: View {
    let cell: CalendarCard.CellModel
    let activeDates: Set<String>

    var body: some View {
        ZStack {
            if let day = cell.dayNumber, let date = cell.date {
                let isActive = activeDates.contains(StreakData.dateKey(for: date))
                let isToday = cell.isToday
                let isFuture = cell.isFuture

                if isActive {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [StreakCalendarView.SAGE.opacity(0.45), StreakCalendarView.SAGE.opacity(0)],
                                center: .center, startRadius: 0, endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)

                    Circle()
                        .fill(StreakCalendarView.SAGE)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().strokeBorder(StreakCalendarView.SAGE_D, lineWidth: 1.3)
                        )
                        .overlay(
                            Ellipse()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: 10, height: 7)
                                .offset(x: -4, y: -4)
                        )
                }

                if isToday {
                    Circle()
                        .strokeBorder(
                            isActive ? Color.white.opacity(0.85) : StreakCalendarView.SAGE_D.opacity(0.9),
                            style: StrokeStyle(lineWidth: 1.4, dash: [2, 3])
                        )
                        .frame(width: 40, height: 40)
                }

                Text("\(day)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(
                        isActive ? Color.white
                        : isToday ? StreakCalendarView.SAGE_D
                        : isFuture ? StreakCalendarView.INK3
                        : StreakCalendarView.INK
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Underline doodle
private struct UnderlineDoodle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.midY
        p.move(to: CGPoint(x: rect.minX + 2, y: y))
        p.addQuadCurve(
            to: CGPoint(x: rect.midX, y: y),
            control: CGPoint(x: rect.minX + rect.width * 0.25, y: y - 3)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - 2, y: y),
            control: CGPoint(x: rect.minX + rect.width * 0.75, y: y + 3)
        )
        return p
    }
}

// MARK: - Paper-fold corner
private struct PaperFoldCorner: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 38, y: 0))
                p.addLine(to: CGPoint(x: 10, y: 0))
                p.addQuadCurve(to: CGPoint(x: 38, y: 24), control: CGPoint(x: 14, y: 14))
                p.closeSubpath()
            }
            .fill(StreakCalendarView.PAPER2)
            .overlay(
                Path { p in
                    p.move(to: CGPoint(x: 38, y: 0))
                    p.addLine(to: CGPoint(x: 10, y: 0))
                    p.addQuadCurve(to: CGPoint(x: 38, y: 24), control: CGPoint(x: 14, y: 14))
                    p.closeSubpath()
                }
                .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
            )
            Path { p in
                p.move(to: CGPoint(x: 10, y: 0))
                p.addQuadCurve(to: CGPoint(x: 38, y: 24), control: CGPoint(x: 14, y: 14))
            }
            .stroke(Color.black.opacity(0.12), lineWidth: 1)
        }
    }
}

// MARK: - Closing note
private struct ClosingNote: View {
    let currentStreak: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image.cached("dino-only")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                (
                    Text("you showed up ")
                        .foregroundColor(StreakCalendarView.INK)
                    + Text("\(currentStreak) day\(currentStreak == 1 ? "" : "s") in a row")
                        .foregroundColor(StreakCalendarView.PEACH_D)
                        .fontWeight(.semibold)
                    + Text(".")
                        .foregroundColor(StreakCalendarView.INK)
                )
                .font(.custom(DinoTheme.customFontName, size: 14))
                .lineSpacing(2)

                Text("if you miss tomorrow, it's okay. dino will wait. \u{1F331}")
                    .font(.custom(DinoTheme.customFontName, size: 13))
                    .foregroundColor(StreakCalendarView.INK2)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(StreakCalendarView.PEACH.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    StreakCalendarView.PEACH,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
    }
}
