//
//  MoodCheckInWidget.swift
//  DinoLiveActivity
//
//  Home screen widget that invites users to check in with their mood.
//  Tapping opens the app's mood screen via dino://mood deep link.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Timeline Entry

struct MoodCheckInEntry: TimelineEntry {
    let date: Date
}

// MARK: - Timeline Provider

struct MoodCheckInProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodCheckInEntry {
        MoodCheckInEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodCheckInEntry) -> Void) {
        completion(MoodCheckInEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodCheckInEntry>) -> Void) {
        let entry = MoodCheckInEntry(date: Date())
        // Refresh at start of next day
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct MoodCheckInWidgetSmallView: View {
    let theme: WidgetTheme
    private let moodEmojis = ["😌", "😊", "😐", "😔"]

    var body: some View {
        VStack(spacing: 6) {
            Image(theme.dinoImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)

            Text("how are\nyou feeling?")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            HStack(spacing: 4) {
                ForEach(moodEmojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 13))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardBackground)
    }
}

struct MoodCheckInWidgetMediumView: View {
    let theme: WidgetTheme
    private let moodOptions: [(emoji: String, label: String)] = [
        ("😌", "calm"),
        ("😊", "happy"),
        ("😐", "okay"),
        ("😔", "low")
    ]

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Image(theme.dinoImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                Text("how are\nyou feeling?")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                Text("tap to check in")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            VStack(spacing: 8) {
                ForEach(moodOptions, id: \.emoji) { option in
                    HStack(spacing: 6) {
                        Text(option.emoji)
                            .font(.system(size: 18))
                        Text(option.label)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textPrimary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: 90)
        }
        .padding(14)
        .background(theme.cardBackground)
    }
}

struct MoodCheckInWidgetLargeView: View {
    let theme: WidgetTheme
    private let moodOptions: [(emoji: String, label: String, description: String)] = [
        ("😌", "calm",  "peaceful and grounded"),
        ("😊", "happy", "bright and energized"),
        ("😐", "okay",  "neither here nor there"),
        ("😔", "low",   "a bit heavy today")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(theme.dinoImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("mood check-in")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text("how are you feeling right now?")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }
            }

            Divider()
                .background(theme.divider)

            // Mood options
            VStack(spacing: 12) {
                ForEach(moodOptions, id: \.emoji) { option in
                    HStack(spacing: 12) {
                        Text(option.emoji)
                            .font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.textPrimary)
                            Text(option.description)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }

            Spacer()

            // CTA
            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.accent)
                Text("tap to open and check in")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(theme.accent)
            }
        }
        .padding(16)
        .background(theme.cardBackground)
    }
}

struct MoodCheckInWidgetEntryView: View {
    let entry: MoodCheckInEntry
    @Environment(\.widgetFamily) var family

    private var theme: WidgetTheme { WidgetTheme.current }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                MoodCheckInWidgetSmallView(theme: theme)
            case .systemMedium:
                MoodCheckInWidgetMediumView(theme: theme)
            case .systemLarge:
                MoodCheckInWidgetLargeView(theme: theme)
            default:
                MoodCheckInWidgetSmallView(theme: theme)
            }
        }
        .widgetURL(URL(string: "dino://mood"))
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Declaration

struct MoodCheckInWidget: Widget {
    let kind: String = "MoodCheckInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodCheckInProvider()) { entry in
            MoodCheckInWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mood Check-In")
        .description("A gentle daily reminder to check in with how you're feeling.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    MoodCheckInWidget()
} timeline: {
    MoodCheckInEntry(date: .now)
}
