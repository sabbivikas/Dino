//
//  StreakWidgetView.swift
//  DinoLiveActivity
//
//  Streak widget bodies for small + medium families. Uses FlameShape (keyframed
//  via Timeline) + weekly locale-aware dot row.
//

import SwiftUI
import WidgetKit

// MARK: - Small

struct StreakSmallView: View {
    let entry: StreakSnapshot

    var body: some View {
        // Background now comes from the widget's `.containerBackground`.
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                FlameShape(flickerPhase: entry.flickerPhase)
                    .frame(width: 64, height: 64)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.currentStreak)")
                        .font(WidgetTheme.widgetFont(size: 44))
                        .foregroundColor(DinoPalette.flameBrown)
                    Text("days")
                        .font(WidgetTheme.widgetFont(size: 12))
                        .foregroundColor(DinoPalette.streakInkMid)
                }

                Text("showing up")
                    .font(WidgetTheme.widgetFont(size: 10))
                    .foregroundColor(DinoPalette.streakInkMid)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Medium

struct StreakMediumView: View {
    let entry: StreakSnapshot

    private var weeklySymbols: [String] {
        // Locale-aware "S M T W T F S"
        Calendar.current.veryShortWeekdaySymbols
    }

    private var todayIndex: Int {
        // Sunday = 1 → index 0
        (Calendar.current.component(.weekday, from: Date()) - 1 + 7) % 7
    }

    private var encouragement: String {
        switch entry.currentStreak {
        case 0:        return String(localized: "every journey\nstarts today")
        case 1...3:    return String(localized: "you've started\nsomething")
        case 4...6:    return String(localized: "almost a week\nkeep going")
        case 7...13:   return String(localized: "one week\nstrong")
        case 14...20:  return String(localized: "two weeks\nin")
        case 21...29:  return String(localized: "three weeks\nshowing up")
        default:       return String(localized: "unstoppable\n\(entry.currentStreak) days")
        }
    }

    var body: some View {
        // Background now comes from the widget's `.containerBackground`.
        ZStack {
            HStack(spacing: 14) {
                // Left: flame + count
                VStack(spacing: 2) {
                    FlameShape(flickerPhase: entry.flickerPhase)
                        .frame(width: 64, height: 64)

                    Text("\(entry.currentStreak)")
                        .font(WidgetTheme.widgetFont(size: 34))
                        .foregroundColor(DinoPalette.flameBrown)

                    Text("day streak")
                        .font(WidgetTheme.widgetFont(size: 10))
                        .foregroundColor(DinoPalette.streakInkMid)
                }
                .frame(width: 82)

                Divider()
                    .frame(height: 110)
                    .background(DinoPalette.flameBrown.opacity(0.18))

                // Right: encouragement + weekly dots
                VStack(alignment: .leading, spacing: 6) {
                    Text(encouragement)
                        .font(WidgetTheme.widgetFont(size: 17))
                        .foregroundColor(DinoPalette.streakInkDeep)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text("this week")
                        .font(WidgetTheme.widgetFont(size: 10))
                        .foregroundColor(DinoPalette.streakInkMid)

                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            let isActive = entry.weeklyDays.indices.contains(i) && entry.weeklyDays[i]
                            let isToday = i == todayIndex
                            VStack(spacing: 2) {
                                ZStack {
                                    if isToday {
                                        Circle()
                                            .stroke(
                                                DinoPalette.flameBrown,
                                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                            )
                                            .frame(width: 26, height: 26)
                                        Circle()
                                            .fill(DinoPalette.flameOrange)
                                            .frame(width: 14, height: 14)
                                    } else if isActive {
                                        Circle()
                                            .fill(DinoPalette.flameOrange)
                                            .frame(width: 20, height: 20)
                                        Circle()
                                            .stroke(DinoPalette.flameBrown, lineWidth: 1.5)
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Circle()
                                            .stroke(
                                                DinoPalette.flameBrown.opacity(0.55),
                                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                            )
                                            .frame(width: 20, height: 20)
                                    }
                                }

                                Text(weeklySymbols.indices.contains(i) ? weeklySymbols[i].lowercased() : "")
                                    .font(WidgetTheme.widgetFont(size: 9))
                                    .foregroundColor(isToday ? DinoPalette.flameBrown : DinoPalette.streakInkMid.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
    }
}
