//
//  MoodCheckInWidget.swift
//  DinoLiveActivity
//
//  Home screen widget that invites users to check in with their mood.
//  Tapping opens the app's mood screen via dino://mood deep link.
//  At night (9PM–6AM), shows a calm sleeping dino scene and links to journal.
//  In the morning (6AM–noon), shows a bright sunrise dino scene.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Time State

enum DinoTimeState {
    case morning   // sunrise (~6AM) to noon
    case day       // noon to 9PM
    case night     // 9PM to 6AM

    static func current(for date: Date = Date()) -> DinoTimeState {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 21 || hour < 6 { return .night }
        if hour < 12 { return .morning }
        return .day
    }

    var deepLink: String {
        switch self {
        case .morning: return "dino://mood"
        case .day: return "dino://mood"
        case .night: return "dino://journal"
        }
    }
}

// MARK: - Timeline Entry

struct MoodCheckInEntry: TimelineEntry {
    let date: Date
    let timeState: DinoTimeState
}

// MARK: - Timeline Provider

struct MoodCheckInProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodCheckInEntry {
        MoodCheckInEntry(date: Date(), timeState: .day)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodCheckInEntry) -> Void) {
        completion(MoodCheckInEntry(date: Date(), timeState: DinoTimeState.current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodCheckInEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let currentState = DinoTimeState.current(for: now)

        var entries: [MoodCheckInEntry] = []
        entries.append(MoodCheckInEntry(date: now, timeState: currentState))

        // Schedule entries at each transition point
        let transitionHours = [6, 12, 21]  // morning, day, night
        let transitionStates: [DinoTimeState] = [.morning, .day, .night]

        for i in 0..<transitionHours.count {
            var target = calendar.date(bySettingHour: transitionHours[i], minute: 0, second: 0, of: now)!
            if target <= now {
                target = calendar.date(byAdding: .day, value: 1, to: target)!
            }
            entries.append(MoodCheckInEntry(date: target, timeState: transitionStates[i]))
        }

        // Sort entries by date
        entries.sort { $0.date < $1.date }

        // Next transition is the second entry (first future one)
        let nextTransition = entries.count > 1 ? entries[1].date : now.addingTimeInterval(3600)
        let timeline = Timeline(entries: entries, policy: .after(nextTransition.addingTimeInterval(60)))
        completion(timeline)
    }
}

// MARK: - Night Mode Color Palette

private let nightBg = Color(hex: "1A1B3D")
private let nightCard = Color(hex: "252650")
private let nightTextPrimary = Color(hex: "E8E8F5")
private let nightTextSecondary = Color(hex: "9898B8")
private let nightAccent = Color(hex: "7B8CDE")

// MARK: - Morning Mode Color Palette

private let morningBg = Color(hex: "F5B731")
private let morningCard = Color(hex: "F0A819")
private let morningTextPrimary = Color(hex: "2D4A2D")
private let morningTextSecondary = Color(hex: "5A6B3A")
private let morningAccent = Color(hex: "2D6B2D")

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

// MARK: - Morning Mode Views

struct MorningMoodSmallView: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Full-bleed morning dino image as background
            Image("DinoMorning")
                .resizable()
                .scaledToFill()
                .clipped()

            // Subtle gradient overlay from top-right for text readability
            LinearGradient(
                colors: [
                    Color.clear,
                    morningBg.opacity(0.55)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            // Bottom-left "good morning" text
            Text("good morning")
                .font(.custom("DinoInitiativeFont-Regular", size: 11))
                .foregroundColor(morningTextPrimary)
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(morningBg)
    }
}

struct MorningMoodMediumView: View {
    private var weeklyDays: [Bool] { WidgetDataProvider().weeklyStreakDays }
    private let motivationalLines = [
        "you're doing great",
        "one step at a time",
        "breathe and begin",
        "today is yours",
        "be gentle with yourself",
    ]

    private var todayLine: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return motivationalLines[day % motivationalLines.count]
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // LEFT SIDE — dino above text, tracker at bottom
                VStack(alignment: .leading, spacing: 0) {
                    // Dino image — fixed size, above greeting
                    Image("DinoMorning")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Spacer().frame(height: 8)

                    // Greeting text
                    Text("good morning")
                        .font(.custom("DinoInitiativeFont-Regular", size: 15))
                        .foregroundColor(morningTextPrimary)
                        .lineLimit(1)

                    Text("take it easy today")
                        .font(.custom("DinoInitiativeFont-Regular", size: 10))
                        .foregroundColor(morningTextSecondary)

                    Spacer()

                    // Weekly tracker at bottom
                    WeeklyTrackerRow(
                        days: weeklyDays,
                        textColor: morningTextPrimary,
                        accentColor: morningAccent
                    )
                }
                .padding(16)
                .frame(width: geo.size.width * 0.52, alignment: .leading)

                // DIVIDER — soft vertical line
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: geo.size.height * 0.6)

                // RIGHT SIDE — motivational text
                VStack(spacing: 4) {
                    Text(todayLine)
                        .font(.custom("DinoInitiativeFont-Regular", size: 13))
                        .foregroundColor(morningTextPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(morningBg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MorningMoodLargeView: View {
    private var weeklyDays: [Bool] { WidgetDataProvider().weeklyStreakDays }

    var body: some View {
        VStack(spacing: 0) {
            // Top: title + subtitle
            Text("good morning")
                .font(.custom("DinoInitiativeFont-Regular", size: 18))
                .foregroundColor(morningTextPrimary)
                .padding(.top, 18)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("a new day begins")
                .font(.custom("DinoInitiativeFont-Regular", size: 12))
                .foregroundColor(morningTextSecondary)
                .padding(.top, 4)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Center: DinoMorning image, prominent
            Image("DinoMorning")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .cornerRadius(14)

            Spacer()

            // Bottom: WeeklyTrackerRow + CTA
            VStack(spacing: 10) {
                WeeklyTrackerRow(
                    days: weeklyDays,
                    textColor: morningTextPrimary,
                    accentColor: morningAccent
                )

                Text("tap to check in")
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(morningAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(morningCard)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(morningBg)
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
            switch entry.timeState {
            case .morning:
                switch family {
                case .systemSmall: MorningMoodSmallView()
                case .systemMedium: MorningMoodMediumView()
                case .systemLarge: MorningMoodLargeView()
                default: MorningMoodSmallView()
                }
            case .day:
                switch family {
                case .systemSmall: MoodCheckInWidgetSmallView(theme: theme)
                case .systemMedium: MoodCheckInWidgetMediumView(theme: theme)
                case .systemLarge: MoodCheckInWidgetLargeView(theme: theme)
                default: MoodCheckInWidgetSmallView(theme: theme)
                }
            case .night:
                switch family {
                case .systemSmall: NightMoodSmallView()
                case .systemMedium: NightMoodMediumView()
                case .systemLarge: NightMoodLargeView()
                default: NightMoodSmallView()
                }
            }
        }
        .widgetURL(URL(string: entry.timeState.deepLink))
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
    MoodCheckInEntry(date: .now, timeState: .morning)
    MoodCheckInEntry(date: .now, timeState: .day)
    MoodCheckInEntry(date: .now, timeState: .night)
}
