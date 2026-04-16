//
//  DailyAffirmationWidget.swift
//  DinoLiveActivity
//
//  Home screen widget showing a daily affirmation that rotates each day.
//  Tapping opens the app via dino://affirmation deep link.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Affirmations

private let affirmations: [String] = [
    "I am enough, exactly as I am.",
    "Each breath brings me closer to peace.",
    "I choose calm over chaos.",
    "My feelings are valid and worth honoring.",
    "I give myself permission to rest.",
    "Growth happens one small step at a time.",
    "I am worthy of love and kindness.",
    "Today I choose to be gentle with myself.",
    "I trust the process of my own journey.",
    "My presence is a gift to the world.",
    "I release what I cannot control.",
    "I am stronger than I think.",
    "Stillness is my superpower.",
    "I deserve joy, even in small moments.",
    "I am becoming the best version of myself.",
    "My mind is calm, my heart is open.",
    "I welcome new beginnings with ease.",
    "I am grateful for this moment.",
    "Every day is a fresh start.",
    "I radiate warmth and compassion.",
    "I honor my need for rest and renewal.",
    "I am exactly where I need to be.",
    "My inner peace is unshakeable.",
    "I attract what I put into the world.",
    "I am learning and that is enough.",
    "Small steps forward still move me forward.",
    "I choose kindness — starting with myself.",
    "This too shall pass, and I am okay.",
    "I embrace the beauty of today.",
    "I am rooted, resilient, and at peace."
]

private func todayAffirmation() -> String {
    let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    let index = (dayOfYear - 1) % affirmations.count
    return affirmations[index]
}

// MARK: - Timeline Entry

struct DailyAffirmationEntry: TimelineEntry {
    let date: Date
    let affirmation: String
}

// MARK: - Timeline Provider

struct DailyAffirmationProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyAffirmationEntry {
        DailyAffirmationEntry(date: Date(), affirmation: "I am enough, exactly as I am.")
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyAffirmationEntry) -> Void) {
        completion(DailyAffirmationEntry(date: Date(), affirmation: todayAffirmation()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyAffirmationEntry>) -> Void) {
        var entries: [DailyAffirmationEntry] = []
        let calendar = Calendar.current

        // Generate entries for today + next 6 days
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) else { continue }
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: day) ?? 1
            let index = (dayOfYear - 1) % affirmations.count
            entries.append(DailyAffirmationEntry(date: day, affirmation: affirmations[index]))
        }

        // Refresh at start of next day
        let tomorrow = calendar.startOfDay(for: Date()).addingTimeInterval(86400)
        let timeline = Timeline(entries: entries, policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct DailyAffirmationSmallView: View {
    let affirmation: String
    let theme: WidgetTheme

    var body: some View {
        VStack(spacing: 6) {
            Text("✨")
                .font(.system(size: 22))

            Text(affirmation)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.8)

            Text("daily affirmation")
                .font(.system(size: 8, weight: .regular, design: .rounded))
                .foregroundColor(theme.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardBackground)
    }
}

struct DailyAffirmationMediumView: View {
    let affirmation: String
    let theme: WidgetTheme

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("✨")
                    .font(.system(size: 28))
                Text("daily\naffirmation")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.accent)
                    .lineLimit(2)
            }

            Divider()
                .background(theme.divider)
                .frame(height: 60)

            VStack(alignment: .leading, spacing: 6) {
                Text("\u{201C}")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.accent.opacity(0.5))
                    .offset(y: 4)

                Text(affirmation)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(theme.cardBackground)
    }
}

struct DailyAffirmationLargeView: View {
    let affirmation: String
    let theme: WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Text("✨")
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text("daily affirmation")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text(Date(), style: .date)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
            }

            Divider()
                .background(theme.divider)

            // Quote
            VStack(alignment: .leading, spacing: 8) {
                Text("\u{201C}")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(theme.accent.opacity(0.4))
                    .offset(y: 8)

                Text(affirmation)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\u{201D}")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(theme.accent.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: -8)
            }

            Spacer()

            Divider()
                .background(theme.divider)

            // Footer
            HStack {
                Text("reflect on this today")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("tap to read more")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(theme.accent)
            }
        }
        .padding(16)
        .background(theme.cardBackground)
    }
}

struct DailyAffirmationEntryView: View {
    let entry: DailyAffirmationEntry
    @Environment(\.widgetFamily) var family

    private var theme: WidgetTheme { WidgetTheme.current }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                DailyAffirmationSmallView(affirmation: entry.affirmation, theme: theme)
            case .systemMedium:
                DailyAffirmationMediumView(affirmation: entry.affirmation, theme: theme)
            case .systemLarge:
                DailyAffirmationLargeView(affirmation: entry.affirmation, theme: theme)
            default:
                DailyAffirmationSmallView(affirmation: entry.affirmation, theme: theme)
            }
        }
        .widgetURL(URL(string: "dino://affirmation"))
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Declaration

struct DailyAffirmationWidget: Widget {
    let kind: String = "DailyAffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyAffirmationProvider()) { entry in
            DailyAffirmationEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Affirmation")
        .description("A calming affirmation that changes every day to ground and inspire you.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    DailyAffirmationWidget()
} timeline: {
    DailyAffirmationEntry(date: .now, affirmation: "I am enough, exactly as I am.")
}
