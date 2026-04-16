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

// MARK: - Widget Views

private let dayLettersF = ["S", "M", "T", "W", "T", "F", "S"]

struct TodaysFocusSmallView: View {
    let focusText: String
    let theme: WidgetTheme

    private var hasFocused: Bool { !focusText.isEmpty }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: hasFocused ? "checkmark.seal.fill" : "timer")
                    .font(.custom("DinoInitiativeFont-Regular", size: 22))
                    .foregroundColor(theme.accent)
            }

            if hasFocused {
                Text(focusText)
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                Text("start today's focus")
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardBackground)
    }
}

struct TodaysFocusMediumView: View {
    let focusText: String
    let weeklyDays: [Bool]
    let theme: WidgetTheme

    private var hasFocused: Bool { !focusText.isEmpty }

    var body: some View {
        HStack(spacing: 16) {
            // Left: icon + status
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: hasFocused ? "checkmark.seal.fill" : "timer")
                            .font(.custom("DinoInitiativeFont-Regular", size: 20))
                            .foregroundColor(theme.accent)
                    }

                    Text("focus")
                        .font(.custom("DinoInitiativeFont-Regular", size: 18))
                        .foregroundColor(theme.textPrimary)
                }

                if hasFocused {
                    Text(focusText)
                        .font(.custom("DinoInitiativeFont-Regular", size: 12))
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text("no focus session yet")
                        .font(.custom("DinoInitiativeFont-Regular", size: 12))
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.custom("DinoInitiativeFont-Regular", size: 11))
                        .foregroundColor(theme.accent)
                    Text(hasFocused ? "continue" : "start focusing")
                        .font(.custom("DinoInitiativeFont-Regular", size: 11))
                        .foregroundColor(theme.accent)
                }
            }

            Divider()
                .background(theme.divider)
                .frame(height: 60)

            // Right: weekly dots
            VStack(alignment: .leading, spacing: 6) {
                Text("this week")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(theme.textSecondary)

                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 3) {
                            Circle()
                                .fill(weeklyDays.indices.contains(i) && weeklyDays[i]
                                      ? theme.accent
                                      : theme.divider)
                                .frame(width: 18, height: 18)
                            Text(dayLettersF[i])
                                .font(.custom("DinoInitiativeFont-Regular", size: 8))
                                .foregroundColor(theme.textSecondary.opacity(0.6))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(theme.cardBackground)
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
