//
//  MoodCheckInWidget.swift
//  DinoLiveActivity
//
//  Home screen widget that invites users to check in with their mood.
//  Tapping opens the app's mood screen via dino://mood deep link.
//  At night (9PM–6AM), shows a calm sleeping dino scene and links to journal.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Timeline Entry

struct MoodCheckInEntry: TimelineEntry {
    let date: Date
    let isNightMode: Bool
}

// MARK: - Timeline Provider

struct MoodCheckInProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodCheckInEntry {
        MoodCheckInEntry(date: Date(), isNightMode: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodCheckInEntry) -> Void) {
        completion(MoodCheckInEntry(date: Date(), isNightMode: isNightTime()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodCheckInEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let isNight = hour >= 21 || hour < 6  // 9PM – 6AM

        var entries: [MoodCheckInEntry] = []
        entries.append(MoodCheckInEntry(date: now, isNightMode: isNight))

        // Schedule transition entries at 9PM and 6AM
        var nextTransition: Date
        if hour >= 21 {
            // Currently night, next transition is 6AM tomorrow
            nextTransition = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now)!
            if nextTransition <= now {
                nextTransition = calendar.date(byAdding: .day, value: 1, to: nextTransition)!
            }
        } else if hour < 6 {
            // Currently night (early morning), next transition is 6AM today
            nextTransition = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now)!
        } else {
            // Currently day, next transition is 9PM today
            nextTransition = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)!
        }

        entries.append(MoodCheckInEntry(date: nextTransition, isNightMode: !isNight))

        let timeline = Timeline(entries: entries, policy: .after(nextTransition.addingTimeInterval(3600)))
        completion(timeline)
    }

    private func isNightTime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 21 || hour < 6
    }
}

// MARK: - Night Mode Color Palette

private let nightBg = Color(hex: "1A1B3D")
private let nightCard = Color(hex: "252650")
private let nightTextPrimary = Color(hex: "E8E8F5")
private let nightTextSecondary = Color(hex: "9898B8")
private let nightAccent = Color(hex: "7B8CDE")

// MARK: - Weekly Tracker Row

struct WeeklyTrackerRow: View {
    let days: [Bool]  // from WidgetDataProvider().weeklyStreakDays
    let dayLabels = ["s", "m", "t", "w", "t", "f", "s"]
    let textColor: Color
    let accentColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let isToday = Calendar.current.component(.weekday, from: Date()) - 1 == index
                VStack(spacing: 3) {
                    Text(dayLabels[index])
                        .font(.custom("DinoInitiativeFont-Regular", size: 8))
                        .foregroundColor(isToday ? accentColor : textColor.opacity(0.5))

                    Circle()
                        .fill(days[index] ? accentColor : textColor.opacity(0.15))
                        .frame(width: 8, height: 8)
                        .overlay(
                            isToday
                                ? Circle().stroke(accentColor, lineWidth: 1.5).frame(width: 12, height: 12)
                                : nil
                        )
                }
            }
        }
    }
}

// MARK: - Night Mode Views

struct NightMoodSmallView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Full-bleed sleeping dino image as background
            Image("DinoSleeping")
                .resizable()
                .scaledToFill()
                .clipped()

            // Semi-transparent overlay for text readability
            LinearGradient(
                colors: [
                    nightBg.opacity(0.65),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft text top-left
            VStack(alignment: .leading, spacing: 3) {
                Text("time to")
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(nightTextPrimary)
                Text("slow down")
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(nightTextPrimary)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(nightBg)
    }
}

struct NightMoodMediumView: View {
    private var weeklyDays: [Bool] { WidgetDataProvider().weeklyStreakDays }

    var body: some View {
        ZStack {
            // Background
            nightBg

            // Sleeping dino on the right (~60%)
            GeometryReader { geo in
                Image("DinoSleeping")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width * 0.62, height: geo.size.height)
                    .clipped()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    // Fade left edge into the background
                    .mask(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Left side content
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()

                    Text("how was\nyour day?")
                        .font(.custom("DinoInitiativeFont-Regular", size: 14))
                        .foregroundColor(nightTextPrimary)
                        .lineLimit(2)

                    Text("take a quiet moment")
                        .font(.custom("DinoInitiativeFont-Regular", size: 10))
                        .foregroundColor(nightTextSecondary)

                    Spacer()

                    // Weekly tracker
                    WeeklyTrackerRow(
                        days: weeklyDays,
                        textColor: nightTextPrimary,
                        accentColor: nightAccent
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NightMoodLargeView: View {
    private var weeklyDays: [Bool] { WidgetDataProvider().weeklyStreakDays }

    var body: some View {
        VStack(spacing: 0) {
            // Top title
            Text("time to slow down")
                .font(.custom("DinoInitiativeFont-Regular", size: 18))
                .foregroundColor(nightTextPrimary)
                .padding(.top, 18)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("a moment to rest and reflect")
                .font(.custom("DinoInitiativeFont-Regular", size: 12))
                .foregroundColor(nightTextSecondary)
                .padding(.top, 4)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Sleeping dino image — prominent center piece
            Image("DinoSleeping")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .cornerRadius(14)

            Spacer()

            // Bottom section
            VStack(spacing: 10) {
                WeeklyTrackerRow(
                    days: weeklyDays,
                    textColor: nightTextPrimary,
                    accentColor: nightAccent
                )

                Text("tap to reflect")
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(nightAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(nightCard)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(nightBg)
    }
}

// MARK: - Day Mode Widget Views (unchanged)

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
                .font(.custom("DinoInitiativeFont-Regular", size: 11))
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
                    .font(.custom("DinoInitiativeFont-Regular", size: 14))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                Text("tap to check in")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            VStack(spacing: 8) {
                ForEach(moodOptions, id: \.emoji) { option in
                    HStack(spacing: 6) {
                        Text(option.emoji)
                            .font(.system(size: 18))
                        Text(option.label)
                            .font(.custom("DinoInitiativeFont-Regular", size: 12))
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
                        .font(.custom("DinoInitiativeFont-Regular", size: 18))
                        .foregroundColor(theme.textPrimary)
                    Text("how are you feeling right now?")
                        .font(.custom("DinoInitiativeFont-Regular", size: 12))
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
                                .font(.custom("DinoInitiativeFont-Regular", size: 14))
                                .foregroundColor(theme.textPrimary)
                            Text(option.description)
                                .font(.custom("DinoInitiativeFont-Regular", size: 11))
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
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(theme.accent)
                Text("tap to open and check in")
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(theme.accent)
            }
        }
        .padding(16)
        .background(theme.cardBackground)
    }
}

// MARK: - Entry View

struct MoodCheckInWidgetEntryView: View {
    let entry: MoodCheckInEntry
    @Environment(\.widgetFamily) var family

    private var theme: WidgetTheme { WidgetTheme.current }

    var body: some View {
        Group {
            if entry.isNightMode {
                // Night mode views
                switch family {
                case .systemSmall:
                    NightMoodSmallView()
                case .systemMedium:
                    NightMoodMediumView()
                case .systemLarge:
                    NightMoodLargeView()
                default:
                    NightMoodSmallView()
                }
            } else {
                // Existing day views — keep unchanged
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
        }
        .widgetURL(URL(string: entry.isNightMode ? "dino://journal" : "dino://mood"))
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
    MoodCheckInEntry(date: .now, isNightMode: false)
    MoodCheckInEntry(date: .now, isNightMode: true)
}
