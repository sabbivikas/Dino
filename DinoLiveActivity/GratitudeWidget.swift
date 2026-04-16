//
//  GratitudeWidget.swift
//  DinoLiveActivity
//
//  Home screen widget for tracking daily gratitude entries.
//  Tapping opens the app's gratitude jar via dino://gratitude deep link.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Timeline Entry

struct GratitudeEntry: TimelineEntry {
    let date: Date
    let todayCount: Int
    let totalCount: Int
}

// MARK: - Timeline Provider

struct GratitudeProvider: TimelineProvider {
    func placeholder(in context: Context) -> GratitudeEntry {
        GratitudeEntry(date: Date(), todayCount: 2, totalCount: 47)
    }

    func getSnapshot(in context: Context, completion: @escaping (GratitudeEntry) -> Void) {
        let data = WidgetDataProvider()
        completion(GratitudeEntry(
            date: Date(),
            todayCount: data.todayGratitudeCount,
            totalCount: data.totalGratitudeCount
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GratitudeEntry>) -> Void) {
        let data = WidgetDataProvider()
        let entry = GratitudeEntry(
            date: Date(),
            todayCount: data.todayGratitudeCount,
            totalCount: data.totalGratitudeCount
        )
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct GratitudeSmallView: View {
    let todayCount: Int
    let theme: WidgetTheme

    var body: some View {
        VStack(spacing: 6) {
            Text("🫙")
                .font(.system(size: 32))

            Text("\(todayCount)")
                .font(.custom("DinoInitiativeFont-Regular", size: 32))
                .foregroundColor(theme.accent)

            Text(todayCount == 1 ? "gratitude today" : "gratitudes today")
                .font(.custom("DinoInitiativeFont-Regular", size: 10))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardBackground)
    }
}

struct GratitudeMediumView: View {
    let todayCount: Int
    let totalCount: Int
    let theme: WidgetTheme

    // Target: 3 gratitudes per day is "full"
    private let dailyGoal = 3
    private var fillFraction: Double {
        min(Double(todayCount) / Double(dailyGoal), 1.0)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: jar + count
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("🫙")
                        .font(.system(size: 28))
                    Text("\(todayCount)")
                        .font(.custom("DinoInitiativeFont-Regular", size: 34))
                        .foregroundColor(theme.accent)
                }

                Text(todayCount == 1 ? "gratitude today" : "gratitudes today")
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(theme.textSecondary)

                Spacer()

                Text("\(totalCount) total")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(theme.textSecondary.opacity(0.6))
            }

            Divider()
                .background(theme.divider)
                .frame(height: 60)

            // Right: progress + CTA
            VStack(alignment: .leading, spacing: 8) {
                Text("today's jar")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(theme.textSecondary)

                // Progress bar representing today's jar fill
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.divider)
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.accent)
                            .frame(width: geo.size.width * fillFraction, height: 10)
                    }
                }
                .frame(height: 10)

                Text("\(todayCount)/\(dailyGoal) slips added")
                    .font(.custom("DinoInitiativeFont-Regular", size: 10))
                    .foregroundColor(theme.textSecondary.opacity(0.7))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.custom("DinoInitiativeFont-Regular", size: 12))
                        .foregroundColor(theme.accent)
                    Text("add today's gratitude")
                        .font(.custom("DinoInitiativeFont-Regular", size: 11))
                        .foregroundColor(theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(theme.cardBackground)
    }
}

struct GratitudeLargeView: View {
    let todayCount: Int
    let totalCount: Int
    let theme: WidgetTheme

    private let dailyGoal = 3
    private var fillFraction: Double {
        min(Double(todayCount) / Double(dailyGoal), 1.0)
    }

    private var encouragement: String {
        switch todayCount {
        case 0:  return "what are you grateful for today?"
        case 1:  return "a great start — what else?"
        case 2:  return "almost there — one more slip?"
        default: return "your jar is full of good things. ✨"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Text("🫙")
                    .font(.system(size: 36))
                VStack(alignment: .leading, spacing: 2) {
                    Text("gratitude jar")
                        .font(.custom("DinoInitiativeFont-Regular", size: 18))
                        .foregroundColor(theme.textPrimary)
                    Text("\(totalCount) slips total")
                        .font(.custom("DinoInitiativeFont-Regular", size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(todayCount)")
                        .font(.custom("DinoInitiativeFont-Regular", size: 28))
                        .foregroundColor(theme.accent)
                    Text("today")
                        .font(.custom("DinoInitiativeFont-Regular", size: 10))
                        .foregroundColor(theme.textSecondary)
                }
            }

            Divider()
                .background(theme.divider)

            // Today's progress
            VStack(alignment: .leading, spacing: 8) {
                Text("today's progress")
                    .font(.custom("DinoInitiativeFont-Regular", size: 12))
                    .foregroundColor(theme.textSecondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.divider)
                            .frame(height: 14)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.accent)
                            .frame(width: geo.size.width * fillFraction, height: 14)
                    }
                }
                .frame(height: 14)

                Text("\(todayCount) of \(dailyGoal) daily gratitudes added")
                    .font(.custom("DinoInitiativeFont-Regular", size: 11))
                    .foregroundColor(theme.textSecondary.opacity(0.7))
            }

            Divider()
                .background(theme.divider)

            // Encouragement
            Text(encouragement)
                .font(.custom("DinoInitiativeFont-Regular", size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.leading)

            Spacer()

            // CTA
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.custom("DinoInitiativeFont-Regular", size: 16))
                    .foregroundColor(theme.accent)
                Text("tap to add a gratitude")
                    .font(.custom("DinoInitiativeFont-Regular", size: 13))
                    .foregroundColor(theme.accent)
            }
        }
        .padding(16)
        .background(theme.cardBackground)
    }
}

struct GratitudeWidgetEntryView: View {
    let entry: GratitudeEntry
    @Environment(\.widgetFamily) var family

    private var theme: WidgetTheme { WidgetTheme.current }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                GratitudeSmallView(todayCount: entry.todayCount, theme: theme)
            case .systemMedium:
                GratitudeMediumView(
                    todayCount: entry.todayCount,
                    totalCount: entry.totalCount,
                    theme: theme
                )
            case .systemLarge:
                GratitudeLargeView(
                    todayCount: entry.todayCount,
                    totalCount: entry.totalCount,
                    theme: theme
                )
            default:
                GratitudeSmallView(todayCount: entry.todayCount, theme: theme)
            }
        }
        .widgetURL(URL(string: "dino://gratitude"))
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Declaration

struct GratitudeWidget: Widget {
    let kind: String = "GratitudeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GratitudeProvider()) { entry in
            GratitudeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Gratitude Jar")
        .description("See how many gratitudes you've added today and keep the jar filling up.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    GratitudeWidget()
} timeline: {
    GratitudeEntry(date: .now, todayCount: 2, totalCount: 47)
}
