//
//  StreakWidget.swift
//  DinoLiveActivity
//
//  Home-screen streak widget. Small + medium. Hand-drawn flame (keyframed by
//  the TimelineProvider) + streak count + locale-aware weekly dot row.
//
//  kind = "StreakWidget" preserved from the prior implementation.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct StreakTimelineProvider: TimelineProvider {
    typealias Entry = StreakSnapshot

    // 6 flicker keyframes per the plan
    private let flickerPhases: [Double] = [0.00, 0.18, 0.36, 0.58, 0.80, 0.95]

    func placeholder(in context: Context) -> StreakSnapshot {
        StreakSnapshot(
            date: Date(),
            currentStreak: 7,
            longestStreak: 14,
            weeklyDays: [true, true, true, false, true, false, false],
            flickerPhase: 0.4
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakSnapshot) -> Void) {
        let data = WidgetDataProvider()
        completion(StreakSnapshot(
            date: Date(),
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak,
            weeklyDays: data.weeklyStreakDays,
            flickerPhase: 0.0
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakSnapshot>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let data = WidgetDataProvider()

        var entries: [StreakSnapshot] = []

        // Primary entry at now
        entries.append(StreakSnapshot(
            date: now,
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak,
            weeklyDays: data.weeklyStreakDays,
            flickerPhase: flickerPhases[0]
        ))

        // 6 entries at 10-min cadence starting at the next 10-min boundary
        let minute = calendar.component(.minute, from: now)
        let delta = (10 - (minute % 10)) % 10
        var startBoundary = calendar.date(byAdding: .minute, value: delta == 0 ? 10 : delta, to: now) ?? now
        startBoundary = calendar.date(
            bySettingHour: calendar.component(.hour, from: startBoundary),
            minute: calendar.component(.minute, from: startBoundary),
            second: 0,
            of: startBoundary
        ) ?? startBoundary

        for step in 0..<6 {
            let d = calendar.date(byAdding: .minute, value: step * 10, to: startBoundary) ?? startBoundary
            entries.append(StreakSnapshot(
                date: d,
                currentStreak: data.currentStreak,
                longestStreak: data.longestStreak,
                weeklyDays: data.weeklyStreakDays,
                flickerPhase: flickerPhases[(step + 1) % flickerPhases.count]
            ))
        }

        // Midnight boundary entry so the streak/day dot rolls over even if the main app hasn't reloaded.
        let midnight = calendar.startOfDay(for: now).addingTimeInterval(86400)
        entries.append(StreakSnapshot(
            date: midnight,
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak,
            weeklyDays: data.weeklyStreakDays,
            flickerPhase: 0.0
        ))

        entries.sort { $0.date < $1.date }

        let last = entries.last?.date ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(last)))
    }
}

// MARK: - Entry View

struct StreakWidgetEntryView: View {
    let entry: StreakSnapshot
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                StreakSmallView(entry: entry)
            case .systemMedium:
                StreakMediumView(entry: entry)
            default:
                StreakSmallView(entry: entry)
            }
        }
        .widgetURL(URL(string: "dino://journal"))
        .containerBackground(WidgetGradients.streak, for: .widget)
    }
}

// MARK: - Widget Declaration

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("streak")
        .description("your streak at a glance — with this week's progress")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    StreakWidget()
} timeline: {
    StreakSnapshot(
        date: .now,
        currentStreak: 7,
        longestStreak: 14,
        weeklyDays: [true, true, true, false, true, false, false],
        flickerPhase: 0.2
    )
}
