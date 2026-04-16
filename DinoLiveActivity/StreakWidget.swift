//
//  StreakWidget.swift
//  DinoLiveActivity
//
//  Home screen widget showing the user's current streak and weekly progress.
//  Tapping opens the app's profile screen via dino://streak deep link.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Timeline Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let longestStreak: Int
    let weeklyDays: [Bool]
}

// MARK: - Timeline Provider

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(
            date: Date(),
            currentStreak: 7,
            longestStreak: 14,
            weeklyDays: [true, true, true, false, true, false, false]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let data = WidgetDataProvider()
        completion(StreakEntry(
            date: Date(),
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak,
            weeklyDays: data.weeklyStreakDays
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let data = WidgetDataProvider()
        let entry = StreakEntry(
            date: Date(),
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak,
            weeklyDays: data.weeklyStreakDays
        )
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Widget Views

private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

struct StreakSmallView: View {
    let streak: Int
    let theme: WidgetTheme

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(theme.accent.opacity(0.18))
                .frame(width: 44, height: 44)
                .overlay(
                    Text("🔥")
                        .font(.system(size: 24))
                )

            Text("\(streak)")
                .font(.custom("DinoInitiativeFont-Regular", size: 32))
                .foregroundColor(theme.accent)

            Text("day streak")
                .font(.custom("DinoInitiativeFont-Regular", size: 11))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardBackground)
    }
}

struct StreakMediumView: View {
    let streak: Int
    let longestStreak: Int
    let weeklyDays: [Bool]
    let theme: WidgetTheme

    var body: some View {
        HStack(spacing: 16) {
            // Left: streak count
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 28))
                    Text("\(streak)")
                        .font(.custom("DinoInitiativeFont-Regular", size: 36))
                        .foregroundColor(theme.accent)
                }

                Text("day streak")
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(theme.textSecondary)

                Spacer()

                Text("best: \(longestStreak)d")
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(theme.textSecondary.opacity(0.7))
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
                            Text(dayLetters[i])
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

struct StreakLargeView: View {
    let streak: Int
    let longestStreak: Int
    let weeklyDays: [Bool]
    let theme: WidgetTheme

    private var motivationalText: String {
        switch streak {
        case 0:       return "every journey starts with a single day."
        case 1...3:   return "you've started something great. keep going."
        case 4...6:   return "almost a week — you're building a habit."
        case 7...13:  return "one week strong. momentum is on your side."
        case 14...20: return "two weeks in. this is becoming who you are."
        case 21...29: return "three weeks of showing up. incredible."
        default:      return "you're unstoppable. \(streak) days and counting."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Text("🔥")
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak) day streak")
                        .font(.custom("DinoInitiativeFont-Regular", size: 22))
                        .foregroundColor(theme.textPrimary)
                    Text("longest: \(longestStreak) days")
                        .font(.custom("DinoInitiativeFont-Regular", size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
            }

            Divider()
                .background(theme.divider)

            // Weekly progress
            VStack(alignment: .leading, spacing: 8) {
                Text("this week")
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(theme.textSecondary)

                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(weeklyDays.indices.contains(i) && weeklyDays[i]
                                      ? theme.accent
                                      : theme.divider)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    weeklyDays.indices.contains(i) && weeklyDays[i]
                                    ? Text("✓")
                                        .font(.custom("DinoInitiativeFont-Regular", size: 12))
                                        .foregroundColor(.white)
                                    : nil
                                )
                            Text(dayLetters[i])
                                .font(.custom("DinoInitiativeFont-Regular", size: 10))
                                .foregroundColor(theme.textSecondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Divider()
                .background(theme.divider)

            // Motivational text
            Text(motivationalText)
                .font(.custom("DinoInitiativeFont-Regular", size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer()
        }
        .padding(16)
        .background(theme.cardBackground)
    }
}

struct StreakWidgetEntryView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) var family

    private var theme: WidgetTheme { WidgetTheme.current }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                StreakSmallView(streak: entry.currentStreak, theme: theme)
            case .systemMedium:
                StreakMediumView(
                    streak: entry.currentStreak,
                    longestStreak: entry.longestStreak,
                    weeklyDays: entry.weeklyDays,
                    theme: theme
                )
            case .systemLarge:
                StreakLargeView(
                    streak: entry.currentStreak,
                    longestStreak: entry.longestStreak,
                    weeklyDays: entry.weeklyDays,
                    theme: theme
                )
            default:
                StreakSmallView(streak: entry.currentStreak, theme: theme)
            }
        }
        .widgetURL(URL(string: "dino://streak"))
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Declaration

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Track your daily wellness streak and weekly progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    StreakWidget()
} timeline: {
    StreakEntry(
        date: .now,
        currentStreak: 7,
        longestStreak: 14,
        weeklyDays: [true, true, true, false, true, true, false]
    )
}
