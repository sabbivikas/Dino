//
//  MoodNightView.swift
//  DinoLiveActivity
//
//  Night (8pm–6am) mood scene for small + medium families.
//  Night sky + stars + moon + mountain silhouette + WidgetMascotNight mascot.
//

import SwiftUI
import WidgetKit

// MARK: - Small (night)

struct MoodNightSmallView: View {
    let entry: MoodSnapshot

    var body: some View {
        ZStack {
            WidgetGradients.moodNight

            // Stars scattered across upper band
            StarsShape()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Moon top-right
            MoonShape()
                .frame(width: 34, height: 34)
                .position(x: 130, y: 34)

            // Mountains bottom
            VStack {
                Spacer()
                MountainsShape()
                    .frame(height: 80)
            }

            // Mascot bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image("WidgetMascotNight")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .offset(x: 10, y: 10)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("tonight")
                    .font(WidgetTheme.widgetFont(size: 10))
                    .foregroundColor(DinoPalette.nightTextSecondary)
                    .textCase(.uppercase)
                Text("time to\nslow down")
                    .font(WidgetTheme.widgetFont(size: 17))
                    .foregroundColor(DinoPalette.nightTextPrimary)
                    .lineLimit(2)
                Spacer()
                Text("reflect gently")
                    .font(WidgetTheme.widgetFont(size: 10))
                    .foregroundColor(DinoPalette.nightTextSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Large (night)

struct MoodNightLargeView: View {
    let entry: MoodSnapshot

    private var weeklyDays: [Bool] {
        WidgetDataProvider().weeklyStreakDays
    }

    private var todayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) - 1 + 7) % 7
    }

    private var weeklySymbols: [String] {
        Calendar.current.veryShortWeekdaySymbols
    }

    private let nightPurple = Color(hex: "#7B8CDE")

    var body: some View {
        ZStack {
            WidgetGradients.moodNight

            // Stars across the upper band
            StarsShape()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Moon top-right
            MoonShape()
                .frame(width: 56, height: 56)
                .position(x: 290, y: 60)

            // Mountains bottom
            VStack {
                Spacer()
                MountainsShape()
                    .frame(height: 130)
            }

            // Mascot bottom-right, bleeds past the edge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image("WidgetMascotNight")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170, height: 170)
                        .offset(x: 22, y: 22)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("tonight")
                    .font(WidgetTheme.widgetFont(size: 12))
                    .foregroundColor(DinoPalette.nightTextSecondary)
                    .textCase(.uppercase)

                Text("time to slow down.")
                    .font(WidgetTheme.widgetFont(size: 30))
                    .foregroundColor(DinoPalette.nightTextPrimary)
                    .lineLimit(1)

                Text("a quiet moment to reflect on your day")
                    .font(WidgetTheme.widgetFont(size: 13))
                    .foregroundColor(DinoPalette.nightTextSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text("this week")
                    .font(WidgetTheme.widgetFont(size: 11))
                    .foregroundColor(DinoPalette.nightTextSecondary)

                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        let isActive = weeklyDays.indices.contains(i) && weeklyDays[i]
                        let isToday = i == todayIndex
                        VStack(spacing: 3) {
                            ZStack {
                                if isToday {
                                    Circle()
                                        .stroke(nightPurple, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                                        .frame(width: 30, height: 30)
                                    Circle()
                                        .fill(nightPurple)
                                        .frame(width: 16, height: 16)
                                } else if isActive {
                                    Circle()
                                        .fill(nightPurple)
                                        .frame(width: 26, height: 26)
                                } else {
                                    Circle()
                                        .stroke(nightPurple.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                                        .frame(width: 26, height: 26)
                                }
                            }
                            Text(weeklySymbols.indices.contains(i) ? weeklySymbols[i].lowercased() : "")
                                .font(WidgetTheme.widgetFont(size: 10))
                                .foregroundColor(isToday ? nightPurple : DinoPalette.nightTextSecondary.opacity(0.75))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Medium (night)

struct MoodNightMediumView: View {
    let entry: MoodSnapshot

    var body: some View {
        ZStack {
            WidgetGradients.moodNight

            // Stars across top
            StarsShape()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Moon
            MoonShape()
                .frame(width: 44, height: 44)
                .position(x: 260, y: 36)

            // Mountains
            VStack {
                Spacer()
                MountainsShape()
                    .frame(height: 90)
            }

            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("tonight")
                        .font(WidgetTheme.widgetFont(size: 11))
                        .foregroundColor(DinoPalette.nightTextSecondary)
                        .textCase(.uppercase)

                    Text("time to\nslow down")
                        .font(WidgetTheme.widgetFont(size: 22))
                        .foregroundColor(DinoPalette.nightTextPrimary)
                        .lineLimit(2)

                    Spacer()

                    Text("take a quiet moment")
                        .font(WidgetTheme.widgetFont(size: 11))
                        .foregroundColor(DinoPalette.nightTextSecondary)
                }
                .padding(.vertical, 12)
                .padding(.leading, 14)

                Spacer(minLength: 0)

                Image("WidgetMascotNight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .offset(x: 8, y: 12)
            }
        }
    }
}
