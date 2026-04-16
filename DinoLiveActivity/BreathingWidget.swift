//
//  BreathingWidget.swift
//  DinoLiveActivity
//
//  Home screen widget prompting users to take a breathing break.
//  This is a static widget — NOT the Live Activity.
//  Tapping opens the breathing screen via dino://breathe deep link.
//

import WidgetKit
import SwiftUI

// Color(hex:) is defined in BreathingLiveActivity.swift

// MARK: - Timeline Entry

struct BreathingWidgetEntry: TimelineEntry {
    let date: Date
}

// MARK: - Timeline Provider

struct BreathingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BreathingWidgetEntry {
        BreathingWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (BreathingWidgetEntry) -> Void) {
        completion(BreathingWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreathingWidgetEntry>) -> Void) {
        let entry = BreathingWidgetEntry(date: Date())
        // Refresh every hour — breathing prompts can update throughout the day
        let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextHour))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct BreathingWidgetSmallView: View {
    let theme: WidgetTheme

    var body: some View {
        VStack(spacing: 8) {
            // Calm pulsing circle visual
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.12))
                    .frame(width: 52, height: 52)

                Circle()
                    .fill(theme.accent.opacity(0.22))
                    .frame(width: 36, height: 36)

                Circle()
                    .fill(theme.accent.opacity(0.6))
                    .frame(width: 22, height: 22)

                Text("🌿")
                    .font(.system(size: 13))
            }

            Text("take 1 minute")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)

            Text("breathe")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.cardBackground)
    }
}

struct BreathingWidgetMediumView: View {
    let theme: WidgetTheme

    var body: some View {
        HStack(spacing: 18) {
            // Left: breathing circle
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.10))
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(theme.accent.opacity(0.20))
                    .frame(width: 52, height: 52)

                Circle()
                    .fill(theme.accent.opacity(0.50))
                    .frame(width: 34, height: 34)

                Text("🌿")
                    .font(.system(size: 18))
            }

            // Right: copy
            VStack(alignment: .leading, spacing: 6) {
                Text("breathe")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Text("take a mindful moment and reset with a guided breathing session.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.accent)
                    Text("start breathing")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(theme.cardBackground)
    }
}

struct BreathingWidgetEntryView: View {
    let entry: BreathingWidgetEntry
    @Environment(\.widgetFamily) var family

    private var theme: WidgetTheme { WidgetTheme.current }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                BreathingWidgetSmallView(theme: theme)
            case .systemMedium:
                BreathingWidgetMediumView(theme: theme)
            default:
                BreathingWidgetSmallView(theme: theme)
            }
        }
        .widgetURL(URL(string: "dino://breathe"))
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget Declaration

struct BreathingWidget: Widget {
    let kind: String = "BreathingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BreathingWidgetProvider()) { entry in
            BreathingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Breathing")
        .description("A gentle reminder to take a mindful breathing break.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    BreathingWidget()
} timeline: {
    BreathingWidgetEntry(date: .now)
}
