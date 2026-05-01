//
//  TodaysFocusWidget.swift
//  DinoLiveActivity
//
//  Home screen widget showing today's focus activity.
//  Tapping opens the app's home screen via dino://focus deep link.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Timeline Entry

struct TodaysFocusEntry: TimelineEntry {
    let date: Date
    let focusText: String       // e.g. "25 min focused today" or "" if none
    let weeklyDays: [Bool]      // 7 bools for weekly completion dots
}

// MARK: - Timeline Provider

struct TodaysFocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaysFocusEntry {
        TodaysFocusEntry(
            date: Date(),
            focusText: "25 min focused today",
            weeklyDays: [true, true, false, true, false, false, false]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaysFocusEntry) -> Void) {
        let data = WidgetDataProvider()
        completion(TodaysFocusEntry(
            date: Date(),
            focusText: data.todayFocus,
            weeklyDays: data.weeklyStreakDays
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysFocusEntry>) -> Void) {
        let data = WidgetDataProvider()
        let entry = TodaysFocusEntry(
            date: Date(),
            focusText: data.todayFocus,
            weeklyDays: data.weeklyStreakDays
        )
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Visual primitives

private let focusBackground = LinearGradient(
    colors: [Color(hex: "#E1ECF4"), Color(hex: "#C8DDED")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let focusInk     = Color(hex: "#11402D")
private let focusInkSoft = Color(hex: "#3F6F4A")
private let focusGreen   = Color(hex: "#0F6F4A")
private let focusSage    = Color(hex: "#A8C5A0")
private let focusPulse   = Color(hex: "#B9D3A8")

private struct ClockFace: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            // Pulse halo behind the clock
            Circle()
                .stroke(focusPulse.opacity(0.3), lineWidth: 2)
                .frame(width: size * 1.22, height: size * 1.22)
            Circle()
                .stroke(focusPulse.opacity(0.18), lineWidth: 1)
                .frame(width: size * 1.4, height: size * 1.4)

            // Clock body
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: size, height: size)
            Circle()
                .stroke(focusGreen, lineWidth: 1.6)
                .frame(width: size, height: size)

            // Hour hatches (4 directions)
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(focusGreen.opacity(0.7))
                    .frame(width: 1.4, height: size * 0.10)
                    .offset(y: -size * 0.42)
                    .rotationEffect(.degrees(Double(i) * 90))
            }

            // Hour hand
            Capsule()
                .fill(focusGreen)
                .frame(width: 2, height: size * 0.28)
                .offset(y: -size * 0.14)
                .rotationEffect(.degrees(40))

            // Minute hand
            Capsule()
                .fill(focusGreen)
                .frame(width: 1.6, height: size * 0.38)
                .offset(y: -size * 0.19)
                .rotationEffect(.degrees(140))

            // Center dot
            Circle()
                .fill(focusGreen)
                .frame(width: size * 0.10, height: size * 0.10)
        }
        .frame(width: size * 1.4, height: size * 1.4)
    }
}

private struct WeeklyDotsRow: View {
    let weeklyDays: [Bool]

    private var weeklySymbols: [String] {
        Calendar.current.veryShortWeekdaySymbols
    }

    private var todayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) - 1 + 7) % 7
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let isActive = weeklyDays.indices.contains(i) && weeklyDays[i]
                let isToday = i == todayIndex
                VStack(spacing: 3) {
                    ZStack {
                        if isToday {
                            Circle()
                                .stroke(focusGreen, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .frame(width: 22, height: 22)
                            Circle()
                                .fill(focusGreen)
                                .frame(width: 12, height: 12)
                        } else if isActive {
                            Circle()
                                .fill(focusSage)
                                .frame(width: 18, height: 18)
                            Circle()
                                .stroke(focusGreen, lineWidth: 1.2)
                                .frame(width: 18, height: 18)
                        } else {
                            Circle()
                                .stroke(focusGreen.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .frame(width: 18, height: 18)
                        }
                    }
                    Text(weeklySymbols.indices.contains(i) ? weeklySymbols[i].lowercased() : "")
                        .font(.custom("DinoInitiativeFont-Regular", size: 9))
                        .foregroundColor(isToday ? focusGreen : focusInkSoft.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Widget Views

struct TodaysFocusSmallView: View {
    let focusText: String
    let theme: WidgetTheme

    private var hasFocused: Bool { !focusText.isEmpty }

    var body: some View {
        VStack(spacing: 6) {
            ClockFace(size: 64)

            Text(hasFocused ? focusText : "start today's focus")
                .font(.custom("DinoInitiativeFont-Regular", size: 12))
                .foregroundColor(focusInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(focusBackground)
    }
}

struct TodaysFocusMediumView: View {
    let focusText: String
    let weeklyDays: [Bool]
    let theme: WidgetTheme

    private var hasFocused: Bool { !focusText.isEmpty }

    private var headline: String {
        hasFocused ? "one session\ndown." : "ready when\nyou are."
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 4) {
                ClockFace(size: 70)
                Text(hasFocused ? focusText : "25 min")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(focusInkSoft)
            }
            .frame(width: 110)

            Divider()
                .background(focusGreen.opacity(0.2))
                .frame(height: 110)

            VStack(alignment: .leading, spacing: 6) {
                Text("today's focus")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(focusInkSoft)
                    .textCase(.lowercase)

                Text(headline)
                    .font(.custom("DinoInitiativeFont-Regular", size: 19))
                    .foregroundColor(focusInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text("this week")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(focusInkSoft)

                WeeklyDotsRow(weeklyDays: weeklyDays)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(focusBackground)
    }
}

struct TodaysFocusWidgetEntryView: View {
    let entry: TodaysFocusEntry
    @Environment(\.widgetFamily) var family

    private var theme: WidgetTheme { WidgetTheme.current }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                TodaysFocusSmallView(focusText: entry.focusText, theme: theme)
            case .systemMedium:
                TodaysFocusMediumView(
                    focusText: entry.focusText,
                    weeklyDays: entry.weeklyDays,
                    theme: theme
                )
            default:
                TodaysFocusSmallView(focusText: entry.focusText, theme: theme)
            }
        }
        .widgetURL(URL(string: "dino://focus"))
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Declaration

struct TodaysFocusWidget: Widget {
    let kind: String = "TodaysFocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysFocusProvider()) { entry in
            TodaysFocusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Focus")
        .description("See your daily focus progress and weekly consistency.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    TodaysFocusWidget()
} timeline: {
    TodaysFocusEntry(
        date: .now,
        focusText: "25 min focused today",
        weeklyDays: [true, true, false, true, false, false, false]
    )
}
