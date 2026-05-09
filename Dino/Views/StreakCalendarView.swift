//
//  StreakCalendarView.swift
//  Dino
//
//  Pixel-faithful port of the v8 streak-calendar design.
//  Source: /tmp/dino_design_v8/preview/streak-calendar v2.html
//

import SwiftUI

struct StreakCalendarView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())

    // ── Spec colors (from streak-calendar v2.html) ──────────────────
    fileprivate static let INK     = Color(hex: "#3D3A35")
    fileprivate static let INK2    = Color(hex: "#7A7266")
    fileprivate static let INK3    = Color(hex: "#A8A29A")
    fileprivate static let CREAM   = Color(hex: "#FAF6EC")
    fileprivate static let PAPER   = Color(hex: "#FEFBF3")
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

            ScrollView {
                VStack(spacing: 0) {
                    HeroHeader(displayedMonth: displayedMonth)
                        .frame(height: 150)

                    StatCardsRow(
                        currentStreak: dataManager.streakData.currentStreak,
                        longestStreak: dataManager.streakData.longestStreak,
                        totalVisits: dataManager.streakData.activeDates.count
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    CalendarCard(
                        displayedMonth: $displayedMonth,
                        activeDates: dataManager.streakData.activeDates
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                    ClosingNote(currentStreak: dataManager.streakData.currentStreak)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 26)
                }
            }
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

// MARK: - Hero header
//
// Spec: 150pt tall, layered radial+linear gradients (peach + golden),
// rolling dotted hills, sun w/ 8 rays top-right, dino mascot bottom-right,
// "<month> · <year>" top-left, "your streaks" + subtitle bottom-left.
private struct HeroHeader: View {
    let displayedMonth: Date

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient stack — radial peach over golden linear
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

            // dotted rolling hills bottom
            Hills()
                .frame(height: 80)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .frame(maxHeight: .infinity, alignment: .bottom)

            // Sun — top right
            Sun()
                .frame(width: 70, height: 70)
                .position(x: UIScreen.main.bounds.width - 55, y: 49)

            // Mascot — bottom right (cut-DinoChecklist)
            Image("cut-DinoChecklist")
                .resizable()
                .scaledToFit()
                .frame(width: 110)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .offset(y: 6)
                .allowsHitTesting(false)

            // Top-left date
            Text(monthYearLabel)
                .font(.custom(DinoTheme.customFontName, size: 13))
                .tracking(0.5)
                .foregroundColor(Color(hex: "#8A5A28"))
                .padding(.top, 20)
                .padding(.leading, 20)

            // Bottom-left titles
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text("your streaks")
                    .font(.custom(DinoTheme.customFontName, size: 30))
                    .foregroundColor(StreakCalendarView.INK)
                Text("a gentle nudge, not a scoreboard")
                    .font(.custom(DinoTheme.customFontName, size: 13))
                    .foregroundColor(StreakCalendarView.INK2)
                    .padding(.bottom, 22)
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

// MARK: - Hills SVG path → SwiftUI Path
private struct Hills: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // back hill — #F5D28A 0.55
                Path { p in
                    let s = CGSize(width: w, height: h)
                    let scaleX = s.width / 390
                    let scaleY = s.height / 120
                    p.move(to: CGPoint(x: 0, y: 90 * scaleY))
                    p.addQuadCurve(
                        to: CGPoint(x: 130 * scaleX, y: 75 * scaleY),
                        control: CGPoint(x: 60 * scaleX, y: 55 * scaleY)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: 290 * scaleX, y: 60 * scaleY),
                        control: CGPoint(x: 210 * scaleX, y: 95 * scaleY)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: 390 * scaleX, y: 70 * scaleY),
                        control: CGPoint(x: 350 * scaleX, y: 40 * scaleY)
                    )
                    p.addLine(to: CGPoint(x: 390 * scaleX, y: 120 * scaleY))
                    p.addLine(to: CGPoint(x: 0, y: 120 * scaleY))
                    p.closeSubpath()
                }
                .fill(Color(hex: "#F5D28A").opacity(0.55))

                // front hill — #E8B98A 0.65
                Path { p in
                    let s = CGSize(width: w, height: h)
                    let scaleX = s.width / 390
                    let scaleY = s.height / 120
                    p.move(to: CGPoint(x: 0, y: 105 * scaleY))
                    p.addQuadCurve(
                        to: CGPoint(x: 160 * scaleX, y: 95 * scaleY),
                        control: CGPoint(x: 80 * scaleX, y: 80 * scaleY)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: 320 * scaleX, y: 85 * scaleY),
                        control: CGPoint(x: 240 * scaleX, y: 108 * scaleY)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: 390 * scaleX, y: 90 * scaleY),
                        control: CGPoint(x: 370 * scaleX, y: 74 * scaleY)
                    )
                    p.addLine(to: CGPoint(x: 390 * scaleX, y: 120 * scaleY))
                    p.addLine(to: CGPoint(x: 0, y: 120 * scaleY))
                    p.closeSubpath()
                }
                .fill(Color(hex: "#E8B98A").opacity(0.65))

                // dotted horizon
                Path { p in
                    let scaleX = w / 390
                    let scaleY = h / 120
                    p.move(to: CGPoint(x: 0, y: 78 * scaleY))
                    p.addQuadCurve(
                        to: CGPoint(x: 200 * scaleX, y: 70 * scaleY),
                        control: CGPoint(x: 100 * scaleX, y: 55 * scaleY)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: 390 * scaleX, y: 60 * scaleY),
                        control: CGPoint(x: 295 * scaleX, y: 65 * scaleY)
                    )
                }
                .stroke(
                    Color(hex: "#C4925A").opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [1, 5])
                )
            }
        }
    }
}

// MARK: - Sun — circle + 8 rays
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
//
// Spec: 3 cards, gap 10, padding 14 16 0; each card paper bg + colored tint wash,
// numeric value 22pt, label 12pt dino, caption 10pt. Tints: PEACH / SAGE / SKY.
private struct StatCardsRow: View {
    let currentStreak: Int
    let longestStreak: Int
    let totalVisits: Int

    var body: some View {
        HStack(spacing: 10) {
            StatCard(
                tint: StreakCalendarView.PEACH,
                ring: StreakCalendarView.PEACH.opacity(0.53),
                value: currentStreak,
                label: "current",
                caption: "days blooming"
            ) { StreakIcon() }
            StatCard(
                tint: StreakCalendarView.SAGE,
                ring: StreakCalendarView.SAGE.opacity(0.53),
                value: longestStreak,
                label: "longest",
                caption: "personal best"
            ) { TrophyIcon() }
            StatCard(
                tint: StreakCalendarView.SKY,
                ring: StreakCalendarView.SKY.opacity(0.53),
                value: totalVisits,
                label: "total",
                caption: "visits"
            ) { CalIcon() }
        }
    }
}

private struct StatCard<Icon: View>: View {
    let tint: Color
    let ring: Color
    let value: Int
    let label: String
    let caption: String
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(StreakCalendarView.PAPER)
            RoundedRectangle(cornerRadius: 18)
                .fill(tint.opacity(0.35))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(ring, lineWidth: 1)
        )
        .overlay(
            VStack(spacing: 2) {
                icon().frame(width: 32, height: 32)
                Text("\(value)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(StreakCalendarView.INK)
                    .padding(.top, 2)
                Text(label)
                    .font(.custom(DinoTheme.customFontName, size: 12))
                    .foregroundColor(StreakCalendarView.INK2)
                    .padding(.top, 2)
                Text(caption)
                    .font(.custom(DinoTheme.customFontName, size: 10))
                    .foregroundColor(StreakCalendarView.INK3)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 3)
        .frame(maxWidth: .infinity)
    }
}

private struct StreakIcon: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 16, y: 26))
                p.addQuadCurve(to: CGPoint(x: 8, y: 16), control: CGPoint(x: 8, y: 24))
                p.addQuadCurve(to: CGPoint(x: 12, y: 8), control: CGPoint(x: 8, y: 11))
                p.addQuadCurve(to: CGPoint(x: 14, y: 14), control: CGPoint(x: 11, y: 13))
                p.addQuadCurve(to: CGPoint(x: 16, y: 4), control: CGPoint(x: 12, y: 8))
                p.addQuadCurve(to: CGPoint(x: 22, y: 12), control: CGPoint(x: 18, y: 10))
                p.addQuadCurve(to: CGPoint(x: 22, y: 18), control: CGPoint(x: 20, y: 15))
                p.addQuadCurve(to: CGPoint(x: 22, y: 24), control: CGPoint(x: 24, y: 21))
                p.addQuadCurve(to: CGPoint(x: 16, y: 26), control: CGPoint(x: 20, y: 26))
                p.closeSubpath()
            }
            .fill(StreakCalendarView.PEACH)
            .overlay(
                Path { p in
                    p.move(to: CGPoint(x: 16, y: 26))
                    p.addQuadCurve(to: CGPoint(x: 8, y: 16), control: CGPoint(x: 8, y: 24))
                    p.addQuadCurve(to: CGPoint(x: 12, y: 8), control: CGPoint(x: 8, y: 11))
                    p.addQuadCurve(to: CGPoint(x: 14, y: 14), control: CGPoint(x: 11, y: 13))
                    p.addQuadCurve(to: CGPoint(x: 16, y: 4), control: CGPoint(x: 12, y: 8))
                    p.addQuadCurve(to: CGPoint(x: 22, y: 12), control: CGPoint(x: 18, y: 10))
                    p.addQuadCurve(to: CGPoint(x: 22, y: 18), control: CGPoint(x: 20, y: 15))
                    p.addQuadCurve(to: CGPoint(x: 22, y: 24), control: CGPoint(x: 24, y: 21))
                    p.addQuadCurve(to: CGPoint(x: 16, y: 26), control: CGPoint(x: 20, y: 26))
                    p.closeSubpath()
                }
                .stroke(StreakCalendarView.PEACH_D, lineWidth: 1.4)
            )
        }
        .frame(width: 32, height: 32)
    }
}

private struct TrophyIcon: View {
    var body: some View {
        ZStack {
            // cup
            Path { p in
                p.move(to: CGPoint(x: 10, y: 8))
                p.addLine(to: CGPoint(x: 22, y: 8))
                p.addLine(to: CGPoint(x: 21, y: 16))
                p.addQuadCurve(to: CGPoint(x: 16, y: 20), control: CGPoint(x: 20, y: 20))
                p.addQuadCurve(to: CGPoint(x: 11, y: 16), control: CGPoint(x: 12, y: 20))
                p.closeSubpath()
            }
            .fill(StreakCalendarView.SAGE)
            .overlay(
                Path { p in
                    p.move(to: CGPoint(x: 10, y: 8))
                    p.addLine(to: CGPoint(x: 22, y: 8))
                    p.addLine(to: CGPoint(x: 21, y: 16))
                    p.addQuadCurve(to: CGPoint(x: 16, y: 20), control: CGPoint(x: 20, y: 20))
                    p.addQuadCurve(to: CGPoint(x: 11, y: 16), control: CGPoint(x: 12, y: 20))
                    p.closeSubpath()
                }
                .stroke(StreakCalendarView.SAGE_D, lineWidth: 1.4)
            )
            // base
            Rectangle()
                .fill(StreakCalendarView.SAGE_D)
                .frame(width: 6, height: 3)
                .offset(x: 0, y: 5.5)
            RoundedRectangle(cornerRadius: 1)
                .fill(StreakCalendarView.SAGE_D)
                .frame(width: 12, height: 2.5)
                .offset(x: 0, y: 8)
            // gem
            Circle()
                .fill(Color(hex: "#FFE082"))
                .frame(width: 3, height: 3)
                .offset(x: 0, y: -3)
        }
        .frame(width: 32, height: 32)
    }
}

private struct CalIcon: View {
    var body: some View {
        ZStack {
            // body
            RoundedRectangle(cornerRadius: 3)
                .fill(StreakCalendarView.SKY)
                .frame(width: 22, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color(hex: "#4A7A95"), lineWidth: 1.3)
                )
            // header
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "#87B8CF"))
                .frame(width: 22, height: 6)
                .offset(y: -6)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color(hex: "#4A7A95"), lineWidth: 1.3)
                        .frame(width: 22, height: 6)
                        .offset(y: -6)
                )
            // hangers
            Capsule()
                .fill(Color(hex: "#4A7A95"))
                .frame(width: 1.6, height: 6)
                .offset(x: -5, y: -10)
            Capsule()
                .fill(Color(hex: "#4A7A95"))
                .frame(width: 1.6, height: 6)
                .offset(x: 7, y: -10)
            // dots
            HStack(spacing: 3) {
                Circle().fill(Color(hex: "#4A7A95")).frame(width: 2.6, height: 2.6)
                Circle().fill(Color(hex: "#4A7A95")).frame(width: 2.6, height: 2.6)
                Circle().fill(Color(hex: "#4A7A95")).frame(width: 2.6, height: 2.6)
            }
            .offset(y: 3)
            HStack(spacing: 3) {
                Circle().fill(Color(hex: "#4A7A95").opacity(0.5)).frame(width: 2.6, height: 2.6)
                Circle().fill(Color(hex: "#4A7A95")).frame(width: 2.6, height: 2.6)
                Circle().fill(Color(hex: "#4A7A95").opacity(0.3)).frame(width: 2.6, height: 2.6)
            }
            .offset(y: 7)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Calendar card
//
// Spec: paper bg, radius 24, dashed sage inner frame, month nav row, dotted underline,
// 7-col grid with weekday labels (s/m/t/w/t/f/s), filled circles for active days,
// dashed sage ring for today, paper-fold corner top-right.
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

                // dotted underline doodle
                UnderlineDoodle()
                    .stroke(StreakCalendarView.SAGE.opacity(0.6), lineWidth: 1.2)
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)

                // weekday header
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

                // grid
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
                // dashed sage inner frame
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        StreakCalendarView.SAGE_D.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 4])
                    )
                    .padding(8)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 9, x: 0, y: 6)

            // paper-fold corner
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
                .frame(height: 48)
            }
        }
    }

    fileprivate struct CellModel {
        let date: Date?       // nil = leading/trailing placeholder
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

        // Sunday-first: weekday is 1..7, Sunday = 1
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
                    // bloom halo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [StreakCalendarView.SAGE.opacity(0.45), StreakCalendarView.SAGE.opacity(0)],
                                center: .center, startRadius: 0, endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)

                    // filled dot
                    Circle()
                        .fill(StreakCalendarView.SAGE)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().strokeBorder(StreakCalendarView.SAGE_D, lineWidth: 1.3)
                        )
                        .overlay(
                            // inner highlight
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
            Image("dino-only")
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
