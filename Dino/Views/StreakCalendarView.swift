//
//  StreakCalendarView.swift
//  Dino
//
//  Pixel-faithful port of the v8 “growth” journey + bloom log design.
//  Source: /tmp/dino_design_v8/profile_growth/growth-v1.jsx
//    • Hero: header “your garden” (38pt dino), subtitle 14pt dino color #7A7266
//    • Journey scrubber: day N / 62, stage label, range 0..62 with seed/sprout/growing/bloomed
//    • Bloom log: “this week’s bloom log” — 7 rows mon..sun, day label 12pt #A8A29A,
//      colored 10pt dot per category, label 15pt dino, muted (#A8A29A) if rest day.
//
//  Per-day completion derivation:
//    A day is “completed” if any of journalEntries / moodEntries / gratitudeNotes /
//    breathingSessions / meditationSessions has a record on that calendar day.
//    The dot color reflects the most recent practice that day, by category:
//        journal     → #A8C5A0 (sage)
//        mood        → #E8B4B8 (rose)
//        gratitude   → #F5C84F (gold)
//        breathing   → #C4B8D4 (lilac)
//        meditation  → #C4B8D4 (lilac — paired with breathing in spec)
//

import SwiftUI

struct StreakCalendarView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    // Spec colors
    private let GBG    = Color(hex: "#FAF6EC")       // page background
    private let GINK   = Color(hex: "#3D3A35")       // ink primary
    private let GINK2  = Color(hex: "#7A7266")       // ink muted
    private let GINK3  = Color(hex: "#A8A29A")       // ink very muted
    private let GSURF  = Color(hex: "#FEFBF3")       // card surface
    private let GBORDER = Color(red: 168/255, green: 197/255, blue: 160/255, opacity: 0.25) // rgba(168,197,160,0.25)

    var body: some View {
        ZStack {
            GBG.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                        .padding(.bottom, 12)

                    journeyCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)

                    bloomLog
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    legend
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GINK2)
                }
            }
        }
    }

    // MARK: - Header (spec: padding 72px 22px 12px on phone; we reduce top in nav context)
    // sub 14pt dino #7A7266, title 38pt dino #3D3A35 lineHeight 1.05
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headerSubtitle)
                .font(.custom(DinoTheme.customFontName, size: 14))
                .foregroundColor(GINK2)
            Text("your garden")
                .font(.custom(DinoTheme.customFontName, size: 38))
                .foregroundColor(GINK)
                .padding(.top, 2)
        }
    }

    private var headerSubtitle: String {
        let streak = dataManager.streakData.currentStreak
        if streak == 0 { return "a new season" }
        let cal = Calendar.current
        let todayKey = StreakData.dateKey(for: cal.startOfDay(for: Date()))
        if !dataManager.streakData.activeDates.contains(todayKey) && streak > 0 {
            return "needs a little water"
        }
        return "this season"
    }

    // MARK: - Journey card
    // Spec: bg #FEFBF3, radius 18, border rgba(168,197,160,0.25), padding 14 18,
    //       shadow 0 4 12 rgba(0,0,0,0.04)
    //       row: “day <N> · <stage>” 14pt dino, right tag “journey” 11pt uppercase #A8A29A
    //       progress bar via input range; we render as a sage track + green thumb.
    //       captions row: seed · sprout · growing · bloomed (10pt #A8A29A uppercase)
    private var journeyCard: some View {
        let day = min(dataManager.streakData.currentStreak, 62)
        let stage: String = {
            switch day {
            case 0...6:   return "seedling"
            case 7...13:  return "sprouting"
            case 14...29: return "growing"
            case 30...49: return "blooming"
            default:      return "in full bloom"
            }
        }()
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                // “day <N> · <stage>”
                HStack(spacing: 0) {
                    Text("day ")
                        .foregroundColor(GINK)
                    Text("\(day)")
                        .foregroundColor(GINK)
                        .fontWeight(.semibold)
                    Text(" · ")
                        .foregroundColor(GINK2)
                    Text(stage)
                        .foregroundColor(GINK2)
                }
                .font(.custom(DinoTheme.customFontName, size: 14))
                Spacer()
                Text("journey")
                    .font(.custom(DinoTheme.customFontName, size: 11))
                    .tracking(0.8)
                    .foregroundColor(GINK3)
                    .textCase(.uppercase)
            }
            .padding(.bottom, 8)

            // progress track — sage filled to N/62
            GeometryReader { geo in
                let frac = CGFloat(day) / 62.0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "#E8E4D5"))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color(hex: "#A8C5A0"))
                        .frame(width: geo.size.width * frac, height: 4)
                    // thumb
                    Circle()
                        .fill(Color(hex: "#FEFBF3"))
                        .overlay(Circle().strokeBorder(Color(hex: "#A8C5A0"), lineWidth: 2))
                        .frame(width: 22, height: 22)
                        .shadow(color: Color(red: 168/255, green: 197/255, blue: 160/255, opacity: 0.4), radius: 6, x: 0, y: 2)
                        .offset(x: max(0, geo.size.width * frac - 11))
                }
                .frame(height: 22)
            }
            .frame(height: 22)
            .padding(.bottom, 4)

            HStack {
                stageCaption("seed")
                Spacer()
                stageCaption("sprout")
                Spacer()
                stageCaption("growing")
                Spacer()
                stageCaption("bloomed")
            }
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(GSURF)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18).strokeBorder(GBORDER, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    private func stageCaption(_ s: String) -> some View {
        Text(s)
            .font(.custom(DinoTheme.customFontName, size: 10))
            .tracking(0.8)
            .foregroundColor(GINK3)
            .textCase(.uppercase)
    }

    // MARK: - Bloom log
    // Spec: section label 12pt uppercase #A8A29A letter-spacing 1, padding 0 6 6
    //       card: bg #FEFBF3 radius 20, border rgba(168,197,160,0.25), padding 8 18,
    //             shadow 0 4 12 rgba(0,0,0,0.04)
    //       row: 36pt day column 12pt uppercase #A8A29A; 10pt dot, label 15pt dino
    private var bloomLog: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("this week's bloom log")
                .font(.custom(DinoTheme.customFontName, size: 12))
                .tracking(1.0)
                .foregroundColor(GINK3)
                .textCase(.uppercase)
                .padding(.horizontal, 6)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(weekRows()) { row in
                    BloomRow(
                        dayLabel: row.dayLabel,
                        dotColor: row.dotColor,
                        text: row.text,
                        muted: row.muted,
                        isToday: row.isToday
                    )
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: 20).fill(GSURF))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(GBORDER, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
        }
    }

    // MARK: - Legend
    // Spec: gap 12, dot 8 + label 11 #7A7266
    private var legend: some View {
        HStack(spacing: 12) {
            legendDot(color: Color(hex: "#A8C5A0"), label: "journal")
            legendDot(color: Color(hex: "#E8B4B8"), label: "mood")
            legendDot(color: Color(hex: "#F5C84F"), label: "gratitude")
            legendDot(color: Color(hex: "#C4B8D4"), label: "breathing")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.custom(DinoTheme.customFontName, size: 11))
                .foregroundColor(GINK2)
        }
    }

    // MARK: - Per-day derivation
    private struct WeekRow: Identifiable {
        let id = UUID()
        let date: Date
        let dayLabel: String   // "mon", "tue", ...
        let dotColor: Color?
        let text: String
        let muted: Bool
        let isToday: Bool
    }

    private func weekRows() -> [WeekRow] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var rows: [WeekRow] = []
        let dfDay = DateFormatter()
        dfDay.dateFormat = "EEE"
        for offset in (0..<7).reversed() {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let isToday = cal.isDate(date, inSameDayAs: today)
            let summary = activitySummary(on: date)
            let dayLabel = dfDay.string(from: date).lowercased()
            rows.append(
                WeekRow(
                    date: date,
                    dayLabel: dayLabel,
                    dotColor: summary.dotColor,
                    text: summary.text,
                    muted: summary.muted,
                    isToday: isToday
                )
            )
        }
        return rows
    }

    private struct DaySummary {
        let dotColor: Color?
        let text: String
        let muted: Bool
    }

    private func activitySummary(on date: Date) -> DaySummary {
        let cal = Calendar.current
        // gather counts by category
        let journals = dataManager.journalEntries.filter { cal.isDate($0.date, inSameDayAs: date) }
        let moods = dataManager.moodEntries.filter { cal.isDate($0.date, inSameDayAs: date) }
        let grats = dataManager.gratitudeNotes.filter { cal.isDate($0.createdAt, inSameDayAs: date) }
        let breaths = dataManager.breathingSessions.filter { cal.isDate($0.date, inSameDayAs: date) }
        let meds = dataManager.meditationSessions.filter { cal.isDate($0.date, inSameDayAs: date) }

        // Pick “highlight” category by priority: journal > mood > gratitude > breathing > meditation
        if !journals.isEmpty {
            let label = journals.count == 1
                ? "journaled"
                : "journaled — \(journals.count) entries"
            return DaySummary(dotColor: Color(hex: "#A8C5A0"), text: label, muted: false)
        }
        if !moods.isEmpty {
            return DaySummary(dotColor: Color(hex: "#E8B4B8"), text: "logged mood", muted: false)
        }
        if !grats.isEmpty {
            let label = grats.count == 1
                ? "a gratitude in the jar"
                : "\(grats.count) gratitudes in the jar"
            return DaySummary(dotColor: Color(hex: "#F5C84F"), text: label, muted: false)
        }
        if !breaths.isEmpty {
            let mins = max(1, breaths.reduce(0) { $0 + $1.durationSeconds } / 60)
            return DaySummary(dotColor: Color(hex: "#C4B8D4"), text: "\(mins)-minute breathing", muted: false)
        }
        if !meds.isEmpty {
            return DaySummary(dotColor: Color(hex: "#C4B8D4"), text: "a quiet meditation", muted: false)
        }
        // missed day
        return DaySummary(dotColor: nil, text: "rested — that counts too.", muted: true)
    }
}

// MARK: - BloomRow
// Spec: padding 10 0; day col width 36, 12pt uppercase #A8A29A;
//       dot 10pt with subtle 1.5px border rgba(0,0,0,0.08);
//       text 15pt dino, muted #A8A29A or normal #3D3A35
private struct BloomRow: View {
    let dayLabel: String
    let dotColor: Color?
    let text: String
    let muted: Bool
    let isToday: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(dayLabel)
                .font(.custom(DinoTheme.customFontName, size: 12))
                .tracking(0.6)
                .foregroundColor(Color(hex: "#A8A29A"))
                .textCase(.uppercase)
                .frame(width: 36, alignment: .leading)

            ZStack {
                Circle()
                    .fill(dotColor ?? Color(hex: "#E8E4D5"))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 1.5)
                    )
                if isToday {
                    // ring around today (3pt outside the dot)
                    Circle()
                        .strokeBorder(Color(hex: "#A8C5A0"), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 22, height: 22)

            Text(text)
                .font(.custom(DinoTheme.customFontName, size: 15))
                .foregroundColor(muted ? Color(hex: "#A8A29A") : Color(hex: "#3D3A35"))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}
